class_name TypewriterLabel
extends RichTextLabel

@export_range(1.0, 200.0, 1.0) var characters_per_second: float = 42.0
## Sfx cue played once per Blip Every revealed characters; empty stays silent.
@export var blip_cue: StringName = &"text_blip"
@export_range(1, 20) var blip_every: int = 3
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
	var previous := progress
	progress += delta * characters_per_second
	visible_characters = int(progress)
	# A closed panel keeps typing in the background; only visible text should blip.
	if not blip_cue.is_empty() and is_visible_in_tree() and floori(progress / blip_every) > floori(previous / blip_every):
		SoundEffects.play(blip_cue)
	if visible_characters >= get_total_character_count():
		complete()

