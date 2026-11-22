using System.IO;
using NUnit.Framework;
using RetroSF.EditorTools;
using UnityEditor;
using UnityEngine;

namespace RetroSF.Tests
{
    /// <summary>Score rules, the saved high score, and the battle frame that holds the score box.</summary>
    public class ScoreTests
    {
        string savePath;

        [SetUp]
        public void SetUp() => savePath = Path.Combine(Path.GetTempPath(), "retrosf_score_test_" + System.Guid.NewGuid().ToString("N") + ".json");

        [TearDown]
        public void TearDown()
        {
            foreach (var path in new[] { savePath, savePath + ".tmp" })
                if (File.Exists(path)) File.Delete(path);
        }

        static GameCatalog Catalog()
        {
            var catalog = AssetDatabase.LoadAssetAtPath<GameCatalog>("Assets/Data/game_catalog.asset");
            Assert.IsNotNull(catalog, "the game catalog asset exists");
            return catalog;
        }

        [Test]
        public void ScoreShowsPlainDigits()
        {
            Assert.AreEqual("0", CombatHUD.FormatScore(0));
            Assert.AreEqual("23000", CombatHUD.FormatScore(23000));
            Assert.AreEqual("123456789", CombatHUD.FormatScore(123456789));
            Assert.AreEqual("0", CombatHUD.FormatScore(-5));
        }

        [Test]
        public void ClearBonusCountsOnlyLivingPilots()
        {
            var catalog = Catalog();
            var run = new RunState(catalog);
            int perPilot = catalog.rules.clearBonusPerSurvivor;
            Assert.Greater(perPilot, 0);
            Assert.AreEqual(catalog.pilots.Count * perPilot, run.ClearBonus());
            run.MarkDead(catalog.pilots[0].id);
            Assert.AreEqual((catalog.pilots.Count - 1) * perPilot, run.ClearBonus());
        }

        [Test]
        public void EveryEnemyIsWorthPointsAndBiggerOnesWorthMore()
        {
            int Score(string name) => AssetDatabase.LoadAssetAtPath<EnemyShip>($"Assets/Prefabs/enemies/{name}.prefab").scoreValue;
            foreach (var guid in AssetDatabase.FindAssets("t:Prefab", new[] { "Assets/Prefabs/enemies" }))
            {
                var enemy = AssetDatabase.LoadAssetAtPath<EnemyShip>(AssetDatabase.GUIDToAssetPath(guid));
                if (enemy != null) Assert.Greater(enemy.scoreValue, 0, enemy.name);
            }
            Assert.Greater(Score("n1_interceptor"), Score("z1_wedge"), "an n-series enemy outscores a zako");
            Assert.Greater(Score("m1_carapace"), Score("n4_armor"), "a midboss outscores an n-series enemy");
            Assert.Greater(Score("boss"), Score("m3_star_eye"), "the boss outscores a midboss");
        }

        [Test]
        public void HighScoreSurvivesReloadAndOnlyRises()
        {
            var store = new SaveStore(savePath);
            Assert.IsTrue(store.LoadProgress());
            Assert.AreEqual(0, store.HighScore);
            Assert.IsTrue(store.RecordRun("new_home", 52300));
            Assert.IsTrue(store.RecordRun("new_home", 1200), "a lower score still records its ending");

            var reloaded = new SaveStore(savePath);
            Assert.IsTrue(reloaded.LoadProgress());
            Assert.AreEqual(52300, reloaded.HighScore);
            CollectionAssert.AreEqual(new[] { "new_home" }, reloaded.Unlocked);
        }

        [Test]
        public void SaveWithoutHighScoreStillLoads()
        {
            File.WriteAllText(savePath, "{\"version\":1,\"endings\":[\"new_home\"]}");
            var store = new SaveStore(savePath);
            Assert.IsTrue(store.LoadProgress(), "a save from before the score system is still readable");
            Assert.AreEqual(0, store.HighScore);
            CollectionAssert.AreEqual(new[] { "new_home" }, store.Unlocked);
        }

        [Test]
        public void BattleFrameIsBakedFromTheCurrentArt()
        {
            var source = BattleFrameBaker.LoadUnimported(BattleFrameBaker.SourcePath);
            var baked = BattleFrameBaker.LoadUnimported(BattleFrameBaker.BakedPath);
            try
            {
                Assert.AreEqual(source.width, baked.width);
                Assert.AreEqual(source.height, baked.height);
                var expected = BattleFrameBaker.Key(source.GetPixels32(), source.width, source.height);
                var actual = baked.GetPixels32();
                int wrong = 0;
                for (int i = 0; i < expected.Length; i++)
                {
                    var e = expected[i];
                    var a = actual[i];
                    // Image editors may rewrite the color of fully transparent pixels; only alpha matters there.
                    bool same = e.a == a.a && (e.a == 0 || (e.r == a.r && e.g == a.g && e.b == a.b));
                    if (!same) wrong++;
                }
                Assert.AreEqual(0, wrong, $"{BattleFrameBaker.BakedPath} is stale: run RetroSF > Bake Battle Frame after editing {BattleFrameBaker.SourcePath}.");
            }
            finally
            {
                Object.DestroyImmediate(source);
                Object.DestroyImmediate(baked);
            }
        }
    }
}
