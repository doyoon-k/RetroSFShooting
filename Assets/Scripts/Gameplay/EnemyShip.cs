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

        public event Action<EnemyShip> Destroyed;
        public event Action<EnemyShip> Damaged;
        public event Action<float, int> HealthChanged;

        [Range(1, 2000)] public int maximumHp = 3;
        [Range(0, 10)] public int contactDamage = 1;
        [Range(0f, 1f)] public float hitFlashSeconds = 0.08f;
        [Range(0f, 1000f)] public float despawnMargin = 320f;
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
        Animator animator;
        Collider2D[] colliders;
        bool disableCollidersPending;
        bool freed;
        MaterialPropertyBlock block;

        public Vector2 Position
        {
            get => transform.position;
            set => transform.SetPosition2D(value);
        }

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
            if (dying)
            {
                deathLeft -= delta;
                if (deathLeft <= 0f) Free();
            }
            else if (!isBoss && !G.HasPoint(G.Grow(bounds, despawnMargin), Position))
            {
                Free();
            }
        }

        public void TakeDamage(float amount)
        {
            if (dying || hp <= 0f || GamePause.Paused) return;
            float previousHp = hp;
            hp = Mathf.Max(0f, hp - amount);
            HealthChanged?.Invoke(hp, maximumHp);
            if (hp < previousHp)
            {
                hitFlashLeft = hitFlashSeconds;
                SetFlash(hitFlashLeft > 0f ? 1f : 0f);
                Damaged?.Invoke(this);
            }
            if (isBoss && !phaseTwo && hp / maximumHp <= phaseThreshold)
            {
                phaseTwo = true;
                if (hp > 0f) Sfx.Play("boss_phase_two");
                if (shooter != null && secondPhase.Count > 0) shooter.SetSequence(secondPhase);
            }
            if (hp == 0f)
            {
                dying = true;
                movement.enabled = false;
                if (shooter != null) shooter.enabled = false;
                // Godot set_deferred("monitorable", false): stop being hit after this physics step.
                disableCollidersPending = true;
                Destroyed?.Invoke(this);
                if (animator != null && !string.IsNullOrEmpty(deathAnimation) &&
                    animator.HasState(0, Animator.StringToHash(deathAnimation)))
                    animator.Play(deathAnimation, 0, 0f);
                deathLeft = deathAnimationSeconds;
                if (deathLeft <= 0f) Free();
            }
        }

        public void Free()
        {
            if (freed) return;
            freed = true;
            Destroy(gameObject);
        }

        public bool IsFreed => freed;

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
