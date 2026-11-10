using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    /// <summary>Approved BGM tracks and playback settings. Lives at Resources/MusicBank.</summary>
    [CreateAssetMenu(menuName = "RetroSF/Music Bank")]
    public class MusicBank : ScriptableObject
    {
        [Serializable]
        public class LoopEnd
        {
            public string cue = "";
            [Min(0.1f)] public float seconds = 1f;
        }

        [Header("Approved Tracks")]
        public AudioClip titleTrack;
        public AudioClip selectTrack;
        public AudioClip stageTrack;
        public AudioClip bossTrack;
        public AudioClip clearTrack;
        public AudioClip endingTrack;
        public AudioClip somberEndingTrack;

        [Header("Playback")]
        [Range(-40f, 0f)] public float volumeDb = -18f;
        [Range(0f, 3f)] public float crossfadeSeconds = 0.5f;
        [Range(0.05f, 3f)] public float loopCrossfadeSeconds = 1f;
        [Tooltip("Authored seamless tracks use native sample looping to preserve their rhythm.")]
        public List<string> nativeLoopCues = new List<string> { "select" };
        [Tooltip("Optional end positions exclude near-silent tails from the loop transition.")]
        public List<LoopEnd> loopEndSeconds = new List<LoopEnd>();
        public List<string> somberEndingIds = new List<string> { "extinction", "last_signal", "betrayal" };

        public AudioClip SourceFor(string cue)
        {
            switch (cue)
            {
                case "title": return titleTrack;
                case "select": return selectTrack;
                case "stage": return stageTrack;
                case "boss": return bossTrack;
                case "clear": return clearTrack;
                case "ending": return endingTrack;
                case "somber_ending": return somberEndingTrack;
            }
            return null;
        }
    }
}
