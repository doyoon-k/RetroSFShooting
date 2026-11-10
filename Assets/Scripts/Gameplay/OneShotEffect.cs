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
        Animator animator;
        bool started;

        protected virtual void Awake() => animator = GetComponent<Animator>();

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
