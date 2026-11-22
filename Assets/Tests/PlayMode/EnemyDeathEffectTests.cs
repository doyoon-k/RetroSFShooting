using System.Collections;
using System.Linq;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;

namespace RetroSF.Tests
{
    /// <summary>A shot-down enemy bursts with the artist's death effect, which pauses with the game and then goes away.</summary>
    public class EnemyDeathEffectTests
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
        public IEnumerator ShotDownEnemyBurstsAtItsBodyCenterThenTheBurstEnds()
        {
            SceneManager.LoadScene("StageTest");
            yield return null;
            var stage = Object.FindAnyObjectByType<StageController>();
            Assert.IsNotNull(stage.enemyDeathPrefab, "the stage has an enemy death effect");
            yield return new WaitForSecondsRealtime(stage.catalog.rules.launchSeconds + 0.3f);

            EnemyShip enemy = null;
            for (float waited = 0f; enemy == null && waited < 10f; waited += Time.unscaledDeltaTime)
            {
                stage.player.invincibility = 10f;
                yield return null;
                enemy = stage.actors.GetComponentsInChildren<EnemyShip>()
                    .FirstOrDefault(e => e.hp > 0f && !e.dying && !e.isBoss && !e.isMidboss);
            }
            Assert.IsNotNull(enemy, "waves spawn an enemy to shoot down");

            var effects = stage.transform.Find("Simulation/Effects");
            Vector2 center = enemy.BodyCenter;
            enemy.TakeDamage(enemy.maximumHp);
            var burst = effects.GetComponentsInChildren<OneShotEffect>()
                .Where(e => e.name.StartsWith(stage.enemyDeathPrefab.name))
                .OrderBy(e => Vector2.Distance(e.Center, center))
                .FirstOrDefault();
            Assert.IsNotNull(burst, "the death effect spawns when the enemy is shot down");
            Assert.AreEqual(0f, Vector2.Distance(burst.Center, center), 0.001f, "the middle of its art lands on the body center");
            Assert.AreEqual(stage.enemyDeathPrefab.transform.localScale, burst.transform.localScale, "it keeps the prefab's own size");

            GamePause.Set(true);
            yield return new WaitForSecondsRealtime(0.8f);
            Assert.IsTrue(burst != null, "the effect waits while the game is paused");
            GamePause.Set(false);

            yield return new WaitForSeconds(0.8f);
            Assert.IsTrue(burst == null, "the effect removes itself once its clip ends");
        }
    }
}
