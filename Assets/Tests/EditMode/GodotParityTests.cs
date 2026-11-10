using System.Collections.Generic;
using System.Linq;
using NUnit.Framework;
using UnityEngine;

namespace RetroSF.Tests
{
    /// <summary>
    /// Re-computes formulas exactly as the Godot GDScript does (y down, clockwise angles)
    /// and checks the Unity port gives the same screen result after the y flip.
    /// </summary>
    public class GodotParityTests
    {
        static readonly Rect GodotArena = new Rect(440f, 24f, 1464f, 952f);
        static Rect UnityArena => G.FromGodotRect(GodotArena.x, GodotArena.y, GodotArena.width, GodotArena.height);

        static Vector2 Flip(Vector2 v) => new Vector2(v.x, -v.y);

        [Test]
        public void RectConversionKeepsTopAndBottom()
        {
            var arena = UnityArena;
            Assert.AreEqual(-24f, arena.yMax, 0.001f, "Godot top edge y=24 becomes Unity yMax=-24");
            Assert.AreEqual(-976f, arena.yMin, 0.001f, "Godot bottom edge y=976 becomes Unity yMin=-976");
            Assert.AreEqual(G.FromTop(arena, 0.25f), -(GodotArena.y + GodotArena.height * 0.25f), 0.001f);
        }

        [Test]
        public void CurtainRowsMatchGodot([Values(0, 1, 2, 3)] int volley)
        {
            var pattern = ScriptableObject.CreateInstance<AttackPattern>();
            pattern.shape = AttackPattern.Shape.Curtain;
            pattern.bulletCount = 11;
            pattern.corridorWidth = 180f;
            pattern.corridorRoutes = new List<FloatList> { new FloatList { values = new List<float> { 0.32f, 0.52f, 0.42f, 0.54f } } };
            pattern.curtainSwayVolley = 1;
            pattern.curtainSwayAmplitude = 40f;
            var origin = new Vector2(1800f, -500f);

            // Godot: y = arena.position.y + 45 + spacing * index; skip |y - gap| < width / 2.
            float gap = GodotArena.y + GodotArena.height * Mathf.Clamp(pattern.corridorRoutes[0].values[volley], 0.15f, 0.85f);
            float sway = volley == 1 ? 40f : 0f;
            float spacing = (GodotArena.height - 90f) / (pattern.bulletCount - 1);
            int guard = Mathf.CeilToInt(sway / Mathf.Max(spacing, 1f));
            var expected = new List<float>();
            for (int index = -guard; index < pattern.bulletCount + guard; index++)
            {
                float y = GodotArena.y + 45f + spacing * index;
                if (Mathf.Abs(y - gap) < pattern.corridorWidth * 0.5f) continue;
                expected.Add(-y);
            }
            var actual = pattern.ShotsForVolley(origin, UnityArena, Mathf.PI, volley, 0).Select(s => s.position.y).ToList();
            CollectionAssert.AreEqual(expected, actual, new FloatComparer());
            Object.DestroyImmediate(pattern);
        }

        [Test]
        public void FanAnglesMirrorGodot()
        {
            var pattern = ScriptableObject.CreateInstance<AttackPattern>();
            pattern.shape = AttackPattern.Shape.Fan;
            pattern.bulletCount = 5;
            pattern.spreadDegrees = 60f;
            // Godot data rotates the fan +12° (clockwise on screen) per volley; the importer negates it.
            pattern.rotationPerVolley = -12f;
            float godotBase = Mathf.Deg2Rad * 150f;
            for (int volley = 0; volley < 3; volley++)
            {
                var godotDirections = new List<Vector2>();
                float center = godotBase + Mathf.Deg2Rad * 12f * volley;
                for (int i = 0; i < 5; i++)
                {
                    float angle = center + Mathf.Deg2Rad * 60f * ((float)i / 4 - 0.5f);
                    godotDirections.Add(Flip(new Vector2(Mathf.Cos(angle), Mathf.Sin(angle))));
                }
                var unity = pattern.AnglesForVolley(-godotBase, volley).Select(G.FromAngle).ToList();
                foreach (var direction in godotDirections)
                    Assert.IsTrue(unity.Any(u => Vector2.Distance(u, direction) < 0.0001f), $"volley {volley} misses {direction}");
            }
            Object.DestroyImmediate(pattern);
        }

        [Test]
        public void RicochetLaunchMatchesGodot([Values(true, false)] bool above)
        {
            var godotOrigin = new Vector2(1500f, 400f);
            var field = new Rect(GodotArena.x + 64f, GodotArena.y + 64f, GodotArena.width - 128f, GodotArena.height - 128f);
            float vertical = above ? godotOrigin.y - field.y : field.yMax - godotOrigin.y;
            float horizontal = Mathf.Max(1f, godotOrigin.x - field.x);
            var godot = new Vector2(-horizontal, (above ? -1f : 1f) * (vertical + field.height * 0.5f)).normalized;
            var unity = RicochetCore.LaunchDirection(Flip(godotOrigin), UnityArena, above);
            Assert.AreEqual(Flip(godot).x, unity.x, 0.0001f);
            Assert.AreEqual(Flip(godot).y, unity.y, 0.0001f);
        }

        [Test]
        public void OrthogonalPointsTheSameWayOnScreen()
        {
            // Godot: Vector2.LEFT.orthogonal() == (0, 1), i.e. down on screen.
            Assert.AreEqual(Flip(new Vector2(0f, 1f)), G.Orthogonal(Vector2.left));
        }

        [Test]
        public void ProximityDamageCurve()
        {
            var bullet = new GameObject("Bullet").AddComponent<Projectile>();
            bullet.proximityPoints = new List<Vector2> { new Vector2(80f, 1.6f), new Vector2(360f, 1f) };
            Assert.AreEqual(1.6f, bullet.ProximityMultiplier(40f), 0.0001f);
            Assert.AreEqual(1.3f, bullet.ProximityMultiplier(220f), 0.0001f);
            Assert.AreEqual(1f, bullet.ProximityMultiplier(500f), 0.0001f);
            Object.DestroyImmediate(bullet.gameObject);
        }

        [Test]
        public void RotateTowardMatchesGodot()
        {
            Assert.AreEqual(0.5f, G.RotateToward(0f, 2f, 0.5f), 0.0001f);
            Assert.AreEqual(2f, G.RotateToward(0f, 2f, 5f), 0.0001f);
            Assert.AreEqual(-0.5f, G.RotateToward(0f, -2f, 0.5f), 0.0001f);
            // Wraps through PI like Godot's angle_difference.
            Assert.AreEqual(3f + 0.2f, G.RotateToward(3f, -3f, 0.2f), 0.0001f);
        }

        [Test]
        public void SortieDamageAndShield()
        {
            var rules = ScriptableObject.CreateInstance<GameRules>();
            var sortie = new SortieState(rules) { powerLevel = 3, shield = true };
            Assert.IsTrue(sortie.Damage());
            Assert.AreEqual(2, sortie.hp, "the shield absorbs the hit");
            Assert.AreEqual(3, sortie.powerLevel);
            Assert.IsTrue(sortie.Damage());
            Assert.AreEqual(1, sortie.hp);
            Assert.AreEqual(2, sortie.powerLevel, "a real hit lowers the shared level");
            sortie.Bombs = 9;
            Assert.AreEqual(SortieState.MaxBombs, sortie.Bombs);
            Object.DestroyImmediate(rules);
        }

        class FloatComparer : System.Collections.IComparer
        {
            public int Compare(object a, object b) => Mathf.Abs((float)a - (float)b) < 0.001f ? 0 : 1;
        }
    }
}
