using System;
using UnityEngine;

namespace RetroSF
{
    [DisallowMultipleComponent]
    [RequireComponent(typeof(Rigidbody2D))]
    public class Pickup : MonoBehaviour
    {
        public enum Kind { Power, Bomb, Shield }

        public Kind kind = Kind.Power;
        [Range(0.1f, 30f)] public float lifetime = 7f;
        [Range(0f, 200f)] public float attraction = 24f;
        [Range(0f, 400f)] public float maximumSpeed = 95f;
        public Vector2 initialVelocity = new Vector2(-50f, -40f);
        [Range(1f, 100f)] public float boundaryPadding = 24f;
        public SpriteRenderer visual;

        [NonSerialized] public Rect bounds;
        [NonSerialized] public PlayerShip target;
        [NonSerialized] public Vector2 velocity;
        [NonSerialized] public bool taken;
        Vector2 previousBoundsPosition;
        bool ready;
        bool freed;

        public Vector2 Position
        {
            get => transform.position;
            set => transform.SetPosition2D(value);
        }

        // The spawner may override velocity right after Instantiate (Godot sets it after _ready).
        void Awake() => velocity = initialVelocity;

        void EnsureReady()
        {
            if (ready) return;
            ready = true;
            previousBoundsPosition = bounds.position;
        }

        void Start() => EnsureReady();

        void FixedUpdate()
        {
            EnsureReady();
            if (freed) return;
            float delta = Time.fixedDeltaTime;
            lifetime -= delta;
            if (lifetime <= 0f)
            {
                Free();
                return;
            }
            // Drift and bounce in screen space while the stage scrolls in world space.
            Position += bounds.position - previousBoundsPosition;
            previousBoundsPosition = bounds.position;
            if (target != null && !target.deathReported)
                velocity += G.DirectionTo(Position, target.Position) * attraction * delta;
            velocity = G.LimitLength(velocity, maximumSpeed);
            Position += velocity * delta;
            var area = G.Grow(bounds, -boundaryPadding);
            var p = Position;
            if (p.x <= area.xMin) velocity.x = Mathf.Abs(velocity.x);
            else if (p.x >= area.xMax) velocity.x = -Mathf.Abs(velocity.x);
            if (p.y <= area.yMin) velocity.y = Mathf.Abs(velocity.y);
            else if (p.y >= area.yMax) velocity.y = -Mathf.Abs(velocity.y);
            Position = G.Clamp(p, area.min, area.max);
            if (visual != null)
            {
                bool blink = lifetime < 2f && G.Fmod(lifetime, 0.25f) < 0.125f;
                var color = visual.color;
                color.a = blink ? 0.35f : 1f;
                visual.color = color;
            }
        }

        void Free()
        {
            if (freed) return;
            freed = true;
            Destroy(gameObject);
        }

        void OnTriggerEnter2D(Collider2D other)
        {
            if (taken || freed || GamePause.Paused) return;
            var body = other.attachedRigidbody;
            var player = body != null ? body.GetComponent<PlayerShip>() : null;
            if (player != null && player.state != null && player.state.hp > 0)
            {
                taken = true;
                player.Collect(kind);
                Free();
            }
        }
    }
}
