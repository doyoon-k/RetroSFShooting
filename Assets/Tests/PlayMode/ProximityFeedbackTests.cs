using System.Collections;
using System.Linq;
using NUnit.Framework;
using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;

namespace RetroSF.Tests
{
    public class ProximityFeedbackTests
    {
        StageController stage;
        ProximityFeedbackStyle style;

        [UnitySetUp]
        public IEnumerator SetUp()
        {
            GamePause.Set(false);
            SceneManager.LoadScene("StageTest");
            yield return null;
            stage = Object.FindAnyObjectByType<StageController>();
            yield return new WaitForSecondsRealtime(stage.catalog.rules.launchSeconds + 0.3f);
            stage.enabled = false;
            stage.player.enabled = false;
            stage.player.weapon.enabled = false;
            stage.player.GrantInvincibility(999f);
            stage.player.Position = new Vector2(9f, -5.3f);
            style = Object.Instantiate(stage.player.weapon.proximityFeedback);
            stage.player.weapon.proximityFeedback = style;
        }

        [UnityTearDown]
        public IEnumerator TearDown()
        {
            GamePause.Set(false);
            if (style != null) Object.Destroy(style);
            yield return null;
        }

        EnemyShip MakeEnemy()
        {
            var source = stage.placedEnemies.GetComponentsInChildren<EnemyShip>(true).First();
            var enemy = Object.Instantiate(source, stage.actors);
            enemy.gameObject.SetActive(true);
            enemy.enabled = true;
            enemy.hp = 100f;
            enemy.maximumHp = 100;
            enemy.bounds = stage.viewBounds;
            enemy.movement.enabled = false;
            if (enemy.shooter != null) enemy.shooter.enabled = false;
            foreach (var part in enemy.GetComponentsInChildren<Transform>(true)) part.gameObject.layer = Layers.Enemy;
            foreach (var renderer in enemy.GetComponentsInChildren<SpriteRenderer>(true)) renderer.enabled = true;
            foreach (var collider in enemy.GetComponentsInChildren<Collider2D>()) collider.enabled = true;
            return enemy;
        }

        [UnityTest]
        public IEnumerator FiredShotsApplyFourStepsAndRenderTheSharedNumericFont()
        {
            int firstFrame = Time.frameCount;
            foreach (var entry in new[] { new Vector2(4f, 1), new Vector2(2.4f, 2), new Vector2(1.2f, 3), new Vector2(0.6f, 4) })
            {
                var enemy = MakeEnemy();
                stage.player.weapon.Fire();
                var shots = stage.projectiles.GetComponentsInChildren<Projectile>().Where(p => p.friendly && !p.IsFreed).ToArray();
                var bullet = shots[0];
                foreach (var extra in shots.Skip(1)) extra.Free();
                Vector2 origin = bullet.damageOrigin;
                Physics2D.SyncTransforms();
                float radius = enemy.GetComponentInChildren<Collider2D>().bounds.extents.x;
                enemy.Position = origin + new Vector2(entry.x + radius, 0f);
                Physics2D.SyncTransforms();
                float deadline = Time.realtimeSinceStartup + 2f;
                while (enemy.hp == 100f && Time.realtimeSinceStartup < deadline) yield return new WaitForFixedUpdate();
                Assert.AreEqual(entry.y, 100f - enemy.hp, 0.001f, "actual Area2D-equivalent collision applies the integer step");
                var feedback = enemy.DamageFeedback;
                Assert.IsNotNull(feedback);
                Assert.AreEqual("x" + (int)entry.y, feedback.Label.text);
                var hudFont = stage.combatHUD.GetComponentsInChildren<TextMeshProUGUI>(true).First(t => t.text.StartsWith("LV")).font;
                Assert.AreSame(hudFont, feedback.Label.font);
                Assert.AreEqual(style.ColorFor((int)entry.y), feedback.Label.color);
                Assert.AreEqual(origin, bullet != null ? bullet.damageOrigin : origin);
                stage.player.weapon.enabled = true;
                stage.player.weapon.Fire();
                foreach (var spare in stage.projectiles.GetComponentsInChildren<Projectile>().Where(p => p.friendly)) spare.Free();
                yield return ScreenCaptureTests.Capture("05_proximity_x" + (int)entry.y);
                stage.player.weapon.enabled = false;
                Object.Destroy(enemy.gameObject);
                Object.Destroy(feedback.gameObject);
                yield return null;
            }
            Assert.Greater(Time.frameCount, firstFrame, "the test advances real rendered frames");
        }

        [UnityTest]
        public IEnumerator LabelReusesTracksPausesAndSurvivesTheKillingHit()
        {
            var enemy = MakeEnemy();
            enemy.Position = stage.viewBounds.center;
            style.x3Color = Color.magenta;
            enemy.TakeProjectileDamage(1, 3, style, enemy.Position);
            var feedback = enemy.DamageFeedback;
            Assert.AreEqual(Color.magenta, feedback.Label.color);
            enemy.TakeProjectileDamage(1, 3, style, enemy.Position);
            Assert.AreSame(feedback, enemy.DamageFeedback, "successive pellets share a single label");
            enemy.TakeProjectileDamage(1, 4, style, enemy.Position);
            Assert.AreSame(feedback, enemy.DamageFeedback);
            Assert.AreEqual("x4", feedback.Label.text);
            Vector3 before = feedback.transform.position;
            enemy.Position += new Vector2(0.3f, 0.2f);
            yield return null;
            Assert.Less(Vector3.Distance(before + new Vector3(0.3f, 0.2f), feedback.transform.position), 0.0001f);
            GamePause.Set(true);
            float left = feedback.TimeLeft;
            yield return new WaitForSecondsRealtime(0.15f);
            Assert.AreEqual(left, feedback.TimeLeft, "pause freezes feedback timers");
            GamePause.Set(false);
            float hp = enemy.hp;
            enemy.TakeDamage(10);
            Assert.AreEqual(hp - 10f, enemy.hp, "direct/bomb damage is never multiplied");
            Assert.AreEqual(1, enemy.LastHitMultiplier);
            Assert.AreEqual(left, feedback.TimeLeft, "direct damage does not refresh a shot label");
            enemy.TakeProjectileDamage(100, 4, style, enemy.Position);
            yield return null;
            Assert.IsTrue(enemy == null, "the enemy is removed");
            Assert.IsTrue(feedback != null, "the killing-hit label remains");
            yield return new WaitForSeconds(style.duration + 0.1f);
            Assert.IsTrue(feedback == null, "detached feedback expires");
        }
    }
}
