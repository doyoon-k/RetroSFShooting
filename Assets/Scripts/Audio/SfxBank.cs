using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    /// <summary>
    /// Every sound-effect cue, its clip and level. Lives at Resources/SfxBank so Sfx can load it anywhere.
    /// Converted from scenes/audio/sound_effects.tscn.
    /// </summary>
    [CreateAssetMenu(menuName = "RetroSF/Sfx Bank")]
    public class SfxBank : ScriptableObject
    {
        [Serializable]
        public class Entry
        {
            public string cue = "";
            public AudioClip clip;
            [Range(-80f, 24f)] public float volumeDb;
            [Range(1, 8)] public int maxPolyphony = 1;
            [Tooltip("Stops with the combat pause (Godot PROCESS_MODE_PAUSABLE).")]
            public bool pausable;
            [Tooltip("Blocks restarts that come sooner than this many seconds.")]
            [Min(0f)] public float minInterval;
        }

        public List<Entry> entries = new List<Entry>();
    }

    public static class AudioLevels
    {
        /// <summary>
        /// Godot allows players above 0 dB (up to +5 here); AudioSource cannot exceed 1.0.
        /// Every sound, music included, is lowered by this headroom so the mix keeps its balance.
        /// </summary>
        public const float HeadroomDb = 5f;

        public static float Volume(float db) => Mathf.Clamp01(G.DbToLinear(db - HeadroomDb));
    }
}
