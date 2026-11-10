using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    [CreateAssetMenu(menuName = "RetroSF/Pattern Step")]
    public class PatternStep : ScriptableObject
    {
        public AttackPattern pattern;
        [Range(1, 20)] public int repetitions = 1;
        [Range(0f, 10f)] public float waitAfter;
    }
}
