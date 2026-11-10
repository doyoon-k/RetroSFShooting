using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.UI;

namespace RetroSF
{
    /// <summary>
    /// Owns screen lifetimes and the current run (Godot main.gd). Combat lives entirely in the stage.
    /// Title → Intro → Character Select → Stage → Ending → Result → Title.
    /// </summary>
    public class GameFlow : MonoBehaviour
    {
        const float FadeSeconds = 0.3f;

        public GameCatalog catalog;
        public TitleScreen titlePrefab;
        public StoryScreen storyPrefab;
        public CharacterSelect selectPrefab;
        public StageController stagePrefab;
        public ResultScreen resultPrefab;

        [SerializeField] Transform screenHost;
        [SerializeField] Image fade;
        [Tooltip("Godot's fade tween is bound to the pausable Main node, so it holds while the tree is paused " +
                 "(the stage's launch phase). Off: the fade always runs on unscaled time.")]
        public bool fadeHoldsDuringPause = true;

        RunState run;
        MonoBehaviour currentScreen;
        Action detachCurrent;
        SaveStore saveStore;
        readonly List<KeyValuePair<int, Action>> deferred = new List<KeyValuePair<int, Action>>();
        Color fadeColor = Color.black;
        float fadeLeft;

        public SaveStore Saves => saveStore;

        void Awake()
        {
            saveStore = new SaveStore(Path.Combine(Application.persistentDataPath, "endings.json"));
            saveStore.SaveFailed += OnSaveFailed;
            UiRuntime.Ensure();
            if (fade != null)
            {
                fadeColor = fade.color;
                fade.raycastTarget = false;
            }
        }

        void Start()
        {
            saveStore.LoadProgress();
            ShowTitle();
        }

        void OnDestroy()
        {
            detachCurrent?.Invoke();
            detachCurrent = null;
            if (saveStore != null) saveStore.SaveFailed -= OnSaveFailed;
        }

        void Update()
        {
            // A fade started this frame begins next frame, like a new Godot tween.
            UpdateFade();
            RunDeferred();
        }

        static void OnSaveFailed(string message) => Debug.LogWarning(message);

        public void ShowTitle()
        {
            run = null;
            var screen = Replace(titlePrefab);
            screen.catalog = catalog;
            screen.unlocked = new List<string>(saveStore.Unlocked);
            OnceDeferred(h => screen.NewGameRequested += h, h => screen.NewGameRequested -= h, StartNewGame);
        }

        void StartNewGame()
        {
            run = new RunState(catalog);
            var screen = Replace(storyPrefab);
            screen.story = catalog.intro;
            OnceDeferred(h => screen.Finished += h, h => screen.Finished -= h, ShowSelect);
        }

        void ShowSelect()
        {
            var screen = Replace(selectPrefab);
            screen.catalog = catalog;
            screen.run = run;
            OnceDeferredWithId(h => screen.SortieRequested += h, h => screen.SortieRequested -= h, StartStage);
        }

        void StartStage(string id)
        {
            if (!run.BeginSortie(id)) return;
            var screen = Replace(stagePrefab);
            screen.catalog = catalog;
            screen.run = run;
            OnceDeferred(h => screen.Completed += h, h => screen.Completed -= h, ShowEnding);
        }

        void ShowEnding()
        {
            run.endingId = EndingResolver.Resolve(run);
            var ending = catalog.EndingById(run.endingId);
            if (ending == null)
            {
                Debug.LogError("No ending matches the completed run.");
                return;
            }
            var screen = Replace(storyPrefab);
            screen.story = ending.story;
            screen.musicCue = Music.EndingCue(run.endingId);
            OnceDeferred(h => screen.Finished += h, h => screen.Finished -= h, ShowResult);
        }

        void ShowResult()
        {
            var screen = Replace(resultPrefab);
            screen.run = run;
            screen.ending = catalog.EndingById(run.endingId);
            screen.saveOk = saveStore.Unlock(run.endingId);
            OnceDeferred(h => screen.ReturnRequested += h, h => screen.ReturnRequested -= h, ShowTitle);
        }

        /// <summary>
        /// Godot _replace. The new screen is configured by the caller before its Start runs.
        /// </summary>
        T Replace<T>(T prefab) where T : MonoBehaviour
        {
            GamePause.Set(false);
            detachCurrent?.Invoke();
            detachCurrent = null;
            if (currentScreen != null)
            {
                // Godot remove_child: the old screen stops at once and is freed at the end of the frame.
                currentScreen.gameObject.SetActive(false);
                Destroy(currentScreen.gameObject);
            }
            var screen = Instantiate(prefab, screenHost);
            currentScreen = screen;
            fadeLeft = FadeSeconds;
            ApplyFade(1f);
            return screen;
        }

        /// <summary>Godot CONNECT_DEFERRED | CONNECT_ONE_SHOT: handled once, next frame, never inside the screen's callback.</summary>
        void OnceDeferred(Action<Action> subscribe, Action<Action> unsubscribe, Action next)
        {
            Action handler = null;
            handler = () =>
            {
                unsubscribe(handler);
                detachCurrent = null;
                Defer(next);
            };
            subscribe(handler);
            detachCurrent = () => unsubscribe(handler);
        }

        void OnceDeferredWithId(Action<Action<string>> subscribe, Action<Action<string>> unsubscribe, Action<string> next)
        {
            Action<string> handler = null;
            handler = id =>
            {
                unsubscribe(handler);
                detachCurrent = null;
                Defer(() => next(id));
            };
            subscribe(handler);
            detachCurrent = () => unsubscribe(handler);
        }

        void Defer(Action action) => deferred.Add(new KeyValuePair<int, Action>(Time.frameCount, action));

        void RunDeferred()
        {
            int frame = Time.frameCount;
            for (int i = 0; i < deferred.Count;)
            {
                if (deferred[i].Key >= frame)
                {
                    i++;
                    continue;
                }
                var action = deferred[i].Value;
                deferred.RemoveAt(i);
                action();
            }
        }

        void UpdateFade()
        {
            if (fadeLeft <= 0f) return;
            float delta = fadeHoldsDuringPause ? Time.deltaTime : Time.unscaledDeltaTime;
            fadeLeft = Mathf.Max(0f, fadeLeft - delta);
            ApplyFade(fadeLeft / FadeSeconds);
        }

        void ApplyFade(float alpha)
        {
            if (fade != null) fade.color = new Color(fadeColor.r, fadeColor.g, fadeColor.b, fadeColor.a * alpha);
        }
    }
}
