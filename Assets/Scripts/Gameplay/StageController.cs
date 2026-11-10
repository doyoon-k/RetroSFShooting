using System;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace RetroSF
{
    /// <summary>Coordinates actors; owns the only combat pause and outcome decision.</summary>
    /// <remarks>Runs before the actors each tick, like the Godot root node it replaces.</remarks>
    [DefaultExecutionOrder(-100)]
    public class StageController : MonoBehaviour
    {
        public enum Phase { Launching, Playing, BossIntro, PlayerDying, SelectingNext, Clearing, Finished }

        const float DesignHeight = 1080f;
        const float DesignWidth = 1920f;

        public event Action Completed;

        public GameCatalog catalog;
        public Pickup recoveryPickup;
        public Pickup recoveryBomb;
        public OneShotEffect explosionPrefab;
        public EnemyHitEffect enemyHitPrefab;
        [Range(0.1f, 10f)] public float bossIntroSeconds = 2f;
        [Range(0.1f, 10f)] public float clearIntroSeconds = 1.5f;
        [Range(1f, 1000f)] public float scrollSpeed = 180f;
        [Range(0f, 500f)] public float activationMargin = 80f;
        [Tooltip("Interface overlays (dimmer, bomb flash) in world space at the stage start.")]
        public Rect presentationBounds = G.FromGodotRect(440f, 24f, 1464f, 952f);

        [Header("World")]
        public Transform playfield;
        public WaveSequence waveSequence;
        public Transform placedEnemies;
        public Transform actors;
        public Transform projectiles;
        public Transform items;

        [Header("Interface")]
        public PilotRoster roster;
        public CombatHUD combatHUD;
        public PowerUpMessage powerUpMessage;
        public Image bombFlash;
        public Image pauseDimmer;
        public GameObject sequencePanel;
        public Image sequencePortrait;
        public TextMeshProUGUI sequenceTitle;
        public TypewriterText sequenceText;
        public GameObject nextPilotPanel;
        public TextMeshProUGUI countdown;
        public GameObject pauseMenu;
        public Button resume;

        [NonSerialized] public RunState run;
        [NonSerialized] public Phase phase = Phase.Launching;
        [NonSerialized] public bool userPaused;
        [NonSerialized] public float phaseLeft;
        [NonSerialized] public PlayerShip player;
        [NonSerialized] public EnemyShip boss;
        [NonSerialized] public EnemyShip midEnemy;
        [NonSerialized] public int defeated;
        [NonSerialized] public int placedActivated;
        [NonSerialized] public float progressX;
        [NonSerialized] public Rect viewBounds;

        struct PendingDeath
        {
            public bool active;
            public Vector2 position;
            public int powerups;
            public int bombs;
            public string pilot;
        }

        PendingDeath pendingDeath;
        bool pendingBoss;
        bool bossWaitingToEnter;
        bool resolutionQueued;
        string dyingPilotId = "";
        int victoryIndex = -1;
        GameRules rules;
        bool bombPending;
        float bombDelayLeft;
        float bombCooldownLeft;
        float bombFlashAlpha;
        float bombFlashFadeLeft;
        float bombFlashFadeFrom;
        Transform simulationEffects;
        Transform presentationEffects;
        Color bombFlashColor = Color.white;
        readonly List<Action> deferred = new List<Action>();
        readonly List<EnemyShip> placedPending = new List<EnemyShip>();
        bool started;

        void Awake()
        {
            simulationEffects = transform.Find("Simulation/Effects");
            presentationEffects = transform.Find("Presentation/Effects");
            if (bombFlash != null) bombFlashColor = bombFlash.color;
        }

        void Start()
        {
            if (run == null)
            {
                run = new RunState(catalog);
                run.BeginSortie(catalog.pilots[0].id);
            }
            rules = catalog.rules;
            viewBounds = rules.playfield;
            if (placedEnemies != null)
            {
                foreach (Transform child in placedEnemies)
                {
                    var enemy = child.GetComponent<EnemyShip>();
                    if (enemy == null) continue;
                    placedPending.Add(enemy);
                    enemy.gameObject.SetActive(false);
                }
            }
            roster.Configure(catalog, run);
            roster.PilotSelected += SelectNext;
            waveSequence.EnemyRequested += SpawnWaveEnemy;
            waveSequence.BossRequested += RequestBossIntro;
            resume.onClick.AddListener(TogglePause);
            combatHUD.BombRequested += OnBombRequested;
            combatHUD.WeaponChangeRequested += SwitchWeapon;
            combatHUD.PauseRequested += TogglePause;
            PlaceOverlay(pauseDimmer);
            PlaceOverlay(bombFlash);
            SetBombFlash(0f);
            SyncWorldBounds();
            Music.Play("stage");
            started = true;
            LaunchCurrent();
        }

        void OnDestroy()
        {
            if (roster != null) roster.PilotSelected -= SelectNext;
            if (waveSequence != null)
            {
                waveSequence.EnemyRequested -= SpawnWaveEnemy;
                waveSequence.BossRequested -= RequestBossIntro;
            }
            if (combatHUD != null)
            {
                combatHUD.BombRequested -= OnBombRequested;
                combatHUD.WeaponChangeRequested -= SwitchWeapon;
                combatHUD.PauseRequested -= TogglePause;
            }
            if (resume != null) resume.onClick.RemoveListener(TogglePause);
            if (!started) return;
            Music.SetPaused(false);
            GamePause.Set(false);
        }

        /// <summary>Interface overlays use the design canvas (origin bottom-left, y up).</summary>
        static Rect DesignRect(Rect worldAtStart) =>
            new Rect(worldAtStart.x, worldAtStart.y + DesignHeight, worldAtStart.width, worldAtStart.height);

        void PlaceOverlay(Image overlay)
        {
            if (overlay == null) return;
            // The overlay's parent (PlayfieldMask) covers the whole 1920×1080 design canvas.
            var rect = DesignRect(presentationBounds);
            var rt = overlay.rectTransform;
            rt.anchorMin = rt.anchorMax = Vector2.zero;
            rt.pivot = Vector2.zero;
            rt.anchoredPosition = rect.position;
            rt.sizeDelta = rect.size;
        }

        void FixedUpdate()
        {
            if (phase != Phase.Playing || userPaused) return;
            AdvanceBomb(Time.fixedDeltaTime);
            if (boss != null || midEnemy != null || bossWaitingToEnter) return;
            progressX += scrollSpeed * Time.fixedDeltaTime;
            SyncWorldBounds();
            waveSequence.Advance(viewBounds.xMax + activationMargin);
            for (int i = placedPending.Count - 1; i >= 0; i--)
            {
                var enemy = placedPending[i];
                if (enemy == null)
                {
                    placedPending.RemoveAt(i);
                    continue;
                }
                if (enemy.transform.position.x <= viewBounds.xMax + activationMargin)
                {
                    placedPending.RemoveAt(i);
                    ActivatePlacedEnemy(enemy);
                }
            }
        }

        void SyncWorldBounds()
        {
            viewBounds = new Rect(rules.playfield.position + new Vector2(progressX, 0f), rules.playfield.size);
            var camera = Camera.main;
            if (camera != null)
                camera.transform.position = new Vector3(DesignWidth * 0.5f + progressX, -DesignHeight * 0.5f, camera.transform.position.z);
            if (playfield != null)
                playfield.position = new Vector3(viewBounds.x, viewBounds.yMax, playfield.position.z);
            if (player != null)
            {
                player.bounds = viewBounds;
                player.weapon.bounds = viewBounds;
            }
            foreach (Transform child in actors)
            {
                var enemy = child.GetComponent<EnemyShip>();
                if (enemy == null) continue;
                enemy.bounds = viewBounds;
                if (enemy.shooter != null) enemy.shooter.bounds = viewBounds;
            }
            foreach (Transform child in projectiles)
            {
                var bullet = child.GetComponent<Projectile>();
                if (bullet != null) bullet.bounds = viewBounds;
            }
            foreach (Transform child in items)
            {
                var item = child.GetComponent<Pickup>();
                if (item != null) item.bounds = viewBounds;
            }
        }

        void Update()
        {
            if (!started) return;
            if (GameInput.PausePressed) TogglePause();
            UpdateHud();
            UpdateBombFlashFade();
            if (phase == Phase.Finished || userPaused) return;
            if (phase == Phase.Playing) return;
            // Always-processing: these timers run while the combat pause is on.
            phaseLeft -= Time.unscaledDeltaTime;
            if (phase == Phase.Launching && player != null)
            {
                float t = Mathf.Clamp01(1f - phaseLeft / rules.launchSeconds);
                var from = new Vector2(rules.playfield.x - 80f, rules.spawnPosition.y);
                player.Position = Vector2.Lerp(from, rules.spawnPosition, 1f - Mathf.Pow(1f - t, 3f)) + new Vector2(progressX, 0f);
            }
            if (phase == Phase.SelectingNext)
            {
                string text = Mathf.Max(1, Mathf.CeilToInt(phaseLeft)).ToString();
                if (countdown.text != text)
                {
                    countdown.text = text;
                    Sfx.Play("countdown_tick");
                }
            }
            if (phaseLeft > 0f) return;
            switch (phase)
            {
                case Phase.Launching:
                    player.GrantInvincibility(rules.spawnInvincibility);
                    Enter(Phase.Playing);
                    break;
                case Phase.BossIntro:
                    Enter(Phase.Playing);
                    break;
                case Phase.PlayerDying:
                    FinishDeath();
                    break;
                case Phase.SelectingNext:
                    SelectNext(run.AutomaticChoice(roster.highlightedId));
                    break;
                case Phase.Clearing:
                    NextVictoryLine();
                    break;
            }
        }

        /// <summary>Godot call_deferred: runs at the end of this frame.</summary>
        void LateUpdate()
        {
            while (deferred.Count > 0)
            {
                var batch = deferred.ToArray();
                deferred.Clear();
                foreach (var action in batch) action();
            }
        }

        void Defer(Action action) => deferred.Add(action);

        void Enter(Phase nextPhase, float seconds = 0f)
        {
            if (nextPhase != Phase.Playing) powerUpMessage.Clear();
            if (nextPhase == Phase.PlayerDying || nextPhase == Phase.Clearing || nextPhase == Phase.Finished) CancelBomb();
            phase = nextPhase;
            phaseLeft = seconds;
            GamePause.Set(phase != Phase.Playing || userPaused);
            GameInput.ClearLatches();
            if (player != null)
                player.autoAdvanceSpeed = phase == Phase.Playing && boss == null && midEnemy == null && !bossWaitingToEnter ? scrollSpeed : 0f;
            sequencePanel.SetActive(false);
            nextPilotPanel.SetActive(phase == Phase.SelectingNext);
            // Cleared so the first second of every countdown also ticks.
            if (phase == Phase.SelectingNext) countdown.text = "";
            pauseDimmer.gameObject.SetActive(phase == Phase.PlayerDying || phase == Phase.SelectingNext || phase == Phase.Clearing || userPaused);
            roster.selectable = phase == Phase.SelectingNext;
            roster.Refresh();
            if (phase == Phase.Playing && bossWaitingToEnter) Defer(BeginBossIntro);
        }

        void LaunchCurrent()
        {
            CancelBomb();
            bombCooldownLeft = 0f;
            Enter(Phase.Launching, rules.launchSeconds);
            roster.showSurvivedStatus = false;
            roster.highlightedId = run.currentPilotId;
            roster.Refresh();
            var pilot = catalog.PilotById(run.currentPilotId);
            var spawn = new Vector3(progressX + rules.playfield.x - 80f, rules.spawnPosition.y, 0f);
            player = Instantiate(pilot.shipPrefab, spawn, pilot.shipPrefab.transform.rotation, actors);
            player.state = run.currentSortie;
            player.rules = rules;
            player.bounds = viewBounds;
            player.weapon.state = run.currentSortie;
            player.weapon.projectiles = projectiles;
            player.weapon.bounds = viewBounds;
            player.BombRequested += OnBombRequested;
            player.Died += PlayerDied;
            player.PowerUpCollected += ShowPowerUpMessage;
            foreach (Transform child in items)
            {
                var item = child.GetComponent<Pickup>();
                if (item != null) item.target = player;
            }
            ShowMessage("SORTIE / " + pilot.callsign, "대사 1", null);
            Sfx.Play("sortie");
        }

        void ShowPowerUpMessage()
        {
            if (phase != Phase.Playing || userPaused || player == null) return;
            // Keep the message above the persistent shield icon when it is equipped.
            float clearance = player.state.shield ? 50f : 0f;
            powerUpMessage.ShowAt(WorldToDesign(player.Position), DesignRect(rules.playfield), clearance);
        }

        Vector2 WorldToDesign(Vector2 world) => new Vector2(world.x - progressX, world.y + DesignHeight);

        void UpdateHud()
        {
            if (run == null || run.currentSortie == null) return;
            var pilot = catalog.PilotById(run.currentPilotId);
            if (pilot != null)
                combatHUD.Display(run.currentSortie, roster.PortraitFor(pilot), phase == Phase.Playing && !userPaused, CanUseBomb());
        }

        public Transform GetTarget() => player != null && !player.deathReported ? player.transform : null;

        void SpawnWaveEnemy(EnemyWave wave, int index)
        {
            float chance = 0f;
            if (wave.dropMode == EnemyWave.DropMode.Guaranteed) chance = 1f;
            else if (wave.dropMode == EnemyWave.DropMode.Chance) chance = wave.dropChance;
            var route = wave.Route;
            var offset = wave.spawnOffset * index;
            Vector2 location = (Vector2)wave.transform.position + offset;
            if (route != null && route.Length > 0f) location = route.SampleWorld(0f) + offset;
            SpawnEnemy(wave.enemyPrefab, location, wave.dropPrefab, chance, wave.movementProfile, wave.attackSequence, route, offset);
        }

        EnemyShip SpawnEnemy(EnemyShip prefab, Vector2 location, Pickup drop = null, float chance = 0f,
            MovementProfile movementProfile = null, AttackSequence attackSequence = null, PathRoute route = null, Vector2 pathOffset = default)
        {
            var enemy = Instantiate(prefab, new Vector3(location.x, location.y, 0f), prefab.transform.rotation, actors);
            if (movementProfile != null) enemy.movement.ApplyProfile(movementProfile);
            if (attackSequence != null) enemy.ApplyAttackSequence(attackSequence);
            if (route != null && route.Length > 0f) enemy.movement.UsePath(route, pathOffset);
            ConfigureEnemy(enemy, drop, chance);
            if (enemy.isMidboss)
            {
                ClearProjectiles(false);
                midEnemy = enemy;
                if (player != null) player.autoAdvanceSpeed = 0f;
            }
            return enemy;
        }

        void ActivatePlacedEnemy(EnemyShip enemy)
        {
            placedActivated += 1;
            enemy.transform.SetParent(actors, true);
            enemy.gameObject.SetActive(true);
            enemy.movement.origin = enemy.Position;
            ConfigureEnemy(enemy, enemy.dropPrefab, enemy.dropChance);
        }

        void ConfigureEnemy(EnemyShip enemy, Pickup drop, float chance)
        {
            enemy.bounds = viewBounds;
            enemy.movement.lastArenaX = viewBounds.x;
            enemy.dropPrefab = drop;
            enemy.dropChance = chance;
            enemy.Damaged += EnemyDamaged;
            enemy.Destroyed += EnemyDestroyed;
            var mode = enemy.movement.mode;
            if (mode == EnemyMovement.Mode.EnterHoldExit || mode == EnemyMovement.Mode.VerticalSweep || mode == EnemyMovement.Mode.StrafeExit)
            {
                // Encounters keep their authored local coordinates as the arena moves.
                enemy.movement.holdPosition += (Vector2)waveSequence.transform.localPosition + new Vector2(progressX, 0f);
            }
            if (enemy.shooter != null)
            {
                enemy.shooter.projectiles = projectiles;
                enemy.shooter.targetProvider = GetTarget;
                enemy.shooter.bounds = viewBounds;
            }
        }

        void RequestBossIntro()
        {
            bossWaitingToEnter = true;
            Defer(BeginBossIntro);
        }

        void BeginBossIntro()
        {
            if (phase != Phase.Playing || waveSequence.bossPrefab == null) return;
            if (pendingDeath.active || pendingBoss)
            {
                QueueResolution();
                return;
            }
            if (boss != null || run.bossCleared)
            {
                bossWaitingToEnter = false;
                return;
            }
            bossWaitingToEnter = false;
            ClearProjectiles(false);
            boss = SpawnEnemy(waveSequence.bossPrefab, waveSequence.BossMarker.position);
            Enter(Phase.BossIntro, bossIntroSeconds);
            Music.Play("boss");
            Sfx.Play("warning");
            ShowMessage("WARNING / BOSS", "대사 2", null);
        }

        void EnemyDamaged(EnemyShip enemy)
        {
            Sfx.Play("enemy_hit");
            var effect = SpawnEffect(enemy.Position, enemyHitPrefab, enemy.isBoss && enemy.hp <= 0f) as EnemyHitEffect;
            if (effect != null) effect.FitToEnemy(enemy);
        }

        void EnemyDestroyed(EnemyShip enemy)
        {
            defeated += 1;
            Sfx.Play(enemy.isMidboss || enemy.isBoss ? "large_enemy_destroyed" : enemy.destroyedCue);
            if (enemy == midEnemy)
            {
                midEnemy = null;
                ClearProjectiles(false);
                if (player != null && phase == Phase.Playing) player.autoAdvanceSpeed = scrollSpeed;
            }
            if (enemy.dropPrefab != null && UnityEngine.Random.value < enemy.dropChance)
            {
                // Trigger callbacks run inside the physics step; spawn after it.
                var drop = enemy.dropPrefab;
                var location = enemy.Position;
                Defer(() => SpawnPickup(drop, location));
            }
            if (enemy.isBoss)
            {
                pendingBoss = true;
                QueueResolution();
            }
        }

        void PlayerDied(Vector2 location, int recoveryPowerups, int recoveryBombs)
        {
            if (phase != Phase.Playing || pendingDeath.active) return;
            CancelBomb();
            pendingDeath = new PendingDeath
            {
                active = true,
                position = location,
                powerups = recoveryPowerups,
                bombs = recoveryBombs,
                pilot = run.currentPilotId,
            };
            QueueResolution();
        }

        void QueueResolution()
        {
            if (resolutionQueued) return;
            resolutionQueued = true;
            Defer(ResolveOutcome);
        }

        void ResolveOutcome()
        {
            resolutionQueued = false;
            if (phase != Phase.Playing) return;
            if (pendingBoss)
            {
                run.bossCleared = true;
                pendingBoss = false;
            }
            if (pendingDeath.active) StartDeath();
            else if (run.bossCleared) StartClear();
        }

        void StartDeath()
        {
            var location = pendingDeath.position;
            int powerups = pendingDeath.powerups;
            int bombs = pendingDeath.bombs;
            dyingPilotId = pendingDeath.pilot;
            pendingDeath = default;
            Enter(Phase.PlayerDying, rules.deathSeconds);
            Sfx.Play("player_destroyed");
            SpawnEffect(location, explosionPrefab, true);
            for (int i = 0; i < powerups; i++)
            {
                float row = i - (powerups - 1) * 0.5f;
                var pickup = SpawnPickup(recoveryPickup, location + new Vector2(-80f, -row * 56f));
                if (pickup != null) pickup.velocity = new Vector2(-65f, -row * 35f);
            }
            for (int i = 0; i < bombs; i++)
            {
                float row = i - (bombs - 1) * 0.5f;
                var pickup = SpawnPickup(recoveryBomb, location + new Vector2(80f, -row * 56f));
                if (pickup != null) pickup.velocity = new Vector2(65f, -row * 35f);
            }
            if (player != null) Destroy(player.gameObject);
            player = null;
            roster.Refresh();
            var pilot = catalog.PilotById(dyingPilotId);
            ShowMessage("SIGNAL LOST / " + pilot.displayName, pilot.deathLine, roster.PortraitFor(pilot));
        }

        void FinishDeath()
        {
            run.MarkDead(dyingPilotId);
            roster.Refresh();
            if (run.Survivors().Count == 0)
            {
                Finish();
            }
            else if (run.bossCleared)
            {
                StartClear();
            }
            else
            {
                Enter(Phase.SelectingNext, rules.selectionSeconds);
                roster.FocusFirst();
            }
        }

        public void SelectNext(string id)
        {
            if (phase != Phase.SelectingNext || !run.BeginSortie(id)) return;
            ClearProjectiles(false);
            LaunchCurrent();
        }

        void StartClear()
        {
            Music.Play("clear");
            Sfx.Play("stage_clear");
            Enter(Phase.Clearing, clearIntroSeconds);
            ClearProjectiles(true);
            roster.showSurvivedStatus = true;
            roster.Refresh();
            victoryIndex = -1;
            ShowMessage("SECTOR CLEAR", "대사 3", null);
        }

        void NextVictoryLine()
        {
            victoryIndex += 1;
            var survivors = run.Survivors();
            if (victoryIndex >= survivors.Count)
            {
                Finish();
                return;
            }
            var pilot = survivors[victoryIndex];
            phaseLeft = rules.victoryLineSeconds;
            string label = pilot.displayName == pilot.callsign ? pilot.displayName : pilot.displayName + " / " + pilot.callsign;
            // Other sequence messages arrive with their own cue (sortie, warning, death, clear).
            Sfx.Play("message_appear");
            ShowMessage(label, pilot.victoryLine, roster.PortraitFor(pilot));
        }

        void Finish()
        {
            Enter(Phase.Finished);
            run.endingId = EndingResolver.Resolve(run);
            Completed?.Invoke();
        }

        Pickup SpawnPickup(Pickup prefab, Vector2 location)
        {
            if (prefab == null) return null;
            var clamped = G.Clamp(location, viewBounds.min + new Vector2(25f, 25f), viewBounds.max - new Vector2(25f, 25f));
            var pickup = Instantiate(prefab, new Vector3(clamped.x, clamped.y, 0f), prefab.transform.rotation, items);
            pickup.bounds = viewBounds;
            pickup.target = player;
            return pickup;
        }

        public bool CanUseBomb() =>
            phase == Phase.Playing && !userPaused && !bombPending && bombCooldownLeft <= 0f && player != null &&
            !player.deathReported && run.currentSortie.hp > 0 && run.currentSortie.Bombs > 0;

        void OnBombRequested() => TryBomb();

        public bool TryBomb()
        {
            if (!CanUseBomb() || !run.currentSortie.SpendBomb()) return false;
            bombPending = true;
            bombDelayLeft = rules.bombActivationDelay;
            bombCooldownLeft = rules.bombCooldown;
            bombFlashFadeLeft = 0f;
            SetBombFlash(0.04f);
            if (bombDelayLeft <= 0f) DetonateBomb();
            UpdateHud();
            return true;
        }

        void AdvanceBomb(float delta)
        {
            bombCooldownLeft = Mathf.Max(0f, bombCooldownLeft - delta);
            if (G.IsZeroApprox(bombCooldownLeft)) bombCooldownLeft = 0f;
            if (!bombPending) return;
            if (player == null || player.deathReported)
            {
                CancelBomb();
                return;
            }
            bombDelayLeft = Mathf.Max(0f, bombDelayLeft - delta);
            SetBombFlash(Mathf.Lerp(0.04f, 0.14f, 1f - bombDelayLeft / Mathf.Max(rules.bombActivationDelay, 0.001f)));
            if (G.IsZeroApprox(bombDelayLeft)) DetonateBomb();
        }

        void CancelBomb()
        {
            bombPending = false;
            bombDelayLeft = 0f;
            bombFlashFadeLeft = 0f;
            SetBombFlash(0f);
        }

        void DetonateBomb()
        {
            if (!bombPending || player == null || player.deathReported)
            {
                CancelBomb();
                return;
            }
            bombPending = false;
            bombDelayLeft = 0f;
            player.GrantInvincibility(rules.bombInvincibility);
            Sfx.Play("bomb_detonate");
            foreach (Transform child in actors)
            {
                var enemy = child.GetComponent<EnemyShip>();
                if (enemy != null && G.HasPoint(viewBounds, enemy.Position)) enemy.TakeDamage(rules.bombDamage);
            }
            if (rules.bombClearsBullets) ClearProjectiles(false);
            // Godot tween with TWEEN_PAUSE_STOP: fades on scaled time.
            SetBombFlash(0.65f);
            bombFlashFadeFrom = 0.65f;
            bombFlashFadeLeft = 0.4f;
        }

        void UpdateBombFlashFade()
        {
            if (bombFlashFadeLeft <= 0f) return;
            bombFlashFadeLeft = Mathf.Max(0f, bombFlashFadeLeft - Time.deltaTime);
            SetBombFlash(bombFlashFadeFrom * (bombFlashFadeLeft / 0.4f));
        }

        void SetBombFlash(float alpha)
        {
            bombFlashAlpha = alpha;
            if (bombFlash == null) return;
            var color = bombFlashColor;
            color.a *= bombFlashAlpha;
            bombFlash.color = color;
        }

        void ClearProjectiles(bool includeFriendly)
        {
            foreach (Transform child in projectiles)
            {
                var bullet = child.GetComponent<Projectile>();
                if (bullet == null || (!includeFriendly && bullet.friendly)) continue;
                bullet.spent = true;
                bullet.Free();
            }
        }

        Component SpawnEffect(Vector2 location, Component prefab, bool presentation = false)
        {
            if (prefab == null) return null;
            var container = presentation ? presentationEffects : simulationEffects;
            var effect = Instantiate(prefab, new Vector3(location.x, location.y, 0f), prefab.transform.rotation, container);
            if (effect is OneShotEffect oneShot) oneShot.SetUnscaled(presentation);
            return effect;
        }

        void ShowMessage(string title, string message, Sprite portrait)
        {
            sequencePanel.SetActive(true);
            sequenceTitle.text = title;
            sequenceText.Reveal(message);
            sequencePortrait.sprite = portrait;
            sequencePortrait.gameObject.SetActive(portrait != null);
        }

        public void TogglePause()
        {
            if (phase != Phase.Playing) return;
            userPaused = !userPaused;
            Sfx.Play(userPaused ? "pause_open" : "pause_close");
            Music.SetPaused(userPaused);
            GamePause.Set(userPaused);
            GameInput.ClearLatches();
            pauseMenu.SetActive(userPaused);
            pauseDimmer.gameObject.SetActive(userPaused);
            if (userPaused && EventSystem.current != null) EventSystem.current.SetSelectedGameObject(resume.gameObject);
        }

        void SwitchWeapon()
        {
            if (phase != Phase.Playing || userPaused || player == null) return;
            player.weapon.SwitchWeapon();
        }
    }
}
