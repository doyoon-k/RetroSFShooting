using UnityEngine;

namespace RetroSF
{
    /// <summary>Spins a visual. Positive speed turns clockwise on screen, as in Godot.</summary>
    public class SpinningShell : MonoBehaviour
    {
        [Range(-2f, 2f)] public float angularSpeed = 0.45f;

        void Update()
        {
            transform.Rotate(0f, 0f, -angularSpeed * Mathf.Rad2Deg * Time.deltaTime);
        }
    }
}
