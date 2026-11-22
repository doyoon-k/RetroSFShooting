using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    [DisallowMultipleComponent]
    [RequireComponent(typeof(Rigidbody2D))]
    [RequireComponent(typeof(EnemyMovement))]
    public class EnemyShip : MonoBehaviour
    {
        static readonly int FlashAmountId = Shader.PropertyToID("_FlashAmount");
        static readonly int TintId = Shader.PropertyToID("_Tint");
        /// <summary>Without a death animation, a body that breaks up in several bursts fades out over this long.</summary>
        public const float DeathFadeSeconds = 0.5f;
        /// <summary>
        /// A chain bursts no faster than this: a quicker chain reads as a frantic blur rather than a run of
        /// explosions, and the body flashes at its climax (more than three flashes a second can trigger
        /// photosensitive seizures, WCAG 2.3.1).
        /// </summary>
        public const float MinimumBurstSpacing = 1f / 3f;
        const int BurstCandidates = 24;
        const int CoreCandidates = 48;
        /// <summary>Burst candidates at least this share of the deepest candidate's depth count as well inside the body.</summary>
        const float DeepShare = 0.5f;
        const int RememberedBursts = 3;

        public enum BurstKind { Death, Damage }

        [Serializable]
        public struct BurstPattern
        {
            [Tooltip("Effects bursting at random points well inside the drawn body. A single one bursts at the body center.")]
            [Range(1, 20)] public int count;
            [Tooltip("Seconds from the first burst to the last; the bursts are evenly spaced. Keep the spacing at 1/3 s or more.")]
            [Range(0f, 8f)] public float seconds;
            [Tooltip("Extra bursts together with the last one: the climax of the chain.")]
            [Range(0, 6)] public int finale;

            /// <summary>Seconds between two bursts; 0 for a single burst.</summary>
            public float Spacing => count > 1 ? Mathf.Max(0f, seconds) / (count - 1) : 0f;

            /// <summary>Every burst, the finale included.</summary>
            public int Total => Mathf.Max(1, count) + Mathf.Max(0, finale);
        }

        public event Action<EnemyShip> Destroyed;
        public event Action<EnemyShip> Damaged;
        public event Action<float, int> HealthChanged;
        /// <summary>An effect bursts at this world point: a death burst, or a damage burst at the phase change.</summary>
        public event Action<EnemyShip, Vector2, BurstKind> BurstRequested;
        /// <summary>The death sequence is over; the ship is removed right after.</summary>
        public event Action<EnemyShip> DeathFinished;

        [Range(1, 2000)] public int maximumHp = 3;
        [Range(0, 10)] public int contactDamage = 1;
        [Range(0f, 1f)] public float hitFlashSeconds = 0.08f;
        [Range(0f, 10f)] public float despawnMargin = 3.2f;
        [Tooltip("Animator state played on death (the Godot AnimationPlayer animation name).")]
        public string deathAnimation = "";
        [Range(0f, 5f)] public float deathAnimationSeconds;
        public bool isBoss;
        public bool isMidboss;
        [Tooltip("Sfx cue for an ordinary death. Midbosses and the boss always use large_enemy_destroyed.")]
        public string destroyedCue = "small_enemy_destroyed";
        [Range(0.05f, 0.95f)] public float phaseThreshold = 0.5f;
        public List<PatternStep> secondPhase = new List<PatternStep>();
        public Pickup dropPrefab;
        [Range(0f, 1f)] public float dropChance;
        [Tooltip("Points for shooting this enemy down, multiplied by the proximity multiplier (x1-x4) of the killing hit.")]
        [Min(0)] public int scoreValue = 100;
        [Header("Break-up")]
        [Tooltip("Death effects. A chain ends at the thickest part of the body with its finale; the death animation (or, without one, a fade) starts then.")]
        public BurstPattern deathBursts = new BurstPattern { count = 1 };
        [Tooltip("Damage effects when the HP falls past Phase Threshold (ships with a second phase).")]
        public BurstPattern phaseBreakBursts = new BurstPattern { count = 1 };
        [Tooltip("Through its death chain the body blinks in this color with every burst (HDR; the boss's death animation peaks at 3, 2, 1).")]
        [ColorUsage(true, true)] public Color deathBlinkTint = new Color(3f, 2f, 1f, 1f);
        [Tooltip("Every Nth blink of the death chain is a white flash instead of the tint; 0 for tint blinks only.")]
        [Range(0, 6)] public int deathBlinkWhiteEvery;
        [Tooltip("The body flashes white with every damage burst of the phase change.")]
        public bool phaseBreakBlinkWhite = true;
        [Tooltip("At the phase change the ship holds fire this long, then starts its second phase.")]
        [Range(0f, 3f)] public float phaseBreakHoldSeconds = 0.75f;
        [Header("Parts")]
        [Tooltip("Body renderer: flashes on hits and sizes the hit effect.")]
        public SpriteRenderer visual;
        [Tooltip("Optional second renderer that also flashes.")]
        public SpriteRenderer core;

        [NonSerialized] public float hp;
        [NonSerialized] public Rect bounds;
        [NonSerialized] public bool phaseTwo;
        [NonSerialized] public bool dying;
        [NonSerialized] public float deathLeft;
        [NonSerialized] public EnemyMovement movement;
        [NonSerialized] public EnemyShooter shooter;

        float hitFlashLeft;
        float tintLeft;
        bool blinking;
        float clock;
        float secondPhaseAt = -1f;
        float endingAt = -1f;
        float fadeLeft;
        Color visualColor;
        Color coreColor;
        readonly List<ScheduledBurst> scheduled = new List<ScheduledBurst>();
        readonly List<Vector2> recentBursts = new List<Vector2>();
        Animator animator;
        Collider2D[] colliders;
        bool disableCollidersPending;
        bool freed;
        MaterialPropertyBlock block;
        public int LastHitMultiplier { get; private set; } = 1;
        public Color LastHitColor { get; private set; } = Color.white;
        public DamageMultiplierFeedback DamageFeedback { get; private set; }

        /// <summary>What this kill scores: the base score times the killing hit's proximity multiplier (bombs hit at x1).</summary>
        public int KillScore => scoreValue * Mathf.Max(1, LastHitMultiplier);

        public Vector2 Position
        {
            get => transform.position;
            set => transform.SetPosition2D(value);
        }

        /// <summary>World center of the drawn body (its sprite's opaque pixels); the ship position without a sprite.</summary>
        public Vector2 BodyCenter => visual != null && visual.sprite != null
            ? (Vector2)visual.transform.TransformPoint(EnemyHitEffect.OpaqueRect(visual.sprite).center)
            : Position;

        /// <summary>Ships with a second phase: the boss, and any ship given a Second Phase pattern.</summary>
        public bool HasPhases => isBoss || secondPhase.Count > 0;

        /// <summary>Bursts still to come, of either kind.</summary>
        public int PendingBursts => scheduled.Count;

        /// <summary>The second phase has been reached but its pattern has not started yet.</summary>
        public bool InPhaseBreak => secondPhaseAt >= 0f;

        enum BurstPlace { Random, Center, Core }

        enum Blink { None, Tint, White }

        struct ScheduledBurst
        {
            public float time;
            public BurstKind kind;
            public BurstPlace place;
            public Blink blink;
        }

        /// <summary>The body is blinking through its death chain (before its death animation or fade).</summary>
        public bool DeathBlinking => blinking;

        void Awake()
        {
            hp = maximumHp;
            movement = GetComponent<EnemyMovement>();
            shooter = GetComponentInChildren<EnemyShooter>(true);
            animator = GetComponent<Animator>();
            colliders = GetComponentsInChildren<Collider2D>(true);
            block = new MaterialPropertyBlock();
        }

        public void ApplyAttackSequence(AttackSequence sequence)
        {
            if (sequence == null) return;
            var emitter = shooter;
            if (emitter == null && sequence.steps.Count > 0)
            {
                var host = new GameObject("Shooter");
                host.transform.SetParent(transform, false);
                emitter = host.AddComponent<EnemyShooter>();
            }
            if (emitter != null)
            {
                emitter.initialDelay = sequence.initialDelay;
                emitter.SetSequence(new List<PatternStep>(sequence.steps));
                shooter = emitter;
            }
        }

        void FixedUpdate()
        {
            if (freed) return;
            float delta = Time.fixedDeltaTime;
            if (disableCollidersPending)
            {
                disableCollidersPending = false;
                foreach (var shape in colliders) shape.enabled = false;
            }
            if (hitFlashLeft > 0f)
            {
                hitFlashLeft = Mathf.Max(0f, hitFlashLeft - delta);
                if (hitFlashLeft == 0f) SetFlash(0f);
            }
            if (tintLeft > 0f) tintLeft = Mathf.Max(0f, tintLeft - delta);
            clock += delta;
            FireDueBursts();
            if (secondPhaseAt >= 0f && clock >= secondPhaseAt) StartSecondPhase();
            if (dying)
            {
                if (endingAt >= 0f && clock >= endingAt) BeginEnding();
                if (fadeLeft > 0f)
                {
                    fadeLeft = Mathf.Max(0f, fadeLeft - delta);
                    SetAlpha(fadeLeft / DeathFadeSeconds);
                }
                deathLeft -= delta;
                if (deathLeft <= 0f) Free();
            }
            else if (!isBoss && !G.HasPoint(G.Grow(bounds, despawnMargin), Position))
            {
                Free();
            }
        }

        public void TakeProjectileDamage(int baseDamage, int multiplier, ProximityFeedbackStyle feedback, Vector2 impact)
        {
            float before = hp;
            ApplyDamage(baseDamage * multiplier, multiplier, feedback != null ? feedback.ColorFor(multiplier) : Color.white);
            if (hp >= before || feedback == null) return;
            if (DamageFeedback == null || DamageFeedback.TimeLeft <= 0f)
            {
                var host = new GameObject("DamageMultiplierFeedback");
                host.transform.SetParent(transform.parent, false);
                DamageFeedback = host.AddComponent<DamageMultiplierFeedback>();
            }
            DamageFeedback.ShowHit(this, impact, multiplier, feedback);
        }

        public void TakeDamage(float amount) => ApplyDamage(amount, 1, Color.white);

        void ApplyDamage(float amount, int multiplier, Color hitColor)
        {
            if (dying || hp <= 0f || GamePause.Paused) return;
            float previousHp = hp;
            hp = Mathf.Max(0f, hp - amount);
            HealthChanged?.Invoke(hp, maximumHp);
            if (hp < previousHp)
            {
                LastHitMultiplier = multiplier;
                LastHitColor = hitColor;
                hitFlashLeft = hitFlashSeconds;
                SetFlash(hitFlashLeft > 0f ? 1f : 0f);
                Damaged?.Invoke(this);
            }
            if (HasPhases && !phaseTwo && hp / maximumHp <= phaseThreshold)
            {
                phaseTwo = true;
                if (hp > 0f) BeginPhaseBreak();
            }
            if (hp == 0f) BeginDeath();
        }

        /// <summary>Holds fire while the damage effects burst over the body, then the second phase starts.</summary>
        void BeginPhaseBreak()
        {
            Sfx.Play("boss_phase_two");
            if (shooter != null) shooter.enabled = false;
            Schedule(phaseBreakBursts, BurstKind.Damage);
            secondPhaseAt = clock + Mathf.Max(phaseBreakHoldSeconds, phaseBreakBursts.seconds);
            FireDueBursts();
        }

        void StartSecondPhase()
        {
            secondPhaseAt = -1f;
            if (dying || shooter == null) return;
            if (secondPhase.Count > 0) shooter.SetSequence(secondPhase);
            shooter.enabled = true;
        }

        void BeginDeath()
        {
            dying = true;
            movement.enabled = false;
            if (shooter != null) shooter.enabled = false;
            // Godot set_deferred("monitorable", false): stop being hit after this physics step.
            disableCollidersPending = true;
            // A phase change in progress gives way to the death.
            scheduled.Clear();
            secondPhaseAt = -1f;
            blinking = deathBursts.count > 1;
            if (blinking)
            {
                // The death chain blinks in its own color from the start: drop the killing hit's white flash.
                hitFlashLeft = 0f;
                SetFlash(0f);
            }
            Destroyed?.Invoke(this);
            Schedule(deathBursts, BurstKind.Death);
            float span = Mathf.Max(0f, deathBursts.seconds);
            endingAt = clock + span;
            deathLeft = span + (HasDeathAnimation ? deathAnimationSeconds : deathBursts.count > 1 ? DeathFadeSeconds : 0f);
            FireDueBursts();
            if (clock >= endingAt) BeginEnding();
            if (deathLeft <= 0f) Free();
        }

        bool HasDeathAnimation => animator != null && !string.IsNullOrEmpty(deathAnimation) &&
            animator.HasState(0, Animator.StringToHash(deathAnimation));

        /// <summary>From the last death burst: the death animation, or a fade for a ship without one.</summary>
        void BeginEnding()
        {
            endingAt = -1f;
            if (blinking)
            {
                // Hand the tint back to the death animation (or the fade) at its normal value.
                blinking = false;
                tintLeft = 0f;
                SetTint(Color.white);
            }
            if (HasDeathAnimation) animator.Play(deathAnimation, 0, 0f);
            else if (deathBursts.count > 1)
            {
                if (visual != null) visualColor = visual.color;
                if (core != null) coreColor = core.color;
                fadeLeft = DeathFadeSeconds;
            }
        }

        void Schedule(BurstPattern pattern, BurstKind kind)
        {
            int count = Mathf.Max(1, pattern.count);
            float step = pattern.Spacing;
            for (int i = 0; i < count; i++)
            {
                bool last = i == count - 1;
                var place = count == 1 ? BurstPlace.Center
                    : kind == BurstKind.Death && last ? BurstPlace.Core : BurstPlace.Random;
                // A dying body blinks in its death tint with every burst of its chain (white every Nth time if set);
                // a breaking one flashes white with every damage burst.
                var blink = Blink.None;
                if (kind == BurstKind.Death && count > 1)
                    blink = deathBlinkWhiteEvery > 0 && (i + 1) % deathBlinkWhiteEvery == 0 ? Blink.White : Blink.Tint;
                else if (kind == BurstKind.Damage && phaseBreakBlinkWhite) blink = Blink.White;
                scheduled.Add(new ScheduledBurst { time = clock + step * i, kind = kind, place = place, blink = blink });
            }
            for (int i = 0; i < pattern.finale; i++)
                scheduled.Add(new ScheduledBurst { time = clock + step * (count - 1), kind = kind, place = BurstPlace.Random });
        }

        void FireDueBursts()
        {
            for (int i = 0; i < scheduled.Count;)
            {
                var burst = scheduled[i];
                if (burst.time > clock + 0.0001f)
                {
                    i++;
                    continue;
                }
                scheduled.RemoveAt(i);
                Vector2 point = burst.place == BurstPlace.Center ? BodyCenter
                    : burst.place == BurstPlace.Core ? CorePoint() : RandomBodyPoint();
                // A blink lasts half the spacing, so the body is lit and plain in turn: at most one flash per burst.
                float blinkSeconds = Mathf.Max(hitFlashSeconds, (burst.kind == BurstKind.Death ? deathBursts : phaseBreakBursts).Spacing * 0.5f);
                if (burst.blink == Blink.White)
                {
                    tintLeft = 0f;
                    hitFlashLeft = blinkSeconds;
                    SetFlash(1f);
                }
                else if (burst.blink == Blink.Tint) tintLeft = blinkSeconds;
                BurstRequested?.Invoke(this, point, burst.kind);
            }
        }

        /// <summary>
        /// A random point well inside the drawn body: candidates are drawn over the sprite's tight mesh, the ones
        /// near its outline (thin parts, edges) are dropped, and of the rest the one farthest from the last bursts
        /// wins, so a chain spreads over the body without bursting off it.
        /// </summary>
        public Vector2 RandomBodyPoint()
        {
            var body = BodyMesh.Of(visual);
            if (body == null) return visual != null && visual.sprite != null ? BodyCenter : Position;
            var candidates = new Vector2[BurstCandidates];
            var depths = new float[BurstCandidates];
            float deepest = 0f;
            for (int i = 0; i < BurstCandidates; i++)
            {
                candidates[i] = body.Sample();
                depths[i] = body.Depth(candidates[i]);
                deepest = Mathf.Max(deepest, depths[i]);
            }
            Vector2 best = BodyCenter;
            float bestGap = -1f;
            for (int i = 0; i < BurstCandidates; i++)
            {
                if (depths[i] < deepest * DeepShare) continue;
                Vector2 point = visual.transform.TransformPoint(candidates[i]);
                float gap = float.MaxValue;
                foreach (var previous in recentBursts) gap = Mathf.Min(gap, Vector2.Distance(previous, point));
                if (gap > bestGap)
                {
                    bestGap = gap;
                    best = point;
                }
            }
            recentBursts.Add(best);
            if (recentBursts.Count > RememberedBursts) recentBursts.RemoveAt(0);
            return best;
        }

        static float TriangleArea(Vector2 a, Vector2 b, Vector2 c) =>
            Mathf.Abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) * 0.5f;

        /// <summary>The thickest part of the drawn body: the deepest of many points sampled over its tight mesh.</summary>
        public Vector2 CorePoint()
        {
            var body = BodyMesh.Of(visual);
            if (body == null) return visual != null && visual.sprite != null ? BodyCenter : Position;
            Vector2 best = Vector2.zero;
            float deepest = -1f;
            for (int i = 0; i < CoreCandidates; i++)
            {
                var point = body.Sample();
                float depth = body.Depth(point);
                if (depth > deepest)
                {
                    deepest = depth;
                    best = point;
                }
            }
            return visual.transform.TransformPoint(best);
        }

        /// <summary>
        /// A sprite's tight mesh in its local units: area-weighted random points, and how far a point lies from
        /// the mesh outline (the edges only one triangle uses).
        /// </summary>
        public sealed class BodyMesh
        {
            readonly Vector2[] vertices;
            readonly ushort[] triangles;
            readonly float[] cumulativeArea;
            readonly List<Vector2Int> outline = new List<Vector2Int>();

            BodyMesh(Sprite sprite)
            {
                vertices = sprite.vertices;
                triangles = sprite.triangles;
                cumulativeArea = new float[triangles.Length / 3];
                var edges = new Dictionary<Vector2Int, int>();
                float total = 0f;
                for (int t = 0; t < triangles.Length; t += 3)
                {
                    total += TriangleArea(vertices[triangles[t]], vertices[triangles[t + 1]], vertices[triangles[t + 2]]);
                    cumulativeArea[t / 3] = total;
                    for (int e = 0; e < 3; e++)
                    {
                        int a = triangles[t + e], b = triangles[t + (e + 1) % 3];
                        var key = new Vector2Int(Mathf.Min(a, b), Mathf.Max(a, b));
                        edges[key] = edges.TryGetValue(key, out int uses) ? uses + 1 : 1;
                    }
                }
                foreach (var edge in edges)
                    if (edge.Value == 1) outline.Add(edge.Key);
            }

            public static BodyMesh Of(SpriteRenderer renderer)
            {
                var sprite = renderer != null ? renderer.sprite : null;
                if (sprite == null || sprite.vertices == null || sprite.triangles == null || sprite.triangles.Length < 3) return null;
                return new BodyMesh(sprite);
            }

            public Vector2 Sample()
            {
                float pick = UnityEngine.Random.value * cumulativeArea[cumulativeArea.Length - 1];
                int triangle = 0;
                while (triangle < cumulativeArea.Length - 1 && cumulativeArea[triangle] < pick) triangle++;
                int t = triangle * 3;
                float u = UnityEngine.Random.value, v = UnityEngine.Random.value;
                if (u + v > 1f)
                {
                    u = 1f - u;
                    v = 1f - v;
                }
                Vector2 a = vertices[triangles[t]], b = vertices[triangles[t + 1]], c = vertices[triangles[t + 2]];
                return a + u * (b - a) + v * (c - a);
            }

            /// <summary>Distance from a point inside the mesh to its outline.</summary>
            public float Depth(Vector2 point)
            {
                float nearest = float.MaxValue;
                foreach (var edge in outline)
                    nearest = Mathf.Min(nearest, DistanceToSegment(point, vertices[edge.x], vertices[edge.y]));
                return nearest;
            }

            static float DistanceToSegment(Vector2 point, Vector2 a, Vector2 b)
            {
                Vector2 ab = b - a;
                float length = ab.sqrMagnitude;
                float along = length > 0f ? Mathf.Clamp01(Vector2.Dot(point - a, ab) / length) : 0f;
                return Vector2.Distance(point, a + along * ab);
            }
        }

        void SetAlpha(float alpha)
        {
            if (visual != null) visual.color = new Color(visualColor.r, visualColor.g, visualColor.b, visualColor.a * alpha);
            if (core != null) core.color = new Color(coreColor.r, coreColor.g, coreColor.b, coreColor.a * alpha);
        }

        public void Free()
        {
            if (freed) return;
            freed = true;
            if (dying) DeathFinished?.Invoke(this);
            Destroy(gameObject);
        }

        public bool IsFreed => freed;

        /// <summary>
        /// The blink tint goes on after the Animator has run: its idle state writes the default tint every frame,
        /// and the death animation takes the tint over once the blinking stops.
        /// </summary>
        void LateUpdate()
        {
            if (blinking && !freed) SetTint(tintLeft > 0f ? deathBlinkTint : Color.white);
        }

        void SetTint(Color tint)
        {
            ApplyTint(visual, tint);
            ApplyTint(core, tint);
        }

        void ApplyTint(SpriteRenderer target, Color tint)
        {
            if (target == null) return;
            target.GetPropertyBlock(block);
            block.SetColor(TintId, tint);
            target.SetPropertyBlock(block);
        }

        void SetFlash(float amount)
        {
            ApplyFlash(visual, amount);
            ApplyFlash(core, amount);
        }

        void ApplyFlash(SpriteRenderer target, float amount)
        {
            if (target == null) return;
            target.GetPropertyBlock(block);
            block.SetFloat(FlashAmountId, amount);
            target.SetPropertyBlock(block);
        }
    }
}
