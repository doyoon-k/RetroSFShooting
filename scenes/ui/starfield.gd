@tool
extends Node2D

@export var field_size: Vector2 = Vector2(1920, 1080)
@export_range(0, 500) var star_count: int = 160
@export_range(0.0, 300.0, 1.0) var scroll_speed: float = 28.0
@export var star_color: Color = Color("638ca1")
var points: Array[Vector3] = []

func _ready() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 23091
	for i in star_count:
		points.append(Vector3(random.randf_range(0, field_size.x), random.randf_range(0, field_size.y), random.randf_range(0.4, 1.8)))

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		for i in points.size():
			points[i].x = fposmod(points[i].x - scroll_speed * points[i].z * delta, field_size.x)
	queue_redraw()

func _draw() -> void:
	for point in points:
		draw_circle(Vector2(point.x, point.y), point.z, Color(star_color, minf(1.0, point.z)))

