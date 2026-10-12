@tool
class_name EnemyShooter
extends Node2D
## Pattern resources are immutable; this node owns every runtime counter.

@export var steps: Array[PatternStep] = []
@export_range(0.0, 10.0, 0.1) var initial_delay: float = 1.0
@export_range(0.0, 2.0, 0.05) var telegraph_seconds: float = 0.35
var projectiles: Node2D
var target_provider: Callable
var bounds: Rect2
var step_index: int = 0
var repetition: int = 0
var volley: int = 0
var timer: float = 0.0
var locked_angle: float = PI
var starting: bool = true
var warning: bool = false
var volleys_fired: int = 0
var bursts_completed: int = 0

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
	warning = false
	queue_redraw()
	timer = initial_delay

func _physics_process(delta: float) -> void:
	if steps.is_empty() or not is_instance_valid(projectiles):
		return
	if not can_fire():
		# Re-enter with a readable warning, never release a stored burst off screen.
		warning = false
		starting = true
		volley = 0
		timer = maxf(timer, 0.15)
		queue_redraw()
		return
	timer -= delta
	# Preview later curtain rows during their existing interval, without delaying
	# the burst. The second wall also shows that it will move vertically.
	if not starting and volley > 0 and steps[step_index] != null and steps[step_index].pattern != null:
		if steps[step_index].pattern.shape == AttackPattern.Shape.CURTAIN:
			var next_warning := timer > 0.0 and timer <= telegraph_seconds
			if next_warning != warning:
				warning = next_warning
				queue_redraw()
	if warning:
		queue_redraw()
	if timer > 0.0:
		return
	var step := steps[step_index]
	if step == null or step.pattern == null:
		return
	var pattern := step.pattern
	if starting:
		locked_angle = _aim_angle(pattern)
		starting = false
		if telegraph_seconds > 0.0:
			warning = true
			timer = telegraph_seconds
			queue_redraw()
			return
	warning = false
	queue_redraw()
	var angle := _aim_angle(pattern) if pattern.aim == AttackPattern.Aim.TRACK_EACH_VOLLEY else locked_angle
	_fire_volley(pattern, angle)
	volley += 1
	if volley < pattern.volley_count:
		timer = maxf(0.02, pattern.volley_interval)
		return
	bursts_completed += 1
	volley = 0
	starting = true
	repetition += 1
	timer = maxf(0.05, pattern.recovery)
	if repetition >= step.repetitions:
		repetition = 0
		timer += step.wait_after
		step_index = (step_index + 1) % steps.size()

func can_fire() -> bool:
	if bounds.has_area() and not bounds.grow(-32.0).has_point(global_position):
		return false
	var ship := get_parent() as EnemyShip
	if ship != null and ship.movement != null and ship.movement.mode == EnemyMovement.Mode.STRAFE_EXIT:
		# The strafing battery commits to one firing station, then visibly retreats.
		if not ship.movement.reached_hold or (not ship.movement.stay_forever and ship.movement.hold_elapsed >= ship.movement.hold_seconds):
			return false
	if ship != null and not ship.is_boss and not ship.is_midboss and target_provider.is_valid():
		var target: Node2D = target_provider.call()
		if is_instance_valid(target):
			return global_position.x > target.global_position.x + 80.0 and global_position.distance_to(target.global_position) >= 160.0
	return true

func _draw() -> void:
	if warning and not Engine.is_editor_hint():
		var progress := 1.0 - clampf(timer / maxf(telegraph_seconds, 0.01), 0.0, 1.0)
		var pattern := steps[step_index].pattern
		var tint := Color(1.0, 0.95, 0.5, 0.9)
		if pattern.aim == AttackPattern.Aim.FIXED:
			tint = Color(0.4, 0.95, 1.0, 0.9)
		elif pattern.aim == AttackPattern.Aim.TRACK_EACH_VOLLEY:
			tint = Color(1.0, 0.5, 0.75, 0.9)
		var aim_angle := _aim_angle(pattern) if pattern.aim == AttackPattern.Aim.TRACK_EACH_VOLLEY else locked_angle
		var forward := Vector2.from_angle(aim_angle - global_rotation)
		draw_arc(Vector2.ZERO, lerpf(22.0, 8.0, progress), 0.0, TAU, 24, tint, 2.5)
		draw_line(forward * 12.0, forward * 36.0, tint, 2.0)
		if pattern.shape == AttackPattern.Shape.CURTAIN:
			# Show the upcoming wall's actual remote emitter positions.
			for shot in pattern.shots_for_volley(global_position, bounds, locked_angle, volley):
				if not bounds.grow(-16.0).has_point(shot.position): continue
				var point := to_local(shot.position)
				draw_circle(point, 5.0, tint)
				draw_line(point, point + Vector2.LEFT * 18.0, tint, 2.0)
				if pattern.sway_for_volley(volley) > 0.0:
					for side in [-1.0, 1.0]:
						var tip: Vector2 = shot.position + Vector2(0, side * 22)
						draw_polyline(PackedVector2Array([
							to_local(tip + Vector2(-6, -side * 7)), to_local(tip),
							to_local(tip + Vector2(6, -side * 7))
						]), tint, 1.5)
		else:
			for offset in pattern.muzzle_offsets:
				draw_arc(to_local(global_position + offset), 8.0, 0.0, TAU, 16, tint, 2.0)

func _aim_angle(pattern: AttackPattern) -> float:
	if pattern.aim != AttackPattern.Aim.FIXED and target_provider.is_valid():
		var target: Node2D = target_provider.call()
		if is_instance_valid(target):
			return global_position.direction_to(target.global_position).angle() + deg_to_rad(pattern.aim_offset_degrees)
	return deg_to_rad(pattern.angle_degrees)

func _fire_volley(pattern: AttackPattern, angle: float) -> void:
	if pattern.projectile_scene == null:
		return
	volleys_fired += 1
	for shot in pattern.shots_for_volley(global_position, bounds, angle, volley):
		# Only a curtain's edge continuation may start above/below the arena.
		# Its x emitter must still be visible, and can_fire gates the whole burst.
		var sway := pattern.sway_for_volley(volley)
		var spawn_bounds := bounds.grow(-16.0)
		if sway > 0.0:
			spawn_bounds.position.y = bounds.position.y - sway
			spawn_bounds.size.y = bounds.size.y + sway * 2.0
		if not spawn_bounds.has_point(shot.position): continue
		var bullet := pattern.projectile_scene.instantiate() as Projectile
		bullet.direction = Vector2.from_angle(shot.angle)
		bullet.bounds = bounds
		bullet.position = projectiles.to_local(shot.position)
		if bullet is CurtainBullet:
			bullet.sway_amplitude = sway
			bullet.sway_period = pattern.curtain_sway_period
			bullet.despawn_margin = maxf(bullet.despawn_margin, sway)
		if target_provider.is_valid():
			bullet.target = target_provider.call()
		projectiles.add_child(bullet)

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
