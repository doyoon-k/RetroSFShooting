@tool
class_name HangarPilot
extends TextureButton
## A selectable slice of SixPilot.png. Atlas regions retain the shared floor line.

@export var pilot: PilotData:
	set(value):
		if pilot != null and pilot.changed.is_connected(_refresh):
			pilot.changed.disconnect(_refresh)
		pilot = value
		if pilot != null:
			pilot.changed.connect(_refresh)
		_refresh()

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	tooltip_text = "%s 정보 (Enter / A)" % pilot.callsign if pilot != null else ""
