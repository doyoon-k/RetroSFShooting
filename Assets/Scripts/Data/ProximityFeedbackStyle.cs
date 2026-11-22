using TMPro;
using UnityEngine;

namespace RetroSF
{
    [CreateAssetMenu(menuName = "RetroSF/Proximity Feedback")]
    public sealed class ProximityFeedbackStyle : ScriptableObject
    {
        [Header("Multiplier Colors")]
        public Color x1Color = new Color32(219, 231, 237, 255);
        public Color x2Color = new Color32(145, 228, 243, 255);
        public Color x3Color = new Color32(255, 227, 138, 255);
        public Color x4Color = new Color32(255, 177, 111, 255);
        [Header("Hit Label")]
        [Tooltip("Same Stadium TMP font asset as the combat HUD.")]
        public TMP_FontAsset numericFont;
        [Range(12, 64)] public int fontSize = 28;
        [Range(0.15f, 2f)] public float duration = 0.35f;
        [Range(1f, 1.5f)] public float popScale = 1.18f;
        public Vector2 labelOffset = new Vector2(0f, 0.34f);

        public Color ColorFor(int multiplier)
        {
            switch (multiplier)
            {
                case 2: return x2Color;
                case 3: return x3Color;
                case 4: return x4Color;
                default: return x1Color;
            }
        }
    }
}
