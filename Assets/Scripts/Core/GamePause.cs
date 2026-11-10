using UnityEngine;

namespace RetroSF
{
    /// <summary>
    /// Godot SceneTree.paused. Pausable simulation runs in FixedUpdate / scaled time and stops here;
    /// "Always" code reads unscaled time. Pausable sound effects stop through AudioListener.pause.
    /// </summary>
    public static class GamePause
    {
        public static bool Paused { get; private set; }

        public static void Set(bool paused)
        {
            Paused = paused;
            Time.timeScale = paused ? 0f : 1f;
            AudioListener.pause = paused;
        }
    }

    public static class Layers
    {
        public const int Player = 6;
        public const int Enemy = 7;
        public const int PlayerBullet = 8;
        public const int EnemyBullet = 9;
        public const int Item = 10;
    }
}
