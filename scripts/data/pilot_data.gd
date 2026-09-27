@tool
class_name PilotData
extends Resource

@export var id: StringName
@export var display_name: String
@export var callsign: String:
	set(value):
		callsign = value
		changed.emit()
@export_multiline var description: String
@export var is_ai: bool = false
@export var accent: Color = Color("6de5ed")
@export var ship_scene: PackedScene
@export var hangar_animation: StringName = &"idle"
@export_group("Portraits")
@export var hangar_portrait: Texture2D:
	set(value):
		hangar_portrait = value
		changed.emit()
@export var normal: Texture2D:
	set(value):
		normal = value
		changed.emit()
@export var one_dead: Texture2D
@export var two_dead: Texture2D
@export var four_dead: Texture2D
@export var damaged: Texture2D
@export var dead: Texture2D
@export_group("Dialogue")
@export_multiline var death_line: String
@export_multiline var victory_line: String

func portrait(dead_count: int, is_damaged: bool = false, is_dead: bool = false) -> Texture2D:
	if is_dead:
		return dead if dead != null else normal
	var normal_texture: Texture2D = normal
	if dead_count >= 4 and four_dead != null:
		normal_texture = four_dead
	elif dead_count >= 2 and two_dead != null:
		normal_texture = two_dead
	elif dead_count >= 1 and one_dead != null:
		normal_texture = one_dead
	return damaged if is_damaged and damaged != null else normal_texture
