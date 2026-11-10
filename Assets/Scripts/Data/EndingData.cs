using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    [CreateAssetMenu(menuName = "RetroSF/Ending Data")]
    public class EndingData : ScriptableObject
    {
        public string id = "";
        public string number = "";
        public string title = "";
        public StoryData story;
    }
}
