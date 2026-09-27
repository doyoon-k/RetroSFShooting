class_name PilotPortrait
extends Button

var pilot: PilotData

func display(data: PilotData, portrait_texture: Texture2D, active: bool, alive: bool, survived: bool = false) -> void:
	pilot = data
	$Portrait.texture = portrait_texture
	$PilotName.text = data.display_name
	$Status.text = "LOST" if not alive else ("IN FLIGHT" if active else data.callsign)
	if alive and survived:
		$Status.text = "SURVIVED"
	$Status.modulate = Color("ff7c81") if not alive else data.accent
	$Accent.color = data.accent if alive else Color("5e5368")
	tooltip_text = data.description
