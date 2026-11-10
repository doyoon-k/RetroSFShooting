using System;
using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.Controls;
using UnityEngine.UI;

namespace RetroSF
{
    /// <summary>
    /// PRESS ANY BUTTON, then NEW GAME / ENDINGS / EXIT and the ending archive (Godot title.gd).
    /// </summary>
    public class TitleScreen : MonoBehaviour
    {
        enum State { Waiting, Menu, Collection, Starting }

        const float PromptPulseSeconds = 1.8f;
        const float AudioReleaseSeconds = 0.1f;

        public GameCatalog catalog;
        [Range(0f, 30f)] public float shipFloatPixels = 7f;
        [Range(0.5f, 10f)] public float shipFloatSeconds = 4.4f;
        [NonSerialized] public List<string> unlocked = new List<string>();
        public event Action NewGameRequested;

        [SerializeField] Image ship;
        [SerializeField] Image startPrompt;
        [SerializeField] RectTransform menu;
        [SerializeField] Button newGame;
        [SerializeField] Button endings;
        [SerializeField] Button exit;
        [SerializeField] RectTransform collection;
        [SerializeField] TextMeshProUGUI collectionText;
        [SerializeField] Button collectionBack;

        State state = State.Waiting;
        float elapsed;
        Vector2 shipOrigin;
        Color promptColor;
        GraphicRaycaster raycaster;
        // The press that opened the menu. It stays consumed until that same control is released.
        ButtonControl openingInput;

        void Start()
        {
            UiRuntime.Ensure();
            Music.Play("title");
            shipOrigin = ship.rectTransform.anchoredPosition;
            promptColor = startPrompt.color;
            raycaster = GetComponentInParent<GraphicRaycaster>();
            newGame.onClick.AddListener(StartNewGame);
            endings.onClick.AddListener(ShowEndings);
            exit.onClick.AddListener(QuitGame);
            collectionBack.onClick.AddListener(HideEndings);
            UiUtil.SetVisible(menu, false);
            UiUtil.SetVisible(collection, false);
            UiUtil.SetVisible(startPrompt, true);
            // title.tscn focus neighbours: the menu wraps vertically.
            Link(newGame, exit, endings);
            Link(endings, newGame, exit);
            Link(exit, endings, newGame);
            foreach (var button in new[] { newGame, endings, exit, collectionBack })
                Sfx.BindNavigation(button);
        }

        void OnDestroy()
        {
            if (newGame != null) newGame.onClick.RemoveListener(StartNewGame);
            if (endings != null) endings.onClick.RemoveListener(ShowEndings);
            if (exit != null) exit.onClick.RemoveListener(QuitGame);
            if (collectionBack != null) collectionBack.onClick.RemoveListener(HideEndings);
        }

        void Update()
        {
            HandleOpeningInput();
            // Godot _unhandled_input: ui_cancel closes the archive.
            if (state == State.Collection && GameInput.UiCancelPressed) HideEndings();

            elapsed += Time.unscaledDeltaTime;
            // Godot y grows downward, so its +sin offset is -y here.
            ship.rectTransform.anchoredPosition =
                shipOrigin + new Vector2(0f, -Mathf.Sin(G.Tau * elapsed / shipFloatSeconds) * shipFloatPixels);
            if (state == State.Waiting)
            {
                var color = promptColor;
                color.a = promptColor.a * (0.88f + 0.12f * Mathf.Cos(G.Tau * elapsed / PromptPulseSeconds));
                startPrompt.color = color;
            }
        }

        /// <summary>
        /// Godot _input. The opening press, its repeats and its release never reach the menu: GameInput only
        /// reports presses, so skipping the reveal frame covers keys and pad buttons; a mouse opening also
        /// stops pointer hits until that button is released, or the release would click the button under it.
        /// </summary>
        void HandleOpeningInput()
        {
            if (openingInput != null)
            {
                if (openingInput.isPressed) return;
                openingInput = null;
                if (raycaster != null) raycaster.enabled = true;
                return;
            }
            if (state != State.Waiting) return;
            var press = FindStartPress();
            if (press != null) RevealMenu(press);
        }

        void RevealMenu(ButtonControl press)
        {
            state = State.Menu;
            openingInput = press;
            if (raycaster != null && press.device is Mouse) raycaster.enabled = false;
            UiUtil.SetVisible(startPrompt, false);
            UiUtil.SetVisible(menu, true);
            UiRuntime.Focus(newGame);
            Sfx.Play("ui_confirm");
            UiRuntime.ConsumeInput();
        }

        /// <summary>Any key except modifiers, any pad button, or the left/right/middle mouse button.</summary>
        static ButtonControl FindStartPress()
        {
            var keyboard = Keyboard.current;
            if (keyboard != null)
            {
                foreach (var key in keyboard.allKeys)
                    if (key != null && key.wasPressedThisFrame && !IsModifier(key.keyCode)) return key;
            }
            foreach (var pad in Gamepad.all)
            {
                var button = PressedPadButton(pad);
                if (button != null) return button;
            }
            var mouse = Mouse.current;
            if (mouse != null)
            {
                if (mouse.leftButton.wasPressedThisFrame) return mouse.leftButton;
                if (mouse.rightButton.wasPressedThisFrame) return mouse.rightButton;
                if (mouse.middleButton.wasPressedThisFrame) return mouse.middleButton;
            }
            return null;
        }

        static bool IsModifier(Key key) =>
            key == Key.LeftShift || key == Key.RightShift || key == Key.LeftCtrl || key == Key.RightCtrl
            || key == Key.LeftAlt || key == Key.RightAlt || key == Key.LeftMeta || key == Key.RightMeta;

        /// <summary>Godot joypad buttons; the triggers are axes there, so they do not count.</summary>
        static ButtonControl PressedPadButton(Gamepad pad)
        {
            if (Pressed(pad.buttonSouth)) return pad.buttonSouth;
            if (Pressed(pad.buttonEast)) return pad.buttonEast;
            if (Pressed(pad.buttonWest)) return pad.buttonWest;
            if (Pressed(pad.buttonNorth)) return pad.buttonNorth;
            if (Pressed(pad.leftShoulder)) return pad.leftShoulder;
            if (Pressed(pad.rightShoulder)) return pad.rightShoulder;
            if (Pressed(pad.startButton)) return pad.startButton;
            if (Pressed(pad.selectButton)) return pad.selectButton;
            if (Pressed(pad.leftStickButton)) return pad.leftStickButton;
            if (Pressed(pad.rightStickButton)) return pad.rightStickButton;
            if (Pressed(pad.dpad.up)) return pad.dpad.up;
            if (Pressed(pad.dpad.down)) return pad.dpad.down;
            if (Pressed(pad.dpad.left)) return pad.dpad.left;
            if (Pressed(pad.dpad.right)) return pad.dpad.right;
            return null;
        }

        static bool Pressed(ButtonControl button) => button != null && button.wasPressedThisFrame;

        static void Link(Selectable button, Selectable up, Selectable down)
        {
            button.navigation = new Navigation { mode = Navigation.Mode.Explicit, selectOnUp = up, selectOnDown = down };
        }

        void DisableMenu()
        {
            newGame.interactable = false;
            endings.interactable = false;
            exit.interactable = false;
        }

        void StartNewGame()
        {
            if (state != State.Menu) return;
            state = State.Starting;
            Sfx.Play("ui_confirm");
            DisableMenu();
            NewGameRequested?.Invoke();
        }

        void QuitGame()
        {
            if (state != State.Menu) return;
            state = State.Starting;
            DisableMenu();
            Music.Stop();
            Sfx.Shutdown();
            StartCoroutine(QuitAfterAudioRelease());
        }

        /// <summary>Godot SoundEffects.shutdown(): give the audio thread 100 ms of wall time to release voices.</summary>
        IEnumerator QuitAfterAudioRelease()
        {
            yield return new WaitForSecondsRealtime(AudioReleaseSeconds);
            Application.Quit();
#if UNITY_EDITOR
            UnityEditor.EditorApplication.isPlaying = false;
#endif
        }

        void ShowEndings()
        {
            if (state != State.Menu) return;
            state = State.Collection;
            Sfx.Play("ui_confirm");
            var lines = new List<string>();
            int discovered = 0;
            foreach (var ending in catalog.endings)
            {
                if (ending == null) continue;
                bool known = unlocked.Contains(ending.id);
                if (known) discovered++;
                lines.Add($"{ending.number}    {(known ? ending.title : "???")}");
            }
            collectionText.text = $"기록 복원  {discovered} / {catalog.endings.Count}\n\n{string.Join("\n", lines)}";
            UiUtil.SetVisible(collection, true);
            UiUtil.SetVisible(menu, false);
            UiRuntime.Focus(collectionBack);
        }

        void HideEndings()
        {
            if (state != State.Collection) return;
            state = State.Menu;
            UiUtil.SetVisible(collection, false);
            Sfx.Play("ui_cancel");
            UiUtil.SetVisible(menu, true);
            UiRuntime.Focus(endings);
        }
    }
}
