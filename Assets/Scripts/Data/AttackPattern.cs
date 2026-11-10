using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    [Serializable]
    public class FloatList
    {
        public List<float> values = new List<float>();
    }

    public struct Shot
    {
        public Vector2 position;
        public float angle;

        public Shot(Vector2 position, float angle)
        {
            this.position = position;
            this.angle = angle;
        }
    }

    /// <summary>Describes an attack, never stores an emitter's timer or target. Angles are Unity space (CCW).</summary>
    [CreateAssetMenu(menuName = "RetroSF/Attack Pattern")]
    public class AttackPattern : ScriptableObject
    {
        public enum Aim { Fixed, LockOnStart, TrackEachVolley }
        public enum Shape { Fan, Ring, Curtain, Ricochet }

        public string displayName = "Aimed shot";
        public Projectile projectilePrefab;
        public Aim aim = Aim.TrackEachVolley;
        public Shape shape = Shape.Fan;
        [Range(1, 64)] public int bulletCount = 1;
        [Range(0f, 360f)] public float spreadDegrees = 45f;
        [Range(-360f, 360f)] public float angleDegrees = 180f;
        [Range(-180f, 180f)] public float aimOffsetDegrees;
        [Range(1, 100)] public int volleyCount = 1;
        [Range(0.02f, 10f)] public float volleyInterval = 0.2f;
        [Range(-180f, 180f)] public float rotationPerVolley;
        [Range(0.05f, 20f)] public float recovery = 1.5f;
        [Tooltip("-1 uses the emitter's default. Recovery starts after family clearance when enabled.")]
        [Range(-1f, 2f)] public float telegraphSeconds = -1f;
        [Tooltip("Play the shared alert once when this attack's visual telegraph begins.")]
        public bool audibleWarning;
        public bool waitForClear;

        [Header("Fleet geometry")]
        [Tooltip("World-pixel offsets: independent of the ship's visual scale.")]
        public List<Vector2> muzzleOffsets = new List<Vector2> { Vector2.zero };
        [Range(0.15f, 0.85f)] public float corridorCenter = 0.5f;
        [Range(0f, 0.3f)] public float corridorShift = 0.18f;
        [Range(100f, 400f)] public float corridorWidth = 180f;

        [Header("Curtain routes")]
        [Tooltip("Each route stores one normalized corridor height (0 = top) per volley.")]
        public List<FloatList> corridorRoutes = new List<FloatList>();

        [Header("Curtain motion")]
        [Tooltip("Zero-based volley; -1 keeps every wall stationary.")]
        [Range(-1, 99)] public int curtainSwayVolley = -1;
        [Range(0f, 120f)] public float curtainSwayAmplitude;
        [Range(2f, 12f)] public float curtainSwayPeriod = 6f;

        public float SwayForVolley(int volley) =>
            shape == Shape.Curtain && volley == curtainSwayVolley ? curtainSwayAmplitude : 0f;

        /// <summary>Corridor center y. Route values and the legacy layout are fractions from the arena top.</summary>
        public float CorridorY(Rect arena, int volley, int routeIndex = 0)
        {
            if (corridorRoutes.Count > 0)
            {
                var route = corridorRoutes[Mathf.Clamp(routeIndex, 0, corridorRoutes.Count - 1)].values;
                if (route.Count > 0)
                    return G.FromTop(arena, Mathf.Clamp(route[Mathf.Clamp(volley, 0, route.Count - 1)], 0.15f, 0.85f));
            }
            return G.FromTop(arena, Mathf.Clamp(corridorCenter + Mathf.Sin(volley * Mathf.PI * 0.5f) * corridorShift, 0.15f, 0.85f));
        }

        public List<Shot> ShotsForVolley(Vector2 origin, Rect arena, float angle, int volley, int routeIndex = 0)
        {
            var shots = new List<Shot>();
            if (shape == Shape.Curtain)
            {
                float gap = CorridorY(arena, volley, routeIndex);
                float sway = SwayForVolley(volley);
                float spacing = (arena.height - 90f) / Mathf.Max(1, bulletCount - 1);
                // Continue moving rows past the edges, so only the authored corridor opens.
                int guardRows = Mathf.CeilToInt(sway / Mathf.Max(spacing, 1f));
                for (int index = -guardRows; index < bulletCount + guardRows; index++)
                {
                    float y = arena.yMax - 45f - spacing * index;
                    if (Mathf.Abs(y - gap) < corridorWidth * 0.5f) continue;
                    shots.Add(new Shot(new Vector2(origin.x, y), angle));
                }
            }
            else
            {
                var angles = AnglesForVolley(angle, volley);
                foreach (var offset in muzzleOffsets)
                    foreach (var shotAngle in angles)
                        shots.Add(new Shot(origin + offset, shotAngle));
            }
            return shots;
        }

        public List<float> AnglesForVolley(float baseAngle, int volley)
        {
            var result = new List<float>(bulletCount);
            float center = baseAngle + rotationPerVolley * volley * Mathf.Deg2Rad;
            for (int i = 0; i < bulletCount; i++)
            {
                float offset = 0f;
                if (shape == Shape.Ring)
                    offset = G.Tau * i / bulletCount;
                else if (bulletCount > 1)
                    offset = spreadDegrees * Mathf.Deg2Rad * ((float)i / (bulletCount - 1) - 0.5f);
                result.Add(center + offset);
            }
            return result;
        }
    }
}
