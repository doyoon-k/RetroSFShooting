using System;
using System.Globalization;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace RetroSF
{
    /// <summary>Active pilot portrait, the bomb / weapon console (Godot combat_hud.gd) and the run score.</summary>
    public class CombatHUD : MonoBehaviour
    {
        const float SpreadIconDegrees = 18f;

        /// <summary>Plain digits, no padding: the score box right-aligns them like the art reference.</summary>
        public static string FormatScore(int score) => Mathf.Max(0, score).ToString(CultureInfo.InvariantCulture);

        public event Action BombRequested;
        public event Action WeaponChangeRequested;

        public Sprite bombOn;
        public Sprite bombReady;
        public Sprite bombOff;
        public Sprite straightIcon;
        public Sprite spreadIcon;

        [SerializeField] Image activePortrait;
        [SerializeField] Button bombButton;
        [SerializeField] Image bombOne;
        [SerializeField] Image bombTwo;
        [SerializeField] Image bombThree;
        [SerializeField] Image bombFour;
        [SerializeField] Image weaponOne;
        [SerializeField] Image weaponTwo;
        [SerializeField] TextMeshProUGUI weaponLevel;
        [SerializeField] Button weaponChange;
        [SerializeField] TextMeshProUGUI score;

        Image[] bombSlots;
        bool initialized;
        Vector3 weaponTwoPosition;
        Vector2 weaponTwoCenter;
        float shownWeaponTwoDegrees;
        int shownLevel = -1;
        int shownScore = -1;

        void Awake() => Initialize();

        void OnDestroy()
        {
            if (!initialized) return;
            if (bombButton != null) bombButton.onClick.RemoveListener(RequestBomb);
            if (weaponChange != null) weaponChange.onClick.RemoveListener(RequestWeaponChange);
        }

        /// <summary>Also run from Display, which the stage may call before this object first wakes.</summary>
        void Initialize()
        {
            if (initialized) return;
            initialized = true;
            bombSlots = new[] { bombOne, bombTwo, bombThree, bombFour };
            // combat_hud.tscn: the console buttons have focus_mode = FOCUS_NONE (click only).
            if (bombButton != null)
            {
                UiUtil.DisableFocus(bombButton);
                bombButton.onClick.AddListener(RequestBomb);
            }
            if (weaponChange != null)
            {
                UiUtil.DisableFocus(weaponChange);
                weaponChange.onClick.AddListener(RequestWeaponChange);
            }
            if (weaponTwo != null)
            {
                var rect = weaponTwo.rectTransform;
                weaponTwoPosition = rect.localPosition;
                weaponTwoCenter = rect.rect.center;
                shownWeaponTwoDegrees = 0f;
            }
        }

        void RequestBomb() => BombRequested?.Invoke();

        void RequestWeaponChange() => WeaponChangeRequested?.Invoke();

        public void Display(SortieState sortie, int runScore, Sprite portrait, bool canUse, bool bombAvailable)
        {
            Initialize();
            if (sortie == null) return;
            if (score != null && runScore != shownScore)
            {
                shownScore = runScore;
                score.text = FormatScore(runScore);
            }
            UiUtil.SetTextureCovered(activePortrait, portrait);
            bool bombUsable = canUse && bombAvailable && sortie.Bombs > 0;
            int firstBombIndex = bombSlots.Length - sortie.Bombs;
            for (int index = 0; index < bombSlots.Length; index++)
            {
                var texture = index < firstBombIndex ? bombOff : (bombUsable && index == firstBombIndex ? bombReady : bombOn);
                UiUtil.SetTextureFitted(bombSlots[index], texture);
            }
            bombButton.interactable = bombUsable;
            weaponChange.interactable = canUse;
            bool spread = sortie.activeWeapon == SortieState.WeaponType.Spread;
            var icon = spread ? spreadIcon : straightIcon;
            UiUtil.SetTextureFitted(weaponOne, icon);
            UiUtil.SetTextureFitted(weaponTwo, icon);
            RotateWeaponTwo(spread ? SpreadIconDegrees : 0f);
            int level = sortie.CurrentPowerLevel();
            if (level != shownLevel)
            {
                shownLevel = level;
                weaponLevel.text = $"LV.{level}";
            }
        }

        /// <summary>
        /// Godot rotation is clockwise around pivot_offset (the icon's center). The rotation is applied
        /// around the rect center whatever pivot the importer chose.
        /// </summary>
        void RotateWeaponTwo(float clockwiseDegrees)
        {
            if (weaponTwo == null || Mathf.Approximately(clockwiseDegrees, shownWeaponTwoDegrees)) return;
            shownWeaponTwoDegrees = clockwiseDegrees;
            var rect = weaponTwo.rectTransform;
            var rotation = Quaternion.Euler(0f, 0f, -clockwiseDegrees);
            Vector3 center = Vector3.Scale(weaponTwoCenter, rect.localScale);
            rect.localRotation = rotation;
            rect.localPosition = weaponTwoPosition + center - rotation * center;
        }
    }
}
