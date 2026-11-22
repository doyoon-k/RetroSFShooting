using System.Collections.Generic;
using NUnit.Framework;
using RetroSF.EditorTools;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace RetroSF.Tests
{
    /// <summary>
    /// The battle frame is see-through over the pilot panels on the left. Whatever shows there must be
    /// backed, or enemies and bullets flying behind the HUD show through.
    /// </summary>
    public class HudLayoutTests
    {
        const string StagePath = "Assets/Prefabs/gameplay/stage/stage_01.prefab";
        const string HudPath = "Assets/Prefabs/ui/combat_hud.prefab";

        /// <summary>Screen rect (1920x1080, origin at the top-left) of a rect anchored at its parent's top-left.</summary>
        static RectInt ScreenRect(RectTransform rect, Vector2Int parentTopLeft)
        {
            Assert.AreEqual(new Vector2(0f, 1f), rect.anchorMin, rect.name + " is anchored at the top-left");
            Assert.AreEqual(new Vector2(0f, 1f), rect.anchorMax, rect.name + " is anchored at the top-left");
            float left = rect.anchoredPosition.x - rect.pivot.x * rect.sizeDelta.x;
            float top = -rect.anchoredPosition.y - (1f - rect.pivot.y) * rect.sizeDelta.y;
            return new RectInt(parentTopLeft.x + Mathf.RoundToInt(left), parentTopLeft.y + Mathf.RoundToInt(top),
                Mathf.RoundToInt(rect.sizeDelta.x), Mathf.RoundToInt(rect.sizeDelta.y));
        }

        /// <summary>The fully keyed texels connected to <paramref name="seed"/> (screen coordinates, y down).</summary>
        static List<Vector2Int> Hole(Texture2D frame, Vector2Int seed)
        {
            var pixels = frame.GetPixels32();
            int width = frame.width;
            int height = frame.height;
            bool Clear(Vector2Int p) => pixels[(height - 1 - p.y) * width + p.x].a == 0;
            Assert.IsTrue(Clear(seed), $"the frame is see-through at {seed}");
            var seen = new HashSet<Vector2Int> { seed };
            var open = new Queue<Vector2Int>();
            open.Enqueue(seed);
            var hole = new List<Vector2Int>();
            var steps = new[] { Vector2Int.left, Vector2Int.right, Vector2Int.up, Vector2Int.down };
            while (open.Count > 0)
            {
                var p = open.Dequeue();
                hole.Add(p);
                foreach (var step in steps)
                {
                    var next = p + step;
                    if (next.x < 0 || next.y < 0 || next.x >= width || next.y >= height) continue;
                    if (Clear(next) && seen.Add(next)) open.Enqueue(next);
                }
            }
            return hole;
        }

        static void AssertBacked(List<Vector2Int> hole, RectInt backing, string what)
        {
            int open = 0;
            Vector2Int first = default;
            foreach (var p in hole)
            {
                if (backing.Contains(p)) continue;
                if (open++ == 0) first = p;
            }
            Assert.AreEqual(0, open, $"{open} see-through texels of the {what} hole are not backed, e.g. {first}; backing {backing}");
        }

        static void AssertOpaque(Image image) =>
            Assert.AreEqual(1f, image.color.a, image.name + " is fully opaque");

        /// <summary>
        /// The dark score box drawn in the frame, found by walking out from <paramref name="center"/> until the gray
        /// frame starts (screen coordinates, y down).
        /// </summary>
        static RectInt DarkBox(Texture2D frame, Vector2Int center)
        {
            var pixels = frame.GetPixels32();
            bool Dark(int x, int y)
            {
                var c = pixels[(frame.height - 1 - y) * frame.width + x];
                return Mathf.Max(c.r, Mathf.Max(c.g, c.b)) < 45;
            }
            Assert.IsTrue(Dark(center.x, center.y), $"the frame is dark at {center}");
            int left = center.x, right = center.x, top = center.y, bottom = center.y;
            while (Dark(left - 1, center.y)) left--;
            while (Dark(right + 1, center.y)) right++;
            while (Dark(center.x, top - 1)) top--;
            while (Dark(center.x, bottom + 1)) bottom++;
            return new RectInt(left, top, right - left + 1, bottom - top + 1);
        }

        [Test]
        public void ScoreBoxIsTheBoxDrawnInTheFrame()
        {
            var frame = BattleFrameBaker.LoadUnimported(BattleFrameBaker.BakedPath);
            var hud = PrefabUtility.LoadPrefabContents(HudPath);
            try
            {
                // The HUD root is the screen (the stage places it at the top-left), so ScoreBox is in screen pixels.
                var scoreBox = ScreenRect((RectTransform)hud.transform.Find("ScoreBox"), Vector2Int.zero);
                var drawn = DarkBox(frame, Vector2Int.RoundToInt(scoreBox.center));
                Assert.AreEqual(drawn.xMin, scoreBox.xMin, 1, $"left edge; the frame draws {drawn}");
                Assert.AreEqual(drawn.xMax, scoreBox.xMax, 1, $"right edge; the frame draws {drawn}");
                Assert.AreEqual(drawn.yMin, scoreBox.yMin, 1, $"top edge; the frame draws {drawn}");
                Assert.AreEqual(drawn.yMax, scoreBox.yMax, 1, $"bottom edge; the frame draws {drawn}");
            }
            finally
            {
                PrefabUtility.UnloadPrefabContents(hud);
                Object.DestroyImmediate(frame);
            }
        }

        [Test]
        public void PilotPanelsAreBackedAndTheRosterSitsInItsHole()
        {
            var frame = BattleFrameBaker.LoadUnimported(BattleFrameBaker.BakedPath);
            var stage = PrefabUtility.LoadPrefabContents(StagePath);
            var hud = PrefabUtility.LoadPrefabContents(HudPath);
            try
            {
                RectTransform Find(GameObject root, string name)
                {
                    foreach (var rect in root.GetComponentsInChildren<RectTransform>(true))
                        if (rect.name == name) return rect;
                    Assert.Fail($"{root.name} has {name}");
                    return null;
                }

                // stage_01.tscn: Roster offsets (13, 21)-(423, 783), two columns of 196x242 cards 18 apart.
                var roster = Find(stage, "Roster");
                Assert.AreEqual(new RectInt(13, 21, 410, 762), ScreenRect(roster, Vector2Int.zero), "the roster sits where Godot puts it");
                var grid = roster.GetComponent<GridLayoutGroup>();
                Assert.AreEqual(new Vector2(196f, 242f), grid.cellSize);
                Assert.AreEqual(new Vector2(18f, 18f), grid.spacing);

                var rosterBacking = Find(stage, "RosterBacking");
                Assert.Less(rosterBacking.GetSiblingIndex(), roster.GetSiblingIndex(), "the backing draws under the cards");
                AssertOpaque(rosterBacking.GetComponent<Image>());
                AssertBacked(Hole(frame, new Vector2Int(220, 400)), ScreenRect(rosterBacking, Vector2Int.zero), "roster");

                var hudRoot = Find(stage, "CombatHUD");
                var hudTopLeft = ScreenRect(hudRoot, Vector2Int.zero).position;
                var activePilot = Find(hud, "ActivePilot");
                var activeBacking = activePilot.Find("Backing") as RectTransform;
                Assert.IsNotNull(activeBacking, "the active pilot box has a backing");
                Assert.AreEqual(0, activeBacking.GetSiblingIndex(), "the backing draws under the portrait");
                Assert.AreEqual(Vector2.zero, activeBacking.anchorMin);
                Assert.AreEqual(Vector2.one, activeBacking.anchorMax);
                Assert.AreEqual(Vector2.zero, activeBacking.sizeDelta, "the backing fills the box");
                AssertOpaque(activeBacking.GetComponent<Image>());
                AssertBacked(Hole(frame, new Vector2Int(200, 950)), ScreenRect(activePilot, hudTopLeft), "active pilot");
            }
            finally
            {
                PrefabUtility.UnloadPrefabContents(hud);
                PrefabUtility.UnloadPrefabContents(stage);
                Object.DestroyImmediate(frame);
            }
        }
    }
}
