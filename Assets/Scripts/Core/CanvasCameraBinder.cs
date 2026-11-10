using UnityEngine;

namespace RetroSF
{
    /// <summary>
    /// Prefab canvases cannot reference the scene camera. This binds a Screen Space - Camera canvas
    /// to the main camera so the UI follows the letterboxed 16:9 view.
    /// </summary>
    [RequireComponent(typeof(Canvas))]
    [ExecuteAlways]
    public class CanvasCameraBinder : MonoBehaviour
    {
        [Tooltip("Distance in front of the camera. Smaller than the camera's far plane.")]
        public float planeDistance = 5f;

        void OnEnable() => Bind();

        void Update()
        {
            var canvas = GetComponent<Canvas>();
            if (canvas.isRootCanvas && canvas.worldCamera == null) Bind();
        }

        void Bind()
        {
            var canvas = GetComponent<Canvas>();
            if (!canvas.isRootCanvas) return;
            var camera = Camera.main;
            if (camera == null) return;
            canvas.renderMode = RenderMode.ScreenSpaceCamera;
            canvas.worldCamera = camera;
            canvas.planeDistance = planeDistance;
        }
    }
}
