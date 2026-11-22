using System.IO;
using UnityEditor;
using UnityEngine;

namespace RetroSF.EditorTools
{
    /// <summary>
    /// Bakes Godot's <c>battle_frame.gdshader</c> into <see cref="BakedPath"/>: the white windows and the
    /// gray antialiasing beside them become transparent, and the J badge drawn into the art is cleared
    /// because the live console draws its own key hints. Run it after the frame art changes.
    /// </summary>
    public static class BattleFrameBaker
    {
        public const string SourcePath = "Assets/Art/Pilots_sprites/UI/Battle_Bg.png";
        public const string BakedPath = "Assets/Art/_Generated/Battle_Bg_Keyed.png";

        /// <summary>The shader keys min(r, g, b) &gt;= 0.9, that is 229.5 / 255.</summary>
        const int WhiteLevel = 230;
        const int BadgeCenterX = 513;
        const int BadgeCenterY = 938;
        const int BadgeRadius = 49;
        const int BadgeMinX = 478;

        [MenuItem("RetroSF/Bake Battle Frame")]
        static void BakeFromMenu()
        {
            Bake();
            Debug.Log($"Baked {BakedPath} from {SourcePath}.");
        }

        public static void Bake()
        {
            var source = LoadUnimported(SourcePath);
            try
            {
                var baked = new Texture2D(source.width, source.height, TextureFormat.RGBA32, false);
                baked.SetPixels32(Key(source.GetPixels32(), source.width, source.height));
                File.WriteAllBytes(BakedPath, baked.EncodeToPNG());
                Object.DestroyImmediate(baked);
            }
            finally
            {
                Object.DestroyImmediate(source);
            }
            AssetDatabase.ImportAsset(BakedPath);
        }

        /// <summary>The PNG's own pixels, whatever its import settings (Read/Write, compression, max size).</summary>
        public static Texture2D LoadUnimported(string path)
        {
            var texture = new Texture2D(2, 2, TextureFormat.RGBA32, false);
            texture.LoadImage(File.ReadAllBytes(path));
            return texture;
        }

        /// <param name="pixels">Rows from the bottom up, as <see cref="Texture2D.GetPixels32()"/> returns them.</param>
        public static Color32[] Key(Color32[] pixels, int width, int height)
        {
            var white = new int[pixels.Length];
            for (int i = 0; i < pixels.Length; i++)
                white[i] = Mathf.Min(pixels[i].r, Mathf.Min(pixels[i].g, pixels[i].b));
            var result = (Color32[])pixels.Clone();
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    int index = y * width + x;
                    int level = white[index];
                    // Gray antialiasing beside a window joins it: the mask grows by one texel.
                    if (level > 0 && level < WhiteLevel)
                    {
                        for (int dy = -1; dy <= 1; dy++)
                        for (int dx = -1; dx <= 1; dx++)
                        {
                            int nx = Mathf.Clamp(x + dx, 0, width - 1);
                            int ny = Mathf.Clamp(y + dy, 0, height - 1);
                            level = Mathf.Max(level, white[ny * width + nx]);
                        }
                    }
                    // The shader measures the badge in pixels from the top.
                    int fromTop = height - 1 - y;
                    int bx = x - BadgeCenterX, by = fromTop - BadgeCenterY;
                    bool badge = x >= BadgeMinX && bx * bx + by * by < BadgeRadius * BadgeRadius;
                    if (level >= WhiteLevel || badge) result[index].a = 0;
                }
            }
            return result;
        }
    }
}
