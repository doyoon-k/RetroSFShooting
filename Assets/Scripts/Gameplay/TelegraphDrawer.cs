using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    /// <summary>
    /// Immediate-mode lines and circles for attack telegraphs (Godot CanvasItem._draw).
    /// Callers submit world-space shapes every Update; the mesh is rebuilt once per frame.
    /// Shapes keep showing while the game is paused because Update still runs.
    /// </summary>
    [DefaultExecutionOrder(10000)]
    public sealed class TelegraphDrawer : MonoBehaviour
    {
        const int SortingOrder = 200;

        static TelegraphDrawer instance;

        readonly List<Vector3> vertices = new List<Vector3>(4096);
        readonly List<Color> colors = new List<Color>(4096);
        readonly List<int> indices = new List<int>(8192);
        Mesh mesh;
        int submittedFrame = -1;

        static TelegraphDrawer Instance
        {
            get
            {
                if (instance == null)
                {
                    var host = new GameObject("TelegraphDrawer");
                    instance = host.AddComponent<TelegraphDrawer>();
                }
                return instance;
            }
        }

        void Awake()
        {
            instance = this;
            mesh = new Mesh { name = "Telegraphs", indexFormat = UnityEngine.Rendering.IndexFormat.UInt32 };
            mesh.MarkDynamic();
            gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            var meshRenderer = gameObject.AddComponent<MeshRenderer>();
            var shader = Shader.Find("Universal Render Pipeline/2D/Sprite-Unlit-Default");
            if (shader == null) shader = Shader.Find("Sprites/Default");
            meshRenderer.sharedMaterial = new Material(shader) { name = "Telegraphs" };
            meshRenderer.sortingOrder = SortingOrder;
        }

        void OnDestroy()
        {
            if (instance == this) instance = null;
            if (mesh != null) Destroy(mesh);
        }

        void BeginFrameIfNeeded()
        {
            if (submittedFrame == Time.frameCount) return;
            submittedFrame = Time.frameCount;
            vertices.Clear();
            colors.Clear();
            indices.Clear();
        }

        void LateUpdate()
        {
            if (submittedFrame != Time.frameCount)
            {
                vertices.Clear();
                colors.Clear();
                indices.Clear();
            }
            mesh.Clear();
            mesh.SetVertices(vertices);
            mesh.SetColors(colors);
            mesh.SetTriangles(indices, 0);
            mesh.RecalculateBounds();
        }

        void AddQuad(Vector2 a, Vector2 b, Vector2 c, Vector2 d, Color color)
        {
            int start = vertices.Count;
            vertices.Add(a); vertices.Add(b); vertices.Add(c); vertices.Add(d);
            colors.Add(color); colors.Add(color); colors.Add(color); colors.Add(color);
            indices.Add(start); indices.Add(start + 1); indices.Add(start + 2);
            indices.Add(start); indices.Add(start + 2); indices.Add(start + 3);
        }

        public static void Line(Vector2 from, Vector2 to, Color color, float width = 1f)
        {
            var self = Instance;
            self.BeginFrameIfNeeded();
            Vector2 along = to - from;
            if (along.sqrMagnitude < 0.000001f) return;
            Vector2 side = G.Orthogonal(along.normalized) * (width * 0.5f);
            self.AddQuad(from - side, from + side, to + side, to - side, color);
        }

        public static void Polyline(IList<Vector2> points, Color color, float width = 1f)
        {
            for (int i = 1; i < points.Count; i++) Line(points[i - 1], points[i], color, width);
        }

        /// <summary>Godot draw_arc. Angles are Unity space radians.</summary>
        public static void Arc(Vector2 center, float radius, float startAngle, float endAngle, int segments, Color color, float width = 1f)
        {
            segments = Mathf.Max(1, segments);
            Vector2 previous = center + G.FromAngle(startAngle) * radius;
            for (int i = 1; i <= segments; i++)
            {
                float angle = Mathf.Lerp(startAngle, endAngle, (float)i / segments);
                Vector2 point = center + G.FromAngle(angle) * radius;
                Line(previous, point, color, width);
                previous = point;
            }
        }

        public static void Ring(Vector2 center, float radius, int segments, Color color, float width = 1f) =>
            Arc(center, radius, 0f, G.Tau, segments, color, width);

        /// <summary>Godot draw_circle (filled).</summary>
        public static void Circle(Vector2 center, float radius, Color color, int segments = 16)
        {
            var self = Instance;
            self.BeginFrameIfNeeded();
            int start = self.vertices.Count;
            self.vertices.Add(center);
            self.colors.Add(color);
            for (int i = 0; i <= segments; i++)
            {
                self.vertices.Add(center + G.FromAngle(G.Tau * i / segments) * radius);
                self.colors.Add(color);
            }
            for (int i = 0; i < segments; i++)
            {
                self.indices.Add(start);
                self.indices.Add(start + i + 1);
                self.indices.Add(start + i + 2);
            }
        }
    }
}
