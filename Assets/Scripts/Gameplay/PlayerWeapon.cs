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
        [Range(0f, 1f)] public float straightShotSpacing = 0.28f;
        [Tooltip("How far along its flight direction a shot first appears, in this transform's local units. Visual only: damage distance still measures from the weapon.")]
        [Range(0f, 1f)] public float spawnForward = 0.27f;
        [Header("Proximity Damage")]
        public List<ProximityDamageTier> proximityTiers = new List<ProximityDamageTier>();
        [Tooltip("Expand the shared asset to edit x1/x2/x3/x4 colors and the numeric font.")]
        public ProximityFeedbackStyle proximityFeedback;
        [Header("Muzzle Flash")]
        [Tooltip("Looping flash (ShotFx) shown at the muzzle while the weapon keeps firing. Starts inactive.")]
        public GameObject muzzleFlash;

        [NonSerialized] public SortieState state;
        [NonSerialized] public Transform projectiles;
        [NonSerialized] public Rect bounds;
        [NonSerialized] public float cooldown;
        float muzzleFlashLeft;

        void FixedUpdate()
        {
            muzzleFlashLeft = Mathf.Max(0f, muzzleFlashLeft - Time.fixedDeltaTime);
            ShowMuzzleFlash(muzzleFlashLeft > 0f && state != null && state.hp > 0);
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
            // Lasts until the next shot is due, so holding fire keeps one continuous looping flash.
            muzzleFlashLeft = level.interval + Time.fixedDeltaTime;
            ShowMuzzleFlash(true);
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
                Vector2 direction = G.Rotated(Vector2.right, angle * Mathf.Deg2Rad);
                Vector3 origin = transform.TransformPoint(offset);
                Vector3 spawn = transform.TransformPoint(offset + direction * spawnForward);
                var bullet = Instantiate(level.projectilePrefab, new Vector3(spawn.x, spawn.y, 0f), Quaternion.identity, projectiles);
                bullet.friendly = true;
                bullet.damage = level.damage;
                bullet.direction = direction;
                bullet.bounds = bounds;
                bullet.proximityPoints = new List<Vector2>(proximityPoints);
                bullet.proximityFeedback = proximityFeedback;
                bullet.damageOrigin = origin;
            }
            Sfx.Play(state.activeWeapon == SortieState.WeaponType.Spread ? "player_shot_spread" : "player_shot");
        }

        void ShowMuzzleFlash(bool visible)
        {
            if (muzzleFlash != null && muzzleFlash.activeSelf != visible) muzzleFlash.SetActive(visible);
        }
    }
}
