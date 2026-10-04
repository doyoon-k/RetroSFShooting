extends PilotPortrait

func _ready() -> void:
	focus_entered.connect(func(): $Selection.show())
	focus_exited.connect(func(): $Selection.hide())
	mouse_entered.connect(func(): $Selection.visible = not disabled)
	mouse_exited.connect(func(): $Selection.visible = has_focus())

func display(data: PilotData, portrait_texture: Texture2D, active: bool, alive: bool, survived: bool = false) -> void:
	super.display(data, portrait_texture, active, alive, survived)
	var in_flight := active and alive and not survived
	$Portrait.visible = not in_flight
	$OnSortie.visible = in_flight
	$Selection.visible = has_focus()
