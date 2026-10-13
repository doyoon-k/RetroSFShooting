class_name RicochetCore
extends Projectile
## A fixed bank shot: top/left/bottom or its vertical mirror, one generation only.
signal offspring_spawned(child: Projectile)
signal banked(index: int, wall: Vector2)

const EDGE_INSET := 64.0
const MAX_BANKS := 3
const CUE_COLOR := Color(1.0, 0.85, 0.35, 0.95)

@export var child_scene: PackedScene
@export var starts_above := true
@export_range(0.1, 1.0, 0.05) var bank_warning_seconds := 0.45
@export_range(0.1, 0.8, 0.05) var bank_pause_seconds := 0.18
@export_range(0.5, 1.0, 0.01) var speed_retention := 0.96
@export_range(1, 15) var child_count := 7
@export_range(1, 15) var middle_child_count := 9
@export_range(1, 15) var final_child_count := 11
@export_range(20.0, 90.0, 1.0) var child_spread := 70.0
@export_range(50.0, 600.0, 10.0) var child_speed := 360.0
@export_range(0.5, 5.0, 0.1) var child_lifetime := 3.8
@export var aimed_fans := true
var bank_count := 0
var bank_wait := 0.0
var bank_arena: Rect2
var _bank_normal := Vector2.ZERO
var _fan_bank := 0
var _fan_center := Vector2.ZERO
@onready var visual: Sprite2D = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D
var _visual_scale := Vector2.ONE

static func reflection_bounds(arena: Rect2) -> Rect2:
	return arena.grow(-EDGE_INSET)

static func launch_direction(origin: Vector2, arena: Rect2, above: bool) -> Vector2:
	var field := reflection_bounds(arena)
	# Unfold the first two banks to put the left-wall contact at mid-height.
	var vertical := origin.y - field.position.y if above else field.end.y - origin.y
	var horizontal := maxf(1.0, origin.x - field.position.x)
	return Vector2(-horizontal, (-1.0 if above else 1.0) * (vertical + field.size.y * 0.5)).normalized()

static func fan_direction(outgoing: Vector2, normal: Vector2, spread: float) -> Vector2:
	# Shallow bank shots still put the entire fan inside the arena.
	var limit := PI * 0.5 - deg_to_rad(spread) * 0.5
	var offset := wrapf(outgoing.angle() - normal.angle(), -PI, PI)
	return Vector2.from_angle(normal.angle() + clampf(offset, -limit, limit))

func _ready() -> void:
	bank_arena = reflection_bounds(bounds)
	direction = launch_direction(global_position, bounds, starts_above)
	super._ready()
	_visual_scale = visual.scale
	if not bank_arena.has_area() or not bank_arena.has_point(global_position):
		queue_free()
	queue_redraw()

func next_bank() -> Dictionary:
	var distance := INF
	var normal := Vector2.ZERO
	if absf(direction.x) > 0.0001:
		var wall_x := bank_arena.position.x if direction.x < 0.0 else bank_arena.end.x
		distance = maxf(0.0, (wall_x - global_position.x) / direction.x)
		normal = Vector2.RIGHT if direction.x < 0.0 else Vector2.LEFT
	if absf(direction.y) > 0.0001:
		var wall_y := bank_arena.position.y if direction.y < 0.0 else bank_arena.end.y
		var vertical := maxf(0.0, (wall_y - global_position.y) / direction.y)
		if vertical < distance:
			distance = vertical
			normal = Vector2.DOWN if direction.y < 0.0 else Vector2.UP
	return {"position": global_position + direction * distance, "normal": normal, "distance": distance}

func fan_count(index: int) -> int:
	if index >= MAX_BANKS: return final_child_count
	return middle_child_count if index == 2 else child_count

func _lock_fan(bank: Dictionary, index: int) -> void:
	if _fan_bank == index: return
	var outgoing := direction.bounce(bank.normal)
	if aimed_fans and is_instance_valid(target):
		outgoing = Vector2(bank.position).direction_to(target.global_position)
	_fan_center = fan_direction(outgoing, bank.normal, child_spread)
	_fan_bank = index

func _physics_process(delta: float) -> void:
	if spent or is_queued_for_deletion(): return
	age += delta
	lifetime -= delta
	if lifetime <= 0.0 or not bounds.grow(despawn_margin).has_point(global_position):
		queue_free()
		return
	var remaining := delta
	while remaining > 0.00001 and not is_queued_for_deletion():
		if bank_wait > 0.0:
			var elapsed := minf(bank_wait, remaining)
			bank_wait = maxf(0.0, bank_wait - elapsed)
			remaining -= elapsed
			if bank_wait <= 0.00001:
				bank_wait = 0.0
				_emit_fan()
				if bank_count >= MAX_BANKS:
					queue_free()
					return
		else:
			var bank := next_bank()
			var travel := float(bank.distance) / maxf(speed, 1.0)
			if travel <= bank_warning_seconds: _lock_fan(bank, bank_count + 1)
			if travel > remaining:
				global_position += direction * speed * remaining
				remaining = 0.0
			else:
				_lock_fan(bank, bank_count + 1)
				global_position = bank.position
				remaining -= travel
				direction = direction.bounce(bank.normal)
				_bank_normal = bank.normal
				bank_count += 1
				speed *= speed_retention
				bank_wait = bank_pause_seconds
				banked.emit(bank_count, bank.normal)
				if bank_count == MAX_BANKS:
					# The final cue remains visible, but the exhausted core cannot hit.
					collision_layer = 0
					collision_mask = 0
					visual.visible = false
	rotation = direction.angle()
	var size_factor := 1.0 - 0.14 * mini(bank_count, MAX_BANKS - 1)
	visual.scale = _visual_scale * size_factor
	collision.scale = Vector2.ONE * size_factor
	if bank_wait <= 0.0:
		var upcoming := next_bank()
		if float(upcoming.distance) / maxf(speed, 1.0) <= bank_warning_seconds:
			_lock_fan(upcoming, bank_count + 1)
	queue_redraw()

func _emit_fan() -> void:
	if spent or is_queued_for_deletion() or child_scene == null: return
	var count := fan_count(bank_count)
	var center := _fan_center
	for index in count:
		var child := child_scene.instantiate() as Projectile
		if child == null: continue
		if child is RicochetCore or child is BroodCore:
			child.free()
			continue
		var offset := deg_to_rad(child_spread) * (float(index) / maxi(1, count - 1) - 0.5) if count > 1 else 0.0
		child.direction = center.rotated(offset)
		child.bounds = bounds
		child.position = get_parent().to_local(global_position + child.direction * 18.0)
		child.speed = child_speed
		child.lifetime = child_lifetime
		get_parent().add_child(child)
		offspring_spawned.emit(child)

func _draw() -> void:
	if spent or is_queued_for_deletion() or not is_node_ready(): return
	if bank_count < MAX_BANKS:
		var radius := 18.0 * (1.0 - 0.14 * bank_count)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, CUE_COLOR, 1.3)
		for index in MAX_BANKS - bank_count:
			draw_circle(Vector2(-radius - 5.0, (index - (MAX_BANKS - bank_count - 1) * 0.5) * 5.0), 1.5, CUE_COLOR)
	var point := global_position
	var outgoing := direction
	var normal := _bank_normal
	var until_bank := 0.0
	var next_count := bank_count
	if bank_wait <= 0.0:
		var bank := next_bank()
		until_bank = float(bank.distance) / maxf(speed, 1.0)
		if until_bank > bank_warning_seconds: return
		point = bank.position
		outgoing = direction.bounce(bank.normal)
		normal = bank.normal
		next_count += 1
	var count := fan_count(next_count)
	outgoing = _fan_center if _fan_bank == next_count else fan_direction(outgoing, normal, child_spread)
	var alpha := 1.0 - 0.5 * clampf(until_bank / bank_warning_seconds, 0.0, 1.0)
	var tint := Color(CUE_COLOR, alpha)
	var world_scale := maxf(global_scale.abs().x, 0.01)
	draw_arc(to_local(point), 32.0 / world_scale, 0.0, TAU, 24, tint, 2.0 / world_scale)
	for index in count:
		var offset := deg_to_rad(child_spread) * (float(index) / maxi(1, count - 1) - 0.5) if count > 1 else 0.0
		var ray := outgoing.rotated(offset)
		draw_line(to_local(point + ray * 24.0), to_local(point + ray * 105.0), tint, 2.0 / world_scale)
