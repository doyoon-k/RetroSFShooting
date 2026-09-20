extends Node

@onready var resolution_label: Label = %ResolutionLabel


func _ready() -> void:
	get_viewport().size_changed.connect(_update_resolution_label)
	_update_resolution_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().quit()


func _update_resolution_label() -> void:
	var visible_size := get_viewport().get_visible_rect().size
	resolution_label.text = "Viewport: %d × %d" % [
		roundi(visible_size.x),
		roundi(visible_size.y),
	]

