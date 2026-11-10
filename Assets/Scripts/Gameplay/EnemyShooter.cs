using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    /// <summary>Pattern assets are immutable; this component owns every runtime counter.</summary>
    public class EnemyShooter : MonoBehaviour
    {
        public List<PatternStep> steps = new List<PatternStep>();
        [Range(0f, 10f)] public float initialDelay = 1f;
        [Range(0f, 2f)] public float telegraphSeconds = 0.35f;

        [NonSerialized] public Transform projectiles;
        [NonSerialized] public Func<Transform> targetProvider;
        [NonSerialized] public Rect bounds;
        [NonSerialized] public int stepIndex;
        [NonSerialized] public int repetition;
        [NonSerialized] public int volley;
        [NonSerialized] public float timer;
        [NonSerialized] public float lockedAngle = Mathf.PI;
        [NonSerialized] public bool starting = true;
        [NonSerialized] public int volleysFired;
        [NonSerialized] public int burstsCompleted;
        [NonSerialized] public int curtainRouteIndex = -1;
        [NonSerialized] public int lastCurtainRoute = -1;
        [NonSerialized] public bool ricochetStartsAbove = true;

        readonly List<Projectile> burstProjectiles = new List<Projectile>();
        bool waitingForClear;
        bool warning;

        public Vector2 Position => transform.position;

        protected EnemyShip Ship { get; private set; }

        public bool Warning
        {
            get => warning;
            set
            {
                if (warning == value) return;
                warning = value;
                if (warning)
                {
                    var pattern = CurrentPattern;
                    if (pattern != null && pattern.audibleWarning) Sfx.Play("warning");
                }
            }
        }

        protected AttackPattern CurrentPattern =>
            stepIndex < steps.Count && steps[stepIndex] != null ? steps[stepIndex].pattern : null;

        protected virtual void Awake() => Ship = GetComponentInParent<EnemyShip>();

        protected virtual void Start() => timer = initialDelay;

        protected Transform Target() => targetProvider != null ? targetProvider() : null;

        public virtual void SetSequence(List<PatternStep> sequence)
        {
            steps = sequence;
            stepIndex = 0;
            repetition = 0;
            volley = 0;
            curtainRouteIndex = -1;
            starting = true;
            Warning = false;
            // A boss phase change must still wait for a pending bank shot's offspring.
            timer = waitingForClear ? Mathf.Max(timer, initialDelay) : initialDelay;
            if (!waitingForClear) burstProjectiles.Clear();
        }

        protected virtual void FixedUpdate() => Step(Time.fixedDeltaTime);

        void Step(float delta)
        {
            if (steps.Count == 0 || projectiles == null) return;
            for (int index = burstProjectiles.Count - 1; index >= 0; index--)
                if (burstProjectiles[index] == null || burstProjectiles[index].IsFreed) burstProjectiles.RemoveAt(index);
            // Give the bank charge its own stage even if the preceding wall still travels.
            if (starting && CurrentPattern != null && CurrentPattern.shape == AttackPattern.Shape.Ricochet && burstProjectiles.Count > 0)
                return;
            if (waitingForClear)
            {
                if (burstProjectiles.Count > 0) return;
                waitingForClear = false;
                // Preserve the complete counter window after the last hazard disappears.
                return;
            }
            if (!CanFire())
            {
                // Re-enter with a readable warning, never release a stored burst off screen.
                Warning = false;
                starting = true;
                volley = 0;
                timer = Mathf.Max(timer, 0.15f);
                return;
            }
            timer -= delta;
            // Preview later curtain rows during their existing interval, without delaying
            // the burst. The second wall also shows that it will move vertically.
            if (!starting && volley > 0 && CurrentPattern != null && CurrentPattern.shape == AttackPattern.Shape.Curtain)
                Warning = timer > 0f && timer <= telegraphSeconds;
            if (timer > 0f) return;
            var step = steps[stepIndex];
            if (step == null || step.pattern == null) return;
            var pattern = step.pattern;
            if (starting)
            {
                lockedAngle = AimAngle(pattern);
                ChooseCurtainRoute(pattern);
                starting = false;
                if (TelegraphDuration() > 0f)
                {
                    Warning = true;
                    timer = TelegraphDuration();
                    return;
                }
            }
            Warning = false;
            float angle = pattern.aim == AttackPattern.Aim.TrackEachVolley ? AimAngle(pattern) : lockedAngle;
            FireVolley(pattern, angle);
            volley += 1;
            if (volley < pattern.volleyCount)
            {
                timer = Mathf.Max(0.02f, pattern.volleyInterval);
                return;
            }
            burstsCompleted += 1;
            volley = 0;
            starting = true;
            repetition += 1;
            timer = Mathf.Max(0.05f, pattern.recovery);
            waitingForClear = pattern.waitForClear && burstProjectiles.Count > 0;
            if (repetition >= step.repetitions)
            {
                repetition = 0;
                timer += step.waitAfter;
                stepIndex = (stepIndex + 1) % steps.Count;
            }
        }

        protected void ChooseCurtainRoute(AttackPattern pattern)
        {
            curtainRouteIndex = -1;
            if (pattern.shape != AttackPattern.Shape.Curtain || pattern.corridorRoutes.Count == 0) return;
            int count = pattern.corridorRoutes.Count;
            if (count > 1 && lastCurtainRoute >= 0 && lastCurtainRoute < count)
            {
                curtainRouteIndex = UnityEngine.Random.Range(0, count - 1);
                if (curtainRouteIndex >= lastCurtainRoute) curtainRouteIndex += 1;
            }
            else
            {
                curtainRouteIndex = UnityEngine.Random.Range(0, count);
            }
            lastCurtainRoute = curtainRouteIndex;
        }

        public virtual bool CanFire()
        {
            if (G.HasArea(bounds) && !G.HasPoint(G.Grow(bounds, -32f), Position)) return false;
            if (Ship != null && Ship.movement != null && Ship.movement.mode == EnemyMovement.Mode.StrafeExit)
            {
                // The strafing battery commits to one firing station, then visibly retreats.
                var movement = Ship.movement;
                if (!movement.reachedHold || (!movement.stayForever && movement.holdElapsed >= movement.holdSeconds)) return false;
            }
            if (Ship != null && !Ship.isBoss && !Ship.isMidboss && targetProvider != null)
            {
                var target = targetProvider();
                if (target != null)
                {
                    Vector2 targetPosition = target.position;
                    return Position.x > targetPosition.x + 80f && Vector2.Distance(Position, targetPosition) >= 160f;
                }
            }
            return true;
        }

        protected virtual void Update()
        {
            if (Warning) DrawTelegraph();
        }

        protected float WorldScale => Mathf.Max(Mathf.Abs(transform.lossyScale.x), 0.01f);

        protected void DrawTelegraph()
        {
            var pattern = CurrentPattern;
            if (pattern == null) return;
            float progress = 1f - Mathf.Clamp01(timer / Mathf.Max(TelegraphDuration(), 0.01f));
            if (pattern.shape == AttackPattern.Shape.Ricochet)
            {
                DrawRicochetCharge(progress);
                return;
            }
            float s = WorldScale;
            Vector2 center = Position;
            var tint = new Color(1f, 0.95f, 0.5f, 0.9f);
            if (pattern.aim == AttackPattern.Aim.Fixed) tint = new Color(0.4f, 0.95f, 1f, 0.9f);
            else if (pattern.aim == AttackPattern.Aim.TrackEachVolley) tint = new Color(1f, 0.5f, 0.75f, 0.9f);
            float aimAngle = pattern.aim == AttackPattern.Aim.TrackEachVolley ? AimAngle(pattern) : lockedAngle;
            var forward = G.FromAngle(aimAngle);
            TelegraphDrawer.Ring(center, Mathf.Lerp(22f, 8f, progress) * s, 23, tint, 2.5f * s);
            TelegraphDrawer.Line(center + forward * 12f * s, center + forward * 36f * s, tint, 2f * s);
            if (pattern.shape == AttackPattern.Shape.Curtain)
            {
                // Show the upcoming wall's actual remote emitter positions.
                var inner = G.Grow(bounds, -16f);
                bool sways = pattern.SwayForVolley(volley) > 0f;
                foreach (var shot in pattern.ShotsForVolley(center, bounds, lockedAngle, volley, curtainRouteIndex))
                {
                    if (!G.HasPoint(inner, shot.position)) continue;
                    var point = shot.position;
                    TelegraphDrawer.Circle(point, 5f * s, tint);
                    TelegraphDrawer.Line(point, point + Vector2.left * 18f * s, tint, 2f * s);
                    if (!sways) continue;
                    for (int side = -1; side <= 1; side += 2)
                    {
                        // Godot side -1 is above the row (y - 22 in y-down space).
                        var tip = shot.position + new Vector2(0f, -side * 22f);
                        TelegraphDrawer.Line(tip + new Vector2(-6f, side * 7f), tip, tint, 1.5f * s);
                        TelegraphDrawer.Line(tip, tip + new Vector2(6f, side * 7f), tint, 1.5f * s);
                    }
                }
            }
            else
            {
                foreach (var offset in pattern.muzzleOffsets)
                    TelegraphDrawer.Ring(center + offset, 8f * s, 15, tint, 2f * s);
            }
        }

        protected float AimAngle(AttackPattern pattern)
        {
            if (pattern.shape == AttackPattern.Shape.Ricochet)
                return G.Angle(RicochetCore.LaunchDirection(Position, bounds, ricochetStartsAbove));
            if (pattern.aim != AttackPattern.Aim.Fixed && targetProvider != null)
            {
                var target = targetProvider();
                if (target != null)
                    return G.Angle(G.DirectionTo(Position, target.position)) + pattern.aimOffsetDegrees * Mathf.Deg2Rad;
            }
            return pattern.angleDegrees * Mathf.Deg2Rad;
        }

        /// <summary>Fires one volley and returns the projectiles it created.</summary>
        protected List<Projectile> FireVolley(AttackPattern pattern, float angle)
        {
            var created = new List<Projectile>();
            if (pattern.projectilePrefab == null) return created;
            volleysFired += 1;
            foreach (var shot in pattern.ShotsForVolley(Position, bounds, angle, volley, curtainRouteIndex))
            {
                // Only a curtain's edge continuation may start above/below the arena.
                // Its x emitter must still be visible, and CanFire gates the whole burst.
                float sway = pattern.SwayForVolley(volley);
                var spawnBounds = G.Grow(bounds, -16f);
                if (sway > 0f)
                    spawnBounds = new Rect(spawnBounds.x, bounds.yMin - sway, spawnBounds.width, bounds.height + sway * 2f);
                if (!G.HasPoint(spawnBounds, shot.position)) continue;
                var bullet = Instantiate(pattern.projectilePrefab, new Vector3(shot.position.x, shot.position.y, 0f), Quaternion.identity, projectiles);
                bullet.direction = G.FromAngle(shot.angle);
                bullet.bounds = bounds;
                if (bullet is RicochetCore ricochet)
                {
                    ricochet.startsAbove = ricochetStartsAbove;
                    ricochetStartsAbove = !ricochetStartsAbove;
                }
                if (bullet is CurtainBullet curtain)
                {
                    curtain.swayAmplitude = sway;
                    curtain.swayPeriod = pattern.curtainSwayPeriod;
                    curtain.despawnMargin = Mathf.Max(curtain.despawnMargin, sway);
                }
                bullet.target = Target();
                created.Add(bullet);
                TrackBurstProjectile(bullet);
                bullet.OffspringSpawned += TrackBurstProjectile;
            }
            if (created.Count > 0) Sfx.Play("enemy_shot");
            return created;
        }

        void TrackBurstProjectile(Projectile bullet) => burstProjectiles.Add(bullet);

        protected float TelegraphDuration()
        {
            var pattern = CurrentPattern;
            if (pattern != null && pattern.telegraphSeconds >= 0f) return pattern.telegraphSeconds;
            return telegraphSeconds;
        }

        void DrawRicochetCharge(float progress)
        {
            float s = WorldScale;
            Vector2 center = Position;
            var forward = RicochetCore.LaunchDirection(center, bounds, ricochetStartsAbove);
            var tint = RicochetCore.CueColor;
            TelegraphDrawer.Ring(center, Mathf.Lerp(20f, 10f, progress) * s, 31, tint, 2f * s);
            TelegraphDrawer.Line(center + forward * 12f * s, center + forward * 42f * s, tint, 2f * s);
            for (int index = 0; index < 3; index++)
                TelegraphDrawer.Circle(center + new Vector2(-24f, (index - 1) * 6f) * s, 2f * s, tint);
        }
    }
}
