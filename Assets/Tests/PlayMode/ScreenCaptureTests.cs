using System.Collections;
using System.IO;
using System.Reflection;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;

namespace RetroSF.Tests
{
    /// <summary>
    /// Renders key moments of the game to Captures/*.png for side-by-side comparison with the Godot
    /// screenshots (build/screenshots in a checkout of the godot-final tag). Works in batch mode: no focused Editor needed.
    /// Run alone: unity test . --mode PlayMode --filter RetroSF.Tests.ScreenCaptureTests
    /// </summary>
    [Category("Capture")]
    public class ScreenCaptureTests
    {
        static string Folder => Path.Combine(Application.dataPath, "..", "Captures");

        [UnityTearDown]
        public IEnumerator TearDown()
        {
            GamePause.Set(false);
            yield return null;
        }

        static IEnumerator Capture(string name)
        {
            yield return null;
            var camera = Camera.main;
            Assert.IsNotNull(camera, "a main camera renders the game");
            var letterbox = camera.GetComponent<LetterboxCamera>();
            if (letterbox != null) letterbox.enabled = false;
            var rect = camera.rect;
            var target = new RenderTexture(1920, 1080, 24, RenderTextureFormat.ARGB32);
            camera.rect = new Rect(0f, 0f, 1f, 1f);
            camera.targetTexture = target;
            Canvas.ForceUpdateCanvases();
            yield return null;
            Canvas.ForceUpdateCanvases();
            camera.Render();
            var previous = RenderTexture.active;
            RenderTexture.active = target;
            var texture = new Texture2D(1920, 1080, TextureFormat.RGB24, false);
            texture.ReadPixels(new Rect(0, 0, 1920, 1080), 0, 0);
            texture.Apply();
            RenderTexture.active = previous;
            camera.targetTexture = null;
            camera.rect = rect;
            if (letterbox != null) letterbox.enabled = true;
            Directory.CreateDirectory(Folder);
            File.WriteAllBytes(Path.Combine(Folder, name + ".png"), texture.EncodeToPNG());
            Object.Destroy(texture);
            target.Release();
            Object.Destroy(target);
        }

        static object Call(object target, string method, params object[] args)
        {
            var info = target.GetType().GetMethod(method, BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public);
            Assert.IsNotNull(info, $"{target.GetType().Name}.{method} exists");
            return info.Invoke(target, args);
        }

        [UnityTest]
        public IEnumerator CaptureGameFlow()
        {
            SceneManager.LoadScene("Main");
            yield return new WaitForSecondsRealtime(1.2f);
            yield return Capture("01_title");

            var title = Object.FindAnyObjectByType<TitleScreen>();
            var keyboard = Keyboard.current ?? InputSystem.AddDevice<Keyboard>();
            Call(title, "RevealMenu", keyboard.enterKey);
            yield return new WaitForSecondsRealtime(0.5f);
            yield return Capture("01b_title_menu");

            var flow = Object.FindAnyObjectByType<GameFlow>();
            Call(flow, "StartNewGame");
            yield return new WaitForSecondsRealtime(1.5f);
            yield return Capture("02_intro");

            Call(flow, "ShowSelect");
            yield return new WaitForSecondsRealtime(0.8f);
            yield return Capture("03_character_select");
            var select = Object.FindAnyObjectByType<CharacterSelect>();
            Call(select, "OpenPilot", flow.catalog.pilots[0].id);
            yield return new WaitForSecondsRealtime(1.5f);
            yield return Capture("03b_character_details");

            Call(flow, "StartStage", flow.catalog.pilots[0].id);
            yield return new WaitForSecondsRealtime(0.6f);
            var stage = Object.FindAnyObjectByType<StageController>();
            Assert.IsNotNull(stage);
            yield return Capture("04a_launch");
            yield return new WaitForSecondsRealtime(stage.catalog.rules.launchSeconds);
            stage.player.GrantInvincibility(999f);
            float until = Time.realtimeSinceStartup + 9f;
            while (Time.realtimeSinceStartup < until)
            {
                if (stage.player != null && stage.player.weapon.cooldown <= 0f) stage.player.weapon.Fire();
                yield return null;
            }
            yield return Capture("04_stage");

            stage.TogglePause();
            yield return new WaitForSecondsRealtime(0.3f);
            yield return Capture("05_pause");
            stage.TogglePause();

            stage.player.invincibility = 0f;
            stage.player.TakeDamage(10);
            yield return new WaitForSecondsRealtime(1.0f);
            yield return Capture("06_death");
            yield return new WaitForSecondsRealtime(stage.catalog.rules.deathSeconds);
            yield return Capture("07_select_next");
        }

        [UnityTest]
        public IEnumerator CaptureEnemyLab()
        {
            SceneManager.LoadScene("EnemyLab");
            yield return new WaitForSecondsRealtime(3f);
            yield return Capture("10_enemy_lab");
            var lab = Object.FindAnyObjectByType<EnemyLab>();
            var field = typeof(EnemyLab).GetField("enemyIndex", BindingFlags.Instance | BindingFlags.NonPublic);
            string[] names = { "m1_carapace", "m2_wing", "m3_star_eye", "boss" };
            foreach (var name in names)
            {
                int index = lab.enemyPrefabs.FindIndex(p => p != null && p.name == name);
                if (index < 0) continue;
                field.SetValue(lab, index);
                lab.player.GrantInvincibility(999f);
                lab.SpawnSample();
                yield return new WaitForSecondsRealtime(5f);
                yield return Capture("11_lab_" + name);
            }
        }
    }
}
