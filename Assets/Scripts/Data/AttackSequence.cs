using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    /// <summary>Reusable, immutable attack settings. EnemyShooter owns the runtime counters.</summary>
    [CreateAssetMenu(menuName = "RetroSF/Attack Sequence")]
    public class AttackSequence : ScriptableObject
    {
        public List<PatternStep> steps = new List<PatternStep>();
        [Range(0f, 10f)] public float initialDelay = 1f;
    }
}
