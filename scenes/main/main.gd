extends Node
## Owns screen lifetimes and the current run. Combat lives entirely in Stage.

@export var catalog: GameCatalog
@export var title_scene: PackedScene
@export var story_scene: PackedScene
@export var select_scene: PackedScene
@export var stage_scene: PackedScene
@export var result_scene: PackedScene
var run: RunState
var current_screen: Node
@onready var save_store: SaveStore = $SaveStore

func _ready() -> void:
	save_store.load_progress()
	show_title()

func _replace(screen: Node) -> void:
	get_tree().paused = false
	if is_instance_valid(current_screen):
		$ScreenHost.remove_child(current_screen)
		current_screen.queue_free()
	current_screen = screen
	$ScreenHost.add_child(screen)
	%Fade.modulate.a = 1.0
	create_tween().tween_property(%Fade, "modulate:a", 0.0, 0.3)

func show_title() -> void:
	run = null
	var screen := title_scene.instantiate()
	screen.catalog = catalog
	screen.unlocked = save_store.unlocked.duplicate()
	screen.new_game_requested.connect(start_new_game, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	_replace(screen)

func start_new_game() -> void:
	run = RunState.new(catalog)
	var screen := story_scene.instantiate()
	screen.story = catalog.intro
	screen.finished.connect(show_select, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	_replace(screen)

func show_select() -> void:
	var screen := select_scene.instantiate()
	screen.catalog = catalog
	screen.run = run
	screen.sortie_requested.connect(start_stage, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	_replace(screen)

func start_stage(id: StringName) -> void:
	if not run.begin_sortie(id):
		return
	var screen := stage_scene.instantiate()
	screen.catalog = catalog
	screen.run = run
	screen.completed.connect(show_ending, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	_replace(screen)

func show_ending() -> void:
	run.ending_id = EndingResolver.resolve(run)
	var ending := catalog.ending_by_id(run.ending_id)
	if ending == null:
		push_error("No ending matches the completed run.")
		return
	var screen := story_scene.instantiate()
	screen.story = ending.story
	screen.finished.connect(show_result, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	_replace(screen)

func show_result() -> void:
	var screen := result_scene.instantiate()
	screen.run = run
	screen.ending = catalog.ending_by_id(run.ending_id)
	screen.save_error = save_store.unlock(run.ending_id)
	screen.return_requested.connect(show_title, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	_replace(screen)
