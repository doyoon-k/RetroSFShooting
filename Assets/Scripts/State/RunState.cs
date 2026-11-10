using System;
using System.Collections.Generic;

namespace RetroSF
{
    /// <summary>One run, from NEW GAME to Result. Owned by GameFlow.</summary>
    public class RunState
    {
        public event Action RosterChanged;

        public GameCatalog catalog;
        public string currentPilotId = "";
        public readonly List<string> deadPilotIds = new List<string>();
        public SortieState currentSortie;
        public bool bossCleared;
        public string endingId = "";

        public RunState(GameCatalog content = null)
        {
            catalog = content;
        }

        public List<PilotData> Survivors()
        {
            var result = new List<PilotData>();
            foreach (var pilot in catalog.pilots)
                if (IsAlive(pilot.id)) result.Add(pilot);
            return result;
        }

        public bool IsAlive(string id) => catalog.PilotById(id) != null && !deadPilotIds.Contains(id);

        public bool BeginSortie(string id)
        {
            if (!IsAlive(id)) return false;
            currentPilotId = id;
            currentSortie = new SortieState(catalog.rules);
            RosterChanged?.Invoke();
            return true;
        }

        public void MarkDead(string id)
        {
            if (IsAlive(id))
            {
                deadPilotIds.Add(id);
                RosterChanged?.Invoke();
            }
        }

        public string AutomaticChoice(string preferred)
        {
            if (!string.IsNullOrEmpty(preferred) && IsAlive(preferred)) return preferred;
            var living = Survivors();
            return living.Count > 0 ? living[0].id : "";
        }
    }
}
