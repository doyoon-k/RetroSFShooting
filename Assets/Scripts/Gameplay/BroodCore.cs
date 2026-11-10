using System;
using System.Collections.Generic;
using UnityEngine;

namespace RetroSF
{
    /// <summary>One generation only: travel -> stationary, visible incubation -> hatch.</summary>
    public class BroodCore : Projectile
    {
        public Projectile childPrefab;
        public Sprite incubationHintTexture;
        [Range(0.1f, 3f)] public float travelSeconds = 0.85f;
        [Range(0.4f, 2f)] public float incubationSeconds = 0.65f;
        [Range(3, 20)] public int childCount = 7;
        [Range(30f, 180f)] public float childSpread = 120f;
        public SpriteRenderer visual;
        public Transform incubationHints;

        [NonSerialized] public bool hatched;
        [NonSerialized] public bool hatchHeld;
        [NonSerialized] public float incubationElapsed;

        readonly List<SpriteRenderer> hints = new List<SpriteRenderer>();
        readonly List<float> hintAngles = new List<float>();
        float hintAlpha = 1f;

        protected override void OnReady()
        {
            base.OnReady();
            for (int index = 0; index < childCount; index++)
            {
                var hint = new GameObject("Hint" + index).AddComponent<SpriteRenderer>();
                hint.sprite = incubationHintTexture;
                if (visual != null)
                {
                    hint.sharedMaterial = visual.sharedMaterial;
                    hint.sortingLayerID = visual.sortingLayerID;
                    hint.sortingOrder = visual.sortingOrder;
                }
                hint.transform.SetParent(incubationHints, false);
                hint.transform.localScale = new Vector3(0.2f, 0.2f, 1f);
                float angle = childSpread * Mathf.Deg2Rad * ((float)index / (childCount - 1) - 0.5f);
                hint.transform.localRotation = Quaternion.Euler(0f, 0f, angle * Mathf.Rad2Deg);
                hints.Add(hint);
                hintAngles.Add(angle);
            }
        }

        protected override void Step(float delta)
        {
            if (spent) return;
            if (age >= travelSeconds) speed = 0f;
            float beforeAge = age;
            BaseStep(delta);
            if (!hatchHeld)
                incubationElapsed += Mathf.Max(0f, age - Mathf.Max(beforeAge, travelSeconds));
            UpdateVisual();
            if (!hatchHeld && !IsFreed && incubationElapsed >= incubationSeconds)
                Hatch();
        }

        public void Hatch()
        {
            if (hatched || hatchHeld || spent || IsFreed) return;
            hatched = true;
            // No on-destruction callback: a bomb/clear removes the core without children.
            if (childPrefab != null && G.HasPoint(G.Grow(bounds, -24f), Position))
            {
                for (int index = 0; index < childCount; index++)
                {
                    // Prevent accidental recursive spawning through editor configuration.
                    if (childPrefab is BroodCore) continue;
                    var child = Instantiate(childPrefab, transform.position, Quaternion.identity, transform.parent);
                    child.bounds = bounds;
                    child.direction = G.Rotated(direction, childSpread * Mathf.Deg2Rad * ((float)index / (childCount - 1) - 0.5f));
                    RaiseOffspring(child);
                }
                Sfx.Play("bullet_split");
            }
            Free();
        }

        void UpdateVisual()
        {
            if (age < travelSeconds)
            {
                SetVisualAlpha(1f);
                incubationHints.gameObject.SetActive(false);
                return;
            }
            if (hatchHeld)
            {
                SetVisualAlpha(0.85f);
                incubationHints.gameObject.SetActive(false);
                return;
            }
            float progress = Mathf.Clamp01(incubationElapsed / incubationSeconds);
            // Pulse the authored sprite during incubation without changing its hitbox or size.
            SetVisualAlpha(0.7f + 0.3f * Mathf.Abs(Mathf.Cos(progress * G.Tau * 3f)));
            incubationHints.gameObject.SetActive(true);
            hintAlpha = 0.5f + 0.35f * progress;
            for (int i = 0; i < hints.Count; i++)
            {
                hints[i].transform.localPosition = G.FromAngle(hintAngles[i]) * (33f + 15f * progress);
                hints[i].color = new Color(1f, 1f, 1f, hintAlpha);
            }
        }

        void SetVisualAlpha(float alpha)
        {
            if (visual != null) visual.color = new Color(1f, 1f, 1f, alpha);
        }
    }
}
