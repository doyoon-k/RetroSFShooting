using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem.UI;
using UnityEngine.UI;

namespace RetroSF
{
    /// <summary>
    /// Godot's GUI focus layer, shared by every screen and always on unscaled time.
    /// GameInput's ui_up/down/left/right move keyboard focus to the neighbour, ui_accept presses the
    /// focused button, and focus only changes when Godot's would. The EventSystem keeps pointer input
    /// but its own Move/Submit/Cancel are switched off so nothing is handled twice.
    /// Runs after screen scripts: a screen that handled an action first (Godot _input +
    /// set_input_as_handled) calls ConsumeInput so the focused button never sees it.
    /// Also advances every TypewriterText, so a hidden panel keeps typing like Godot's _process.
    /// </summary>
    [DefaultExecutionOrder(1000)]
    public sealed class UiRuntime : MonoBehaviour
    {
        static UiRuntime instance;
        static bool quitting;
        static int consumedFrame = -1;
        static readonly List<TypewriterText> typewriters = new List<TypewriterText>();

        GameObject lastFocus;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        static void ResetStatics()
        {
            instance = null;
            quitting = false;
            consumedFrame = -1;
            typewriters.Clear();
            Application.quitting -= OnQuitting;
            Application.quitting += OnQuitting;
        }

        static void OnQuitting() => quitting = true;

        /// <summary>Creates the runtime (and an EventSystem when the scene has none).</summary>
        public static void Ensure()
        {
            if (quitting || !Application.isPlaying) return;
            if (instance == null)
            {
                var host = new GameObject("UiRuntime");
                DontDestroyOnLoad(host);
                instance = host.AddComponent<UiRuntime>();
            }
            if (EventSystem.current == null) EnsureEventSystem();
        }

        /// <summary>Godot set_input_as_handled() from _input: this frame's ui actions skip the focused button.</summary>
        public static void ConsumeInput() => consumedFrame = Time.frameCount;

        /// <summary>Godot grab_focus(). Ignored for FOCUS_NONE controls, like Godot.</summary>
        public static bool Focus(Selectable target)
        {
            if (target == null || target.navigation.mode == Navigation.Mode.None) return false;
            var eventSystem = EventSystem.current;
            if (eventSystem == null || eventSystem.alreadySelecting) return false;
            eventSystem.SetSelectedGameObject(target.gameObject);
            return true;
        }

        /// <summary>Godot has_focus().</summary>
        public static bool HasFocus(GameObject target)
        {
            var eventSystem = EventSystem.current;
            return target != null && eventSystem != null && eventSystem.currentSelectedGameObject == target;
        }

        public static bool HasFocus(Component target) => target != null && HasFocus(target.gameObject);

        internal static void Track(TypewriterText typewriter)
        {
            Ensure();
            if (!typewriters.Contains(typewriter)) typewriters.Add(typewriter);
        }

        void Awake()
        {
            if (instance != null && instance != this)
            {
                Destroy(gameObject);
                return;
            }
            instance = this;
        }

        void OnDestroy()
        {
            if (instance == this) instance = null;
        }

        void Update()
        {
            TickTypewriters(Time.unscaledDeltaTime);

            var eventSystem = EventSystem.current;
            if (eventSystem == null)
            {
                EnsureEventSystem();
                eventSystem = EventSystem.current;
                if (eventSystem == null) return;
            }
            Configure(eventSystem);
            RestoreFocus(eventSystem);
            if (consumedFrame != Time.frameCount) Navigate(eventSystem);
            lastFocus = eventSystem.currentSelectedGameObject;
        }

        static void TickTypewriters(float delta)
        {
            for (int i = typewriters.Count - 1; i >= 0; i--)
            {
                var typewriter = typewriters[i];
                if (typewriter == null || !typewriter.Typing)
                {
                    typewriters.RemoveAt(i);
                    continue;
                }
                typewriter.Tick(delta);
            }
        }

        static void Configure(EventSystem eventSystem)
        {
            if (eventSystem.sendNavigationEvents) eventSystem.sendNavigationEvents = false;
            // Godot keeps keyboard focus when the mouse clicks something that cannot take focus.
            if (eventSystem.currentInputModule is InputSystemUIInputModule module && module.deselectOnBackgroundClick)
                module.deselectOnBackgroundClick = false;
        }

        /// <summary>
        /// uGUI drops the selection when a FOCUS_NONE button (HUD, Story NEXT) is clicked; Godot keeps it.
        /// Hidden, disabled or unfocusable controls lose focus in both engines and are not restored.
        /// </summary>
        void RestoreFocus(EventSystem eventSystem)
        {
            if (eventSystem.currentSelectedGameObject != null || lastFocus == null) return;
            var selectable = lastFocus.GetComponent<Selectable>();
            if (selectable != null && selectable.isActiveAndEnabled && selectable.IsInteractable()
                && selectable.navigation.mode != Navigation.Mode.None && !eventSystem.alreadySelecting)
                eventSystem.SetSelectedGameObject(lastFocus);
        }

        static void Navigate(EventSystem eventSystem)
        {
            var current = eventSystem.currentSelectedGameObject;
            if (current == null || !current.activeInHierarchy) return;
            var selectable = current.GetComponent<Selectable>();
            if (selectable == null) return;

            Selectable next = null;
            if (GameInput.UiUpPressed) next = Neighbor(selectable, Vector2.up);
            else if (GameInput.UiDownPressed) next = Neighbor(selectable, Vector2.down);
            else if (GameInput.UiLeftPressed) next = Neighbor(selectable, Vector2.left);
            else if (GameInput.UiRightPressed) next = Neighbor(selectable, Vector2.right);
            if (next != null && next != selectable && next.isActiveAndEnabled)
            {
                Focus(next);
                return;
            }

            if (GameInput.UiAcceptPressed && selectable.IsInteractable())
                ExecuteEvents.Execute(current, new BaseEventData(eventSystem), ExecuteEvents.submitHandler);
        }

        /// <summary>Godot focus_neighbor_* when set (Explicit navigation), otherwise Godot's own search.</summary>
        static Selectable Neighbor(Selectable from, Vector2 direction)
        {
            if (from.navigation.mode != Navigation.Mode.Explicit) return FindGodotNeighbor(from, direction);
            if (direction == Vector2.up) return from.FindSelectableOnUp();
            if (direction == Vector2.down) return from.FindSelectableOnDown();
            if (direction == Vector2.left) return from.FindSelectableOnLeft();
            return from.FindSelectableOnRight();
        }

        static readonly Vector3[] corners = new Vector3[4];

        /// <summary>
        /// Godot Control._get_focus_neighbor without neighbours set: among visible FOCUS_ALL controls (disabled
        /// ones included) whose far edge lies beyond this control's far edge in the direction, take the one with
        /// the smallest rect-to-rect distance; the first found wins ties. uGUI's automatic navigation scores by
        /// center alignment instead and picks differently when a grid has gaps (dead pilots in the roster).
        /// </summary>
        static Selectable FindGodotNeighbor(Selectable from, Vector2 direction)
        {
            if (!(from.transform is RectTransform fromRect)) return null;
            var canvas = from.GetComponentInParent<Canvas>();
            Transform space = canvas != null ? canvas.rootCanvas.transform : null;
            Rect origin = RectIn(space, fromRect);
            float limit = Mathf.Max(Vector2.Dot(direction, origin.min), Vector2.Dot(direction, origin.max));
            float closest = float.MaxValue;
            Selectable result = null;
            foreach (var candidate in Selectable.allSelectablesArray)
            {
                if (candidate == from || candidate.navigation.mode == Navigation.Mode.None || !candidate.isActiveAndEnabled)
                    continue;
                if (!(candidate.transform is RectTransform candidateRect)) continue;
                Rect rect = RectIn(space, candidateRect);
                float reach = Mathf.Max(Vector2.Dot(direction, rect.min), Vector2.Dot(direction, rect.max));
                if (reach <= limit + 0.00001f) continue;
                float dx = Gap(origin.xMin, origin.xMax, rect.xMin, rect.xMax);
                float dy = Gap(origin.yMin, origin.yMax, rect.yMin, rect.yMax);
                float distance = dx * dx + dy * dy;
                if (distance < closest)
                {
                    closest = distance;
                    result = candidate;
                }
            }
            return result;
        }

        static float Gap(float aMin, float aMax, float bMin, float bMax)
        {
            if (bMin > aMax) return bMin - aMax;
            if (aMin > bMax) return aMin - bMax;
            return 0f;
        }

        static Rect RectIn(Transform space, RectTransform rect)
        {
            rect.GetWorldCorners(corners);
            Vector2 min = new Vector2(float.MaxValue, float.MaxValue);
            Vector2 max = new Vector2(float.MinValue, float.MinValue);
            foreach (var corner in corners)
            {
                Vector2 point = space != null ? (Vector2)space.InverseTransformPoint(corner) : (Vector2)corner;
                min = Vector2.Min(min, point);
                max = Vector2.Max(max, point);
            }
            return Rect.MinMaxRect(min.x, min.y, max.x, max.y);
        }

        static void EnsureEventSystem()
        {
            if (FindAnyObjectByType<EventSystem>() != null) return;
            var host = new GameObject("EventSystem");
            DontDestroyOnLoad(host);
            var eventSystem = host.AddComponent<EventSystem>();
            eventSystem.sendNavigationEvents = false;
            var module = host.AddComponent<InputSystemUIInputModule>();
            if (module.actionsAsset == null) module.AssignDefaultActions();
            module.deselectOnBackgroundClick = false;
        }
    }
}
