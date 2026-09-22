class_name TypewriterLabel
extends RichTextLabel

@export_range(1.0, 200.0, 1.0) var characters_per_second: float = 42.0
var progress: float = 0.0
var typing: bool = false

func reveal(message: String) -> void:
	text = message
	visible_characters = 0
	progress = 0.0
	typing = not message.is_empty()

func complete() -> void:
	visible_characters = -1
	typing = false

func _process(delta: float) -> void:
	if not typing:
		return
	progress += delta * characters_per_second
	visible_characters = int(progress)
	if visible_characters >= get_total_character_count():
		complete()

