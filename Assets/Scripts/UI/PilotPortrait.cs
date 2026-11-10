using System;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace RetroSF
{
    /// <summary>One roster card (Godot PilotPortrait, a Button). Sits next to the card's Button component.</summary>
    public class PilotPortrait : MonoBehaviour, ISelectHandler
    {
        [SerializeField] protected Image portrait;
        [SerializeField] protected TextMeshProUGUI pilotName;
        [SerializeField] protected TextMeshProUGUI status;

        Button button;
        Navigation focusNavigation;
        bool navigationCached;
        ModulateGroup modulate;

        /// <summary>Godot focus_entered.</summary>
        public event Action FocusEntered;

        public PilotData Pilot { get; private set; }

        public Button Button
        {
            get
            {
                if (button == null) button = GetComponent<Button>();
                return button;
            }
        }

        /// <summary>Godot BaseButton.disabled.</summary>
        public bool Disabled
        {
            get => Button == null || !Button.interactable;
            set
            {
                if (Button != null) Button.interactable = !value;
            }
        }

        public bool HasFocus => UiRuntime.HasFocus(gameObject);

        public virtual void Display(PilotData data, Sprite portraitTexture, bool active, bool alive, bool survived = false)
        {
            Pilot = data;
            ShowPortrait(portraitTexture);
            if (pilotName != null) pilotName.text = data.displayName;
            if (status != null)
            {
                status.text = !alive ? "LOST" : (active ? "IN FLIGHT" : data.callsign);
                if (alive && survived) status.text = "SURVIVED";
            }
        }

        /// <summary>Godot focus_mode FOCUS_ALL (true) or FOCUS_NONE (false).</summary>
        public void SetFocusable(bool focusable)
        {
            var target = Button;
            if (target == null) return;
            if (!navigationCached)
            {
                navigationCached = true;
                focusNavigation = target.navigation.mode == Navigation.Mode.None ? Navigation.defaultNavigation : target.navigation;
            }
            target.navigation = focusable ? focusNavigation : UiUtil.NoFocus;
        }

        /// <summary>Godot modulate on the whole card.</summary>
        public void SetModulate(Color color)
        {
            modulate ??= new ModulateGroup(gameObject);
            modulate.Set(color);
        }

        /// <summary>pilot_portrait.tscn draws the portrait with KEEP_ASPECT_CENTERED.</summary>
        protected virtual void ShowPortrait(Sprite texture) => UiUtil.SetTextureFitted(portrait, texture);

        public virtual void OnSelect(BaseEventData eventData) => FocusEntered?.Invoke();
    }
}
