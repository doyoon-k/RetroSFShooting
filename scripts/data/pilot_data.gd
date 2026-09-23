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
@export var shocked: Texture2D
@export var anxious: Texture2D
@export var angry: Texture2D
@export var despair: Texture2D
@export var alone: Texture2D
@export var victory: Texture2D
@export var dead: Texture2D
@export var cockpit: Texture2D
@export_group("Dialogue")
@export_multiline var death_line: String
@export_multiline var victory_line: String

func portrait(expression: StringName) -> Texture2D:
	var texture: Texture2D = get(String(expression)) as Texture2D
	return texture if texture != null else normal
