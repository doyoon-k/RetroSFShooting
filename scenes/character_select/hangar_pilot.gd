@tool
class_name HangarPilot
extends Node2D

@export var pilot: PilotData:
	set(value):
		if pilot != null and pilot.changed.is_connected(_refresh):
			pilot.changed.disconnect(_refresh)
		pilot = value
		if pilot != null:
			pilot.changed.connect(_refresh)
		_refresh()

@onready var portrait: Sprite2D = $Portrait
@onready var name_label: Label = $Name
@onready var animation: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_refresh()
	if Engine.is_editor_hint() or pilot == null:
		return
	if animation.has_animation(pilot.hangar_animation):
		animation.play(pilot.hangar_animation)

func _refresh() -> void:
	if not is_node_ready():
		return
	if pilot == null:
		portrait.texture = null
		name_label.text = ""
		return
	portrait.texture = pilot.hangar_portrait if pilot.hangar_portrait != null else pilot.normal
	name_label.text = pilot.callsign
