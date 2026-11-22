using UnityEngine;

namespace RetroSF
{
    /// <summary>
    /// Plays the Animator's default state once and removes the object when it ends
    /// (Godot AnimatedSprite2D + animation_finished → queue_free).
    /// Set the Animator's Update Mode to Unscaled Time for effects that must run during the pause.
    /// </summary>
    [RequireComponent(typeof(Animator))]
    public class OneShotEffect : MonoBehaviour
    {
        [Tooltip("Spawn so the middle of everything the animation draws lands on the spawn point, " +
                 "instead of the sprite pivot. For art drawn off the canvas center.")]
        public bool anchorToArt;
        [Tooltip("Middle of the opaque pixels of all frames, relative to the pivot in local units. " +
                 "Filled in by RetroSF > Measure Effect Anchors.")]
        public Vector2 artCenter;

        Animator animator;
        bool started;

        protected virtual void Awake()
        {
            animator = GetComponent<Animator>();
            // Instantiate has already placed the pivot on the spawn point.
            if (anchorToArt) transform.position -= transform.TransformVector(artCenter);
        }

        /// <summary>World point the effect is centered on: the art center when anchored, else the pivot.</summary>
        public Vector2 Center => anchorToArt ? (Vector2)transform.TransformPoint(artCenter) : (Vector2)transform.position;

        public void SetUnscaled(bool unscaled) =>
            GetComponent<Animator>().updateMode = unscaled ? AnimatorUpdateMode.UnscaledTime : AnimatorUpdateMode.Normal;

        void LateUpdate()
        {
            if (animator == null || animator.runtimeAnimatorController == null) return;
            var info = animator.GetCurrentAnimatorStateInfo(0);
            if (!started)
            {
                started = info.length > 0f;
                return;
            }
            if (!info.loop && info.normalizedTime >= 1f) Destroy(gameObject);
        }
    }
}
