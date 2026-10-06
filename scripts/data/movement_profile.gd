class_name MovementProfile
extends Resource
## Reusable movement settings. A wave Path2D overrides this mode at spawn time.

enum Mode { LINEAR, SINE, ENTER_HOLD_EXIT, VERTICAL_SWEEP, STRAFE_EXIT }

@export var mode: Mode = Mode.LINEAR
@export var direction: Vector2 = Vector2.LEFT
@export_range(0.0, 1000.0, 5.0) var speed: float = 180.0
@export_group("Sine")
@export_range(0.0, 500.0, 5.0) var amplitude: float = 100.0
@export_range(0.05, 5.0, 0.05) var frequency: float = 0.5
@export_group("Enter / hold / exit")
@export var hold_position: Vector2 = Vector2(1220, 532)
@export_range(0.0, 300.0, 0.1) var hold_seconds: float = 4.0
@export var stay_forever: bool = false
@export var exit_direction: Vector2 = Vector2.LEFT
## Follow arena scrolling while entering/holding; exit remains in world space.
@export var follow_scroll: bool = false
