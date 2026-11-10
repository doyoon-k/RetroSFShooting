using System;
using UnityEngine;

namespace RetroSF
{
    /// <summary>Every row in a volley shares its age, preserving the gap while it sways.</summary>
    public class CurtainBullet : Projectile
    {
        public SpriteRenderer visual;

        [NonSerialized] public float swayAmplitude;
        [NonSerialized] public float swayPeriod = 6f;
        [NonSerialized] public float swayOffset;

        protected override void Step(float delta)
        {
            if (spent) return;
            // Move/cull along the straight flight path; edge guard rows must survive
            // their temporary excursion beyond the arena before moving back inside.
            // Godot's +y offset is downward, so Unity subtracts it.
            var p = Position;
            p.y += swayOffset;
            Position = p;
            BaseStep(delta);
            swayOffset = swayAmplitude * Mathf.Sin(age * G.Tau / Mathf.Max(swayPeriod, 0.01f));
            p = Position;
            p.y -= swayOffset;
            Position = p;
            // Moving rows pulse their sprite; fixed rows keep the original asset opaque.
            float alpha = swayAmplitude > 0f ? 0.7f + 0.3f * Mathf.Abs(Mathf.Cos(age * G.Tau * 2f)) : 1f;
            if (visual != null) visual.color = new Color(1f, 1f, 1f, alpha);
        }
    }
}
