using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    /// <summary>
    /// Godot Path2D + baked Curve2D: a polyline in local space sampled by distance.
    /// The importer bakes the Godot bezier into points; edit the points to change the route.
    /// </summary>
    public class PathRoute : MonoBehaviour
    {
        public List<Vector2> points = new List<Vector2>();

        float[] cumulative;
        int cachedCount = -1;

        public float Length
        {
            get
            {
                Bake();
                return cumulative.Length > 0 ? cumulative[cumulative.Length - 1] : 0f;
            }
        }

        void Bake()
        {
            if (cumulative != null && cachedCount == points.Count) return;
            cachedCount = points.Count;
            cumulative = new float[points.Count];
            for (int i = 1; i < points.Count; i++)
                cumulative[i] = cumulative[i - 1] + Vector2.Distance(points[i - 1], points[i]);
        }

        public Vector2 SampleLocal(float distance)
        {
            Bake();
            if (points.Count == 0) return Vector2.zero;
            if (distance <= 0f || points.Count == 1) return points[0];
            for (int i = 1; i < points.Count; i++)
            {
                if (distance <= cumulative[i])
                {
                    float segment = cumulative[i] - cumulative[i - 1];
                    float t = segment > 0f ? (distance - cumulative[i - 1]) / segment : 0f;
                    return Vector2.Lerp(points[i - 1], points[i], t);
                }
            }
            return points[points.Count - 1];
        }

        public Vector2 SampleWorld(float distance) => transform.TransformPoint(SampleLocal(distance));

        void OnDrawGizmos()
        {
            if (points.Count < 2) return;
            Gizmos.color = new Color(0.4f, 0.9f, 1f, 0.8f);
            for (int i = 1; i < points.Count; i++)
                Gizmos.DrawLine(transform.TransformPoint(points[i - 1]), transform.TransformPoint(points[i]));
        }
    }
}
