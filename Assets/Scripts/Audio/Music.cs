using System;
using UnityEngine;

namespace RetroSF
{
    /// <summary>
    /// Persistent BGM with two voices for screen changes and non-looping source tracks (Godot GameMusic).
    /// Always runs on unscaled time; the combat pause stops it only through SetPaused.
    /// </summary>
    public sealed class Music : MonoBehaviour
    {
        public static event Action<string> TrackChanged;
        public static event Action<string> TrackLooped;

        static Music instance;

        MusicBank bank;
        readonly AudioSource[] channels = new AudioSource[2];
        string currentCue = "";
        bool musicPaused;
        int activeIndex;
        float fadeRemaining;
        float fadeDuration;
        float outgoingGain;

        public static Music Instance
        {
            get
            {
                if (instance == null)
                {
                    var host = new GameObject("Music");
                    DontDestroyOnLoad(host);
                    instance = host.AddComponent<Music>();
                }
                return instance;
            }
        }

        public static string CurrentCue => instance != null ? instance.currentCue : "";

        public static void Play(string cue) => Instance.Request(cue);

        public static void SetPaused(bool value)
        {
            if (instance != null) instance.SetPausedInternal(value);
        }

        public static void Stop()
        {
            if (instance != null) instance.StopInternal();
        }

        public static string EndingCue(string id) =>
            Instance.bank != null && Instance.bank.somberEndingIds.Contains(id) ? "somber_ending" : "ending";

        void Awake()
        {
            if (instance != null && instance != this)
            {
                Destroy(gameObject);
                return;
            }
            instance = this;
            bank = Resources.Load<MusicBank>("MusicBank");
            if (bank == null)
                Debug.LogError("Music: Resources/MusicBank is missing, so the game has no BGM. Run the Godot port importer.");
            for (int i = 0; i < channels.Length; i++)
            {
                var source = gameObject.AddComponent<AudioSource>();
                source.playOnAwake = false;
                source.ignoreListenerPause = true;
                source.volume = 0f;
                channels[i] = source;
            }
        }

        void OnDestroy()
        {
            if (instance == this) instance = null;
        }

        AudioSource ActivePlayer => channels[activeIndex];

        float LinearGain(float db) => AudioLevels.Volume(db);

        float LoopEnd(string cue)
        {
            var source = bank != null ? bank.SourceFor(cue) : null;
            if (source == null) return 0f;
            float end = source.length;
            foreach (var entry in bank.loopEndSeconds)
                if (entry.cue == cue) end = entry.seconds;
            return Mathf.Clamp(end, 0.1f, source.length);
        }

        void Request(string cue)
        {
            SetPausedInternal(false);
            if (cue == currentCue && ActivePlayer.isPlaying) return;
            if (bank == null || bank.SourceFor(cue) == null)
            {
                StopInternal();
                return;
            }
            Begin(cue, bank.crossfadeSeconds);
        }

        void Begin(string cue, float duration, bool looping = false)
        {
            var outgoing = ActivePlayer;
            int incomingIndex = 1 - activeIndex;
            var incoming = channels[incomingIndex];
            bool changed = cue != currentCue;
            incoming.Stop();
            incoming.clip = bank.SourceFor(cue);
            incoming.loop = bank.nativeLoopCues.Contains(cue);
            incoming.volume = 0f;
            outgoingGain = outgoing.isPlaying ? outgoing.volume : 0f;
            activeIndex = incomingIndex;
            currentCue = cue;
            fadeDuration = Mathf.Max(0f, duration);
            fadeRemaining = fadeDuration;
            incoming.Play();
            if (fadeDuration <= 0f)
            {
                outgoing.Stop();
                outgoing.clip = null;
                incoming.volume = LinearGain(bank.volumeDb);
            }
            if (changed) TrackChanged?.Invoke(cue);
            else if (looping) TrackLooped?.Invoke(cue);
        }

        void Update()
        {
            if (string.IsNullOrEmpty(currentCue) || musicPaused || bank == null) return;
            float delta = Time.unscaledDeltaTime;
            var incoming = ActivePlayer;
            if (fadeRemaining > 0f)
            {
                fadeRemaining = Mathf.Max(0f, fadeRemaining - delta);
                float progress = 1f - fadeRemaining / fadeDuration;
                var outgoing = channels[1 - activeIndex];
                incoming.volume = LinearGain(bank.volumeDb) * Mathf.Sqrt(progress);
                outgoing.volume = outgoingGain * Mathf.Sqrt(1f - progress);
                if (fadeRemaining <= 0f)
                {
                    outgoing.Stop();
                    outgoing.clip = null;
                }
            }
            else
            {
                incoming.volume = LinearGain(bank.volumeDb);
            }
            if (incoming.loop)
            {
                // Native loops end early when a loop end trims a silent tail.
                float nativeEnd = LoopEnd(currentCue);
                if (incoming.time >= nativeEnd) incoming.time = 0f;
                return;
            }
            if (!incoming.isPlaying)
            {
                Begin(currentCue, 0f, true);
                return;
            }
            if (fadeRemaining > 0f) return;
            float end = LoopEnd(currentCue);
            float overlap = Mathf.Min(bank.loopCrossfadeSeconds, end * 0.25f);
            if (incoming.time >= end - overlap) Begin(currentCue, overlap, true);
        }

        void SetPausedInternal(bool value)
        {
            musicPaused = value;
            foreach (var player in channels)
            {
                if (value) player.Pause();
                else player.UnPause();
            }
        }

        void StopInternal()
        {
            currentCue = "";
            fadeRemaining = 0f;
            musicPaused = false;
            foreach (var player in channels)
            {
                player.Stop();
                player.clip = null;
            }
        }
    }
}
