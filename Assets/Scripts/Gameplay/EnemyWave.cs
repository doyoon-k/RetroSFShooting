using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    /// <summary>
    /// Position and Spawn Offset place enemies in world space. A child PathRoute named "Path2D" adds a route.
    /// </summary>
    public class EnemyWave : MonoBehaviour
    {
        public enum DropMode { None, Guaranteed, Chance }

        public EnemyShip enemyPrefab;
        [Range(1, 100)] public int count = 5;
        public Vector2 spawnOffset = Vector2.zero;
        [Header("Optional Overrides")]
        public MovementProfile movementProfile;
        public AttackSequence attackSequence;
        [Header("Drops")]
        public DropMode dropMode = DropMode.None;
        public Pickup dropPrefab;
        [Range(0f, 1f)] public float dropChance = 0.5f;

        [NonSerialized] public int emitted;
        readonly HashSet<int> spawned = new HashSet<int>();

        public PathRoute Route
        {
            get
            {
                var child = transform.Find("Path2D");
                return child != null ? child.GetComponent<PathRoute>() : null;
            }
        }

        public Vector2 StartPosition
        {
            get
            {
                var route = Route;
                if (route != null && route.Length > 0f) return route.SampleWorld(0f);
                return transform.position;
            }
        }

        public void Advance(float activationX, Action<EnemyWave, int> spawn)
        {
            if (enemyPrefab == null) return;
            float startX = StartPosition.x;
            for (int index = 0; index < count; index++)
            {
                if (!spawned.Contains(index) && startX + spawnOffset.x * index <= activationX)
                {
                    spawned.Add(index);
                    emitted += 1;
                    spawn(this, index);
                }
            }
        }

        void OnDrawGizmos()
        {
            Gizmos.color = enemyPrefab != null ? new Color(0.74f, 0.35f, 0.95f, 0.8f) : Color.red;
            Vector2 start = StartPosition;
            for (int index = 0; index < count; index++)
                Gizmos.DrawWireSphere(start + spawnOffset * index, 24f);
        }
    }
}
