class_name EnemyLab
extends Node2D
## Standalone F6 playground for one enemy, movement, and attack combination.

const BOUNDS := Rect2(48, 100, 1440, 864)
const SPAWN_POSITION := Vector2(1300, 532)

@export var player_scene: PackedScene
@export var enemy_scenes: Array[PackedScene] = []
@export var movement_presets: Array[MovementProfile] = []
@export var attack_presets: Array[AttackSequence] = []

var rules: GameRules
var state: SortieState
var player: PlayerShip
var auto_respawn: bool = true
var respawn_left: float = 0.7

@onready var actors: Node2D = $Actors
@onready var projectiles: Node2D = $Projectiles
@onready var route: Path2D = $Route
@onready var enemy_picker: OptionButton = %EnemyPicker
@onready var movement_picker: OptionButton = %MovementPicker
@onready var attack_picker: OptionButton = %AttackPicker
@onready var power_picker: OptionButton = %PowerPicker
@onready var path_toggle: CheckButton = %PathToggle
@onready var status_label: Label = %Status

func _ready() -> void:
	$Camera2D.make_current()
	rules = load("res://data/rules/default.tres") as GameRules
	_build_route()
	_fill_picker(enemy_picker, enemy_scenes)
	_fill_picker(movement_picker, movement_presets, "Scene default")
	_fill_picker(attack_picker, attack_presets, "Scene default")
	for level in 3:
		power_picker.add_item("LV%d" % (level + 1), level)
	power_picker.select(0)
	power_picker.item_selected.connect(_set_power)
	%Spawn.pressed.connect(spawn_sample)
	%Clear.pressed.connect(clear_sample)
	_spawn_player()
	spawn_sample()

func _process(delta: float) -> void:
	var enemy_count := 0
	for actor in actors.get_children():
		if actor is EnemyShip and not actor.is_queued_for_deletion():
			enemy_count += 1
	if enemy_count == 0 and auto_respawn:
		respawn_left -= delta
		if respawn_left <= 0.0:
			spawn_sample()
	elif enemy_count > 0:
		respawn_left = 0.7
	var hp := state.hp if state != null else 0
	status_label.text = "PLAYER  HP %d/%d  LV%d\nENEMIES %d    BULLETS %d" % [hp, rules.starting_hp, state.current_power_level() if state != null else 1, enemy_count, projectiles.get_child_count()]

func _fill_picker(picker: OptionButton, resources: Array, default_label: String = "") -> void:
	if not default_label.is_empty():
		picker.add_item(default_label, 0)
	for index in resources.size():
		var resource := resources[index] as Resource
		var label := resource.resource_name if not resource.resource_name.is_empty() else resource.resource_path.get_file().get_basename()
		picker.add_item(label.capitalize(), index + (1 if not default_label.is_empty() else 0))
	picker.select(0)

func _build_route() -> void:
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(-300, -220))
	curve.add_point(Vector2(-690, 170))
	curve.add_point(Vector2(-1390, 0))
	route.curve = curve

func _spawn_player() -> void:
	if player_scene == null:
		return
	state = SortieState.new(rules)
	state.power_level = power_picker.get_selected_id() + 1
	player = player_scene.instantiate() as PlayerShip
	player.position = Vector2(260, 532)
	player.state = state
	player.rules = rules
	player.bounds = BOUNDS
	actors.add_child(player)
	player.weapon.state = state
	player.weapon.projectiles = projectiles
	player.weapon.bounds = BOUNDS
	player.died.connect(_on_player_died)

func _on_player_died(_position: Vector2, _powerups: int, _bombs: int) -> void:
	_reset_player.call_deferred()

func _reset_player() -> void:
	if is_instance_valid(player):
		player.queue_free()
	await get_tree().process_frame
	_spawn_player()

func _set_power(index: int) -> void:
	if state != null:
		state.power_level = index + 1
		state.changed.emit()

func get_target() -> Node2D:
	return player if is_instance_valid(player) and not player.death_reported else null

func spawn_sample() -> EnemyShip:
	clear_sample()
	if enemy_scenes.is_empty():
		return null
	var scene := enemy_scenes[enemy_picker.get_selected_id()]
	var enemy := scene.instantiate() as EnemyShip
	if enemy == null:
		return null
	var movement := enemy.get_node("Movement") as EnemyMovement
	if movement_picker.get_selected_id() > 0:
		movement.apply_profile(movement_presets[movement_picker.get_selected_id() - 1])
	if attack_picker.get_selected_id() > 0:
		enemy.apply_attack_sequence(attack_presets[attack_picker.get_selected_id() - 1])
	enemy.position = SPAWN_POSITION
	if path_toggle.button_pressed:
		enemy.position = route.to_global(route.curve.sample_baked(0.0))
		movement.use_path(route)
	enemy.bounds = BOUNDS
	actors.add_child(enemy)
	if enemy.shooter != null:
		enemy.shooter.projectiles = projectiles
		enemy.shooter.target_provider = get_target
		enemy.shooter.bounds = BOUNDS
	auto_respawn = true
	respawn_left = 0.7
	return enemy

func clear_sample() -> void:
	auto_respawn = false
	for actor in actors.get_children():
		if actor is EnemyShip:
			actor.queue_free()
	for bullet in projectiles.get_children():
		bullet.queue_free()
