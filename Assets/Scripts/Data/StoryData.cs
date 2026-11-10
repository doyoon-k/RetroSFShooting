using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    [Serializable]
    public class StoryPage
    {
        public Sprite illustration;
        public string caption = "";
        [TextArea(2, 8)] public string text = "";
    }

    [CreateAssetMenu(menuName = "RetroSF/Story Data")]
    public class StoryData : ScriptableObject
    {
        public string title = "";
        public List<StoryPage> pages = new List<StoryPage>();
        [Range(1f, 200f)] public float charactersPerSecond = 42f;
    }
}
