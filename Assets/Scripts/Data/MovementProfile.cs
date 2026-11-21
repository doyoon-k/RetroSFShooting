using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    /// <summary>Reusable movement settings. A wave path overrides this mode at spawn time.</summary>
    [CreateAssetMenu(menuName = "RetroSF/Movement Profile")]
    public class MovementProfile : ScriptableObject
    {
        public enum Mode { Linear, Sine, EnterHoldExit, VerticalSweep, StrafeExit }

        public Mode mode = Mode.Linear;
        public Vector2 direction = Vector2.left;
        [Range(0f, 10f)] public float speed = 1.8f;
        [Header("Sine")]
        [Range(0f, 5f)] public float amplitude = 1f;
        [Range(0.05f, 5f)] public float frequency = 0.5f;
        [Header("Enter / hold / exit")]
        [Tooltip("Arena-local position (Unity space: y is negative going down).")]
        public Vector2 holdPosition = new Vector2(12.2f, -5.32f);
        [Range(0f, 300f)] public float holdSeconds = 4f;
        public bool stayForever;
        public Vector2 exitDirection = Vector2.left;
        [Tooltip("Follow arena scrolling while entering/holding; exit remains in world space.")]
        public bool followScroll;
    }
}
