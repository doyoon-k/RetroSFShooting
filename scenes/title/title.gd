extends Control

signal new_game_requested
@export var catalog: GameCatalog
var unlocked: Array[StringName] = []

func _ready() -> void:
	%NewGame.pressed.connect(func(): new_game_requested.emit())
	%Endings.pressed.connect(_show_endings)
	%Exit.pressed.connect(func(): get_tree().quit())
	%CollectionBack.pressed.connect(_hide_endings)
	%NewGame.grab_focus()

func _show_endings() -> void:
	var lines := PackedStringArray()
	var discovered := 0
	for ending in catalog.endings:
		var known := unlocked.has(ending.id)
		if known:
			discovered += 1
		lines.append("%s    %s" % [ending.number, ending.title if known else "???"])
	%CollectionText.text = "기록 복원  %d / %d\n\n%s" % [discovered, catalog.endings.size(), "\n\n".join(lines)]
	%Collection.show()
	%Menu.hide()
	%CollectionBack.grab_focus()

func _hide_endings() -> void:
	%Collection.hide()
	%Menu.show()
	%Endings.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and %Collection.visible:
		_hide_endings()
		get_viewport().set_input_as_handled()
