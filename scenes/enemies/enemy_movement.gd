class_name EnemyMovement
extends Node
## Exactly one movement mode writes the actor position.

enum Mode { LINEAR, PATH, SINE, ENTER_HOLD_EXIT }
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
var path: Path2D
var path_offset: Vector2 = Vector2.ZERO
var distance: float = 0.0
var age: float = 0.0
var hold_elapsed: float = 0.0
var reached_hold: bool = false
var origin: Vector2
var actor: Node2D

func _ready() -> void:
	actor = get_parent() as Node2D
	origin = actor.position

func use_path(route: Path2D, offset: Vector2 = Vector2.ZERO) -> void:
	path = route
	path_offset = offset
	mode = Mode.PATH
	distance = 0.0

func _physics_process(delta: float) -> void:
	age += delta
	match mode:
		Mode.LINEAR:
			actor.position += direction.normalized() * speed * delta
		Mode.PATH:
			if not is_instance_valid(path) or path.curve == null:
				return
			distance += speed * delta
			actor.global_position = path.to_global(path.curve.sample_baked(distance)) + path_offset
			if distance >= path.curve.get_baked_length():
				actor.queue_free()
		Mode.SINE:
			var forward := direction.normalized()
			actor.position = origin + forward * speed * age + forward.orthogonal() * sin(age * TAU * frequency) * amplitude
		Mode.ENTER_HOLD_EXIT:
			if not reached_hold:
				actor.position = actor.position.move_toward(hold_position, speed * delta)
				reached_hold = actor.position.is_equal_approx(hold_position)
			elif not stay_forever:
				hold_elapsed += delta
				if hold_elapsed >= hold_seconds:
					actor.position += exit_direction.normalized() * speed * delta
