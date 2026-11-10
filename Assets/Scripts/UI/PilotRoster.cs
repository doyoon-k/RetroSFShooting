using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;

namespace RetroSF
{
    /// <summary>
    /// Six pilot cards in a grid (Godot PilotRoster, a GridContainer). Cards are instantiated under this
    /// transform. Shared by the Result screen and the battle roster.
    /// </summary>
    public class PilotRoster : MonoBehaviour
    {
        static readonly Color Unhighlighted = new Color(0.8f, 0.85f, 0.9f);

        public event Action<string> PilotFocused;
        public event Action<string> PilotSelected;

        public PilotPortrait portraitPrefab;
        [NonSerialized] public bool selectable;
        [NonSerialized] public bool showSurvivedStatus;
        [NonSerialized] public string highlightedId = "";

        GameCatalog catalog;
        RunState run;
        SortieState observedSortie;
        readonly List<PilotPortrait> cards = new List<PilotPortrait>();
        readonly List<Action> focusHandlers = new List<Action>();
        readonly List<UnityAction> clickHandlers = new List<UnityAction>();

        public void Configure(GameCatalog content, RunState runState)
        {
            catalog = content;
            if (run != runState)
            {
                if (run != null) run.RosterChanged -= Refresh;
                run = runState;
                if (run != null) run.RosterChanged += Refresh;
            }
            // Godot waits for _ready; instancing under an inactive Unity object is already safe.
            Build();
        }

        void Start()
        {
            if (catalog != null && cards.Count == 0) Build();
        }

        void OnDestroy()
        {
            if (run != null) run.RosterChanged -= Refresh;
            if (observedSortie != null) observedSortie.Changed -= Refresh;
            for (int i = 0; i < cards.Count; i++)
            {
                var card = cards[i];
                if (card == null) continue;
                card.FocusEntered -= focusHandlers[i];
                if (card.Button != null) card.Button.onClick.RemoveListener(clickHandlers[i]);
            }
        }

        void Build()
        {
            if (cards.Count > 0)
            {
                Refresh();
                return;
            }
            if (catalog == null || portraitPrefab == null) return;
            foreach (var pilot in catalog.pilots)
            {
                var card = Instantiate(portraitPrefab, transform);
                string id = pilot.id;
                Action onFocus = () => FocusPilot(id);
                UnityAction onClick = () => SelectPilot(id);
                cards.Add(card);
                focusHandlers.Add(onFocus);
                clickHandlers.Add(onClick);
                card.FocusEntered += onFocus;
                if (card.Button != null) card.Button.onClick.AddListener(onClick);
                Sfx.BindNavigation(card.Button);
            }
            Refresh();
        }

        public void Refresh()
        {
            if (run == null) return;
            if (observedSortie != run.currentSortie)
            {
                if (observedSortie != null) observedSortie.Changed -= Refresh;
                observedSortie = run.currentSortie;
                if (observedSortie != null) observedSortie.Changed += Refresh;
            }
            for (int i = 0; i < cards.Count; i++)
            {
                var pilot = catalog.pilots[i];
                bool alive = IsDisplayAlive(pilot);
                var card = cards[i];
                card.Display(pilot, PortraitFor(pilot), pilot.id == run.currentPilotId && alive, alive, showSurvivedStatus);
                card.Disabled = !selectable || !alive;
                card.SetFocusable(selectable && alive);
                card.SetModulate(highlightedId == pilot.id || !selectable ? Color.white : Unhighlighted);
            }
        }

        public Sprite PortraitFor(PilotData pilot)
        {
            int deadCount = catalog.pilots.Count - run.Survivors().Count;
            bool current = pilot.id == run.currentPilotId && run.currentSortie != null;
            bool damaged = current && run.currentSortie.hp > 0 && run.currentSortie.hp * 2 <= catalog.rules.startingHp;
            return pilot.Portrait(deadCount, damaged, !IsDisplayAlive(pilot));
        }

        bool IsDisplayAlive(PilotData pilot) =>
            run.IsAlive(pilot.id)
            && !(pilot.id == run.currentPilotId && run.currentSortie != null && run.currentSortie.hp <= 0);

        public void FocusFirst()
        {
            string id = run.AutomaticChoice(highlightedId);
            foreach (var card in cards)
            {
                if (card.Pilot != null && card.Pilot.id == id)
                {
                    UiRuntime.Focus(card.Button);
                    FocusPilot(id);
                    return;
                }
            }
        }

        void FocusPilot(string id)
        {
            if (!selectable || !run.IsAlive(id)) return;
            highlightedId = id;
            Refresh();
            PilotFocused?.Invoke(id);
        }

        void SelectPilot(string id)
        {
            if (selectable && run.IsAlive(id))
            {
                Sfx.Play("ui_confirm");
                FocusPilot(id);
                PilotSelected?.Invoke(id);
            }
        }
    }
}
