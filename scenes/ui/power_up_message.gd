class_name PowerUpMessage
extends Node2D

@export_range(0.1, 3.0, 0.05) var duration: float = 0.8
@export_range(0.0, 100.0, 1.0) var rise_distance: float = 28.0
@export_range(0.0, 200.0, 1.0) var ship_offset: float = 85.0
@export_range(80.0, 300.0, 1.0) var display_width: float = 170.0
var elapsed: float = 0.0
var start_position: Vector2
@onready var visual: Sprite2D = $Visual
@onready var shadow: Sprite2D = $Shadow

func _ready() -> void:
	clear()

func show_at(ship_position: Vector2, playfield: Rect2, extra_clearance: float = 0.0) -> void:
	var factor := display_width / visual.texture.get_width()
	visual.scale = Vector2.ONE * factor
	shadow.scale = visual.scale
	var half_size := visual.texture.get_size() * factor * 0.5 + Vector2(3, 3)
	var safe_area := playfield.grow(-6.0)
	var offset := ship_offset + extra_clearance
	start_position = ship_position + Vector2(0, -offset)
	if start_position.y - half_size.y - rise_distance < safe_area.position.y:
		start_position.y = ship_position.y + offset + rise_distance
	# Reserve room for the full upward drift, including at the screen edges.
	start_position = start_position.clamp(safe_area.position + half_size + Vector2(0, rise_distance), safe_area.end - half_size)
	position = start_position
	elapsed = 0.0
	modulate.a = 1.0
	show()
	set_process(true)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		clear()
		return
	var progress := elapsed / duration
	position = start_position + Vector2.UP * rise_distance * progress
	modulate.a = 1.0 - smoothstep(0.45, 1.0, progress)

func clear() -> void:
	hide()
	set_process(false)
