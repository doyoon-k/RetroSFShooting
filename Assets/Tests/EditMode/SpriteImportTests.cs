using System.Collections.Generic;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;

namespace RetroSF.Tests
{
    /// <summary>
    /// World units are 100 px (see Docs/PORTING.md). A sprite imported at any other Pixels Per Unit
    /// renders at the wrong size, so a new frame can shrink to a dot in the middle of an animation.
    /// </summary>
    public class SpriteImportTests
    {
        static readonly string[] SpriteFolders = { "Assets/Art", "Assets/Pilots_sprites" };

        static IEnumerable<(string path, Sprite sprite)> Sprites(string[] folders)
        {
            var seen = new HashSet<string>();
            foreach (var guid in AssetDatabase.FindAssets("t:Sprite", folders))
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                if (!seen.Add(path)) continue;
                foreach (var asset in AssetDatabase.LoadAllAssetsAtPath(path))
                    if (asset is Sprite sprite) yield return (path, sprite);
            }
        }

        [Test]
        public void EverySpriteUsesOneHundredPixelsPerUnit()
        {
            var wrong = new List<string>();
            foreach (var (path, sprite) in Sprites(SpriteFolders))
                if (!Mathf.Approximately(sprite.pixelsPerUnit, G.PixelsPerUnit))
                    wrong.Add($"{path} ({sprite.name}): {sprite.pixelsPerUnit}");
            Assert.IsEmpty(wrong, "Set Pixels Per Unit to 100 on:\n" + string.Join("\n", wrong));
        }

        [Test]
        public void RegionSpriteMeshesMatchTheirPixelRect()
        {
            int checkedCount = 0;
            foreach (var (path, sprite) in Sprites(new[] { "Assets/Art/_Regions" }))
            {
                Vector2 min = sprite.vertices[0], max = sprite.vertices[0];
                foreach (var vertex in sprite.vertices)
                {
                    min = Vector2.Min(min, vertex);
                    max = Vector2.Max(max, vertex);
                }
                Vector2 meshSize = max - min;
                Vector2 rectSize = sprite.rect.size / G.PixelsPerUnit;
                Assert.LessOrEqual(meshSize.x, rectSize.x + 0.0001f, path);
                Assert.LessOrEqual(meshSize.y, rectSize.y + 0.0001f, path);
                Assert.Greater(meshSize.x, rectSize.x * 0.5f, path);
                Assert.Greater(meshSize.y, rectSize.y * 0.5f, path);
                checkedCount++;
            }
            Assert.Greater(checkedCount, 0, "the region sprites were found");
        }
    }
}
