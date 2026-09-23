@tool
class_name EnemyWave
extends Marker2D
## Position and Spawn Offset place enemies in world space. A Path2D child adds a route.

enum DropMode { NONE, GUARANTEED, CHANCE }
@export var enemy_scene: PackedScene
@export_range(1, 100) var count: int = 5
@export var spawn_offset: Vector2 = Vector2(0, 0)
@export var drop_mode: DropMode = DropMode.NONE
@export var drop_scene: PackedScene
@export_range(0.0, 1.0, 0.05) var drop_chance: float = 0.5
var emitted: int = 0
var spawned: Dictionary = {}

func advance(activation_x: float, spawn: Callable) -> void:
	if enemy_scene == null:
		return
	var route := get_node_or_null("Path2D") as Path2D
	var start_x := global_position.x
	if route != null and route.curve != null:
		start_x = route.to_global(route.curve.sample_baked(0.0)).x
	for index in count:
		if not spawned.has(index) and start_x + spawn_offset.x * index <= activation_x:
			spawned[index] = true
			emitted += 1
			spawn.call(self, index)

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
