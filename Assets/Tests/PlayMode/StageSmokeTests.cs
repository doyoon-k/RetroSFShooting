using System.Collections;
using System.Linq;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;

namespace RetroSF.Tests
{
    /// <summary>
    /// Runs the real scenes for a few seconds. Any error or exception logged during the run fails the test.
    /// </summary>
    public class StageSmokeTests
    {
        [UnitySetUp]
        public IEnumerator ResetPause()
        {
            GamePause.Set(false);
            yield return null;
        }

        [UnityTearDown]
        public IEnumerator TearDown()
        {
            GamePause.Set(false);
            yield return null;
        }

        [UnityTest]
        public IEnumerator StageLaunchesAndScrolls()
        {
            SceneManager.LoadScene("StageTest");
            yield return null;
            var stage = Object.FindAnyObjectByType<StageController>();
            Assert.IsNotNull(stage, "StageTest has a StageController");
            Assert.AreEqual(StageController.Phase.Launching, stage.phase);
            yield return new WaitForSecondsRealtime(stage.catalog.rules.launchSeconds + 0.3f);
            Assert.AreEqual(StageController.Phase.Playing, stage.phase, "the launch ends in Playing");
            Assert.IsNotNull(stage.player, "the first pilot is in the arena");
            Assert.Greater(stage.player.invincibility, 0f, "spawn invincibility starts after the launch");
            float progress = stage.progressX;
            yield return new WaitForSeconds(2f);
            Assert.Greater(stage.progressX, progress + 300f, "the arena scrolls at about 180 px/s");
            Assert.Greater(stage.actors.GetComponentsInChildren<EnemyShip>().Length, 0, "waves spawn enemies");
        }

        [UnityTest]
        public IEnumerator PauseFreezesCombat()
        {
            SceneManager.LoadScene("StageTest");
            yield return null;
            var stage = Object.FindAnyObjectByType<StageController>();
            yield return new WaitForSecondsRealtime(stage.catalog.rules.launchSeconds + 0.3f);
            stage.TogglePause();
            Assert.IsTrue(GamePause.Paused);
            float progress = stage.progressX;
            yield return new WaitForSecondsRealtime(0.5f);
            Assert.AreEqual(progress, stage.progressX, 0.001f, "nothing advances while paused");
            stage.TogglePause();
            Assert.IsFalse(GamePause.Paused);
        }

        [UnityTest]
        public IEnumerator BombClearsEnemyBullets()
        {
            SceneManager.LoadScene("StageTest");
            yield return null;
            var stage = Object.FindAnyObjectByType<StageController>();
            yield return new WaitForSecondsRealtime(stage.catalog.rules.launchSeconds + 0.3f);
            // Keep the idle test pilot alive while enemies start shooting.
            stage.player.GrantInvincibility(999f);
            yield return new WaitForSeconds(6f);
            int bombs = stage.run.currentSortie.Bombs;
            Assert.IsTrue(stage.TryBomb(), "a fresh pilot can bomb");
            Assert.AreEqual(bombs - 1, stage.run.currentSortie.Bombs);
            Assert.IsFalse(stage.TryBomb(), "the cooldown blocks a second bomb");
            yield return new WaitForSeconds(stage.catalog.rules.bombActivationDelay + 0.1f);
            var hostile = stage.projectiles.GetComponentsInChildren<Projectile>().Where(p => !p.friendly && !p.IsFreed);
            Assert.AreEqual(0, hostile.Count(), "the detonation removes enemy bullets");
        }

        [UnityTest]
        public IEnumerator MainSceneShowsTitle()
        {
            SceneManager.LoadScene("Main");
            yield return null;
            yield return null;
            Assert.IsNotNull(Object.FindAnyObjectByType<TitleScreen>(), "GameFlow opens the title first");
        }
    }
}
