using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    [Serializable]
    public class ProximityDamageTier
    {
        [Tooltip("Inclusive maximum distance from the firing point to the hit point, in pixels.")]
        [Range(0f, 5000f)] public float distance = 80f;
        [Range(1, 4)] public int multiplier = 4;
    }

    [Serializable]
    public class ShotLevelData
    {
        public Projectile projectilePrefab;
        [Range(0.03f, 2f)] public float interval = 0.16f;
        [Tooltip("Degrees, Unity space (counter-clockwise).")]
        public List<float> angles = new List<float> { 0f };
        [Range(1, 100)] public int damage = 1;
    }

    [CreateAssetMenu(menuName = "RetroSF/Weapon Data")]
    public class WeaponData : ScriptableObject
    {
        public string displayName = "";
        public List<ShotLevelData> levels = new List<ShotLevelData>();
    }
}
