extends Node2D

@export_range(0.1, 5.0, 0.05) var duration: float = 0.55
@export_range(10.0, 500.0, 5.0) var radius: float = 80.0
@export var color: Color = Color("ffbc70")
var age: float = 0.0

func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= duration:
		queue_free()

func _draw() -> void:
	var t := clampf(age / duration, 0.0, 1.0)
	draw_arc(Vector2.ZERO, radius * t, 0, TAU, 32, Color(color, 1 - t), 4)
	for i in 8:
		var direction := Vector2.from_angle(i * TAU / 8)
		draw_line(direction * radius * t * 0.5, direction * radius * t, Color(color, 1 - t), 3)
