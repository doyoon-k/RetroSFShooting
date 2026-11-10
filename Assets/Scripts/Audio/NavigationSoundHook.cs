using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace RetroSF
{
    /// <summary>Added by Sfx.BindNavigation. Forwards focus and hover to the navigation sound.</summary>
    public sealed class NavigationSoundHook : MonoBehaviour, ISelectHandler, IPointerEnterHandler
    {
        public Selectable target;

        public void OnSelect(BaseEventData eventData) => Sfx.Instance.QueueNavigation(target);

        public void OnPointerEnter(PointerEventData eventData) => Sfx.Instance.QueueNavigation(target);
    }
}
