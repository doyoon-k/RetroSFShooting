using TMPro;
using UnityEngine;

namespace RetroSF
{
    /// <summary>One reusable world-space TMP label per enemy, surviving its killing hit.</summary>
    public sealed class DamageMultiplierFeedback : MonoBehaviour
    {
        public TextMeshProUGUI Label { get; private set; }
        public int Multiplier { get; private set; }
        public float TimeLeft { get; private set; }
        EnemyShip target;
        ProximityFeedbackStyle style;
        Vector3 impactOffset;
        Vector2 impactPosition;
        Rect bounds;
        float popLeft;

        public void ShowHit(EnemyShip enemy, Vector2 impact, int multiplier, ProximityFeedbackStyle feedback)
        {
            bool changed = Multiplier != multiplier || TimeLeft <= 0f;
            target = enemy;
            style = feedback;
            Multiplier = multiplier;
            impactOffset = enemy.transform.InverseTransformPoint(impact);
            impactPosition = impact;
            bounds = enemy.bounds;
            TimeLeft = style.duration;
            if (Label == null) Label = CreateText(transform, "Multiplier", style.numericFont, style.fontSize);
            Label.text = "x" + multiplier;
            Label.font = style.numericFont;
            Label.fontSize = style.fontSize;
            Label.color = style.ColorFor(multiplier);
            Label.rectTransform.sizeDelta = Label.GetPreferredValues() + new Vector2(12f, 8f);
            if (changed)
            {
                popLeft = 0.12f;
                if (multiplier == 4) Sfx.Play("enemy_hit_strong");
            }
            UpdateLabel();
        }

        void Update()
        {
            if (style == null || GamePause.Paused) return;
            TimeLeft = Mathf.Max(0f, TimeLeft - Time.deltaTime);
            popLeft = Mathf.Max(0f, popLeft - Time.deltaTime);
            if (TimeLeft <= 0f) { Destroy(gameObject); return; }
            if (target != null)
            {
                impactPosition = target.transform.TransformPoint(impactOffset);
                bounds = target.bounds;
            }
            UpdateLabel();
        }

        void UpdateLabel()
        {
            float pop = Mathf.Lerp(1f, style.popScale, popLeft / 0.12f);
            var parentScale = transform.parent != null ? transform.parent.lossyScale : Vector3.one;
            // The label canvas is laid out in design pixels; scale it down to world units.
            float scale = pop * G.UnitsPerPixel;
            transform.localScale = new Vector3(scale / parentScale.x, scale / parentScale.y, 1f);
            Vector2 half = (Label.rectTransform.sizeDelta * pop * 0.5f + Vector2.one * 6f) * G.UnitsPerPixel;
            Vector2 location = impactPosition + style.labelOffset;
            if (bounds.width > 0f && bounds.height > 0f)
            {
                location.x = Mathf.Clamp(location.x, bounds.xMin + half.x, bounds.xMax - half.x);
                location.y = Mathf.Clamp(location.y, bounds.yMin + half.y, bounds.yMax - half.y);
            }
            transform.SetPosition2D(location);
            Color color = style.ColorFor(Multiplier);
            color.a *= Mathf.Clamp01(TimeLeft / Mathf.Min(0.12f, style.duration));
            Label.color = color;
        }

        internal static TextMeshProUGUI CreateText(Transform parent, string name, TMP_FontAsset font, int size)
        {
            var host = new GameObject(name, typeof(RectTransform), typeof(Canvas));
            host.transform.SetParent(parent, false);
            var canvas = host.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.WorldSpace;
            canvas.worldCamera = Camera.main;
            canvas.overrideSorting = true;
            canvas.sortingOrder = 250;
            var text = host.AddComponent<TextMeshProUGUI>();
            text.font = font;
            text.fontSize = size;
            text.alignment = TextAlignmentOptions.Center;
            text.textWrappingMode = TextWrappingModes.NoWrap;
            text.overflowMode = TextOverflowModes.Overflow;
            text.raycastTarget = false;
            text.rectTransform.sizeDelta = new Vector2(96f, 56f);
            text.outlineWidth = 0.16f;
            text.outlineColor = new Color32(7, 10, 18, 255);
            return text;
        }
    }
}
