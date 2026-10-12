@tool
class_name SiegeShooter
extends EnemyShooter
## M1 cycles keep their own hazards and wait for them before the counter window.
## An explicit lab attack override still uses EnemyShooter's ordinary sequence.

signal cycle_started(index: int)
signal counter_window_started(index: int)

enum Cycle { LURE, CROSS, CORE, RICOCHET }
enum Phase { WAIT, LURE, DEPLOY, WALL, WAIT_WALL, CROSS, RELEASE, WAIT_CLEAR, RECOVERY, RICOCHET }

@export var wall_cycles_enabled: bool = true
@export var opening_bullet_scene: PackedScene
@export var cross_bullet_scene: PackedScene
@export var core_scene: PackedScene
@export var ricochet_step: PatternStep
@export_range(0.1, 2.0, 0.05) var lure_interval: float = 0.45
@export_range(0.1, 2.0, 0.05) var opening_pause: float = 0.6
@export_range(0.1, 2.0, 0.05) var cross_interval: float = 0.35
@export_range(10.0, 40.0, 1.0) var cross_angle_degrees: float = 24.0
@export_range(0.1, 2.0, 0.05) var core_stagger: float = 0.6
@export_range(1.0, 5.0, 0.1) var counter_seconds: float = 2.0

var cycle_index: int = Cycle.RICOCHET
var cycle_phase: Phase = Phase.WAIT
var cycles_completed: int = 0
var _extra_volley: int = 0
var _lure_angle: float = PI
var _active: Array[Projectile] = []
var _walls: Array[CurtainBullet] = []
var _core_pair: Array[BroodCore] = []

func set_sequence(sequence: Array[PatternStep]) -> void:
	_cancel_held_cores()
	wall_cycles_enabled = false
	super.set_sequence(sequence)

func can_fire() -> bool:
	if wall_cycles_enabled:
		var ship := get_parent() as EnemyShip
		if ship != null and ship.movement != null and ship.movement.mode == EnemyMovement.Mode.ENTER_HOLD_EXIT and not ship.movement.reached_hold:
			return false
	return super.can_fire()

func _physics_process(delta: float) -> void:
	if not wall_cycles_enabled:
		super._physics_process(delta)
		return
	if steps.is_empty() or steps[0] == null or steps[0].pattern == null or not is_instance_valid(projectiles):
		return
	if not can_fire():
		_cancel_held_cores()
		cycle_phase = Phase.WAIT
		starting = true
		warning = false
		volley = 0
		timer = maxf(timer, 0.15)
		queue_redraw()
		return
	_prune_hazards()
	timer = maxf(0.0, timer - delta)
	var previews := cycle_phase in [Phase.LURE, Phase.DEPLOY, Phase.WALL, Phase.CROSS, Phase.RICOCHET]
	warning = previews and timer > 0.0 and timer <= _cycle_warning_seconds()
	queue_redraw()
	if timer > 0.0:
		return
	match cycle_phase:
		Phase.WAIT:
			_begin_cycle()
		Phase.LURE:
			_spawn_shot(opening_bullet_scene, global_position, _lure_angle, 450.0)
			volleys_fired += 1
			_extra_volley += 1
			if _extra_volley < 2:
				_schedule(Phase.LURE, lure_interval)
			else:
				bursts_completed += 1
				_schedule(Phase.WALL, opening_pause + telegraph_seconds)
		Phase.DEPLOY:
			_deploy_cores()
			volleys_fired += 1
			bursts_completed += 1
			_schedule(Phase.WALL, opening_pause + telegraph_seconds)
		Phase.WALL:
			var before := projectiles.get_child_count()
			_fire_volley(steps[0].pattern, PI)
			for index in range(before, projectiles.get_child_count()):
				var bullet := projectiles.get_child(index) as CurtainBullet
				if bullet != null:
					_track(bullet)
					_walls.append(bullet)
			volley += 1
			if volley < steps[0].pattern.volley_count:
				_schedule(Phase.WALL, steps[0].pattern.volley_interval)
			else:
				bursts_completed += 1
				volley = 0
				_schedule(Phase.WAIT_WALL, 0.0)
		Phase.WAIT_WALL:
			if not _walls.is_empty():
				return
			match cycle_index:
				Cycle.LURE:
					_schedule(Phase.WAIT_CLEAR, 0.0)
				Cycle.CROSS:
					_extra_volley = 0
					_schedule(Phase.CROSS, telegraph_seconds)
				Cycle.CORE:
					_release_core(0)
					_schedule(Phase.RELEASE, core_stagger)
		Phase.CROSS:
			for side in [-1.0, 1.0]:
				var point := _cross_muzzle(side)
				_spawn_shot(cross_bullet_scene, point, PI + side * deg_to_rad(cross_angle_degrees), 400.0)
			volleys_fired += 1
			_extra_volley += 1
			if _extra_volley < 3:
				_schedule(Phase.CROSS, cross_interval)
			else:
				bursts_completed += 1
				_schedule(Phase.WAIT_CLEAR, 0.0)
		Phase.RELEASE:
			_release_core(1)
			_schedule(Phase.WAIT_CLEAR, 0.0)
		Phase.RICOCHET:
			if ricochet_step != null and ricochet_step.pattern != null:
				var core := _spawn_shot(ricochet_step.pattern.projectile_scene, global_position, locked_angle) as RicochetCore
				if core != null: core.offspring_spawned.connect(_track)
				volleys_fired += 1
				bursts_completed += 1
			_schedule(Phase.WAIT_CLEAR, 0.0)
		Phase.WAIT_CLEAR:
			if _active.is_empty():
				cycles_completed += 1
				starting = true
				var recovery := ricochet_step.pattern.recovery if cycle_index == Cycle.RICOCHET and ricochet_step != null and ricochet_step.pattern != null else counter_seconds
				_schedule(Phase.RECOVERY, recovery)
				counter_window_started.emit(cycle_index)
		Phase.RECOVERY:
			cycle_index = (cycle_index + 1) % Cycle.size()
			_begin_cycle()

func _begin_cycle() -> void:
	if cycle_index != Cycle.RICOCHET: _choose_curtain_route(steps[0].pattern)
	locked_angle = PI
	volley = 0
	_extra_volley = 0
	_core_pair.clear()
	starting = false
	_lure_angle = PI
	if target_provider.is_valid():
		var target: Node2D = target_provider.call()
		if is_instance_valid(target):
			_lure_angle = global_position.direction_to(target.global_position).angle()
	var first: Phase = Phase.LURE if cycle_index == Cycle.LURE else (Phase.WALL if cycle_index == Cycle.CROSS else Phase.DEPLOY)
	if cycle_index == Cycle.RICOCHET:
		first = Phase.RICOCHET
		locked_angle = RicochetCore.launch_direction(global_position, bounds, ricochet_starts_above).angle()
	_schedule(first, _cycle_warning_seconds())
	cycle_started.emit(cycle_index)

func _schedule(next: Phase, delay: float) -> void:
	cycle_phase = next
	timer = maxf(0.0, delay)
	warning = next in [Phase.LURE, Phase.DEPLOY, Phase.WALL, Phase.CROSS, Phase.RICOCHET] and timer > 0.0 and timer <= _cycle_warning_seconds()
	queue_redraw()

func _cycle_warning_seconds() -> float:
	if cycle_index == Cycle.RICOCHET and ricochet_step != null and ricochet_step.pattern != null:
		if ricochet_step.pattern.telegraph_seconds >= 0.0:
			return ricochet_step.pattern.telegraph_seconds
	return telegraph_seconds

func _spawn_shot(scene: PackedScene, point: Vector2, angle: float, speed: float = 0.0) -> Projectile:
	if scene == null or not bounds.grow(-16.0).has_point(point):
		return null
	var bullet := scene.instantiate() as Projectile
	bullet.direction = Vector2.from_angle(angle)
	bullet.bounds = bounds
	bullet.position = projectiles.to_local(point)
	if bullet is RicochetCore:
		bullet.starts_above = ricochet_starts_above
		ricochet_starts_above = not ricochet_starts_above
	if speed > 0.0: bullet.speed = speed
	projectiles.add_child(bullet)
	_track(bullet)
	return bullet

func _deploy_cores() -> void:
	for fraction in [0.16, 0.84]:
		var point := Vector2(global_position.x, bounds.position.y + bounds.size.y * fraction)
		var core := _spawn_shot(core_scene, point, PI) as BroodCore
		if core != null:
			core.hatch_held = true
			core.offspring_spawned.connect(_track)
		_core_pair.append(core)

func _release_core(index: int) -> void:
	if index >= _core_pair.size(): return
	var core := _core_pair[index]
	if is_instance_valid(core) and not core.is_queued_for_deletion():
		core.hatch_held = false

func _track(bullet: Projectile) -> void:
	_active.append(bullet)

func _prune_hazards() -> void:
	for index in range(_active.size() - 1, -1, -1):
		if not is_instance_valid(_active[index]) or _active[index].is_queued_for_deletion():
			_active.remove_at(index)
	for index in range(_walls.size() - 1, -1, -1):
		if not is_instance_valid(_walls[index]) or _walls[index].is_queued_for_deletion():
			_walls.remove_at(index)

func _cancel_held_cores() -> void:
	for core in _core_pair:
		if is_instance_valid(core) and core.hatch_held:
			core.queue_free()
	_core_pair.clear()

func _exit_tree() -> void:
	_cancel_held_cores()

func _cross_muzzle(side: float) -> Vector2:
	return Vector2(global_position.x, bounds.position.y + bounds.size.y * (0.23 if side < 0.0 else 0.77))

func _draw() -> void:
	if not wall_cycles_enabled or cycle_phase == Phase.WALL:
		super._draw()
		return
	if not warning or Engine.is_editor_hint(): return
	if cycle_phase == Phase.RICOCHET:
		_draw_ricochet_charge(1.0 - clampf(timer / maxf(_cycle_warning_seconds(), 0.01), 0.0, 1.0))
		return
	var tint := Color(1.0, 0.95, 0.5, 0.9)
	if cycle_phase == Phase.LURE:
		var forward := Vector2.from_angle(_lure_angle - global_rotation)
		draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 24, tint, 2.5)
		draw_line(forward * 12.0, forward * 48.0, tint, 2.0)
	elif cycle_phase == Phase.CROSS:
		for side in [-1.0, 1.0]:
			var point := _cross_muzzle(side)
			var direction := Vector2.from_angle(PI + side * deg_to_rad(cross_angle_degrees))
			draw_arc(to_local(point), 8.0, 0.0, TAU, 16, tint, 2.0)
			draw_line(to_local(point), to_local(point + direction * 240.0), tint, 2.0)
	elif cycle_phase == Phase.DEPLOY:
		for fraction in [0.16, 0.84]:
			var point := Vector2(global_position.x, bounds.position.y + bounds.size.y * fraction)
			draw_arc(to_local(point), 8.0, 0.0, TAU, 16, tint, 2.0)
