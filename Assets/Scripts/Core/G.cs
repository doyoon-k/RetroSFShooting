using UnityEngine;

namespace RetroSF
{
    /// <summary>
    /// Godot math helpers expressed in Unity space (y up, counter-clockwise angles).
    /// See Docs/PORTING.md for the coordinate rules.
    /// </summary>
    public static class G
    {
        public const float Tau = Mathf.PI * 2f;
        const float CmpEpsilon = 0.00001f;

        public static Vector2 FromAngle(float radians) => new Vector2(Mathf.Cos(radians), Mathf.Sin(radians));

        public static float Angle(Vector2 v) => Mathf.Atan2(v.y, v.x);

        public static Vector2 Rotated(Vector2 v, float radians)
        {
            float c = Mathf.Cos(radians), s = Mathf.Sin(radians);
            return new Vector2(v.x * c - v.y * s, v.x * s + v.y * c);
        }

        /// <summary>Same screen direction as Godot's orthogonal() after the y flip.</summary>
        public static Vector2 Orthogonal(Vector2 v) => new Vector2(-v.y, v.x);

        public static Vector2 DirectionTo(Vector2 from, Vector2 to) => (to - from).normalized;

        public static Vector2 Bounce(Vector2 v, Vector2 normal) => v - 2f * Vector2.Dot(v, normal) * normal;

        public static Vector2 LimitLength(Vector2 v, float length) => Vector2.ClampMagnitude(v, length);

        public static Vector2 MoveToward(Vector2 from, Vector2 to, float delta) => Vector2.MoveTowards(from, to, delta);

        public static Vector2 Clamp(Vector2 v, Vector2 min, Vector2 max) =>
            new Vector2(Mathf.Clamp(v.x, min.x, max.x), Mathf.Clamp(v.y, min.y, max.y));

        public static bool IsEqualApprox(float a, float b)
        {
            if (a == b) return true;
            float tolerance = CmpEpsilon * Mathf.Abs(a);
            if (tolerance < CmpEpsilon) tolerance = CmpEpsilon;
            return Mathf.Abs(a - b) < tolerance;
        }

        public static bool IsEqualApprox(Vector2 a, Vector2 b) => IsEqualApprox(a.x, b.x) && IsEqualApprox(a.y, b.y);

        public static bool IsZeroApprox(float v) => Mathf.Abs(v) < CmpEpsilon;

        public static float Wrapf(float value, float min, float max)
        {
            float range = max - min;
            if (IsZeroApprox(range)) return min;
            float result = value - range * Mathf.Floor((value - min) / range);
            if (IsEqualApprox(result, max)) return min;
            return result;
        }

        /// <summary>Godot rotate_toward for angles in radians.</summary>
        public static float RotateToward(float from, float to, float delta)
        {
            float difference = AngleDifference(from, to);
            float absDifference = Mathf.Abs(difference);
            return from + Mathf.Clamp(delta, absDifference - Mathf.PI, absDifference) * (difference >= 0f ? 1f : -1f);
        }

        public static float AngleDifference(float from, float to)
        {
            float difference = (to - from) % Tau;
            return (2f * difference) % Tau - difference;
        }

        public static float Fmod(float a, float b) => a % b;

        public static float Smoothstep(float from, float to, float x)
        {
            if (IsEqualApprox(from, to)) return from;
            float s = Mathf.Clamp01((x - from) / (to - from));
            return s * s * (3f - 2f * s);
        }

        public static float DbToLinear(float db) => Mathf.Exp(db * 0.11512925464970228420089957273422f);

        public static float LinearToDb(float linear) => Mathf.Log(linear) * 8.6858896380650365530225783783321f;

        // ---- Rects (Unity space). Godot "top" is yMax, "bottom" is yMin. ----

        public static Rect FromGodotRect(float x, float y, float w, float h) => new Rect(x, -(y + h), w, h);

        public static Vector2 FromGodotPoint(Vector2 godot) => new Vector2(godot.x, -godot.y);

        public static Rect Grow(Rect r, float by) => new Rect(r.x - by, r.y - by, r.width + by * 2f, r.height + by * 2f);

        /// <summary>Godot has_point: begin inclusive, end exclusive. Rect.Contains matches that on both axes.</summary>
        public static bool HasPoint(Rect r, Vector2 p) => r.Contains(p);

        public static bool HasArea(Rect r) => r.width > 0f && r.height > 0f;

        /// <summary>Y of a point measured as a fraction from the top edge (Godot's position.y + size.y * f).</summary>
        public static float FromTop(Rect r, float fraction) => r.yMax - r.height * fraction;

        public static Rect Expand(Rect r, Vector2 p)
        {
            float xMin = Mathf.Min(r.xMin, p.x), yMin = Mathf.Min(r.yMin, p.y);
            float xMax = Mathf.Max(r.xMax, p.x), yMax = Mathf.Max(r.yMax, p.y);
            return Rect.MinMaxRect(xMin, yMin, xMax, yMax);
        }

        public static Vector2 Position2D(this Transform t) => t.position;

        public static void SetPosition2D(this Transform t, Vector2 p) => t.position = new Vector3(p.x, p.y, t.position.z);

        public static Vector2 LocalPosition2D(this Transform t) => t.localPosition;

        public static void SetLocalPosition2D(this Transform t, Vector2 p) =>
            t.localPosition = new Vector3(p.x, p.y, t.localPosition.z);

        /// <summary>Unity z rotation (degrees) for a Unity-space angle in radians.</summary>
        public static void SetRotation2D(this Transform t, float radians) =>
            t.rotation = Quaternion.Euler(0f, 0f, radians * Mathf.Rad2Deg);
    }
}
