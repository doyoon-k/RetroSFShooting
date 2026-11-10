using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace RetroSF
{
    /// <summary>Battle roster slot: covered portrait, "On a sortie" plate and a focus/hover frame.</summary>
    public class CombatPilotPortrait : PilotPortrait, IDeselectHandler, IPointerEnterHandler, IPointerExitHandler
    {
        [SerializeField] Image onSortie;
        [SerializeField] Image selection;

        public override void OnSelect(BaseEventData eventData)
        {
            UiUtil.SetVisible(selection, true);
            base.OnSelect(eventData);
        }

        public void OnDeselect(BaseEventData eventData) => UiUtil.SetVisible(selection, false);

        public void OnPointerEnter(PointerEventData eventData) => UiUtil.SetVisible(selection, !Disabled);

        public void OnPointerExit(PointerEventData eventData) => UiUtil.SetVisible(selection, HasFocus);

        public override void Display(PilotData data, Sprite portraitTexture, bool active, bool alive, bool survived = false)
        {
            base.Display(data, portraitTexture, active, alive, survived);
            bool inFlight = active && alive && !survived;
            UiUtil.SetVisible(portrait, !inFlight);
            UiUtil.SetVisible(onSortie, inFlight);
            UiUtil.SetVisible(selection, HasFocus);
        }

        /// <summary>combat_pilot_portrait.tscn draws the portrait with KEEP_ASPECT_COVERED inside a clipping card.</summary>
        protected override void ShowPortrait(Sprite texture) => UiUtil.SetTextureCovered(portrait, texture);
    }
}
