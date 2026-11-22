using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    /// <summary>
    /// Blood burst at the front of the enemy it hit, the same size on every enemy.
    /// The animated renderer is the child "Visual".
    /// </summary>
    public class EnemyHitEffect : OneShotEffect
    {
        [Tooltip("World scale of the burst on every enemy. 1.08 is the size the Godot game drew on the basic zako (z1_wedge).")]
        [Range(0.1f, 3f)] public float scale = 1.08f;
        [Tooltip("How far into the body, as a share of its width from its front edge, the burst sits.")]
        [Range(0f, 0.5f)] public float frontInset = 0.12f;
        [Tooltip("Every frame of the hit animation, first frame first. The first one anchors the burst on the impact point.")]
        public List<Sprite> frames = new List<Sprite>();
        public SpriteRenderer visual;

        protected override void Awake()
        {
            base.Awake();
            // The first burst sits above the texture center. Anchor that burst, so the
            // rotated animation starts at the impact point and sprays toward the player.
            if (visual != null && frames.Count > 0 && frames[0] != null)
                visual.transform.localPosition = -OpaqueRect(frames[0]).center;
        }

        public void FitToEnemy(EnemyShip enemy)
        {
            var body = enemy != null ? enemy.visual : null;
            if (body == null || body.sprite == null) return;
            var rect = OpaqueRect(body.sprite);
            if (rect.width <= 0f || rect.height <= 0f) return;
            var bodyTransform = body.transform;
            var worldRect = new Rect(bodyTransform.TransformPoint(rect.min), Vector2.zero);
            worldRect = G.Expand(worldRect, bodyTransform.TransformPoint(new Vector2(rect.xMax, rect.yMin)));
            worldRect = G.Expand(worldRect, bodyTransform.TransformPoint(rect.max));
            worldRect = G.Expand(worldRect, bodyTransform.TransformPoint(new Vector2(rect.xMin, rect.yMax)));
            transform.SetPosition2D(new Vector2(worldRect.xMin + worldRect.width * frontInset, worldRect.center.y));
            // Godot grew the burst with the enemy's size (up to 2.25x on bosses); every enemy now gets the zako's.
            var parentScale = transform.parent != null ? transform.parent.lossyScale : Vector3.one;
            transform.localScale = new Vector3(scale / parentScale.x, scale / parentScale.y, 1f);
        }

        /// <summary>Bounds of the sprite's tight mesh (its opaque pixels) in the sprite's local units.</summary>
        public static Rect OpaqueRect(Sprite sprite)
        {
            var vertices = sprite.vertices;
            if (vertices == null || vertices.Length == 0)
            {
                var b = sprite.bounds;
                return new Rect(b.min, b.size);
            }
            Vector2 min = vertices[0], max = vertices[0];
            foreach (var v in vertices)
            {
                min = Vector2.Min(min, v);
                max = Vector2.Max(max, v);
            }
            return Rect.MinMaxRect(min.x, min.y, max.x, max.y);
        }
    }
}
