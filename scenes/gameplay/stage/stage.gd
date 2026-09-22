class_name StageController
extends Node2D
## Coordinates actors; owns the only combat pause and outcome decision.

signal completed
enum Phase { LAUNCHING, PLAYING, BOSS_INTRO, PLAYER_DYING, SELECTING_NEXT, CLEARING, FINISHED }

@export var catalog: GameCatalog
@export var recovery_pickup: PackedScene
@export var explosion_scene: PackedScene
@export_range(0.1, 10.0, 0.1) var boss_intro_seconds: float = 2.0
@export_range(0.1, 10.0, 0.1) var clear_intro_seconds: float = 1.5
@export var boss_spawn_offset: Vector2 = Vector2(130, 0)
var run: RunState
var phase: Phase = Phase.LAUNCHING
var user_paused: bool = false
var phase_left: float = 0.0
var player: PlayerShip
var boss: EnemyShip
var pending_death: Dictionary = {}
var pending_boss: bool = false
var boss_waiting_to_enter: bool = false
var boss_death_position: Vector2
var resolution_queued: bool = false
var dying_pilot_id: StringName
var victory_index: int = -1
var defeated: int = 0
var rules: GameRules
@onready var simulation: Node2D = $Simulation
@onready var actors: Node2D = $Simulation/Actors
@onready var projectiles: Node2D = $Simulation/Projectiles
@onready var items: Node2D = $Simulation/Items
@onready var waves: WaveSequence = $Simulation/WaveSequence
@onready var roster: PilotRoster = %Roster

func _ready() -> void:
	if run == null:
		run = RunState.new(catalog)
		run.begin_sortie(catalog.pilots[0].id)
	rules = catalog.rules
	roster.configure(catalog, run)
	roster.pilot_selected.connect(select_next)
	waves.enemy_requested.connect(_spawn_wave_enemy)
	waves.boss_requested.connect(_request_boss_intro)
	%Resume.pressed.connect(toggle_pause)
	%Playfield.position = rules.playfield.position
	%Playfield.size = rules.playfield.size
	%PauseDimmer.position = rules.playfield.position
	%PauseDimmer.size = rules.playfield.size
	%BombFlash.position = rules.playfield.position
	%BombFlash.size = rules.playfield.size
	_launch_current()

func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false

func _process(delta: float) -> void:
	_update_hud()
	if phase == Phase.FINISHED or user_paused:
		return
	if phase == Phase.PLAYING:
		return
	phase_left -= delta
	if phase == Phase.LAUNCHING and is_instance_valid(player):
		var t := clampf(1.0 - phase_left / rules.launch_seconds, 0.0, 1.0)
		player.position = Vector2(rules.playfield.position.x - 80, rules.spawn_position.y).lerp(rules.spawn_position, 1 - pow(1 - t, 3))
	if phase == Phase.SELECTING_NEXT:
		%Countdown.text = str(maxi(1, ceili(phase_left)))
	if phase_left > 0.0:
		return
	match phase:
		Phase.LAUNCHING:
			player.grant_invincibility(rules.spawn_invincibility)
			_enter(Phase.PLAYING)
		Phase.BOSS_INTRO:
			_enter(Phase.PLAYING)
		Phase.PLAYER_DYING:
			_finish_death()
		Phase.SELECTING_NEXT:
			select_next(run.automatic_choice(roster.highlighted_id))
		Phase.CLEARING:
			_next_victory_line()

func _enter(next_phase: Phase, seconds: float = 0.0) -> void:
	phase = next_phase
	phase_left = seconds
	get_tree().paused = phase != Phase.PLAYING or user_paused
	%SequencePanel.hide()
	%NextPilotPanel.visible = phase == Phase.SELECTING_NEXT
	%PauseDimmer.visible = phase == Phase.PLAYER_DYING or phase == Phase.SELECTING_NEXT or phase == Phase.CLEARING or user_paused
	roster.selectable = phase == Phase.SELECTING_NEXT
	roster.refresh()
	if phase == Phase.PLAYING and boss_waiting_to_enter:
		_begin_boss_intro.call_deferred()

func _launch_current() -> void:
	_enter(Phase.LAUNCHING, rules.launch_seconds)
	roster.expression_override = &""
	roster.highlighted_id = run.current_pilot_id
	roster.refresh()
	var pilot := catalog.pilot_by_id(run.current_pilot_id)
	player = pilot.ship_scene.instantiate() as PlayerShip
	player.state = run.current_sortie
	player.rules = rules
	player.bounds = rules.playfield
	player.position = Vector2(rules.playfield.position.x - 80, rules.spawn_position.y)
	actors.add_child(player)
	player.weapon.state = run.current_sortie
	player.weapon.projectiles = projectiles
	player.weapon.bounds = rules.playfield
	player.weapon.special_fired.connect(_special_attack)
	player.weapon.charge_changed.connect(func(ratio: float): %ChargeBar.value = ratio * 100.0)
	player.bomb_requested.connect(_bomb)
	player.died.connect(_player_died)
	for item in items.get_children():
		item.target = player
	_show_message("SORTIE / " + pilot.callsign, "발진 시퀀스 가동. 귀환을 기다릴게.", null)

func _update_hud() -> void:
	if run == null or run.current_sortie == null:
		return
	var sortie := run.current_sortie
	%StatusLine.text = "HULL  %d/%d     POWER  LV.%d     BOMB  %02d     SHIELD  %s" % [sortie.hp, rules.starting_hp, sortie.power_level, sortie.bombs, "ON" if sortie.shield else "—"]
	%StageTime.text = "SECTOR 01  /  %02d:%02d     DOWN %03d" % [int(waves.elapsed) / 60, int(waves.elapsed) % 60, defeated]
	%SurvivorCount.text = "CREW  %d / %d" % [run.survivors().size(), catalog.pilots.size()]
	if is_instance_valid(boss):
		%BossBar.visible = true
		%BossBar.max_value = boss.maximum_hp
		%BossBar.value = boss.hp

func get_target() -> Node2D:
	return player if is_instance_valid(player) and not player.death_reported else null

func _spawn_wave_enemy(wave: EnemyWave, index: int) -> void:
	var chance := 0.0
	if wave.drop_mode == EnemyWave.DropMode.GUARANTEED:
		chance = 1.0
	elif wave.drop_mode == EnemyWave.DropMode.CHANCE:
		chance = wave.drop_chance
	var path := wave.get_node_or_null("Path2D") as Path2D
	var location := wave.global_position + wave.spawn_offset * index
	if path != null and path.curve != null:
		location = path.to_global(path.curve.sample_baked(0.0))
	var enemy := _spawn_enemy(wave.enemy_scene, location, wave.drop_scene, chance)
	if path != null:
		enemy.movement.use_path(path)

func _spawn_enemy(scene: PackedScene, location: Vector2, drop: PackedScene = null, chance: float = 0.0) -> EnemyShip:
	var enemy := scene.instantiate() as EnemyShip
	enemy.position = location
	enemy.bounds = rules.playfield
	enemy.drop_scene = drop
	enemy.drop_chance = chance
	enemy.destroyed.connect(_enemy_destroyed)
	actors.add_child(enemy)
	if enemy.shooter != null:
		enemy.shooter.projectiles = projectiles
		enemy.shooter.target_provider = get_target
		enemy.shooter.bounds = rules.playfield
	return enemy

func _request_boss_intro() -> void:
	boss_waiting_to_enter = true
	_begin_boss_intro.call_deferred()

func _begin_boss_intro() -> void:
	if phase != Phase.PLAYING or waves.boss_scene == null:
		return
	if not pending_death.is_empty() or pending_boss:
		_queue_resolution()
		return
	if is_instance_valid(boss) or run.boss_cleared:
		boss_waiting_to_enter = false
		return
	boss_waiting_to_enter = false
	boss = _spawn_enemy(waves.boss_scene, Vector2(rules.playfield.end.x, rules.playfield.get_center().y) + boss_spawn_offset)
	_enter(Phase.BOSS_INTRO, boss_intro_seconds)
	_show_message("WARNING / THE WARDEN", "고에너지 반응 접근. 방주의 항로를 확보하라.", null)

func _enemy_destroyed(enemy: EnemyShip) -> void:
	defeated += 1
	_effect(enemy.global_position, enemy.death_effect if enemy.death_effect != null else explosion_scene)
	if enemy.drop_scene != null and randf() < enemy.drop_chance:
		# Area2D callbacks run while the physics server flushes overlap queries.
		_spawn_pickup.call_deferred(enemy.drop_scene, enemy.global_position)
	if enemy.is_boss:
		boss_death_position = enemy.global_position
		pending_boss = true
		_queue_resolution()

func _player_died(location: Vector2, power_level: int) -> void:
	if phase != Phase.PLAYING or not pending_death.is_empty():
		return
	pending_death = {"position": location, "power": power_level, "pilot": run.current_pilot_id}
	_queue_resolution()

func _queue_resolution() -> void:
	if not resolution_queued:
		resolution_queued = true
		_resolve_outcome.call_deferred()

func _resolve_outcome() -> void:
	resolution_queued = false
	if phase != Phase.PLAYING:
		return
	if pending_boss:
		run.boss_cleared = true
		pending_boss = false
	if not pending_death.is_empty():
		_start_death()
	elif run.boss_cleared:
		_start_clear()

func _start_death() -> void:
	var location: Vector2 = pending_death.position
	var power: int = pending_death.power
	dying_pilot_id = pending_death.pilot
	pending_death.clear()
	_enter(Phase.PLAYER_DYING, rules.death_seconds)
	_effect(location, explosion_scene, true)
	for i in maxi(0, power - 1):
		_spawn_pickup(recovery_pickup, location + Vector2(0, (i - (power - 2) * 0.5) * 52))
	if is_instance_valid(player):
		player.queue_free()
	player = null
	roster.expression_override = &"shocked"
	roster.refresh()
	var pilot := catalog.pilot_by_id(dying_pilot_id)
	_show_message("SIGNAL LOST / " + pilot.display_name, pilot.death_line, pilot.portrait(&"cockpit"))

func _finish_death() -> void:
	run.mark_dead(dying_pilot_id)
	roster.expression_override = &""
	roster.refresh()
	if run.survivors().is_empty():
		_finish()
	elif run.boss_cleared:
		_start_clear()
	else:
		_enter(Phase.SELECTING_NEXT, rules.selection_seconds)
		roster.focus_first()

func select_next(id: StringName) -> void:
	if phase != Phase.SELECTING_NEXT or not run.begin_sortie(id):
		return
	_clear_projectiles(false)
	_launch_current()

func _start_clear() -> void:
	_enter(Phase.CLEARING, clear_intro_seconds)
	_clear_projectiles(true)
	%BossBar.hide()
	roster.expression_override = &"victory"
	roster.refresh()
	victory_index = -1
	_effect(boss_death_position, explosion_scene, true)
	_show_message("SECTOR CLEAR", "침묵이 걷히고, 살아남은 목소리들이 돌아온다.", null)

func _next_victory_line() -> void:
	victory_index += 1
	var survivors := run.survivors()
	if victory_index >= survivors.size():
		_finish()
		return
	var pilot := survivors[victory_index]
	phase_left = rules.victory_line_seconds
	_show_message(pilot.display_name + " / " + pilot.callsign, pilot.victory_line, pilot.portrait(&"victory"))

func _finish() -> void:
	_enter(Phase.FINISHED)
	run.ending_id = EndingResolver.resolve(run)
	completed.emit()

func _spawn_pickup(scene: PackedScene, location: Vector2) -> Pickup:
	if scene == null:
		return null
	var pickup := scene.instantiate() as Pickup
	pickup.bounds = rules.playfield
	pickup.target = player
	pickup.position = location.clamp(rules.playfield.position + Vector2(25, 25), rules.playfield.end - Vector2(25, 25))
	items.add_child(pickup)
	return pickup

func _bomb() -> void:
	if phase != Phase.PLAYING or user_paused or not run.current_sortie.spend_bomb():
		return
	player.grant_invincibility(rules.bomb_invincibility)
	for actor in actors.get_children():
		if actor is EnemyShip and rules.playfield.has_point(actor.global_position):
			actor.take_damage(rules.bomb_damage)
	if rules.bomb_clears_bullets:
		_clear_projectiles(false)
	%BombFlash.modulate.a = 0.65
	create_tween().tween_property(%BombFlash, "modulate:a", 0.0, 0.4)

func _special_attack(origin: Vector2, size: Vector2, damage: int) -> void:
	if phase != Phase.PLAYING or user_paused:
		return
	var area := Rect2(origin - Vector2(0, size.y * 0.5), size)
	for actor in actors.get_children():
		if actor is EnemyShip and area.has_point(actor.global_position):
			actor.take_damage(damage)
	for bullet in projectiles.get_children():
		if not bullet.friendly and area.has_point(bullet.global_position):
			bullet.spent = true
			bullet.queue_free()
	%ChargeFlash.position = area.position
	%ChargeFlash.size = area.size
	%ChargeFlash.color = player.weapon.data.charge_color
	%ChargeFlash.modulate.a = 0.65
	create_tween().tween_property(%ChargeFlash, "modulate:a", 0.0, 0.3)

func _clear_projectiles(include_friendly: bool) -> void:
	for bullet in projectiles.get_children():
		if include_friendly or not bullet.friendly:
			bullet.spent = true
			bullet.queue_free()

func _effect(location: Vector2, scene: PackedScene, presentation: bool = false) -> void:
	if scene == null:
		return
	var effect := scene.instantiate() as Node2D
	var container := $Presentation/Effects if presentation else $Simulation/Effects
	container.add_child(effect)
	effect.global_position = location

func _show_message(title: String, message: String, portrait: Texture2D) -> void:
	%SequencePanel.show()
	%SequenceTitle.text = title
	%SequenceText.reveal(message)
	%SequencePortrait.texture = portrait
	%SequencePortrait.visible = portrait != null

func toggle_pause() -> void:
	if phase != Phase.PLAYING:
		return
	user_paused = not user_paused
	get_tree().paused = user_paused
	%PauseMenu.visible = user_paused
	%PauseDimmer.visible = user_paused
	if user_paused:
		%Resume.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()
