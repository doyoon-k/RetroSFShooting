extends Control

signal finished
@export var story: StoryData
var page_index: int = 0
var ended: bool = false

func _ready() -> void:
	%Next.pressed.connect(advance)
	_show_page()

func _show_page() -> void:
	if story == null or story.pages.is_empty():
		ended = true
		finished.emit.call_deferred()
		return
	var page := story.pages[page_index]
	%Heading.text = story.title
	%Illustration.texture = page.illustration
	%Caption.text = page.caption
	%StoryText.characters_per_second = story.characters_per_second
	%StoryText.reveal(page.text)
	%PageNumber.text = "%02d / %02d" % [page_index + 1, story.pages.size()]

func advance() -> void:
	if ended:
		return
	if %StoryText.typing:
		%StoryText.complete()
		return
	page_index += 1
	if page_index >= story.pages.size():
		ended = true
		finished.emit()
	else:
		_show_page()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("story_advance") and not event.is_echo():
		get_viewport().set_input_as_handled()
		advance()

