class_name AttackPattern
extends Resource
## Describes an attack, never stores an emitter's timer or target.

enum Aim { FIXED, LOCK_ON_START, TRACK_EACH_VOLLEY }
enum Shape { FAN, RING, CURTAIN }

@export var display_name: String = "Aimed shot"
@export var projectile_scene: PackedScene
@export var aim: Aim = Aim.TRACK_EACH_VOLLEY
@export var shape: Shape = Shape.FAN
@export_range(1, 64) var bullet_count: int = 1
@export_range(0.0, 360.0, 1.0) var spread_degrees: float = 45.0
@export_range(-360.0, 360.0, 1.0) var angle_degrees: float = 180.0
@export_range(-180.0, 180.0, 1.0) var aim_offset_degrees: float = 0.0
@export_range(1, 100) var volley_count: int = 1
@export_range(0.02, 10.0, 0.01) var volley_interval: float = 0.2
@export_range(-180.0, 180.0, 1.0) var rotation_per_volley: float = 0.0
@export_range(0.05, 20.0, 0.05) var recovery: float = 1.5
@export_group("Fleet geometry")
## World-pixel offsets: independent of the ship's visual scale.
@export var muzzle_offsets: Array[Vector2] = [Vector2.ZERO]
@export_range(0.15, 0.85, 0.01) var corridor_center: float = 0.5
@export_range(0.0, 0.3, 0.01) var corridor_shift: float = 0.18
@export_range(100.0, 400.0, 5.0) var corridor_width: float = 180.0

func corridor_y(arena: Rect2, volley: int) -> float:
	return arena.position.y + arena.size.y * clampf(corridor_center + sin(volley * PI * 0.5) * corridor_shift, 0.15, 0.85)

func shots_for_volley(origin: Vector2, arena: Rect2, angle: float, volley: int) -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	if shape == Shape.CURTAIN:
		var gap := corridor_y(arena, volley)
		for index in bullet_count:
			var y := arena.position.y + 45.0 + (arena.size.y - 90.0) * index / maxi(1, bullet_count - 1)
			if absf(y - gap) < corridor_width * 0.5: continue
			shots.append({"position": Vector2(origin.x, y), "angle": angle})
	else:
		for offset in muzzle_offsets:
			for shot_angle in angles_for_volley(angle, volley):
				shots.append({"position": origin + offset, "angle": shot_angle})
	return shots

func angles_for_volley(base_angle: float, volley: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	var center := base_angle + deg_to_rad(rotation_per_volley * volley)
	for i in bullet_count:
		var offset := 0.0
		if shape == Shape.RING:
			offset = TAU * float(i) / float(bullet_count)
		elif bullet_count > 1:
			offset = deg_to_rad(spread_degrees) * (float(i) / (bullet_count - 1) - 0.5)
		result.append(center + offset)
	return result
