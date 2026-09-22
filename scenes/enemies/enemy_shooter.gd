@tool
class_name EnemyShooter
extends Node2D
## Pattern resources are immutable; this node owns every runtime counter.

@export var steps: Array[PatternStep] = []
@export_range(0.0, 10.0, 0.1) var initial_delay: float = 1.0
var projectiles: Node2D
var target_provider: Callable
var bounds: Rect2
var step_index: int = 0
var repetition: int = 0
var volley: int = 0
var timer: float = 0.0
var locked_angle: float = PI
var starting: bool = true

func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	timer = initial_delay

func set_sequence(sequence: Array[PatternStep]) -> void:
	steps = sequence
	step_index = 0
	repetition = 0
	volley = 0
	starting = true
	timer = initial_delay

func _physics_process(delta: float) -> void:
	if steps.is_empty() or not is_instance_valid(projectiles):
		return
	timer -= delta
	if timer > 0.0:
		return
	var step := steps[step_index]
	if step == null or step.pattern == null:
		return
	var pattern := step.pattern
	if starting:
		locked_angle = _aim_angle(pattern)
		starting = false
	var angle := _aim_angle(pattern) if pattern.aim == AttackPattern.Aim.TRACK_EACH_VOLLEY else locked_angle
	_fire_volley(pattern, angle)
	volley += 1
	if volley < pattern.volley_count:
		timer = maxf(0.02, pattern.volley_interval)
		return
	volley = 0
	starting = true
	repetition += 1
	timer = maxf(0.05, pattern.recovery)
	if repetition >= step.repetitions:
		repetition = 0
		timer += step.wait_after
		step_index = (step_index + 1) % steps.size()

func _aim_angle(pattern: AttackPattern) -> float:
	if pattern.aim != AttackPattern.Aim.FIXED and target_provider.is_valid():
		var target: Node2D = target_provider.call()
		if is_instance_valid(target):
			return global_position.direction_to(target.global_position).angle() + deg_to_rad(pattern.aim_offset_degrees)
	return deg_to_rad(pattern.angle_degrees)

func _fire_volley(pattern: AttackPattern, angle: float) -> void:
	if pattern.projectile_scene == null:
		return
	for shot_angle in pattern.angles_for_volley(angle, volley):
		var bullet := pattern.projectile_scene.instantiate() as Projectile
		bullet.direction = Vector2.from_angle(shot_angle)
		bullet.bounds = bounds
		if target_provider.is_valid():
			bullet.target = target_provider.call()
		projectiles.add_child(bullet)
		bullet.global_position = global_position

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if steps.is_empty():
		warnings.append("Steps에 PatternStep을 추가하세요. 빈 목록은 발사하지 않습니다.")
	for step in steps:
		if step == null or step.pattern == null:
			warnings.append("각 Step에 AttackPattern이 필요합니다.")
		elif step.pattern.projectile_scene == null:
			warnings.append("AttackPattern에 탄환 씬을 연결하세요.")
	return warnings
