using TMPro;
using UnityEngine;

namespace RetroSF
{
    /// <summary>
    /// Godot TypewriterLabel, on the TextMeshProUGUI object (visible_characters → maxVisibleCharacters).
    /// UiRuntime advances it on unscaled time even while its panel is hidden, like Godot's _process,
    /// so death and victory lines keep typing during the combat pause.
    /// </summary>
    public class TypewriterText : MonoBehaviour
    {
        const int AllCharacters = 99999;

        [Range(1f, 200f)] public float charactersPerSecond = 42f;
        [Tooltip("Sfx cue played once per Blip Every revealed characters; empty stays silent.")]
        public string blipCue = "text_blip";
        [Range(1, 20)] public int blipEvery = 3;

        TMP_Text label;
        float progress;
        bool typing;
        int messageLength;

        public bool Typing => typing;

        TMP_Text Label
        {
            get
            {
                if (label == null) label = GetComponent<TMP_Text>();
                return label;
            }
        }

        public void Reveal(string message)
        {
            message ??= "";
            var text = Label;
            if (text != null)
            {
                text.text = message;
                text.maxVisibleCharacters = 0;
            }
            progress = 0f;
            messageLength = message.Length;
            typing = message.Length > 0;
            if (typing) UiRuntime.Track(this);
        }

        public void Complete()
        {
            var text = Label;
            if (text != null) text.maxVisibleCharacters = AllCharacters;
            typing = false;
        }

        internal void Tick(float delta)
        {
            if (!typing) return;
            var text = Label;
            int total = TotalCharacters(text);
            float previous = progress;
            progress += delta * charactersPerSecond;
            int visible = (int)progress;
            if (text != null) text.maxVisibleCharacters = visible;
            int every = Mathf.Max(1, blipEvery);
            // A closed panel keeps typing in the background; only visible text should blip.
            if (!string.IsNullOrEmpty(blipCue) && gameObject.activeInHierarchy
                && Mathf.FloorToInt(progress / every) > Mathf.FloorToInt(previous / every))
                Sfx.Play(blipCue);
            if (visible >= total) Complete();
        }

        /// <summary>Godot get_total_character_count(): TMP's parsed count once generated, else the plain length.</summary>
        int TotalCharacters(TMP_Text text)
        {
            if (text != null && text.IsActive() && !text.havePropertiesChanged && text.textInfo != null)
                return text.textInfo.characterCount;
            return messageLength;
        }
    }
}
