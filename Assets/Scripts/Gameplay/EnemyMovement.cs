using System;
using UnityEngine;

namespace RetroSF
{
    /// <summary>Exactly one movement mode writes the actor position. Lives on the EnemyShip object.</summary>
    [DisallowMultipleComponent]
    public class EnemyMovement : MonoBehaviour
    {
        public enum Mode { Linear, Path, Sine, EnterHoldExit, VerticalSweep, StrafeExit }

        public Mode mode = Mode.Linear;
        public Vector2 direction = Vector2.left;
        [Range(0f, 1000f)] public float speed = 180f;
        [Header("Sine")]
        [Range(0f, 500f)] public float amplitude = 100f;
        [Range(0.05f, 5f)] public float frequency = 0.5f;
        [Header("Enter / hold / exit")]
        [Tooltip("Arena-local position (Unity space). The stage adds the arena offset at spawn.")]
        public Vector2 holdPosition = new Vector2(1220f, -532f);
        [Range(0f, 300f)] public float holdSeconds = 4f;
        public bool stayForever;
        public Vector2 exitDirection = Vector2.left;
        public bool followScroll;

        [NonSerialized] public PathRoute path;
        [NonSerialized] public Vector2 pathOffset;
        [NonSerialized] public float distance;
        [NonSerialized] public float age;
        [NonSerialized] public float holdElapsed;
        [NonSerialized] public bool reachedHold;
        [NonSerialized] public Vector2 origin;
        [NonSerialized] public float lastArenaX;

        EnemyShip actor;

        Vector2 Position
        {
            get => transform.position;
            set => transform.SetPosition2D(value);
        }

        void Awake()
        {
            actor = GetComponent<EnemyShip>();
            origin = Position;
        }

        void Start()
        {
            if (actor != null) lastArenaX = actor.bounds.x;
        }

        public void ApplyProfile(MovementProfile profile)
        {
            if (profile == null) return;
            switch (profile.mode)
            {
                case MovementProfile.Mode.Linear: mode = Mode.Linear; break;
                case MovementProfile.Mode.Sine: mode = Mode.Sine; break;
                case MovementProfile.Mode.EnterHoldExit: mode = Mode.EnterHoldExit; break;
                case MovementProfile.Mode.VerticalSweep: mode = Mode.VerticalSweep; break;
                case MovementProfile.Mode.StrafeExit: mode = Mode.StrafeExit; break;
            }
            direction = profile.direction;
            speed = profile.speed;
            amplitude = profile.amplitude;
            frequency = profile.frequency;
            holdPosition = profile.holdPosition;
            holdSeconds = profile.holdSeconds;
            stayForever = profile.stayForever;
            exitDirection = profile.exitDirection;
            followScroll = profile.followScroll;
            path = null;
            distance = 0f;
            age = 0f;
            holdElapsed = 0f;
            reachedHold = false;
            origin = Position;
        }

        public void UsePath(PathRoute route, Vector2 offset)
        {
            path = route;
            pathOffset = offset;
            mode = Mode.Path;
            distance = 0f;
        }

        void FixedUpdate()
        {
            float delta = Time.fixedDeltaTime;
            age += delta;
            if (actor != null)
            {
                float arenaX = actor.bounds.x;
                if (followScroll && (!reachedHold || stayForever || holdElapsed < holdSeconds))
                {
                    float shift = arenaX - lastArenaX;
                    holdPosition.x += shift;
                    var shifted = Position;
                    shifted.x += shift;
                    Position = shifted;
                }
                lastArenaX = arenaX;
            }
            switch (mode)
            {
                case Mode.Linear:
                    Position += direction.normalized * speed * delta;
                    break;
                case Mode.Path:
                    if (path == null || path.Length <= 0f) return;
                    distance += speed * delta;
                    Position = path.SampleWorld(distance) + pathOffset;
                    if (distance >= path.Length && actor != null) actor.Free();
                    break;
                case Mode.Sine:
                {
                    var forward = direction.normalized;
                    Position = origin + forward * speed * age + G.Orthogonal(forward) * Mathf.Sin(age * G.Tau * frequency) * amplitude;
                    break;
                }
                case Mode.EnterHoldExit:
                    if (!reachedHold)
                    {
                        Position = G.MoveToward(Position, holdPosition, speed * delta);
                        reachedHold = G.IsEqualApprox(Position, holdPosition);
                    }
                    else if (!stayForever)
                    {
                        holdElapsed += delta;
                        if (holdElapsed >= holdSeconds) Position += exitDirection.normalized * speed * delta;
                    }
                    break;
                case Mode.VerticalSweep:
                    if (!reachedHold)
                    {
                        Position = G.MoveToward(Position, holdPosition, speed * delta);
                        reachedHold = G.IsEqualApprox(Position, holdPosition);
                    }
                    else
                    {
                        holdElapsed += delta;
                        // Godot's +y sweep is downward.
                        Position = holdPosition - new Vector2(0f, Mathf.Sin(holdElapsed * G.Tau * frequency) * amplitude);
                    }
                    break;
                case Mode.StrafeExit:
                    if (!reachedHold)
                    {
                        Position = G.MoveToward(Position, holdPosition, speed * delta);
                        reachedHold = G.IsEqualApprox(Position, holdPosition);
                    }
                    else
                    {
                        holdElapsed += delta;
                        if (holdElapsed < holdSeconds || stayForever)
                            Position = holdPosition - new Vector2(0f, Mathf.Sin(holdElapsed * G.Tau * frequency) * amplitude);
                        else
                            Position += exitDirection.normalized * speed * delta;
                    }
                    break;
            }
        }
    }
}
