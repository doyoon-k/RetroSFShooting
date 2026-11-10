using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    /// <summary>Shared tuning. Runtime code must never modify this asset.</summary>
    [CreateAssetMenu(menuName = "RetroSF/Game Rules")]
    public class GameRules : ScriptableObject
    {
        [Header("Sortie")]
        [Range(1, 10)] public int startingHp = 2;
        [Range(0, 4)] public int startingBombs = 2;
        [Range(0f, 5f)] public float spawnInvincibility = 1.5f;
        [Range(0f, 5f)] public float hitInvincibility = 0.75f;
        [Range(0.1f, 15f)] public float selectionSeconds = 5f;
        [Range(0.1f, 5f)] public float launchSeconds = 1.2f;
        [Range(0.1f, 10f)] public float deathSeconds = 2.8f;
        [Range(0.1f, 10f)] public float victoryLineSeconds = 2f;
        [Header("Bomb")]
        [Range(0f, 5f)] public float bombActivationDelay = 0.2f;
        [Range(0f, 10f)] public float bombCooldown = 1.5f;
        [Range(1, 100)] public int bombDamage = 10;
        [Range(0f, 5f)] public float bombInvincibility = 1f;
        public bool bombClearsBullets = true;
        [Header("Playfield (Unity space)")]
        public Rect playfield = G.FromGodotRect(440f, 24f, 1464f, 952f);
        public Vector2 spawnPosition = new Vector2(662f, -500f);
    }
}
