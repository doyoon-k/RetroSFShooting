using System;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace RetroSF
{
    /// <summary>Full-screen cutscene pages with a typed subtitle (Godot story_screen.gd).</summary>
    public class StoryScreen : MonoBehaviour
    {
        public StoryData story;
        public string musicCue = "title";
        public event Action Finished;

        [SerializeField] TextMeshProUGUI heading;
        [SerializeField] Image illustration;
        [SerializeField] TextMeshProUGUI caption;
        [SerializeField] RectTransform storyPanel;
        [SerializeField] TypewriterText storyText;
        [SerializeField] TextMeshProUGUI pageNumber;
        [SerializeField] Button next;

        int pageIndex;
        bool ended;
        bool finishPending;

        void Start()
        {
            UiRuntime.Ensure();
            Music.Play(musicCue);
            UiUtil.DisableFocus(next);
            next.onClick.AddListener(Advance);
            ShowPage();
            Sfx.BindNavigation(next);
        }

        void OnDestroy()
        {
            if (next != null) next.onClick.RemoveListener(Advance);
        }

        /// <summary>Godot _unhandled_input: story_advance (Space / A). Nothing here can hold focus.</summary>
        void Update()
        {
            if (GameInput.StoryAdvancePressed) Advance();
        }

        /// <summary>Godot finished.emit.call_deferred() for a story without pages.</summary>
        void LateUpdate()
        {
            if (!finishPending) return;
            finishPending = false;
            Finished?.Invoke();
        }

        void ShowPage()
        {
            if (story == null || story.pages.Count == 0)
            {
                ended = true;
                finishPending = true;
                return;
            }
            var page = story.pages[pageIndex];
            heading.text = story.title;
            UiUtil.SetTextureFitted(illustration, page.illustration);
            caption.text = page.caption;
            UiUtil.SetVisible(caption, !string.IsNullOrEmpty(page.caption));
            UiUtil.SetVisible(storyPanel, !string.IsNullOrEmpty(page.text));
            storyText.charactersPerSecond = story.charactersPerSecond;
            storyText.Reveal(page.text);
            pageNumber.text = $"{pageIndex + 1:00} / {story.pages.Count:00}";
            UiUtil.SetButtonText(next, pageIndex == story.pages.Count - 1 ? "SPACE / A / 완료" : "SPACE / A / 다음");
        }

        public void Advance()
        {
            if (ended) return;
            Sfx.Play("ui_confirm");
            if (storyText.Typing)
            {
                storyText.Complete();
                return;
            }
            pageIndex++;
            if (pageIndex >= story.pages.Count)
            {
                ended = true;
                Finished?.Invoke();
            }
            else
            {
                ShowPage();
            }
        }
    }
}
