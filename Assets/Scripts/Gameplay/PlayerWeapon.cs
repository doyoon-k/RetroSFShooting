using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    public class PlayerWeapon : MonoBehaviour
    {
        public WeaponData data;
        public WeaponData spreadData;
        [Header("Shot Pattern")]
        [Range(0f, 100f)] public float straightShotSpacing = 28f;
        [Header("Proximity Damage")]
        public List<ProximityDamageTier> proximityTiers = new List<ProximityDamageTier>();

        [NonSerialized] public SortieState state;
        [NonSerialized] public Transform projectiles;
        [NonSerialized] public Rect bounds;
        [NonSerialized] public float cooldown;

        void FixedUpdate()
        {
            if (state == null || state.hp <= 0) return;
            cooldown = Mathf.Max(0f, cooldown - Time.fixedDeltaTime);
            if (GameInput.ConsumeSwitchWeapon()) SwitchWeapon();
            if (GameInput.ShootHeld && cooldown <= 0f) Fire();
        }

        public void SwitchWeapon()
        {
            if (state == null || state.hp <= 0) return;
            state.SwitchWeapon();
            cooldown = 0f;
            Sfx.Play("weapon_switch");
        }

        public WeaponData ActiveData()
        {
            if (state != null && state.activeWeapon == SortieState.WeaponType.Spread) return spreadData;
            return data;
        }

        public void Fire()
        {
            var weapon = ActiveData();
            if (state == null || weapon == null || weapon.levels.Count == 0 || projectiles == null) return;
            var level = weapon.levels[Mathf.Clamp(state.CurrentPowerLevel() - 1, 0, weapon.levels.Count - 1)];
            if (level.projectilePrefab == null) return;
            cooldown = level.interval;
            var proximityPoints = new List<Vector2>();
            foreach (var tier in proximityTiers)
                if (tier != null) proximityPoints.Add(new Vector2(Mathf.Max(0f, tier.distance), Mathf.Max(1f, tier.multiplier)));
            proximityPoints.Sort((a, b) => a.x.CompareTo(b.x));
            int count = level.angles.Count;
            for (int index = 0; index < count; index++)
            {
                float angle = level.angles[index];
                Vector2 offset = Vector2.zero;
                if (state.activeWeapon == SortieState.WeaponType.Straight)
                    offset.y = -((index - (count - 1) * 0.5f) * straightShotSpacing);
                Vector3 spawn = transform.TransformPoint(offset);
                var bullet = Instantiate(level.projectilePrefab, new Vector3(spawn.x, spawn.y, 0f), Quaternion.identity, projectiles);
                bullet.friendly = true;
                bullet.damage = level.damage;
                bullet.direction = G.Rotated(Vector2.right, angle * Mathf.Deg2Rad);
                bullet.bounds = bounds;
                bullet.proximityPoints = new List<Vector2>(proximityPoints);
                bullet.damageOrigin = spawn;
            }
            Sfx.Play(state.activeWeapon == SortieState.WeaponType.Spread ? "player_shot_spread" : "player_shot");
        }
    }
}
