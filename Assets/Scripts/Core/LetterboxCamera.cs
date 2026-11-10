using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    /// <summary>
    /// Godot stretch aspect "keep": this camera draws a centered 16:9 viewport and the window outside it is black.
    /// One shared background camera (below every letterboxed camera, culling nothing) clears the whole window
    /// first, so the bars never show stale pixels. Follows window resizes.
    /// Screen Space - Camera canvases on this camera should use CanvasScaler "Expand" (or match the letterboxed
    /// side) so the 1920×1080 design space fills the viewport exactly.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class LetterboxCamera : MonoBehaviour
    {
        public const float DesignAspect = 1920f / 1080f;

        static readonly List<LetterboxCamera> active = new List<LetterboxCamera>();
        static Camera bars;

        Camera view;
        int width = -1;
        int height = -1;
        float depth = float.NaN;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        static void ResetStatics()
        {
            active.Clear();
            bars = null;
        }

        /// <summary>Normalized viewport of the centered 16:9 area inside a window.</summary>
        public static Rect ViewportFor(int windowWidth, int windowHeight)
        {
            if (windowWidth <= 0 || windowHeight <= 0) return new Rect(0f, 0f, 1f, 1f);
            float window = (float)windowWidth / windowHeight;
            if (window > DesignAspect)
            {
                float share = DesignAspect / window;
                return new Rect((1f - share) * 0.5f, 0f, share, 1f);
            }
            float tall = window / DesignAspect;
            return new Rect(0f, (1f - tall) * 0.5f, 1f, tall);
        }

        void Awake() => view = GetComponent<Camera>();

        void OnEnable()
        {
            if (!active.Contains(this)) active.Add(this);
            Apply();
        }

        void OnDisable()
        {
            active.Remove(this);
            if (view != null) view.rect = new Rect(0f, 0f, 1f, 1f);
            if (active.Count == 0)
            {
                if (bars != null) Destroy(bars.gameObject);
                bars = null;
            }
            else
            {
                UpdateBarsDepth();
            }
        }

        void LateUpdate()
        {
            if (view == null) return;
            if (Screen.width != width || Screen.height != height || view.depth != depth) Apply();
        }

        void Apply()
        {
            if (view == null) view = GetComponent<Camera>();
            if (view == null) return;
            width = Screen.width;
            height = Screen.height;
            depth = view.depth;
            view.rect = ViewportFor(width, height);
            EnsureBars();
            UpdateBarsDepth();
        }

        static void EnsureBars()
        {
            if (bars != null) return;
            var host = new GameObject("LetterboxBars");
            bars = host.AddComponent<Camera>();
            bars.clearFlags = CameraClearFlags.SolidColor;
            bars.backgroundColor = Color.black;
            bars.cullingMask = 0;
            bars.orthographic = true;
            bars.useOcclusionCulling = false;
            bars.allowHDR = false;
            bars.allowMSAA = false;
            bars.rect = new Rect(0f, 0f, 1f, 1f);
        }

        static void UpdateBarsDepth()
        {
            if (bars == null) return;
            float lowest = float.MaxValue;
            foreach (var letterbox in active)
                if (letterbox != null && letterbox.view != null) lowest = Mathf.Min(lowest, letterbox.view.depth);
            if (lowest < float.MaxValue) bars.depth = lowest - 1f;
        }
    }
}
