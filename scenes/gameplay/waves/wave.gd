@tool
class_name EnemyWave
extends Node2D
## Place a Path2D child to author a route. All times use simulation time.

enum DropMode { NONE, GUARANTEED, CHANCE }
@export_range(0.0, 600.0, 0.5) var start_time: float = 0.0
@export var enemy_scene: PackedScene
@export_range(1, 100) var count: int = 5
@export_range(0.05, 20.0, 0.05) var interval: float = 0.4
@export var spawn_offset: Vector2 = Vector2(0, 0)
@export var drop_mode: DropMode = DropMode.NONE
@export var drop_scene: PackedScene
@export_range(0.0, 1.0, 0.05) var drop_chance: float = 0.5
var emitted: int = 0

func advance(elapsed: float, spawn: Callable) -> void:
	if enemy_scene == null:
		return
	while emitted < count and elapsed >= start_time + emitted * maxf(interval, 0.05):
		spawn.call(self, emitted)
		emitted += 1

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if enemy_scene == null:
		warnings.append("Enemy Scene에 적 씬을 연결하세요.")
	if drop_mode != DropMode.NONE and drop_scene == null:
		warnings.append("드롭을 사용하려면 Drop Scene을 연결하세요.")
	var route := get_node_or_null("Path2D") as Path2D
	if route != null and (route.curve == null or route.curve.get_baked_length() <= 0):
		warnings.append("Path2D에 길이가 있는 이동 경로를 그려주세요.")
	return warnings
