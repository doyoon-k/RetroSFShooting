using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    /// <summary>
    /// M1 cycles keep their own hazards and wait for them before the counter window.
    /// An explicit lab attack override still uses EnemyShooter's ordinary sequence.
    /// </summary>
    public class SiegeShooter : EnemyShooter
    {
        public enum Cycle { Lure, Cross, Core }
        public enum Phase { Wait, Lure, Deploy, Wall, WaitWall, Cross, Release, WaitClear, Recovery }

        public event Action<int> CycleStarted;
        public event Action<int> CounterWindowStarted;

        public bool wallCyclesEnabled = true;
        public Projectile openingBulletPrefab;
        public Projectile crossBulletPrefab;
        public BroodCore corePrefab;
        [Range(0.1f, 2f)] public float lureInterval = 0.45f;
        [Range(0.1f, 2f)] public float openingPause = 0.6f;
        [Range(0.1f, 2f)] public float crossInterval = 0.35f;
        [Range(10f, 40f)] public float crossAngleDegrees = 24f;
        [Range(0.1f, 2f)] public float coreStagger = 0.6f;
        [Range(1f, 5f)] public float counterSeconds = 2f;

        [NonSerialized] public Cycle cycleIndex = Cycle.Lure;
        [NonSerialized] public Phase cyclePhase = Phase.Wait;
        [NonSerialized] public int cyclesCompleted;

        int extraVolley;
        float lureAngle = Mathf.PI;
        readonly List<Projectile> active = new List<Projectile>();
        readonly List<Projectile> walls = new List<Projectile>();
        readonly List<BroodCore> corePair = new List<BroodCore>();

        static readonly float[] CoreFractions = { 0.16f, 0.84f };

        public override void SetSequence(List<PatternStep> sequence)
        {
            CancelHeldCores();
            wallCyclesEnabled = false;
            base.SetSequence(sequence);
        }

        public override bool CanFire()
        {
            if (wallCyclesEnabled && Ship != null && Ship.movement != null &&
                Ship.movement.mode == EnemyMovement.Mode.EnterHoldExit && !Ship.movement.reachedHold)
                return false;
            return base.CanFire();
        }

        static bool Previews(Phase phase) =>
            phase == Phase.Lure || phase == Phase.Deploy || phase == Phase.Wall || phase == Phase.Cross;

        protected override void FixedUpdate()
        {
            if (!wallCyclesEnabled)
            {
                base.FixedUpdate();
                return;
            }
            if (steps.Count == 0 || steps[0] == null || steps[0].pattern == null || projectiles == null) return;
            if (!CanFire())
            {
                CancelHeldCores();
                cyclePhase = Phase.Wait;
                starting = true;
                Warning = false;
                volley = 0;
                timer = Mathf.Max(timer, 0.15f);
                return;
            }
            PruneHazards();
            timer = Mathf.Max(0f, timer - Time.fixedDeltaTime);
            Warning = Previews(cyclePhase) && timer > 0f && timer <= telegraphSeconds;
            if (timer > 0f) return;
            switch (cyclePhase)
            {
                case Phase.Wait:
                    BeginCycle();
                    break;
                case Phase.Lure:
                    SpawnShot(openingBulletPrefab, Position, lureAngle, 450f);
                    volleysFired += 1;
                    extraVolley += 1;
                    if (extraVolley < 2)
                    {
                        Schedule(Phase.Lure, lureInterval);
                    }
                    else
                    {
                        burstsCompleted += 1;
                        Schedule(Phase.Wall, openingPause + telegraphSeconds);
                    }
                    break;
                case Phase.Deploy:
                    DeployCores();
                    volleysFired += 1;
                    burstsCompleted += 1;
                    Schedule(Phase.Wall, openingPause + telegraphSeconds);
                    break;
                case Phase.Wall:
                {
                    var pattern = steps[0].pattern;
                    foreach (var bullet in FireVolley(pattern, Mathf.PI))
                    {
                        if (bullet is CurtainBullet)
                        {
                            Track(bullet);
                            walls.Add(bullet);
                        }
                    }
                    volley += 1;
                    if (volley < pattern.volleyCount)
                    {
                        Schedule(Phase.Wall, pattern.volleyInterval);
                    }
                    else
                    {
                        burstsCompleted += 1;
                        volley = 0;
                        Schedule(Phase.WaitWall, 0f);
                    }
                    break;
                }
                case Phase.WaitWall:
                    if (walls.Count > 0) return;
                    switch (cycleIndex)
                    {
                        case Cycle.Lure:
                            Schedule(Phase.WaitClear, 0f);
                            break;
                        case Cycle.Cross:
                            extraVolley = 0;
                            Schedule(Phase.Cross, telegraphSeconds);
                            break;
                        case Cycle.Core:
                            ReleaseCore(0);
                            Schedule(Phase.Release, coreStagger);
                            break;
                    }
                    break;
                case Phase.Cross:
                    for (int side = -1; side <= 1; side += 2)
                        SpawnShot(crossBulletPrefab, CrossMuzzle(side), CrossAngle(side), 400f);
                    volleysFired += 1;
                    extraVolley += 1;
                    if (extraVolley < 3)
                    {
                        Schedule(Phase.Cross, crossInterval);
                    }
                    else
                    {
                        burstsCompleted += 1;
                        Schedule(Phase.WaitClear, 0f);
                    }
                    break;
                case Phase.Release:
                    ReleaseCore(1);
                    Schedule(Phase.WaitClear, 0f);
                    break;
                case Phase.WaitClear:
                    if (active.Count == 0)
                    {
                        cyclesCompleted += 1;
                        starting = true;
                        Schedule(Phase.Recovery, counterSeconds);
                        CounterWindowStarted?.Invoke((int)cycleIndex);
                        Sfx.Play("counter_window");
                    }
                    break;
                case Phase.Recovery:
                    cycleIndex = (Cycle)(((int)cycleIndex + 1) % 3);
                    BeginCycle();
                    break;
            }
        }

        void BeginCycle()
        {
            ChooseCurtainRoute(steps[0].pattern);
            lockedAngle = Mathf.PI;
            volley = 0;
            extraVolley = 0;
            corePair.Clear();
            starting = false;
            lureAngle = Mathf.PI;
            var target = Target();
            if (target != null) lureAngle = G.Angle(G.DirectionTo(Position, target.position));
            var first = cycleIndex == Cycle.Lure ? Phase.Lure : (cycleIndex == Cycle.Cross ? Phase.Wall : Phase.Deploy);
            Schedule(first, telegraphSeconds);
            CycleStarted?.Invoke((int)cycleIndex);
            Sfx.Play("siege_charge");
        }

        void Schedule(Phase next, float delay)
        {
            cyclePhase = next;
            timer = Mathf.Max(0f, delay);
            Warning = Previews(next) && timer > 0f && timer <= telegraphSeconds;
        }

        Projectile SpawnShot(Projectile prefab, Vector2 point, float angle, float speedOverride = 0f)
        {
            if (prefab == null || !G.HasPoint(G.Grow(bounds, -16f), point)) return null;
            var bullet = Instantiate(prefab, new Vector3(point.x, point.y, 0f), Quaternion.identity, projectiles);
            bullet.direction = G.FromAngle(angle);
            bullet.bounds = bounds;
            if (speedOverride > 0f) bullet.speed = speedOverride;
            Track(bullet);
            Sfx.Play("enemy_shot");
            return bullet;
        }

        Vector2 CorePoint(float fraction) => new Vector2(Position.x, G.FromTop(bounds, fraction));

        void DeployCores()
        {
            foreach (float fraction in CoreFractions)
            {
                var core = SpawnShot(corePrefab, CorePoint(fraction), Mathf.PI) as BroodCore;
                if (core != null)
                {
                    core.hatchHeld = true;
                    core.OffspringSpawned += Track;
                }
                corePair.Add(core);
            }
        }

        void ReleaseCore(int index)
        {
            if (index >= corePair.Count) return;
            var core = corePair[index];
            if (core != null && !core.IsFreed) core.hatchHeld = false;
        }

        void Track(Projectile bullet) => active.Add(bullet);

        void PruneHazards()
        {
            for (int index = active.Count - 1; index >= 0; index--)
                if (active[index] == null || active[index].IsFreed) active.RemoveAt(index);
            for (int index = walls.Count - 1; index >= 0; index--)
                if (walls[index] == null || walls[index].IsFreed) walls.RemoveAt(index);
        }

        void CancelHeldCores()
        {
            foreach (var core in corePair)
                if (core != null && core.hatchHeld) core.Free();
            corePair.Clear();
        }

        void OnDestroy() => CancelHeldCores();

        /// <summary>Godot side -1 is the upper muzzle (23% from the top), side 1 the lower one.</summary>
        Vector2 CrossMuzzle(int side) => new Vector2(Position.x, G.FromTop(bounds, side < 0 ? 0.23f : 0.77f));

        /// <summary>The upper muzzle fires down-left and the lower one up-left, so the shots cross.</summary>
        float CrossAngle(int side) => Mathf.PI - side * crossAngleDegrees * Mathf.Deg2Rad;

        protected override void Update()
        {
            if (!wallCyclesEnabled || cyclePhase == Phase.Wall)
            {
                base.Update();
                return;
            }
            if (!Warning) return;
            float s = WorldScale;
            var tint = new Color(1f, 0.95f, 0.5f, 0.9f);
            if (cyclePhase == Phase.Lure)
            {
                var forward = G.FromAngle(lureAngle);
                TelegraphDrawer.Ring(Position, 12f * s, 23, tint, 2.5f * s);
                TelegraphDrawer.Line(Position + forward * 12f * s, Position + forward * 48f * s, tint, 2f * s);
            }
            else if (cyclePhase == Phase.Cross)
            {
                for (int side = -1; side <= 1; side += 2)
                {
                    var point = CrossMuzzle(side);
                    var direction = G.FromAngle(CrossAngle(side));
                    TelegraphDrawer.Ring(point, 8f * s, 15, tint, 2f * s);
                    TelegraphDrawer.Line(point, point + direction * 240f, tint, 2f * s);
                }
            }
            else if (cyclePhase == Phase.Deploy)
            {
                foreach (float fraction in CoreFractions)
                    TelegraphDrawer.Ring(CorePoint(fraction), 8f * s, 15, tint, 2f * s);
            }
        }
    }
}
