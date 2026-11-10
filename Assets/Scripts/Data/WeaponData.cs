using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    [Serializable]
    public class ProximityDamageTier
    {
        [Range(0f, 5000f)] public float distance = 160f;
        [Range(1f, 10f)] public float multiplier = 2f;
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
