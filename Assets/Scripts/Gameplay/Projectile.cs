using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    /// <summary>Extend this prefab/script for a genuinely new projectile behavior.</summary>
    [DisallowMultipleComponent]
    [RequireComponent(typeof(Rigidbody2D))]
    public class Projectile : MonoBehaviour
    {
        public event Action<Projectile> OffspringSpawned;

        [Range(10f, 2000f)] public float speed = 380f;
        [Range(0.1f, 30f)] public float lifetime = 8f;
        [Range(1, 100)] public int damage = 1;
        [Range(0f, 500f)] public float despawnMargin = 80f;
        [Range(0f, 8f)] public float homingRadiansPerSecond;
        [Range(0f, 8f)] public float homingSeconds = 1.2f;

        [NonSerialized] public float age;
        [NonSerialized] public Vector2 direction = Vector2.left;
        [NonSerialized] public bool friendly;
        [NonSerialized] public Rect bounds = G.FromGodotRect(0f, 0f, 1920f, 1080f);
        [NonSerialized] public Transform target;
        [NonSerialized] public bool spent;
        [NonSerialized] public Vector2 damageOrigin;
        [NonSerialized] public List<Vector2> proximityPoints = new List<Vector2>();

        bool ready;

        /// <summary>Godot is_queued_for_deletion: still in the scene until the end of the frame.</summary>
        public bool IsFreed { get; private set; }

        public Vector2 Position
        {
            get => transform.position;
            set => transform.SetPosition2D(value);
        }

        /// <summary>Godot _ready: runs once the spawner has set every field.</summary>
        protected virtual void OnReady()
        {
            // Unity filters collisions by each collider's own layer, so set the whole hierarchy.
            int layer = friendly ? Layers.PlayerBullet : Layers.EnemyBullet;
            foreach (var part in GetComponentsInChildren<Transform>(true)) part.gameObject.layer = layer;
            transform.SetRotation2D(G.Angle(direction));
        }

        protected void EnsureReady()
        {
            if (ready) return;
            ready = true;
            OnReady();
        }

        protected bool IsReady => ready;

        protected virtual void Start() => EnsureReady();

        protected virtual void FixedUpdate()
        {
            EnsureReady();
            if (IsFreed) return;
            Step(Time.fixedDeltaTime);
        }

        protected virtual void Step(float delta) => BaseStep(delta);

        protected void BaseStep(float delta)
        {
            age += delta;
            if (age <= homingSeconds && homingRadiansPerSecond > 0f && target != null)
            {
                float desired = G.Angle(G.DirectionTo(Position, target.position));
                direction = G.FromAngle(G.RotateToward(G.Angle(direction), desired, homingRadiansPerSecond * delta));
            }
            transform.SetRotation2D(G.Angle(direction));
            Position += direction * speed * delta;
            lifetime -= delta;
            if (lifetime <= 0f || !G.HasPoint(G.Grow(bounds, despawnMargin), Position))
                Free();
        }

        public void Free()
        {
            if (IsFreed) return;
            IsFreed = true;
            Destroy(gameObject);
        }

        protected void RaiseOffspring(Projectile child) => OffspringSpawned?.Invoke(child);

        void OnTriggerEnter2D(Collider2D other)
        {
            if (spent || IsFreed || GamePause.Paused) return;
            var body = other.attachedRigidbody;
            if (body == null) return;
            var enemy = body.GetComponent<EnemyShip>();
            var player = enemy == null ? body.GetComponent<PlayerShip>() : null;
            if (enemy == null && player == null) return;
            spent = true;
            if (enemy != null)
            {
                float amount = friendly ? damage * ProximityMultiplier(Vector2.Distance(Position, damageOrigin)) : damage;
                enemy.TakeDamage(amount);
            }
            else
            {
                player.TakeDamage(damage);
            }
            Free();
        }

        public float ProximityMultiplier(float distance)
        {
            if (proximityPoints.Count == 0) return 1f;
            if (distance <= proximityPoints[0].x) return proximityPoints[0].y;
            for (int index = 1; index < proximityPoints.Count; index++)
            {
                var previous = proximityPoints[index - 1];
                var current = proximityPoints[index];
                if (distance <= current.x)
                {
                    float progress = Mathf.Clamp01((distance - previous.x) / (current.x - previous.x));
                    return Mathf.Lerp(previous.y, current.y, progress);
                }
            }
            return 1f;
        }
    }
}
