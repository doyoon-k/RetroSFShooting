class_name SoundEffects
extends Node
## Persistent one-shot players; streams and levels are editable in the autoload scene.

signal cue_played(cue: StringName)

var _last_play_frame: Dictionary = {}
var _last_ui_action_frame: int = -1
var _navigation_target: int = 0
var _shutting_down: bool = false

static func instance() -> SoundEffects:
	var tree := Engine.get_main_loop() as SceneTree
	var bank := tree.root.get_node_or_null("Sfx") as SoundEffects
	# Custom SceneTree test runners do not initialize project autoloads.
	if bank == null:
		bank = (load("res://scenes/audio/sound_effects.tscn") as PackedScene).instantiate() as SoundEffects
		tree.root.add_child(bank)
	return bank

static func play(cue: StringName) -> void:
	instance()._play(cue)

static func bind_navigation(button: BaseButton) -> void:
	instance()._bind_navigation(button)

static func shutdown() -> void:
	await instance()._shutdown()

func _shutdown() -> void:
	_shutting_down = true
	for player: AudioStreamPlayer in get_children():
		player.stop()
	# Give the audio thread time to release stopped voices before engine teardown.
	# Use wall time because --fixed-fps can run many frames between audio mixes.
	var deadline := Time.get_ticks_msec() + 100
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

func _play(cue: StringName) -> void:
	if _shutting_down:
		return
	var player := get_node_or_null(NodePath(cue)) as AudioStreamPlayer
	if player == null or player.stream == null:
		return
	if player.process_mode == Node.PROCESS_MODE_PAUSABLE and get_tree().paused:
		return
	var frame := Engine.get_process_frames()
	if _last_play_frame.get(cue, -1) == frame:
		return
	if cue == &"warning" and player.playing:
		return
	if cue == &"ui_confirm" or cue == &"ui_cancel":
		_last_ui_action_frame = frame
		$ui_move.stop()
	_last_play_frame[cue] = frame
	player.play()
	cue_played.emit(cue)

func _bind_navigation(button: BaseButton) -> void:
	var callback := _queue_navigation.bind(button)
	if not button.focus_entered.is_connected(callback):
		button.focus_entered.connect(callback)
	if not button.mouse_entered.is_connected(callback):
		button.mouse_entered.connect(callback)

func _queue_navigation(button: BaseButton) -> void:
	if _shutting_down or button.disabled or not button.is_visible_in_tree():
		return
	if _navigation_target == button.get_instance_id():
		return
	_navigation_target = button.get_instance_id()
	_play_navigation.call_deferred(weakref(button), Engine.get_process_frames())

func _play_navigation(target: WeakRef, requested_frame: int) -> void:
	var button := target.get_ref() as BaseButton
	if button == null or button.disabled or not button.is_visible_in_tree():
		return
	# A click can focus and activate a button in the same frame. Prefer its action.
	if _last_ui_action_frame >= requested_frame:
		return
	_play(&"ui_move")
