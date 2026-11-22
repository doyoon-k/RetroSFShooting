using System.Collections.Generic;
using NUnit.Framework;
using RetroSF.EditorTools;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

namespace RetroSF.Tests
{
    /// <summary>Effect prefabs follow the rules OneShotEffect relies on.</summary>
    public class EffectTests
    {
        [Test]
        public void OneShotEffectsDoNotLoop()
        {
            var looping = new List<string>();
            int effects = 0;
            foreach (var guid in AssetDatabase.FindAssets("t:Prefab", new[] { "Assets/Prefabs" }))
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                var effect = AssetDatabase.LoadAssetAtPath<OneShotEffect>(path);
                if (effect == null) continue;
                var controller = effect.GetComponent<Animator>().runtimeAnimatorController as AnimatorController;
                Assert.IsNotNull(controller, path + " has an Animator Controller");
                var clip = controller.layers[0].stateMachine.defaultState?.motion as AnimationClip;
                Assert.IsNotNull(clip, path + " has a clip in its default state");
                effects++;
                if (clip.isLooping) looping.Add($"{path} ({AssetDatabase.GetAssetPath(clip)})");
            }
            Assert.Greater(effects, 0, "the project has one-shot effects");
            Assert.IsEmpty(looping,
                "A OneShotEffect removes itself when its clip ends, so a looping clip never goes away. Turn Loop Time off on:\n" +
                string.Join("\n", looping));
        }

        [Test]
        public void LargeEnemiesBreakUpInChainsAndTheBossInTheLongest()
        {
            int boss = 0, longestMidboss = 0;
            foreach (var guid in AssetDatabase.FindAssets("t:Prefab", new[] { "Assets/Prefabs/enemies" }))
            {
                var enemy = AssetDatabase.LoadAssetAtPath<EnemyShip>(AssetDatabase.GUIDToAssetPath(guid));
                if (enemy == null) continue;
                if (enemy.isBoss) boss = Mathf.Max(boss, enemy.deathBursts.Total);
                else if (enemy.isMidboss)
                {
                    Assert.Greater(enemy.deathBursts.count, 1, enemy.name + " breaks up in a chain");
                    longestMidboss = Mathf.Max(longestMidboss, enemy.deathBursts.Total);
                }
            }
            Assert.Greater(boss, longestMidboss, "the boss breaks up in more bursts than any midboss");
        }

        [Test]
        public void AnchoredEffectsKnowWhereTheirArtIs()
        {
            int anchored = 0;
            foreach (var path in EffectAnchors.AnchoredEffectPaths())
            {
                var effect = AssetDatabase.LoadAssetAtPath<OneShotEffect>(path);
                Assert.IsTrue(EffectAnchors.TryMeasure(effect, out var center), path + " has frames to measure");
                Assert.AreEqual(0f, Vector2.Distance(center, effect.artCenter), 0.005f,
                    $"{path} has a stale Art Center ({effect.artCenter}, frames say {center}): run RetroSF > Measure Effect Anchors.");
                anchored++;
            }
            Assert.Greater(anchored, 0, "the burst effects are anchored to their art");
        }

        [Test]
        public void HitBurstIsTheSameSizeOnEveryEnemy()
        {
            var hitPrefab = AssetDatabase.LoadAssetAtPath<EnemyHitEffect>("Assets/Prefabs/gameplay/enemy_hit.prefab");
            var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
            try
            {
                int enemies = 0;
                foreach (var guid in AssetDatabase.FindAssets("t:Prefab", new[] { "Assets/Prefabs/enemies" }))
                {
                    var prefab = AssetDatabase.LoadAssetAtPath<EnemyShip>(AssetDatabase.GUIDToAssetPath(guid));
                    if (prefab == null) continue;
                    var enemy = (EnemyShip)PrefabUtility.InstantiatePrefab(prefab, scene);
                    var burst = (EnemyHitEffect)PrefabUtility.InstantiatePrefab(hitPrefab, scene);
                    burst.FitToEnemy(enemy);
                    Assert.AreEqual(hitPrefab.scale, burst.transform.lossyScale.x, 0.001f, prefab.name + " gets the zako-sized burst");
                    Assert.AreEqual(hitPrefab.scale, burst.transform.lossyScale.y, 0.001f, prefab.name + " gets the zako-sized burst");
                    enemies++;
                }
                Assert.Greater(enemies, 0);
            }
            finally
            {
                UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
            }
        }

        static float ClipSeconds(OneShotEffect effect)
        {
            var controller = (AnimatorController)effect.GetComponent<Animator>().runtimeAnimatorController;
            return ((AnimationClip)controller.layers[0].stateMachine.defaultState.motion).length;
        }

        [Test]
        public void BurstChainsFlashAtMostThreeTimesASecondAndPhaseTwoWaitsForTheDamage()
        {
            var stage = AssetDatabase.LoadAssetAtPath<GameObject>("Assets/Prefabs/gameplay/stage/stage_01.prefab")
                .GetComponentInChildren<StageController>(true);
            float damageSeconds = ClipSeconds(stage.enemyDamagePrefab);
            foreach (var guid in AssetDatabase.FindAssets("t:Prefab", new[] { "Assets/Prefabs/enemies" }))
            {
                var enemy = AssetDatabase.LoadAssetAtPath<EnemyShip>(AssetDatabase.GUIDToAssetPath(guid));
                if (enemy == null) continue;
                foreach (var (pattern, what) in new[] { (enemy.deathBursts, "death"), (enemy.phaseBreakBursts, "phase break") })
                    if (pattern.count > 1)
                        Assert.GreaterOrEqual(pattern.Spacing, EnemyShip.MinimumBurstSpacing,
                            $"{enemy.name} {what} bursts flash the body every {pattern.Spacing:F2} s; keep it at 1/3 s or slower (WCAG 2.3.1).");
                if (enemy.HasPhases)
                    Assert.GreaterOrEqual(enemy.phaseBreakHoldSeconds, enemy.phaseBreakBursts.seconds + damageSeconds - 0.01f,
                        $"{enemy.name} starts its second phase before the last damage effect has played out.");
            }
        }
    }
}
