using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace RetroSF
{
    /// <summary>Godot Control idioms expressed with uGUI.</summary>
    public static class UiUtil
    {
        /// <summary>Godot focus_mode = FOCUS_NONE.</summary>
        public static readonly Navigation NoFocus = new Navigation { mode = Navigation.Mode.None };

        /// <summary>Godot show() / hide() / visible = value.</summary>
        public static void SetVisible(Component node, bool visible)
        {
            if (node != null && node.gameObject.activeSelf != visible) node.gameObject.SetActive(visible);
        }

        /// <summary>Godot CanvasItem.visible (the node's own flag, not is_visible_in_tree).</summary>
        public static bool IsVisible(Component node) => node != null && node.gameObject.activeSelf;

        public static void DisableFocus(Selectable selectable)
        {
            if (selectable != null) selectable.navigation = NoFocus;
        }

        /// <summary>The child "Label" the importer gives every Godot Button.</summary>
        public static TMP_Text ButtonLabel(Selectable button)
        {
            if (button == null) return null;
            var child = button.transform.Find("Label");
            var label = child != null ? child.GetComponent<TMP_Text>() : null;
            return label != null ? label : button.GetComponentInChildren<TMP_Text>(true);
        }

        /// <summary>Godot Button.text.</summary>
        public static void SetButtonText(Selectable button, string value)
        {
            var label = ButtonLabel(button);
            if (label != null) label.text = value;
        }

        /// <summary>Godot TextureRect.texture. A null texture draws nothing; a sprite-less Image would draw a white quad.</summary>
        public static void SetTexture(Image image, Sprite sprite)
        {
            if (image == null) return;
            image.sprite = sprite;
            bool show = sprite != null;
            if (image.enabled != show) image.enabled = show;
        }

        /// <summary>TextureRect stretch_mode KEEP_ASPECT_CENTERED.</summary>
        public static void SetTextureFitted(Image image, Sprite sprite)
        {
            if (image == null) return;
            image.preserveAspect = true;
            SetTexture(image, sprite);
        }

        /// <summary>
        /// TextureRect stretch_mode KEEP_ASPECT_COVERED for a node that fills a clip_contents parent:
        /// the image envelops the parent (AspectRatioFitter) and the parent clips it (RectMask2D).
        /// </summary>
        public static void SetTextureCovered(Image image, Sprite sprite)
        {
            if (image == null) return;
            var fitter = image.GetComponent<AspectRatioFitter>();
            if (sprite != null && fitter != null && image.sprite == sprite && image.enabled) return;
            SetTexture(image, sprite);
            if (sprite == null) return;
            image.preserveAspect = false;
            var rect = image.rectTransform;
            if (rect.parent is RectTransform parent
                && parent.GetComponent<RectMask2D>() == null && parent.GetComponent<Mask>() == null)
                parent.gameObject.AddComponent<RectMask2D>();
            if (fitter == null)
            {
                // Centered like Godot's covered drawing; the fitter stretches the anchors itself.
                rect.pivot = new Vector2(0.5f, 0.5f);
                fitter = image.gameObject.AddComponent<AspectRatioFitter>();
            }
            fitter.aspectMode = AspectRatioFitter.AspectMode.EnvelopeParent;
            fitter.aspectRatio = sprite.rect.width / Mathf.Max(1f, sprite.rect.height);
        }
    }

    /// <summary>
    /// Godot CanvasItem.modulate on a subtree: every Graphic's own color times the modulate color.
    /// Base colors are captured on first use.
    /// </summary>
    public sealed class ModulateGroup
    {
        readonly GameObject root;
        readonly List<Graphic> graphics = new List<Graphic>();
        readonly List<Color> baseColors = new List<Color>();
        Color current = Color.white;
        bool cached;

        public ModulateGroup(GameObject root)
        {
            this.root = root;
        }

        public void Set(Color modulate)
        {
            if (!cached)
            {
                Cache();
            }
            else if (modulate == current)
            {
                return;
            }
            current = modulate;
            for (int i = 0; i < graphics.Count; i++)
                if (graphics[i] != null) graphics[i].color = baseColors[i] * modulate;
        }

        void Cache()
        {
            cached = true;
            root.GetComponentsInChildren(true, graphics);
            // TMP fallback-font sub meshes take their color from the parent text.
            graphics.RemoveAll(graphic => graphic is TMP_SubMeshUI);
            foreach (var graphic in graphics) baseColors.Add(graphic.color);
        }
    }
}
