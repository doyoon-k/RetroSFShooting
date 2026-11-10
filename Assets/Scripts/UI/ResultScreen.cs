using System;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace RetroSF
{
    /// <summary>Mission debrief after the ending (Godot result.gd).</summary>
    public class ResultScreen : MonoBehaviour
    {
        /// <summary>Used only when the screen runs without GameFlow (preview).</summary>
        public GameCatalog previewCatalog;
        [NonSerialized] public RunState run;
        [NonSerialized] public EndingData ending;
        [NonSerialized] public bool saveOk = true;
        public event Action ReturnRequested;

        [SerializeField] TextMeshProUGUI heading;
        [SerializeField] TextMeshProUGUI survivors;
        [SerializeField] PilotRoster roster;
        [SerializeField] TextMeshProUGUI saveStatus;
        // Godot node %Return; "return" is a C# keyword, so the field is spelled @return (serialized as "return").
        [SerializeField] Button @return;

        void Start()
        {
            UiRuntime.Ensure();
            if (run == null)
            {
                run = new RunState(previewCatalog);
                run.bossCleared = true;
                ending = previewCatalog.EndingById("new_home");
            }
            string endingMusic = Music.EndingCue(ending.id);
            Music.Play(endingMusic == "ending" ? "clear" : endingMusic);
            Sfx.Play("result_reveal");
            heading.text = ending.number + " / " + ending.title;
            survivors.text = $"SURVIVORS  {run.Survivors().Count} / {run.catalog.pilots.Count}";
            roster.Configure(run.catalog, run);
            roster.showSurvivedStatus = true;
            roster.Refresh();
            saveStatus.text = saveOk ? "엔딩 기록이 저장되었습니다." : "엔딩 기록 저장에 실패했습니다. 기존 저장 파일은 보존됩니다.";
            @return.onClick.AddListener(ReturnToTitle);
            UiRuntime.Focus(@return);
            Sfx.BindNavigation(@return);
        }

        void OnDestroy()
        {
            if (@return != null) @return.onClick.RemoveListener(ReturnToTitle);
        }

        void ReturnToTitle()
        {
            Sfx.Play("ui_confirm");
            ReturnRequested?.Invoke();
        }
    }
}
