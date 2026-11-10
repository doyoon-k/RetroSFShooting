using System;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace RetroSF
{
    /// <summary>
    /// Godot StyleBoxFlat per button state: background, border and font colour.
    /// The focus style is drawn over the current state like Godot's focus overlay.
    /// Panels use it with only the normal state.
    /// </summary>
    [DisallowMultipleComponent]
    public class UiStyleBox : MonoBehaviour, IPointerEnterHandler, IPointerExitHandler, IPointerDownHandler, IPointerUpHandler
    {
        [Serializable]
        public class State
        {
            public bool used = true;
            public Color background = Color.clear;
            public Color border = Color.clear;
            [Min(0f)] public float borderWidth;
            public Color text = Color.white;
        }

        public Image background;
        [Tooltip("Sliced frame image drawn inside the edges (child \"Border\").")]
        public Image border;
        public TMP_Text label;
        public State normal = new State();
        public State hover = new State { used = false };
        public State pressed = new State { used = false };
        public State disabled = new State { used = false };
        [Tooltip("Overlay while focused: only a visible border or background replaces the current one.")]
        public State focus = new State { used = false };

        Selectable selectable;
        bool hovered;
        bool held;

        void Awake() => selectable = GetComponent<Selectable>();

        void OnEnable() => Apply();

        void OnDisable()
        {
            hovered = false;
            held = false;
        }

        void LateUpdate() => Apply();

        public void OnPointerEnter(PointerEventData eventData) => hovered = true;

        public void OnPointerExit(PointerEventData eventData) => hovered = false;

        public void OnPointerDown(PointerEventData eventData) => held = true;

        public void OnPointerUp(PointerEventData eventData) => held = false;

        void Apply()
        {
            bool interactable = selectable == null || selectable.IsInteractable();
            bool focused = interactable && EventSystem.current != null && EventSystem.current.currentSelectedGameObject == gameObject;
            var state = normal;
            if (!interactable && disabled.used) state = disabled;
            else if (interactable && held && hovered && pressed.used) state = pressed;
            else if (interactable && hovered && hover.used) state = hover;

            Color backgroundColor = state.background;
            Color borderColor = state.border;
            float borderWidth = state.borderWidth;
            Color textColor = state.text;
            if (focused && focus.used)
            {
                if (focus.border.a > 0f && focus.borderWidth > 0f)
                {
                    borderColor = focus.border;
                    borderWidth = focus.borderWidth;
                }
                if (focus.background.a > 0f) backgroundColor = focus.background;
                if (state == normal) textColor = focus.text;
            }

            if (background != null) background.color = backgroundColor;
            if (border != null)
            {
                bool visible = borderWidth > 0f && borderColor.a > 0f;
                if (border.enabled != visible) border.enabled = visible;
                border.color = borderColor;
                if (visible) border.pixelsPerUnitMultiplier = 1f / borderWidth;
            }
            if (label != null) label.color = textColor;
        }
    }
}
