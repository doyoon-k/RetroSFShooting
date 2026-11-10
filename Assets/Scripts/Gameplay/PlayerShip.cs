using System;
using UnityEngine;

namespace RetroSF
{
    [DisallowMultipleComponent]
    [RequireComponent(typeof(Rigidbody2D))]
    public class PlayerShip : MonoBehaviour
    {
        /// <summary>World position, recoverable power-ups and bombs before the fatal hit.</summary>
        public event Action<Vector2, int, int> Died;
        public event Action BombRequested;
        public event Action Hit;
        public event Action PowerUpCollected;

        [Range(50f, 1200f)] public float moveSpeed = 490f;
        [Tooltip("Local-space half extents of the visible ship, excluding transparent texture margins.")]
        public Vector2 boundaryPadding = new Vector2(40f, 30f);
        [Header("Ship Sprites")]
        public Sprite normalSprite;
        public Sprite normalBackSprite;
        public Sprite normalForwardSprite;
        public Sprite damagedSprite;
        public Sprite damagedBackSprite;
        public Sprite damagedForwardSprite;
        [Header("Parts")]
        public PlayerWeapon weapon;
        public SpriteRenderer visuals;
        public GameObject shield;

        [NonSerialized] public float autoAdvanceSpeed;
        [NonSerialized] public SortieState state;
        [NonSerialized] public GameRules rules;
        [NonSerialized] public Rect bounds;
        [NonSerialized] public float invincibility;
        [NonSerialized] public bool deathReported;
        [NonSerialized] public bool hasTakenHit;
        [NonSerialized] public float horizontalInput;

        public Vector2 Position
        {
            get => transform.position;
            set => transform.SetPosition2D(value);
        }

        void Start() => UpdateSprite();

        void FixedUpdate()
        {
            if (state == null || state.hp <= 0) return;
            float delta = Time.fixedDeltaTime;
            invincibility = Mathf.Max(0f, invincibility - delta);
            Vector2 motion = GameInput.Move;
            horizontalInput = motion.x;
            Position += (new Vector2(autoAdvanceSpeed, 0f) + motion * moveSpeed) * delta;
            var scale = transform.localScale;
            var padding = new Vector2(boundaryPadding.x * Mathf.Abs(scale.x), boundaryPadding.y * Mathf.Abs(scale.y));
            Position = G.Clamp(Position, bounds.min + padding, bounds.max - padding);
            UpdateSprite();
            if (visuals != null)
            {
                bool blink = invincibility > 0f && G.Fmod(invincibility, 0.14f) < 0.07f;
                var color = visuals.color;
                color.a = blink ? 0.4f : 1f;
                visuals.color = color;
            }
            if (shield != null && shield.activeSelf != state.shield) shield.SetActive(state.shield);
            if (GameInput.ConsumeBomb()) BombRequested?.Invoke();
        }

        public void GrantInvincibility(float seconds) => invincibility = Mathf.Max(invincibility, seconds);

        public void TakeDamage(int amount = 1)
        {
            if (state == null || deathReported || invincibility > 0f || GamePause.Paused) return;
            int powerupsBeforeHit = state.RecoverablePowerups();
            int bombsBeforeHit = state.Bombs;
            int hpBeforeHit = state.hp;
            bool shieldBeforeHit = state.shield;
            if (!state.Damage(amount)) return;
            if (shieldBeforeHit && !state.shield) Sfx.Play("shield_break");
            if (state.hp < hpBeforeHit)
            {
                hasTakenHit = true;
                UpdateSprite();
                if (state.hp > 0) Sfx.Play("player_hit");
            }
            Hit?.Invoke();
            GrantInvincibility(rules.hitInvincibility);
            if (state.hp == 0)
            {
                deathReported = true;
                Died?.Invoke(Position, Mathf.Max(0, powerupsBeforeHit - 1), Mathf.Max(0, bombsBeforeHit - 1));
            }
        }

        public void Collect(Pickup.Kind kind)
        {
            if (state == null || state.hp <= 0) return;
            int previousPower = state.CurrentPowerLevel();
            int previousBombs = state.Bombs;
            bool previousShield = state.shield;
            state.Collect(kind, weapon.ActiveData().levels.Count);
            if (state.CurrentPowerLevel() > previousPower)
            {
                Sfx.Play("power_up");
                PowerUpCollected?.Invoke();
            }
            else if (kind == Pickup.Kind.Bomb && state.Bombs > previousBombs)
            {
                Sfx.Play("bomb_pickup");
            }
            else if (kind == Pickup.Kind.Shield && state.shield && !previousShield)
            {
                Sfx.Play("shield_gain");
            }
        }

        void OnTriggerEnter2D(Collider2D other)
        {
            var body = other.attachedRigidbody;
            if (body == null) return;
            var enemy = body.GetComponent<EnemyShip>();
            if (enemy != null && enemy.hp > 0f) TakeDamage(enemy.contactDamage);
        }

        void UpdateSprite()
        {
            if (visuals == null) return;
            Sprite next;
            if (horizontalInput > 0f) next = hasTakenHit ? damagedForwardSprite : normalForwardSprite;
            else if (horizontalInput < 0f) next = hasTakenHit ? damagedBackSprite : normalBackSprite;
            else next = hasTakenHit ? damagedSprite : normalSprite;
            if (visuals.sprite != next) visuals.sprite = next;
        }
    }
}
