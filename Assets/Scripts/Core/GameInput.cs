using UnityEngine;
using UnityEngine.InputSystem;

namespace RetroSF
{
    /// <summary>
    /// The Godot Input Map (project.godot) as Input System actions.
    /// Gameplay polls in FixedUpdate, so one-shot presses are latched in Update and consumed once.
    /// Godot joypad indices: A=South, B=East, X=West, Y=North, Start=6.
    /// </summary>
    [DefaultExecutionOrder(-1000)]
    public sealed class GameInput : MonoBehaviour
    {
        const float LatchSeconds = 0.1f;

        static GameInput instance;
        InputActionMap map;
        InputAction move, shoot, bomb, switchWeapon, pause, storyAdvance;
        InputAction uiLeft, uiRight, uiUp, uiDown, uiAccept, uiCancel;
        float bombLatch = -1f, switchLatch = -1f;

        public static GameInput Instance
        {
            get
            {
                if (instance == null)
                {
                    var host = new GameObject("GameInput");
                    DontDestroyOnLoad(host);
                    instance = host.AddComponent<GameInput>();
                }
                return instance;
            }
        }

        /// <summary>Movement in Unity space (up is +y), length ≤ 1 like Input.get_vector.</summary>
        public static Vector2 Move => Instance.move.ReadValue<Vector2>();
        public static bool ShootHeld => Instance.shoot.IsPressed();
        public static bool PausePressed => Instance.pause.WasPressedThisFrame();
        public static bool StoryAdvancePressed => Instance.storyAdvance.WasPressedThisFrame();
        public static bool UiLeftPressed => Instance.uiLeft.WasPressedThisFrame();
        public static bool UiRightPressed => Instance.uiRight.WasPressedThisFrame();
        public static bool UiUpPressed => Instance.uiUp.WasPressedThisFrame();
        public static bool UiDownPressed => Instance.uiDown.WasPressedThisFrame();
        public static bool UiAcceptPressed => Instance.uiAccept.WasPressedThisFrame();
        public static bool UiCancelPressed => Instance.uiCancel.WasPressedThisFrame();

        /// <summary>True once per bomb press. Call from FixedUpdate.</summary>
        public static bool ConsumeBomb() => Instance.Consume(ref Instance.bombLatch);

        /// <summary>True once per weapon-switch press. Call from FixedUpdate.</summary>
        public static bool ConsumeSwitchWeapon() => Instance.Consume(ref Instance.switchLatch);

        /// <summary>Drops presses made before a state change (pause, respawn) so they do not fire later.</summary>
        public static void ClearLatches()
        {
            Instance.bombLatch = -1f;
            Instance.switchLatch = -1f;
        }

        bool Consume(ref float latch)
        {
            if (latch < 0f) return false;
            latch = -1f;
            return true;
        }

        void Awake()
        {
            if (instance != null && instance != this)
            {
                Destroy(gameObject);
                return;
            }
            instance = this;
            Build();
        }

        void OnEnable() => map?.Enable();

        void OnDisable() => map?.Disable();

        void OnDestroy()
        {
            map?.Dispose();
            if (instance == this) instance = null;
        }

        void Update()
        {
            float now = Time.unscaledTime;
            if (bomb.WasPressedThisFrame()) bombLatch = now;
            if (switchWeapon.WasPressedThisFrame()) switchLatch = now;
            if (bombLatch >= 0f && now - bombLatch > LatchSeconds) bombLatch = -1f;
            if (switchLatch >= 0f && now - switchLatch > LatchSeconds) switchLatch = -1f;
        }

        void Build()
        {
            map = new InputActionMap("Gameplay");

            move = map.AddAction("Move", InputActionType.Value, expectedControlLayout: "Vector2");
            AddWasd(move, "<Keyboard>/w", "<Keyboard>/s", "<Keyboard>/a", "<Keyboard>/d");
            AddWasd(move, "<Keyboard>/upArrow", "<Keyboard>/downArrow", "<Keyboard>/leftArrow", "<Keyboard>/rightArrow");
            move.AddBinding("<Gamepad>/leftStick").WithProcessor("stickDeadzone(min=0.2)");

            shoot = Button("Shoot", "<Keyboard>/j", "<Gamepad>/buttonWest");
            bomb = Button("Bomb", "<Keyboard>/k", "<Gamepad>/buttonEast");
            switchWeapon = Button("SwitchWeapon", "<Keyboard>/l", "<Gamepad>/buttonNorth");
            pause = Button("Pause", "<Keyboard>/escape", "<Gamepad>/start");
            storyAdvance = Button("StoryAdvance", "<Keyboard>/space", "<Gamepad>/buttonSouth");

            uiLeft = Button("UiLeft", "<Keyboard>/a", "<Keyboard>/leftArrow", "<Gamepad>/dpad/left");
            uiRight = Button("UiRight", "<Keyboard>/d", "<Keyboard>/rightArrow", "<Gamepad>/dpad/right");
            uiUp = Button("UiUp", "<Keyboard>/w", "<Keyboard>/upArrow", "<Gamepad>/dpad/up");
            uiDown = Button("UiDown", "<Keyboard>/s", "<Keyboard>/downArrow", "<Gamepad>/dpad/down");
            uiAccept = Button("UiAccept", "<Keyboard>/enter", "<Keyboard>/numpadEnter", "<Keyboard>/space", "<Gamepad>/buttonSouth");
            uiCancel = Button("UiCancel", "<Keyboard>/escape", "<Gamepad>/buttonEast");

            map.Enable();
        }

        InputAction Button(string name, params string[] paths)
        {
            var action = map.AddAction(name, InputActionType.Button);
            foreach (var path in paths) action.AddBinding(path);
            return action;
        }

        static void AddWasd(InputAction action, string up, string down, string left, string right)
        {
            action.AddCompositeBinding("2DVector(mode=2)")
                .With("Up", up).With("Down", down).With("Left", left).With("Right", right);
        }
    }
}
