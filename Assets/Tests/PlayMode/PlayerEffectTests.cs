using System.Collections;
using System.Linq;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;

namespace RetroSF.Tests
{
    public class PlayerEffectTests
    {
        StageController stage;
        PlayerShip player;

        GameObject[] Effects => player.transform.Cast<Transform>()
            .Where(child => child.gameObject.activeSelf &&
                (child.name.StartsWith(player.shieldEffectPrefab.name) || child.name.StartsWith(player.powerDownEffect.name)))
            .Select(child => child.gameObject).ToArray();

        [UnitySetUp]
        public IEnumerator LaunchStage()
        {
            GamePause.Set(false);
            SceneManager.LoadScene("StageTest");
            yield return null;
            stage = Object.FindAnyObjectByType<StageController>();
            yield return new WaitForSecondsRealtime(stage.catalog.rules.launchSeconds + 0.3f);
            player = stage.player;
            Assert.IsNotNull(player.shieldEffectPrefab, "the playable ship has a shield effect assigned");
            Assert.IsNotNull(player.powerDownEffect, "the playable ship has a power-down effect assigned");
            player.invincibility = 0f;
        }

        [UnityTearDown]
        public IEnumerator RestorePause()
        {
            GamePause.Set(false);
            yield return null;
        }

        [UnityTest]
        public IEnumerator ShieldLoopsFollowsShipAndStopsWhenConsumed()
        {
            player.Collect(Pickup.Kind.Shield);
            Assert.IsTrue(player.state.shield);
            var effect = Effects.Single();
            Assert.IsTrue(effect.name.StartsWith(player.shieldEffectPrefab.name));
            Assert.Greater(effect.GetComponent<SpriteRenderer>().bounds.size.x, 1f,
                "the effect is over 100 px (1 unit) wide");

            player.Collect(Pickup.Kind.Shield);
            Assert.AreSame(effect, Effects.Single(), "another pickup doesn't duplicate or restart the shield");
            player.Position += new Vector2(0.8f, -0.3f);
            Assert.Less(Vector3.Distance(player.transform.position, effect.transform.position), 0.00001f,
                "the shield stays centered on the moving ship");

            player.GrantInvincibility(999f);

            yield return new WaitForSeconds(0.1f);
            var animator = effect.GetComponent<Animator>();
            stage.TogglePause();
            // Let the frame that requested the pause finish before sampling the Animator.
            yield return null;
            float pausedTime = animator.GetCurrentAnimatorStateInfo(0).normalizedTime;
            yield return new WaitForSecondsRealtime(0.2f);
            Assert.IsTrue(effect != null, "pausing doesn't discard the effect");
            Assert.AreEqual(pausedTime, animator.GetCurrentAnimatorStateInfo(0).normalizedTime, 0.001f,
                "the effect freezes with combat");
            stage.TogglePause();
            yield return new WaitForSeconds(1.5f);
            Assert.AreSame(effect, Effects.Single(), "the shield remains beyond its first animation cycle");
            var animation = animator.GetCurrentAnimatorStateInfo(0);
            Assert.IsTrue(animation.loop, "the shield animation repeats");
            Assert.Greater(animation.normalizedTime, 2f, "the animation advances through multiple cycles");

            int hp = player.state.hp;
            player.invincibility = 0f;
            player.TakeDamage();
            Assert.IsFalse(player.state.shield);
            Assert.AreEqual(hp, player.state.hp, "the shield still absorbs damage");
            Assert.IsFalse(effect.activeSelf, "the visual disappears as soon as the shield is consumed");
            yield return null;
            Assert.IsTrue(effect == null, "the consumed shield visual is destroyed");
            Assert.AreEqual(0, Effects.Length);

            player.Collect(Pickup.Kind.Shield);
            Assert.AreEqual(1, Effects.Length, "a later pickup creates a new shield visual");
        }

        [UnityTest]
        public IEnumerator DamageRequiresAnActualNonfatalPowerLoss()
        {
            player.state.powerLevel = 3;
            player.state.shield = true;
            int hp = player.state.hp;
            player.TakeDamage();
            Assert.AreEqual(hp, player.state.hp);
            Assert.AreEqual(3, player.state.powerLevel);
            Assert.IsFalse(player.state.shield);
            Assert.AreEqual(0, Effects.Length, "shield absorption doesn't play a power-down burst");

            player.TakeDamage();
            Assert.AreEqual(hp, player.state.hp, "hit invincibility rejects the next hit");
            Assert.AreEqual(0, Effects.Length);

            player.invincibility = 0f;
            stage.TogglePause();
            player.TakeDamage();
            Assert.AreEqual(3, player.state.powerLevel, "paused hits don't change power");
            Assert.AreEqual(0, Effects.Length);
            stage.TogglePause();

            player.state.powerLevel = 1;
            player.TakeDamage();
            Assert.AreEqual(1, player.state.powerLevel);
            Assert.AreEqual(0, Effects.Length, "level one cannot lose power");

            player.invincibility = 0f;
            player.state.powerLevel = 3;
            player.TakeDamage(10);
            Assert.AreEqual(0, player.state.hp);
            Assert.IsTrue(player.deathReported);
            Assert.AreEqual(0, Effects.Length, "a fatal hit uses the death presentation");
            yield return null;
        }

        [UnityTest]
        public IEnumerator PowerDownFinishesWhileEquippedShieldKeepsLooping()
        {
            player.state.powerLevel = 3;
            player.TakeDamage();
            Assert.AreEqual(2, player.state.powerLevel);
            var powerDown = Effects.Single();
            Assert.IsTrue(powerDown.name.StartsWith(player.powerDownEffect.name));
            player.GrantInvincibility(999f);

            yield return new WaitForSeconds(0.12f);
            player.Collect(Pickup.Kind.Shield);
            Assert.AreEqual(2, Effects.Length, "shield pickup is allowed during hit invincibility");
            var shieldEffect = Effects.Single(effect => effect != powerDown);
            Assert.IsTrue(shieldEffect.name.StartsWith(player.shieldEffectPrefab.name));

            yield return new WaitForSeconds(0.35f);
            Assert.IsTrue(powerDown == null, "the shorter power-down burst has finished");
            Assert.IsTrue(shieldEffect != null, "the shield continues independently");
            yield return new WaitForSeconds(1f);
            Assert.AreSame(shieldEffect, Effects.Single(), "the shield keeps looping after power-down ends");
            player.invincibility = 0f;
            player.TakeDamage();
            yield return null;
            Assert.AreEqual(0, Effects.Length, "consuming the shield removes the remaining effect");
        }
    }
}
