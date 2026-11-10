using System;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace RetroSF
{
    /// <summary>
    /// A selectable slice of SixPilot.png in the hangar (Godot HangarPilot, a TextureButton).
    /// Sits next to the slot's Button component. CharacterSelect assigns the pilot by slot order.
    /// </summary>
    public class HangarPilot : MonoBehaviour, ISelectHandler
    {
        public PilotData pilot;

        Button button;
        Navigation focusNavigation;
        bool navigationCached;
        ModulateGroup modulate;

        /// <summary>Godot focus_entered.</summary>
        public event Action FocusEntered;

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

        /// <summary>Godot modulate.</summary>
        public void SetModulate(Color color)
        {
            modulate ??= new ModulateGroup(gameObject);
            modulate.Set(color);
        }

        public void OnSelect(BaseEventData eventData) => FocusEntered?.Invoke();
    }
}
