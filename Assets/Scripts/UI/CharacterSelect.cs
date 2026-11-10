using System;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;

namespace RetroSF
{
    /// <summary>
    /// Hangar pilot selection (Godot character_select.gd). Keyboard and gamepad input is handled here
    /// before the GUI sees it; the mouse drives the buttons directly.
    /// </summary>
    public class CharacterSelect : MonoBehaviour
    {
        static readonly Color LostPilot = new Color(0.28f, 0.28f, 0.28f);

        public GameCatalog catalog;
        [NonSerialized] public RunState run;
        public event Action<string> SortieRequested;

        [SerializeField] RectTransform hangar;
        [SerializeField] Button moveLeft;
        [SerializeField] Button moveRight;
        [SerializeField] RectTransform selectionMarker;
        [SerializeField] RectTransform details;
        [SerializeField] Image portrait;
        [SerializeField] TextMeshProUGUI pilotName;
        [SerializeField] TypewriterText description;
        [SerializeField] Button closeDetails;
        [SerializeField] Button sortie;

        string selected = "";
        bool confirmed;
        readonly List<HangarPilot> slots = new List<HangarPilot>();
        readonly List<Action> slotFocusHandlers = new List<Action>();
        readonly List<UnityAction> slotClickHandlers = new List<UnityAction>();
        readonly Vector3[] corners = new Vector3[4];

        void Start()
        {
            UiRuntime.Ensure();
            Music.Play("select");
            if (run == null) run = new RunState(catalog);
            foreach (Transform child in hangar)
            {
                var slot = child.GetComponent<HangarPilot>();
                if (slot == null) continue;
                int index = slots.Count;
                slot.pilot = index < catalog.pilots.Count ? catalog.pilots[index] : null;
                slots.Add(slot);
                Action onFocus = null;
                UnityAction onClick = null;
                if (slot.pilot != null)
                {
                    string id = slot.pilot.id;
                    onFocus = () => FocusPilot(id);
                    onClick = () => OpenPilot(id);
                    slot.FocusEntered += onFocus;
                    if (slot.Button != null) slot.Button.onClick.AddListener(onClick);
                }
                slotFocusHandlers.Add(onFocus);
                slotClickHandlers.Add(onClick);
            }
            moveLeft.onClick.AddListener(MovePrevious);
            moveRight.onClick.AddListener(MoveNext);
            closeDetails.onClick.AddListener(CloseDetails);
            sortie.onClick.AddListener(RequestSortie);
            run.RosterChanged += RefreshRoster;
            RefreshRoster();
            FocusSelectedSlot();
            foreach (var slot in slots) Sfx.BindNavigation(slot.Button);
            Sfx.BindNavigation(moveLeft);
            Sfx.BindNavigation(moveRight);
            Sfx.BindNavigation(closeDetails);
            Sfx.BindNavigation(sortie);
        }

        void OnDestroy()
        {
            if (run != null) run.RosterChanged -= RefreshRoster;
            for (int i = 0; i < slots.Count; i++)
            {
                var slot = slots[i];
                if (slot == null || slotFocusHandlers[i] == null) continue;
                slot.FocusEntered -= slotFocusHandlers[i];
                if (slot.Button != null) slot.Button.onClick.RemoveListener(slotClickHandlers[i]);
            }
            if (moveLeft != null) moveLeft.onClick.RemoveListener(MovePrevious);
            if (moveRight != null) moveRight.onClick.RemoveListener(MoveNext);
            if (closeDetails != null) closeDetails.onClick.RemoveListener(CloseDetails);
            if (sortie != null) sortie.onClick.RemoveListener(RequestSortie);
        }

        /// <summary>Godot _input: every ui action is handled here first and kept from the focused button.</summary>
        void Update()
        {
            if (confirmed) return;
            UiRuntime.ConsumeInput();
            if (GameInput.UiLeftPressed || GameInput.UiUpPressed)
            {
                MoveSelection(-1);
            }
            else if (GameInput.UiRightPressed || GameInput.UiDownPressed)
            {
                MoveSelection(1);
            }
            else if (GameInput.UiAcceptPressed)
            {
                if (!UiUtil.IsVisible(details)) OpenPilot(selected);
                else if (UiRuntime.HasFocus(closeDetails)) CloseDetails();
                else RequestSortie();
            }
            else if (GameInput.UiCancelPressed && UiUtil.IsVisible(details))
            {
                CloseDetails();
            }
        }

        void RefreshRoster()
        {
            foreach (var slot in slots)
            {
                UiUtil.SetVisible(slot, slot.pilot != null);
                if (slot.pilot == null) continue;
                bool alive = run.IsAlive(slot.pilot.id);
                slot.Disabled = confirmed || !alive;
                slot.SetFocusable(!slot.Disabled);
                slot.SetModulate(alive ? Color.white : LostPilot);
            }
            selected = run.AutomaticChoice(selected);
            moveLeft.interactable = !(confirmed || run.Survivors().Count < 2);
            moveRight.interactable = moveLeft.interactable;
            sortie.interactable = !(confirmed || string.IsNullOrEmpty(selected));
            closeDetails.interactable = !confirmed;
            UiUtil.SetVisible(selectionMarker, !string.IsNullOrEmpty(selected));
            if (string.IsNullOrEmpty(selected)) UiUtil.SetVisible(details, false);
            RefreshSelection();
        }

        void FocusPilot(string id)
        {
            if (confirmed || !run.IsAlive(id) || selected == id) return;
            selected = id;
            RefreshSelection();
        }

        void RefreshSelection()
        {
            foreach (var slot in slots)
            {
                if (slot.pilot != null && slot.pilot.id == selected)
                {
                    PlaceMarker(slot);
                    break;
                }
            }
            RefreshDetails();
        }

        /// <summary>Centers the marker over the slot with its bottom edge on the hangar's top edge.</summary>
        void PlaceMarker(HangarPilot slot)
        {
            if (!(selectionMarker.parent is RectTransform layout)) return;
            ((RectTransform)slot.transform).GetWorldCorners(corners);
            Vector3 slotTopCenter = (corners[1] + corners[2]) * 0.5f;
            hangar.GetWorldCorners(corners);
            var anchor = layout.InverseTransformPoint(new Vector3(slotTopCenter.x, corners[1].y, slotTopCenter.z));
            Rect markerRect = selectionMarker.rect;
            Vector3 scale = selectionMarker.localScale;
            Vector3 position = selectionMarker.localPosition;
            position.x = anchor.x - markerRect.center.x * scale.x;
            position.y = anchor.y - markerRect.yMin * scale.y;
            selectionMarker.localPosition = position;
        }

        void FocusSelectedSlot()
        {
            foreach (var slot in slots)
            {
                if (slot.pilot != null && slot.pilot.id == selected && !slot.Disabled)
                {
                    UiRuntime.Focus(slot.Button);
                    return;
                }
            }
        }

        void MovePrevious() => MoveSelection(-1);

        void MoveNext() => MoveSelection(1);

        void MoveSelection(int direction)
        {
            if (confirmed || string.IsNullOrEmpty(selected)) return;
            int current = 0;
            for (int index = 0; index < slots.Count; index++)
            {
                if (slots[index].pilot != null && slots[index].pilot.id == selected)
                {
                    current = index;
                    break;
                }
            }
            for (int step = 1; step <= slots.Count; step++)
            {
                int index = ((current + direction * step) % slots.Count + slots.Count) % slots.Count;
                var slot = slots[index];
                if (slot.pilot != null && run.IsAlive(slot.pilot.id))
                {
                    FocusPilot(slot.pilot.id);
                    FocusSelectedSlot();
                    return;
                }
            }
        }

        void RefreshDetails()
        {
            var pilot = catalog.PilotById(selected);
            if (pilot == null) return;
            UiUtil.SetTextureCovered(portrait, pilot.hangarPortrait != null ? pilot.hangarPortrait : pilot.normal);
            pilotName.text = pilot.displayName == pilot.callsign ? pilot.displayName : pilot.displayName + " / " + pilot.callsign;
            if (UiUtil.IsVisible(details)) description.Reveal(pilot.description);
        }

        void OpenPilot(string id)
        {
            if (confirmed || !run.IsAlive(id)) return;
            FocusPilot(id);
            UiUtil.SetVisible(details, true);
            RefreshDetails();
            UiRuntime.Focus(sortie);
            Sfx.Play("ui_confirm");
        }

        void CloseDetails()
        {
            if (confirmed || !UiUtil.IsVisible(details)) return;
            Sfx.Play("ui_cancel");
            UiUtil.SetVisible(details, false);
            FocusSelectedSlot();
        }

        void RequestSortie()
        {
            if (confirmed || !UiUtil.IsVisible(details) || !run.IsAlive(selected)) return;
            confirmed = true;
            Sfx.Play("ui_confirm");
            RefreshRoster();
            SortieRequested?.Invoke(selected);
        }
    }
}
