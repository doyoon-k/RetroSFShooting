using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    /// <summary>The editable content manifest used by GameFlow and the stage preview.</summary>
    [CreateAssetMenu(menuName = "RetroSF/Game Catalog")]
    public class GameCatalog : ScriptableObject
    {
        public GameRules rules;
        public List<PilotData> pilots = new List<PilotData>();
        public StoryData intro;
        public List<EndingData> endings = new List<EndingData>();

        public PilotData PilotById(string id)
        {
            foreach (var pilot in pilots)
                if (pilot != null && pilot.id == id) return pilot;
            return null;
        }

        public EndingData EndingById(string id)
        {
            foreach (var ending in endings)
                if (ending != null && ending.id == id) return ending;
            return null;
        }
    }
}
