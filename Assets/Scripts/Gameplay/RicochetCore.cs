using System;
using UnityEngine;

namespace RetroSF
{
    /// <summary>A fixed bank shot: top/left/bottom or its vertical mirror, one generation only.</summary>
    public class RicochetCore : Projectile
    {
        public struct Bank
        {
            public Vector2 position;
            public Vector2 normal;
            public float distance;
        }

        public event Action<int, Vector2> Banked;

        public const float EdgeInset = 64f;
        public const int MaxBanks = 3;
        public static readonly Color CueColor = new Color(1f, 0.85f, 0.35f, 0.95f);

        public Projectile childPrefab;
        public bool startsAbove = true;
        [Range(0.1f, 1f)] public float bankWarningSeconds = 0.45f;
        [Range(0.1f, 0.8f)] public float bankPauseSeconds = 0.18f;
        [Range(0.5f, 1f)] public float speedRetention = 0.96f;
        [Range(1, 15)] public int childCount = 7;
        [Range(1, 15)] public int middleChildCount = 9;
        [Range(1, 15)] public int finalChildCount = 11;
        [Range(20f, 90f)] public float childSpread = 70f;
        [Range(50f, 600f)] public float childSpeed = 360f;
        [Range(0.5f, 5f)] public float childLifetime = 3.8f;
        public bool aimedFans = true;
        public SpriteRenderer visual;
        public Collider2D collisionShape2D;

        [NonSerialized] public int bankCount;
        [NonSerialized] public float bankWait;
        [NonSerialized] public Rect bankArena;
        Vector2 bankNormal;
        int fanBank;
        Vector2 fanCenter;
        Vector3 visualScale = Vector3.one;
        Vector3 collisionScale = Vector3.one;

        public static Rect ReflectionBounds(Rect arena) => G.Grow(arena, -EdgeInset);

        public static Vector2 LaunchDirection(Vector2 origin, Rect arena, bool above)
        {
            var field = ReflectionBounds(arena);
            // Unfold the first two banks to put the left-wall contact at mid-height.
            float vertical = above ? field.yMax - origin.y : origin.y - field.yMin;
            float horizontal = Mathf.Max(1f, origin.x - field.xMin);
            return new Vector2(-horizontal, (above ? 1f : -1f) * (vertical + field.height * 0.5f)).normalized;
        }

        public static Vector2 FanDirection(Vector2 outgoing, Vector2 normal, float spread)
        {
            // Shallow bank shots still put the entire fan inside the arena.
            float limit = Mathf.PI * 0.5f - spread * Mathf.Deg2Rad * 0.5f;
            float offset = G.Wrapf(G.Angle(outgoing) - G.Angle(normal), -Mathf.PI, Mathf.PI);
            return G.FromAngle(G.Angle(normal) + Mathf.Clamp(offset, -limit, limit));
        }

        protected override void OnReady()
        {
            bankArena = ReflectionBounds(bounds);
            direction = LaunchDirection(Position, bounds, startsAbove);
            base.OnReady();
            if (visual != null) visualScale = visual.transform.localScale;
            if (collisionShape2D != null) collisionScale = collisionShape2D.transform.localScale;
            if (!G.HasArea(bankArena) || !G.HasPoint(bankArena, Position)) Free();
        }

        public Bank NextBank()
        {
            float distance = float.PositiveInfinity;
            Vector2 normal = Vector2.zero;
            Vector2 position = Position;
            if (Mathf.Abs(direction.x) > 0.0001f)
            {
                float wallX = direction.x < 0f ? bankArena.xMin : bankArena.xMax;
                distance = Mathf.Max(0f, (wallX - position.x) / direction.x);
                normal = direction.x < 0f ? Vector2.right : Vector2.left;
            }
            if (Mathf.Abs(direction.y) > 0.0001f)
            {
                // Moving up (+y) meets the top wall, whose normal points back down.
                float wallY = direction.y > 0f ? bankArena.yMax : bankArena.yMin;
                float vertical = Mathf.Max(0f, (wallY - position.y) / direction.y);
                if (vertical < distance)
                {
                    distance = vertical;
                    normal = direction.y > 0f ? Vector2.down : Vector2.up;
                }
            }
            return new Bank { position = position + direction * distance, normal = normal, distance = distance };
        }

        public int FanCount(int index)
        {
            if (index >= MaxBanks) return finalChildCount;
            return index == 2 ? middleChildCount : childCount;
        }

        void LockFan(Bank bank, int index)
        {
            if (fanBank == index) return;
            Vector2 outgoing = G.Bounce(direction, bank.normal);
            if (aimedFans && target != null) outgoing = G.DirectionTo(bank.position, target.position);
            fanCenter = FanDirection(outgoing, bank.normal, childSpread);
            fanBank = index;
        }

        protected override void Step(float delta)
        {
            if (spent) return;
            age += delta;
            lifetime -= delta;
            if (lifetime <= 0f || !G.HasPoint(G.Grow(bounds, despawnMargin), Position))
            {
                Free();
                return;
            }
            float remaining = delta;
            while (remaining > 0.00001f && !IsFreed)
            {
                if (bankWait > 0f)
                {
                    float elapsed = Mathf.Min(bankWait, remaining);
                    bankWait = Mathf.Max(0f, bankWait - elapsed);
                    remaining -= elapsed;
                    if (bankWait <= 0.00001f)
                    {
                        bankWait = 0f;
                        EmitFan();
                        if (bankCount >= MaxBanks)
                        {
                            Free();
                            return;
                        }
                    }
                }
                else
                {
                    var bank = NextBank();
                    float travel = bank.distance / Mathf.Max(speed, 1f);
                    if (travel <= bankWarningSeconds) LockFan(bank, bankCount + 1);
                    if (travel > remaining)
                    {
                        Position += direction * speed * remaining;
                        remaining = 0f;
                    }
                    else
                    {
                        LockFan(bank, bankCount + 1);
                        Position = bank.position;
                        remaining -= travel;
                        direction = G.Bounce(direction, bank.normal);
                        bankNormal = bank.normal;
                        bankCount += 1;
                        speed *= speedRetention;
                        bankWait = bankPauseSeconds;
                        Banked?.Invoke(bankCount, bank.normal);
                        Sfx.Play("ricochet_bank");
                        if (bankCount == MaxBanks)
                        {
                            // The final cue remains visible, but the exhausted core cannot hit.
                            if (collisionShape2D != null) collisionShape2D.enabled = false;
                            if (visual != null) visual.enabled = false;
                        }
                    }
                }
            }
            transform.SetRotation2D(G.Angle(direction));
            float sizeFactor = 1f - 0.14f * Mathf.Min(bankCount, MaxBanks - 1);
            if (visual != null) visual.transform.localScale = visualScale * sizeFactor;
            if (collisionShape2D != null) collisionShape2D.transform.localScale = collisionScale * sizeFactor;
            if (bankWait <= 0f)
            {
                var upcoming = NextBank();
                if (upcoming.distance / Mathf.Max(speed, 1f) <= bankWarningSeconds)
                    LockFan(upcoming, bankCount + 1);
            }
        }

        void EmitFan()
        {
            if (spent || IsFreed || childPrefab == null) return;
            if (childPrefab is RicochetCore || childPrefab is BroodCore) return;
            int count = FanCount(bankCount);
            Vector2 center = fanCenter;
            for (int index = 0; index < count; index++)
            {
                float offset = count > 1 ? childSpread * Mathf.Deg2Rad * ((float)index / Mathf.Max(1, count - 1) - 0.5f) : 0f;
                var childDirection = G.Rotated(center, offset);
                Vector2 spawn = Position + childDirection * 18f;
                var child = Instantiate(childPrefab, new Vector3(spawn.x, spawn.y, 0f), Quaternion.identity, transform.parent);
                child.direction = childDirection;
                child.bounds = bounds;
                child.speed = childSpeed;
                child.lifetime = childLifetime;
                RaiseOffspring(child);
            }
            Sfx.Play("bullet_split");
        }

        void Update()
        {
            if (spent || IsFreed || !IsReady) return;
            Vector2 position = Position;
            float worldScale = Mathf.Max(Mathf.Abs(transform.lossyScale.x), 0.01f);
            float rotation = G.Angle(direction);
            if (bankCount < MaxBanks)
            {
                float radius = 18f * (1f - 0.14f * bankCount);
                TelegraphDrawer.Ring(position, radius * worldScale, 32, CueColor, 1.3f * worldScale);
                int remainingBanks = MaxBanks - bankCount;
                for (int index = 0; index < remainingBanks; index++)
                {
                    var local = new Vector2(-radius - 5f, (index - (remainingBanks - 1) * 0.5f) * 5f);
                    TelegraphDrawer.Circle(position + G.Rotated(local, rotation) * worldScale, 1.5f * worldScale, CueColor);
                }
            }
            Vector2 point = position;
            Vector2 outgoing = direction;
            Vector2 normal = bankNormal;
            float untilBank = 0f;
            int nextCount = bankCount;
            if (bankWait <= 0f)
            {
                var bank = NextBank();
                untilBank = bank.distance / Mathf.Max(speed, 1f);
                if (untilBank > bankWarningSeconds) return;
                point = bank.position;
                outgoing = G.Bounce(direction, bank.normal);
                normal = bank.normal;
                nextCount += 1;
            }
            int count = FanCount(nextCount);
            outgoing = fanBank == nextCount ? fanCenter : FanDirection(outgoing, normal, childSpread);
            float alpha = 1f - 0.5f * Mathf.Clamp01(untilBank / bankWarningSeconds);
            var tint = new Color(CueColor.r, CueColor.g, CueColor.b, alpha);
            TelegraphDrawer.Ring(point, 32f, 23, tint, 2f);
            for (int index = 0; index < count; index++)
            {
                float offset = count > 1 ? childSpread * Mathf.Deg2Rad * ((float)index / Mathf.Max(1, count - 1) - 0.5f) : 0f;
                var ray = G.Rotated(outgoing, offset);
                TelegraphDrawer.Line(point + ray * 24f, point + ray * 105f, tint, 2f);
            }
        }
    }
}
