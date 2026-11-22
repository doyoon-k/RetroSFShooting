using System.Collections.Generic;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

namespace RetroSF.EditorTools
{
    /// <summary>
    /// Measures <see cref="OneShotEffect.artCenter"/>: the middle of the opaque pixels of every sprite the
    /// effect's default clip shows. Run it after changing the frames of an effect with Anchor To Art.
    /// </summary>
    public static class EffectAnchors
    {
        const string PrefabFolder = "Assets/Prefabs";

        [MenuItem("RetroSF/Measure Effect Anchors")]
        static void MeasureFromMenu()
        {
            int updated = 0;
            foreach (var path in AnchoredEffectPaths())
            {
                var effect = AssetDatabase.LoadAssetAtPath<OneShotEffect>(path);
                if (!TryMeasure(effect, out var center) || center == effect.artCenter) continue;
                var serialized = new SerializedObject(effect);
                serialized.FindProperty(nameof(OneShotEffect.artCenter)).vector2Value = center;
                serialized.ApplyModifiedPropertiesWithoutUndo();
                updated++;
            }
            AssetDatabase.SaveAssets();
            Debug.Log($"Measured effect anchors: {updated} updated.");
        }

        /// <summary>Prefabs whose OneShotEffect has Anchor To Art.</summary>
        public static IEnumerable<string> AnchoredEffectPaths()
        {
            foreach (var guid in AssetDatabase.FindAssets("t:Prefab", new[] { PrefabFolder }))
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                var effect = AssetDatabase.LoadAssetAtPath<OneShotEffect>(path);
                if (effect != null && effect.anchorToArt) yield return path;
            }
        }

        /// <summary>Middle of the union of the opaque pixels of every sprite keyed in the default clip.</summary>
        public static bool TryMeasure(OneShotEffect effect, out Vector2 center)
        {
            center = Vector2.zero;
            var controller = effect.GetComponent<Animator>().runtimeAnimatorController as AnimatorController;
            var clip = controller != null ? controller.layers[0].stateMachine.defaultState?.motion as AnimationClip : null;
            if (clip == null) return false;
            bool any = false;
            var union = new Rect();
            foreach (var binding in AnimationUtility.GetObjectReferenceCurveBindings(clip))
            {
                if (binding.type != typeof(SpriteRenderer) || binding.propertyName != "m_Sprite") continue;
                foreach (var key in AnimationUtility.GetObjectReferenceCurve(clip, binding))
                {
                    if (!(key.value is Sprite sprite) || !TryOpaqueRect(sprite, out var rect)) continue;
                    union = any ? Rect.MinMaxRect(Mathf.Min(union.xMin, rect.xMin), Mathf.Min(union.yMin, rect.yMin),
                        Mathf.Max(union.xMax, rect.xMax), Mathf.Max(union.yMax, rect.yMax)) : rect;
                    any = true;
                }
            }
            if (any) center = union.center;
            return any;
        }

        /// <summary>
        /// Bounds of the sprite's opaque pixels in its local units, read from the PNG itself: a blank frame has none.
        /// (A blank sprite's tight mesh falls back to the whole rect, so the mesh cannot tell.)
        /// </summary>
        static bool TryOpaqueRect(Sprite sprite, out Rect rect)
        {
            rect = default;
            var texture = BattleFrameBaker.LoadUnimported(AssetDatabase.GetAssetPath(sprite.texture));
            try
            {
                var pixels = texture.GetPixels32();
                var area = sprite.rect;
                int xMin = int.MaxValue, yMin = int.MaxValue, xMax = int.MinValue, yMax = int.MinValue;
                for (int y = (int)area.yMin; y < (int)area.yMax; y++)
                for (int x = (int)area.xMin; x < (int)area.xMax; x++)
                {
                    if (pixels[y * texture.width + x].a == 0) continue;
                    xMin = Mathf.Min(xMin, x);
                    xMax = Mathf.Max(xMax, x + 1);
                    yMin = Mathf.Min(yMin, y);
                    yMax = Mathf.Max(yMax, y + 1);
                }
                if (xMax < xMin) return false;
                // Texture rows run bottom-up like sprite space; the pivot is in pixels from the rect's corner.
                Vector2 origin = area.position + sprite.pivot;
                float unitsPerPixel = 1f / sprite.pixelsPerUnit;
                rect = Rect.MinMaxRect((xMin - origin.x) * unitsPerPixel, (yMin - origin.y) * unitsPerPixel,
                    (xMax - origin.x) * unitsPerPixel, (yMax - origin.y) * unitsPerPixel);
                return true;
            }
            finally
            {
                Object.DestroyImmediate(texture);
            }
        }
    }
}
