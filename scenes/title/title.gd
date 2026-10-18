extends Control

signal new_game_requested
@export var catalog: GameCatalog
@export_range(0.0, 30.0, 0.5) var ship_float_pixels: float = 7.0
@export_range(0.5, 10.0, 0.1) var ship_float_seconds: float = 4.4
var unlocked: Array[StringName] = []
enum State { WAITING, MENU, COLLECTION, STARTING }
var state: State = State.WAITING
var elapsed: float = 0.0
var opening_input: InputEvent
@onready var ship_origin: Vector2 = %Ship.position

const DESIGN_SIZE := Vector2(1920, 1080)

func _ready() -> void:
	%NewGame.pressed.connect(_new_game)
	%Endings.pressed.connect(_show_endings)
	%Exit.pressed.connect(_exit)
	%CollectionBack.pressed.connect(_hide_endings)
	%Menu.hide()
	%Collection.hide()
	%StartPrompt.show()
	resized.connect(_fit_layout)
	_fit_layout()
	for button in [%NewGame, %Endings, %Exit, %CollectionBack]:
		SoundEffects.bind_navigation(button)

func _fit_layout() -> void:
	var ratio := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	%Layout.scale = Vector2.ONE * ratio
	%Layout.position = (size - DESIGN_SIZE * ratio) * 0.5

func _process(delta: float) -> void:
	elapsed += delta
	%Ship.position = ship_origin + Vector2(0, sin(TAU * elapsed / ship_float_seconds) * ship_float_pixels)
	if state == State.WAITING:
		%StartPrompt.modulate.a = 0.88 + 0.12 * cos(TAU * elapsed / 1.8)

func _reveal_menu(event: InputEvent) -> void:
	state = State.MENU
	opening_input = event.duplicate()
	%StartPrompt.hide()
	%Menu.show()
	%NewGame.grab_focus()
	SoundEffects.play(&"ui_confirm")

func _new_game() -> void:
	if state != State.MENU:
		return
	state = State.STARTING
	SoundEffects.play(&"ui_confirm")
	for button in [%NewGame, %Endings, %Exit]:
		button.disabled = true
	new_game_requested.emit()

func _exit() -> void:
	if state == State.MENU:
		state = State.STARTING
		for button in [%NewGame, %Endings, %Exit]:
			button.disabled = true
		await SoundEffects.shutdown()
		get_tree().quit()

func _show_endings() -> void:
	if state != State.MENU:
		return
	state = State.COLLECTION
	SoundEffects.play(&"ui_confirm")
	var lines := PackedStringArray()
	var discovered := 0
	for ending in catalog.endings:
		var known := unlocked.has(ending.id)
		if known:
			discovered += 1
		lines.append("%s    %s" % [ending.number, ending.title if known else "???"])
	%CollectionText.text = "기록 복원  %d / %d\n\n%s" % [discovered, catalog.endings.size(), "\n".join(lines)]
	%Collection.show()
	%Menu.hide()
	%CollectionBack.grab_focus()

func _hide_endings() -> void:
	if state != State.COLLECTION:
		return
	state = State.MENU
	%Collection.hide()
	SoundEffects.play(&"ui_cancel")
	%Menu.show()
	%Endings.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and state == State.COLLECTION:
		_hide_endings()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Consume the opening press, repeats and release before focused menu buttons see them.
	if opening_input != null and _matches_opening_input(event):
		if not event.is_pressed():
			opening_input = null
		get_viewport().set_input_as_handled()
		return
	if state == State.WAITING and _is_start_press(event):
		_reveal_menu(event)
		get_viewport().set_input_as_handled()

func _is_start_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode not in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventMouseButton:
		return event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
	return false

func _matches_opening_input(event: InputEvent) -> bool:
	if event is InputEventKey and opening_input is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		var opening_code: int = opening_input.physical_keycode if opening_input.physical_keycode != 0 else opening_input.keycode
		return code == opening_code
	if event is InputEventJoypadButton and opening_input is InputEventJoypadButton:
		return event.device == opening_input.device and event.button_index == opening_input.button_index
	if event is InputEventMouseButton and opening_input is InputEventMouseButton:
		return event.button_index == opening_input.button_index
	return false
