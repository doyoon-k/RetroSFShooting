using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace RetroSF
{
    /// <summary>
    /// The only sound-effect gateway (Godot SoundEffects autoload). Play cues by name; levels live in SfxBank.
    /// </summary>
    public sealed class Sfx : MonoBehaviour
    {
        public static event Action<string> CuePlayed;

        static Sfx instance;

        SfxBank bank;
        readonly Dictionary<string, SfxBank.Entry> entries = new Dictionary<string, SfxBank.Entry>();
        readonly Dictionary<string, AudioSource[]> voices = new Dictionary<string, AudioSource[]>();
        readonly Dictionary<string, int> lastPlayFrame = new Dictionary<string, int>();
        readonly Dictionary<string, float> lastPlayTime = new Dictionary<string, float>();
        float clock;
        int lastUiActionFrame = -1;
        Selectable navigationTarget;
        Selectable queuedNavigation;
        int queuedNavigationFrame = -1;
        bool shuttingDown;

        public static Sfx Instance
        {
            get
            {
                if (instance == null)
                {
                    var host = new GameObject("Sfx");
                    DontDestroyOnLoad(host);
                    instance = host.AddComponent<Sfx>();
                }
                return instance;
            }
        }

        public static void Play(string cue) => Instance.PlayCue(cue);

        /// <summary>Plays ui_move when the button gains focus or the pointer enters it.</summary>
        public static void BindNavigation(Selectable button)
        {
            if (button == null) return;
            var hook = button.GetComponent<NavigationSoundHook>();
            if (hook == null) hook = button.gameObject.AddComponent<NavigationSoundHook>();
            hook.target = button;
        }

        public static void Shutdown() => Instance.StopAll();

        public static bool IsPlaying(string cue)
        {
            if (!Instance.voices.TryGetValue(cue, out var sources)) return false;
            foreach (var source in sources)
                if (source.isPlaying) return true;
            return false;
        }

        void Awake()
        {
            if (instance != null && instance != this)
            {
                Destroy(gameObject);
                return;
            }
            instance = this;
            bank = Resources.Load<SfxBank>("SfxBank");
            if (bank == null)
            {
                Debug.LogError("Sfx: Resources/SfxBank is missing, so every sound effect is silent. Run the Godot port importer.");
                return;
            }
            foreach (var entry in bank.entries)
            {
                if (entry == null || string.IsNullOrEmpty(entry.cue)) continue;
                entries[entry.cue] = entry;
                var sources = new AudioSource[Mathf.Max(1, entry.maxPolyphony)];
                for (int i = 0; i < sources.Length; i++)
                {
                    var source = gameObject.AddComponent<AudioSource>();
                    source.playOnAwake = false;
                    source.clip = entry.clip;
                    source.volume = AudioLevels.Volume(entry.volumeDb);
                    source.ignoreListenerPause = !entry.pausable;
                    sources[i] = source;
                }
                voices[entry.cue] = sources;
            }
        }

        void OnDestroy()
        {
            if (instance == this) instance = null;
        }

        void Update()
        {
            // Engine time keeps min_interval stable while the combat pause stops scaled time.
            clock += Time.unscaledDeltaTime;
        }

        void LateUpdate()
        {
            if (queuedNavigation == null) return;
            var button = queuedNavigation;
            int requested = queuedNavigationFrame;
            queuedNavigation = null;
            if (!IsUsable(button)) return;
            // A click can focus and activate a button in the same frame. Prefer its action.
            if (lastUiActionFrame >= requested) return;
            PlayCue("ui_move");
        }

        void PlayCue(string cue)
        {
            if (shuttingDown || !entries.TryGetValue(cue, out var entry) || entry.clip == null) return;
            if (entry.pausable && GamePause.Paused) return;
            int frame = Time.frameCount;
            if (lastPlayFrame.TryGetValue(cue, out var last) && last == frame) return;
            if (lastPlayTime.TryGetValue(cue, out var time) && clock - time < entry.minInterval) return;
            var sources = voices[cue];
            if (cue == "warning" && sources[0].isPlaying) return;
            if (cue == "ui_confirm" || cue == "ui_cancel")
            {
                lastUiActionFrame = frame;
                if (voices.TryGetValue("ui_move", out var move))
                    foreach (var source in move) source.Stop();
            }
            lastPlayFrame[cue] = frame;
            lastPlayTime[cue] = clock;
            PickVoice(sources).Play();
            CuePlayed?.Invoke(cue);
        }

        static AudioSource PickVoice(AudioSource[] sources)
        {
            // Godot restarts a single voice; with polyphony it adds voices and steals the oldest.
            if (sources.Length == 1) return sources[0];
            AudioSource oldest = sources[0];
            foreach (var source in sources)
            {
                if (!source.isPlaying) return source;
                if (source.time > oldest.time) oldest = source;
            }
            return oldest;
        }

        internal void QueueNavigation(Selectable button)
        {
            if (shuttingDown || !IsUsable(button)) return;
            if (navigationTarget == button) return;
            navigationTarget = button;
            queuedNavigation = button;
            queuedNavigationFrame = Time.frameCount;
        }

        static bool IsUsable(Selectable button) =>
            button != null && button.IsInteractable() && button.isActiveAndEnabled;

        void StopAll()
        {
            shuttingDown = true;
            foreach (var sources in voices.Values)
                foreach (var source in sources) source.Stop();
        }
    }
}
