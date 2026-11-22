using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;

namespace RetroSF.Tests
{
    /// <summary>
    /// Large enemies break up in a chain of death bursts deep in their body before they go; the boss's chain ends
    /// before SECTOR CLEAR, and its phase change shows damage bursts before the second phase starts. Chains burst
    /// at most three times a second.
    /// </summary>
    public class LargeEnemyBreakUpTests
    {
        const BindingFlags Private = BindingFlags.Instance | BindingFlags.NonPublic;
        /// <summary>A random burst lies at least this share of the body's greatest depth inside its outline.</summary>
        const float RandomDepthShare = 0.25f;
        /// <summary>A chain's last burst lies at the thickest part of the body.</summary>
        const float CoreDepthShare = 0.6f;

        struct Burst
        {
            public Vector2 point;
            public EnemyShip.BurstKind kind;
            public float time;
            public float depthShare;
            /// <summary>Inside the body's bounds at the moment it burst: a ship in its phase break keeps moving.</summary>
            public bool onBody;
            public Bounds body;
        }

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

        static IEnumerator StartStage(System.Action<StageController> ready)
        {
            SceneManager.LoadScene("StageTest");
            yield return null;
            var stage = Object.FindAnyObjectByType<StageController>();
            yield return new WaitForSecondsRealtime(stage.catalog.rules.launchSeconds + 0.3f);
            Assert.AreEqual(StageController.Phase.Playing, stage.phase);
            ready(stage);
        }

        static IEnumerator SummonBoss(StageController stage)
        {
            typeof(StageController).GetMethod("BeginBossIntro", Private).Invoke(stage, null);
            Assert.IsNotNull(stage.boss, "the boss spawned");
            while (stage.phase != StageController.Phase.Playing)
            {
                stage.player.invincibility = 10f;
                yield return null;
            }
        }

        /// <summary>Records every burst with its time and how deep in the body (as a share of the deepest point) it lies.</summary>
        static List<Burst> Record(EnemyShip enemy)
        {
            var body = EnemyShip.BodyMesh.Of(enemy.visual);
            float deepest = 0f;
            for (int i = 0; i < 2000; i++) deepest = Mathf.Max(deepest, body.Depth(body.Sample()));
            var bursts = new List<Burst>();
            enemy.BurstRequested += (ship, point, kind) =>
            {
                Vector2 local = ship.visual.transform.InverseTransformPoint(point);
                var bounds = ship.visual.bounds;
                bounds.Expand(0.02f);
                bursts.Add(new Burst
                {
                    point = point, kind = kind, time = Time.time, depthShare = body.Depth(local) / deepest,
                    onBody = bounds.Contains(new Vector3(point.x, point.y, bounds.center.z)), body = bounds,
                });
            };
            return bursts;
        }

        /// <summary>
        /// The chain bursts evenly at 1/3 s or slower, and its finale bursts together with the last one; every burst
        /// is on the body and, apart from the core burst, well inside it.
        /// </summary>
        static void AssertChain(List<Burst> bursts, EnemyShip.BurstPattern pattern, int coreIndex = -1)
        {
            Assert.AreEqual(pattern.Total, bursts.Count);
            for (int i = 1; i < pattern.count; i++)
                Assert.GreaterOrEqual(bursts[i].time - bursts[i - 1].time, EnemyShip.MinimumBurstSpacing - 0.001f,
                    $"bursts {i - 1} and {i} come {bursts[i].time - bursts[i - 1].time:F3} s apart");
            for (int i = pattern.count; i < bursts.Count; i++)
                Assert.AreEqual(bursts[pattern.count - 1].time, bursts[i].time, 0.001f, "the finale bursts with the last one");
            foreach (var burst in bursts)
                Assert.IsTrue(burst.onBody, $"{burst.point} is on the body {burst.body}");
            for (int i = 0; i < bursts.Count; i++)
                if (i != coreIndex)
                    Assert.GreaterOrEqual(bursts[i].depthShare, RandomDepthShare, $"{bursts[i].point} is well inside the body, not on its edge");
            Assert.Greater(bursts.Select(b => b.point).Distinct().Count(), bursts.Count / 2, "the bursts spread over the body");
        }

        static IEnumerable<OneShotEffect> Effects(StageController stage, OneShotEffect prefab) =>
            stage.transform.Find("Simulation/Effects").GetComponentsInChildren<OneShotEffect>()
                .Where(e => e.name.StartsWith(prefab.name));

        static void AssertCenteredOn(StageController stage, OneShotEffect prefab, Vector2 point)
        {
            var effect = Effects(stage, prefab).OrderBy(e => Vector2.Distance(e.Center, point)).FirstOrDefault();
            Assert.IsNotNull(effect, "the stage plays " + prefab.name);
            Assert.AreEqual(0f, Vector2.Distance(effect.Center, point), 0.001f, "the middle of its art lands on the burst point");
        }

        [UnityTest]
        public IEnumerator BossBreaksUpInAChainBeforeTheSectorClears()
        {
            StageController stage = null;
            yield return StartStage(s => stage = s);
            yield return SummonBoss(stage);
            var boss = stage.boss;
            var bursts = Record(boss);
            Assert.Greater(boss.deathBursts.count, 1, "the boss breaks up in a chain");

            boss.TakeDamage(boss.maximumHp);
            float killedAt = Time.time;
            Assert.IsTrue(boss.dying);
            Assert.AreEqual(StageController.Phase.Playing, stage.phase, "the sector does not clear on the killing hit");
            Assert.AreEqual(0, stage.projectiles.GetComponentsInChildren<Projectile>().Count(p => !p.friendly && !p.spent),
                "the boss's bullets go with it");
            Assert.AreEqual(1, bursts.Count, "the first burst comes with the killing hit");
            AssertCenteredOn(stage, stage.enemyDeathPrefab, bursts[0].point);
            Assert.IsTrue(boss.DeathBlinking, "the body blinks through its death chain");

            // Watch the body: lit (blink tint or white flash) and plain in turn.
            var block = new MaterialPropertyBlock();
            var onsets = new List<float>();
            int tintBlinks = 0, whiteBlinks = 0;
            bool wasLit = false;
            while (boss.PendingBursts > 0 && Time.time - killedAt < boss.deathBursts.seconds + 1f)
            {
                stage.player.invincibility = 10f;
                yield return null;
                boss.visual.GetPropertyBlock(block);
                bool white = block.GetFloat("_FlashAmount") > 0.5f;
                bool tinted = block.GetColor("_Tint") == boss.deathBlinkTint;
                bool lit = white || tinted;
                if (lit && !wasLit)
                {
                    onsets.Add(Time.time);
                    if (white) whiteBlinks++;
                    else tintBlinks++;
                }
                wasLit = lit;
            }
            Assert.GreaterOrEqual(tintBlinks, boss.deathBursts.count / 2, "the body blinks in the death tint all along the chain");
            Assert.AreEqual(0, whiteBlinks, "the death chain blinks in its tint only, never white");
            foreach (float start in onsets)
                Assert.LessOrEqual(onsets.Count(t => t >= start && t < start + 1f), 3,
                    "no more than three blinks in any second (WCAG 2.3.1)");
            Assert.IsFalse(boss.DeathBlinking, "the blinking hands over to the death animation after the chain");
            Assert.IsTrue(bursts.All(b => b.kind == EnemyShip.BurstKind.Death));
            int core = boss.deathBursts.count - 1;
            AssertChain(bursts, boss.deathBursts, core);
            Assert.GreaterOrEqual(bursts[core].depthShare, CoreDepthShare, "the chain ends at the thickest part of the body");
            Assert.AreEqual(StageController.Phase.Playing, stage.phase, "the death animation still plays");

            while (boss != null && Time.time - killedAt < 8f) yield return null;
            float goneAt = Time.time;
            Assert.IsTrue(boss == null, "the boss goes once its death animation ends");
            Assert.AreEqual(StageController.Phase.Playing, stage.phase, "the last bursts play out before SECTOR CLEAR");
            while (stage.phase == StageController.Phase.Playing && Time.time - killedAt < 10f) yield return null;
            Assert.AreEqual(StageController.Phase.Clearing, stage.phase);
            Assert.AreEqual(stage.bossClearDelaySeconds, Time.time - goneAt, 0.2f, "SECTOR CLEAR follows after the delay");
            Assert.GreaterOrEqual(Time.time - killedAt,
                boss.deathBursts.seconds + boss.deathAnimationSeconds + stage.bossClearDelaySeconds - 0.05f,
                "SECTOR CLEAR waits for the whole death sequence");
        }

        [UnityTest]
        public IEnumerator BossPhaseChangeShowsDamageThenStartsTheSecondPhase()
        {
            StageController stage = null;
            yield return StartStage(s => stage = s);
            yield return SummonBoss(stage);
            var boss = stage.boss;
            var bursts = Record(boss);
            Assert.IsTrue(boss.HasPhases);
            Assert.IsTrue(boss.shooter.enabled, "the first phase is firing");

            boss.TakeDamage(Mathf.Ceil(boss.maximumHp * (1f - boss.phaseThreshold)) + 1f);
            Assert.IsTrue(boss.phaseTwo);
            Assert.IsTrue(boss.InPhaseBreak);
            Assert.IsFalse(boss.shooter.enabled, "the boss holds fire while it breaks");
            Assert.AreEqual(1, bursts.Count(b => b.kind == EnemyShip.BurstKind.Damage), "the first damage burst comes at once");
            AssertCenteredOn(stage, stage.enemyDamagePrefab, bursts[0].point);

            // The body flashes white with every damage burst.
            float start = Time.time;
            var block = new MaterialPropertyBlock();
            var onsets = new List<float>();
            bool wasWhite = false;
            while (boss.InPhaseBreak && Time.time - start < boss.phaseBreakHoldSeconds + 1f)
            {
                stage.player.invincibility = 10f;
                yield return null;
                boss.visual.GetPropertyBlock(block);
                bool white = block.GetFloat("_FlashAmount") > 0.5f;
                if (white && !wasWhite) onsets.Add(Time.time);
                wasWhite = white;
            }
            Assert.GreaterOrEqual(onsets.Count, boss.phaseBreakBursts.count / 2, "the breaking body flashes white with the damage bursts");
            foreach (float onset in onsets)
                Assert.LessOrEqual(onsets.Count(t => t >= onset && t < onset + 1f), 3,
                    "no more than three flashes in any second (WCAG 2.3.1)");
            Assert.GreaterOrEqual(Time.time - start, boss.phaseBreakHoldSeconds - 0.05f, "the break lasts its hold time");
            Assert.IsTrue(bursts.All(b => b.kind == EnemyShip.BurstKind.Damage));
            AssertChain(bursts, boss.phaseBreakBursts);
            Assert.IsFalse(boss.dying);
            Assert.IsTrue(boss.shooter.enabled, "the second phase starts firing");
        }

        [UnityTest]
        public IEnumerator MidbossBreaksUpInAShorterChainAndTheScrollWaitsForIt()
        {
            StageController stage = null;
            yield return StartStage(s => stage = s);
#if UNITY_EDITOR
            var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<EnemyShip>("Assets/Prefabs/enemies/m1_carapace.prefab");
            var bossPrefab = UnityEditor.AssetDatabase.LoadAssetAtPath<EnemyShip>("Assets/Prefabs/enemies/boss.prefab");
#else
            EnemyShip prefab = null, bossPrefab = null;
            Assert.Ignore("needs the editor to load the prefab");
#endif
            Assert.IsTrue(prefab.isMidboss);
            Assert.Greater(prefab.deathBursts.count, 1, "a midboss breaks up in a chain");
            Assert.Less(prefab.deathBursts.Total, bossPrefab.deathBursts.Total, "fewer bursts than the boss");
            Assert.Less(prefab.deathBursts.seconds, bossPrefab.deathBursts.seconds, "a shorter chain than the boss's");

            var spawn = typeof(StageController).GetMethod("SpawnEnemy", Private);
            var midboss = (EnemyShip)spawn.Invoke(stage, new object[]
                { prefab, stage.viewBounds.center + new Vector2(3f, 0f), null, 0f, null, null, null, Vector2.zero });
            Assert.AreSame(midboss, stage.midEnemy);
            yield return null;
            var bursts = Record(midboss);

            midboss.TakeDamage(midboss.maximumHp);
            float killedAt = Time.time;
            Assert.AreSame(midboss, stage.midEnemy, "the stage holds until the midboss is gone");
            Assert.AreEqual(0f, stage.player.autoAdvanceSpeed, "no scrolling yet");
            Assert.IsTrue(midboss.DeathBlinking, "a midboss blinks through its chain too");

            while (midboss != null && Time.time - killedAt < 6f)
            {
                stage.player.invincibility = 10f;
                yield return null;
            }
            Assert.IsTrue(midboss == null, "the midboss is removed after its chain and fade");
            Assert.GreaterOrEqual(Time.time - killedAt, prefab.deathBursts.seconds + EnemyShip.DeathFadeSeconds - 0.05f);
            int core = prefab.deathBursts.count - 1;
            AssertChain(bursts, prefab.deathBursts, core);
            Assert.GreaterOrEqual(bursts[core].depthShare, CoreDepthShare, "the chain ends at the thickest part of the body");
            Assert.IsNull(stage.midEnemy);
            Assert.AreEqual(stage.scrollSpeed, stage.player.autoAdvanceSpeed, "the scroll resumes");
        }
    }
}
