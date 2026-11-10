using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    /// <summary>
    /// Standalone playground for one enemy, movement, and attack combination.
    /// Open Assets/Scenes/EnemyLab.unity and press Play. The panel is drawn with IMGUI.
    /// </summary>
    public class EnemyLab : MonoBehaviour
    {
        static readonly Rect Bounds = G.FromGodotRect(48f, 100f, 1440f, 864f);
        static readonly Vector2 SpawnPosition = new Vector2(1300f, -532f);
        static readonly Vector2 PlayerStart = new Vector2(260f, -532f);

        public PlayerShip playerPrefab;
        public GameRules rules;
        public List<EnemyShip> enemyPrefabs = new List<EnemyShip>();
        public List<MovementProfile> movementPresets = new List<MovementProfile>();
        public List<AttackSequence> attackPresets = new List<AttackSequence>();
        public Transform actors;
        public Transform projectiles;
        public PathRoute route;

        [NonSerialized] public SortieState state;
        [NonSerialized] public PlayerShip player;
        bool autoRespawn = true;
        float respawnLeft = 0.7f;
        int enemyIndex, movementIndex, attackIndex, powerIndex;
        bool usePath;
        bool resetQueued;
        string status = "PLAYER";
        Vector2 scroll;

        void Start()
        {
            BuildRoute();
            SpawnPlayer();
            SpawnSample();
        }

        void Update()
        {
            int enemyCount = 0;
            foreach (Transform child in actors)
            {
                var enemy = child.GetComponent<EnemyShip>();
                if (enemy != null && !enemy.IsFreed) enemyCount += 1;
            }
            if (enemyCount == 0 && autoRespawn)
            {
                respawnLeft -= Time.deltaTime;
                if (respawnLeft <= 0f) SpawnSample();
            }
            else if (enemyCount > 0)
            {
                respawnLeft = 0.7f;
            }
            int hp = state != null ? state.hp : 0;
            status = $"PLAYER  HP {hp}/{rules.startingHp}  LV{(state != null ? state.CurrentPowerLevel() : 1)}\nENEMIES {enemyCount}    BULLETS {projectiles.childCount}";
        }

        void LateUpdate()
        {
            if (!resetQueued) return;
            resetQueued = false;
            if (player != null) Destroy(player.gameObject);
            SpawnPlayer();
        }

        void BuildRoute()
        {
            if (route == null) return;
            route.points = new List<Vector2>
            {
                Vector2.zero, new Vector2(-300f, 220f), new Vector2(-690f, -170f), new Vector2(-1390f, 0f),
            };
        }

        void SpawnPlayer()
        {
            if (playerPrefab == null) return;
            state = new SortieState(rules) { powerLevel = powerIndex + 1 };
            player = Instantiate(playerPrefab, new Vector3(PlayerStart.x, PlayerStart.y, 0f), playerPrefab.transform.rotation, actors);
            player.state = state;
            player.rules = rules;
            player.bounds = Bounds;
            player.weapon.state = state;
            player.weapon.projectiles = projectiles;
            player.weapon.bounds = Bounds;
            player.Died += (_, __, ___) => resetQueued = true;
        }

        void SetPower(int index)
        {
            powerIndex = index;
            if (state != null) state.powerLevel = index + 1;
        }

        public Transform GetTarget() => player != null && !player.deathReported ? player.transform : null;

        public EnemyShip SpawnSample()
        {
            ClearSample();
            if (enemyPrefabs.Count == 0) return null;
            var prefab = enemyPrefabs[enemyIndex];
            Vector2 position = usePath && route != null ? route.SampleWorld(0f) : SpawnPosition;
            var enemy = Instantiate(prefab, new Vector3(position.x, position.y, 0f), prefab.transform.rotation, actors);
            if (movementIndex > 0) enemy.movement.ApplyProfile(movementPresets[movementIndex - 1]);
            if (attackIndex > 0) enemy.ApplyAttackSequence(attackPresets[attackIndex - 1]);
            if (usePath && route != null) enemy.movement.UsePath(route, Vector2.zero);
            enemy.bounds = Bounds;
            if (enemy.shooter != null)
            {
                enemy.shooter.projectiles = projectiles;
                enemy.shooter.targetProvider = GetTarget;
                enemy.shooter.bounds = Bounds;
            }
            autoRespawn = true;
            respawnLeft = 0.7f;
            return enemy;
        }

        public void ClearSample()
        {
            autoRespawn = false;
            foreach (Transform child in actors)
            {
                var enemy = child.GetComponent<EnemyShip>();
                if (enemy != null) enemy.Free();
            }
            foreach (Transform child in projectiles) Destroy(child.gameObject);
        }

        static string Label(UnityEngine.Object asset) => asset != null ? asset.name : "(none)";

        void OnGUI()
        {
            GUILayout.BeginArea(new Rect(Screen.width - 330, 10, 320, Screen.height - 20), GUI.skin.box);
            scroll = GUILayout.BeginScrollView(scroll);
            GUILayout.Label("ENEMY LAB");
            enemyIndex = Picker("Enemy prefab", enemyIndex, enemyPrefabs.Count, i => Label(enemyPrefabs[i]));
            movementIndex = Picker("Movement preset", movementIndex, movementPresets.Count + 1,
                i => i == 0 ? "Prefab default" : Label(movementPresets[i - 1]));
            attackIndex = Picker("Attack sequence", attackIndex, attackPresets.Count + 1,
                i => i == 0 ? "Prefab default" : Label(attackPresets[i - 1]));
            usePath = GUILayout.Toggle(usePath, "Use sample path");
            int power = Picker("Player power", powerIndex, 3, i => "LV" + (i + 1));
            if (power != powerIndex) SetPower(power);
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("Spawn / Retry")) SpawnSample();
            if (GUILayout.Button("Clear")) ClearSample();
            GUILayout.EndHorizontal();
            GUILayout.Label(status);
            GUILayout.Label("WASD: move    J: shoot\nL: switch weapon\nEnemies respawn after leaving\nClear stops respawning\nPick a preset, then Spawn / Retry");
            GUILayout.EndScrollView();
            GUILayout.EndArea();
        }

        static int Picker(string title, int index, int count, Func<int, string> label)
        {
            GUILayout.Label(title);
            if (count <= 0) return 0;
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("<", GUILayout.Width(28))) index = (index - 1 + count) % count;
            GUILayout.Label(label(Mathf.Clamp(index, 0, count - 1)));
            if (GUILayout.Button(">", GUILayout.Width(28))) index = (index + 1) % count;
            GUILayout.EndHorizontal();
            return Mathf.Clamp(index, 0, count - 1);
        }
    }
}
