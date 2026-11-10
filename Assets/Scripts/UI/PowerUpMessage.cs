using UnityEngine;
using UnityEngine.UI;

namespace RetroSF
{
    /// <summary>
    /// "POWER UP" that rises from the ship and fades (Godot power_up_message.gd, process mode Pausable:
    /// it runs on scaled time and freezes during the combat pause).
    /// Positions are in the parent interface root's 1920×1080 design space, origin bottom-left, y up.
    /// </summary>
    public class PowerUpMessage : MonoBehaviour
    {
        [Range(0.1f, 3f)] public float duration = 0.8f;
        [Range(0f, 100f)] public float riseDistance = 28f;
        [Range(0f, 200f)] public float shipOffset = 85f;
        [Range(80f, 300f)] public float displayWidth = 170f;

        [SerializeField] Image visual;
        [SerializeField] Image shadow;

        float elapsed;
        Vector2 startPosition;
        bool showing;
        bool colorsCached;
        Color visualColor;
        Color shadowColor;

        void Start()
        {
            if (!showing) Clear();
        }

        public void ShowAt(Vector2 shipDesignPosition, Rect playfieldDesign, float extraClearance = 0f)
        {
            if (visual == null || visual.sprite == null) return;
            CacheColors();
            Vector2 size = visual.sprite.rect.size;
            float factor = displayWidth / size.x;
            Resize(visual, size, factor);
            Resize(shadow, shadow != null && shadow.sprite != null ? shadow.sprite.rect.size : size, factor);
            Vector2 halfSize = size * factor * 0.5f + new Vector2(3f, 3f);
            Rect safeArea = G.Grow(playfieldDesign, -6f);
            float offset = shipOffset + extraClearance;
            Vector2 start = shipDesignPosition + new Vector2(0f, offset);
            // Too close to the top to drift upward: start below the ship instead.
            if (start.y + halfSize.y + riseDistance > safeArea.yMax)
                start.y = shipDesignPosition.y - offset - riseDistance;
            // Reserve room for the full upward drift, including at the screen edges.
            start.x = Mathf.Clamp(start.x, safeArea.xMin + halfSize.x, safeArea.xMax - halfSize.x);
            float highest = safeArea.yMax - halfSize.y - riseDistance;
            float lowest = safeArea.yMin + halfSize.y;
            // Godot clamps the top limit first; keep that order for a playfield smaller than the message.
            if (start.y > highest) start.y = highest;
            else if (start.y < lowest) start.y = lowest;
            startPosition = start;
            SetDesignPosition(start);
            elapsed = 0f;
            SetAlpha(1f);
            showing = true;
            gameObject.SetActive(true);
        }

        public void Clear()
        {
            showing = false;
            gameObject.SetActive(false);
        }

        void Update()
        {
            if (!showing) return;
            elapsed += Time.deltaTime;
            if (elapsed >= duration)
            {
                Clear();
                return;
            }
            float progress = elapsed / duration;
            SetDesignPosition(startPosition + Vector2.up * (riseDistance * progress));
            SetAlpha(1f - G.Smoothstep(0.45f, 1f, progress));
        }

        void SetDesignPosition(Vector2 designPosition)
        {
            var parent = transform.parent as RectTransform;
            Vector2 origin = parent != null ? parent.rect.min : Vector2.zero;
            transform.localPosition = new Vector3(origin.x + designPosition.x, origin.y + designPosition.y, transform.localPosition.z);
        }

        /// <summary>Godot Sprite2D: native texture size times the node scale.</summary>
        static void Resize(Image image, Vector2 nativeSize, float factor)
        {
            if (image == null) return;
            var rect = image.rectTransform;
            rect.SetSizeWithCurrentAnchors(RectTransform.Axis.Horizontal, nativeSize.x);
            rect.SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical, nativeSize.y);
            rect.localScale = new Vector3(factor, factor, 1f);
        }

        void CacheColors()
        {
            if (colorsCached) return;
            colorsCached = true;
            visualColor = visual != null ? visual.color : Color.white;
            shadowColor = shadow != null ? shadow.color : Color.white;
        }

        /// <summary>Godot modulate.a on the message multiplies both children.</summary>
        void SetAlpha(float alpha)
        {
            if (visual != null) visual.color = new Color(visualColor.r, visualColor.g, visualColor.b, visualColor.a * alpha);
            if (shadow != null) shadow.color = new Color(shadowColor.r, shadowColor.g, shadowColor.b, shadowColor.a * alpha);
        }
    }
}
