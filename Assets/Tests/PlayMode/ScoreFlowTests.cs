using System.Collections;
using System.Linq;
using NUnit.Framework;
using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;

namespace RetroSF.Tests
{
    /// <summary>Kills in the real stage add to the run score, and the HUD shows it.</summary>
    public class ScoreFlowTests
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

        static EnemyShip[] LiveSmallEnemies(StageController stage) => stage.actors.GetComponentsInChildren<EnemyShip>()
            .Where(e => e.hp > 0f && !e.dying && !e.isBoss && !e.isMidboss).ToArray();

        [UnityTest]
        public IEnumerator KillsScoreTimesTheKillingHitsMultiplier()
        {
            SceneManager.LoadScene("StageTest");
            yield return null;
            var stage = Object.FindAnyObjectByType<StageController>();
            yield return new WaitForSecondsRealtime(stage.catalog.rules.launchSeconds + 0.3f);
            Assert.AreEqual(StageController.Phase.Playing, stage.phase);
            Assert.AreEqual(0, stage.run.score, "a run starts at zero");
            var label = stage.combatHUD.GetComponentsInChildren<TextMeshProUGUI>(true).Single(t => t.name == "Score");
            Assert.AreEqual("0", label.text);

            EnemyShip[] enemies = LiveSmallEnemies(stage);
            for (float waited = 0f; enemies.Length < 2 && waited < 10f; waited += Time.unscaledDeltaTime)
            {
                stage.player.invincibility = 10f;
                yield return null;
                enemies = LiveSmallEnemies(stage);
            }
            Assert.GreaterOrEqual(enemies.Length, 2, "waves spawn enemies to shoot");

            var shot = enemies[0];
            var bombed = enemies[1];
            int before = stage.run.score;
            shot.TakeProjectileDamage(shot.maximumHp, 3, null, shot.Position);
            bombed.TakeDamage(bombed.maximumHp);
            Assert.AreEqual(before + shot.scoreValue * 3 + bombed.scoreValue, stage.run.score,
                "a x3 kill scores three times the enemy's points; a bomb kill scores them once");

            yield return null;
            Assert.AreEqual(CombatHUD.FormatScore(stage.run.score), label.text, "the HUD shows the run score");
        }

        /// <summary>Screen-space ink box (1920x1080, y down) of the label's visible glyphs.</summary>
        static Rect InkRect(TextMeshProUGUI label, RectTransform hud)
        {
            label.ForceMeshUpdate();
            float left = float.MaxValue, right = float.MinValue, top = float.MaxValue, bottom = float.MinValue;
            var info = label.textInfo;
            for (int i = 0; i < info.characterCount; i++)
            {
                var character = info.characterInfo[i];
                if (!character.isVisible) continue;
                // Ink box from the glyph metrics; the character quads carry SDF padding.
                var metrics = character.textElement.glyph.metrics;
                float inkLeft = character.origin + metrics.horizontalBearingX * character.scale;
                float inkTop = character.baseLine + metrics.horizontalBearingY * character.scale;
                Vector3 topLeft = hud.InverseTransformPoint(label.transform.TransformPoint(new Vector3(inkLeft, inkTop)));
                Vector3 bottomRight = hud.InverseTransformPoint(label.transform.TransformPoint(
                    new Vector3(inkLeft + metrics.width * character.scale, inkTop - metrics.height * character.scale)));
                left = Mathf.Min(left, topLeft.x);
                right = Mathf.Max(right, bottomRight.x);
                top = Mathf.Min(top, -topLeft.y);
                bottom = Mathf.Max(bottom, -bottomRight.y);
            }
            return Rect.MinMaxRect(left, top, right, bottom);
        }

        /// <summary>
        /// The score uses the HUD's Stadium font at 42, right-aligned to where the art reference ends its digits
        /// (x 1810), with equal gaps above and below inside the score box. Seven digits shrink to stay in the box.
        /// </summary>
        [UnityTest]
        public IEnumerator ScoreUsesTheHudFontCenteredInTheScoreBox()
        {
            SceneManager.LoadScene("StageTest");
            yield return null;
            var stage = Object.FindAnyObjectByType<StageController>();
            yield return new WaitForSecondsRealtime(stage.catalog.rules.launchSeconds + 0.3f);
            stage.player.invincibility = 10f;
            var labels = stage.combatHUD.GetComponentsInChildren<TextMeshProUGUI>(true);
            var label = labels.Single(t => t.name == "Score");
            Assert.AreEqual(labels.Single(t => t.name == "WeaponLevel").font, label.font, "the score uses the HUD font");

            // The HUD root is the 1920x1080 screen with its pivot at the top-left, so screen y = -local y.
            var hud = (RectTransform)stage.combatHUD.transform;
            Assert.AreEqual(new Vector2(0f, 1f), hud.pivot);
            var corners = new Vector3[4];
            ((RectTransform)label.transform.parent).GetWorldCorners(corners);
            Vector3 boxBottomLeft = hud.InverseTransformPoint(corners[0]);
            Vector3 boxTopRight = hud.InverseTransformPoint(corners[2]);
            var box = Rect.MinMaxRect(boxBottomLeft.x, -boxTopRight.y, boxTopRight.x, -boxBottomLeft.y);

            stage.run.score = 23000;
            yield return null;
            Assert.AreEqual("23000", label.text);
            var ink = InkRect(label, hud);
            Assert.AreEqual(1810f, ink.xMax, 2f, "right edge of the last 0");
            Assert.AreEqual(ink.yMin - box.yMin, box.yMax - ink.yMax, 1f, $"equal gaps above and below the digits in {box}");
            Assert.AreEqual(42f, ink.height, 1f, "digit height");

            stage.run.score = 9999999;
            yield return null;
            ink = InkRect(label, hud);
            Assert.GreaterOrEqual(ink.xMin, box.xMin + 6f, "seven digits stay inside the score box");
            Assert.AreEqual(1810f, ink.xMax, 2f);
            Assert.AreEqual(ink.yMin - box.yMin, box.yMax - ink.yMax, 1f, "still centered");
        }
    }
}
