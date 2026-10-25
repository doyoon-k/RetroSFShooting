extends SceneTree
## Checks approved cue routing through real gameplay and UI events, including pause.

var failures: Array[String] = []
var checks: int = 0
var cues: Array[StringName] = []
var content: GameCatalog

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func frames(count: int = 2) -> void:
	for index in count:
		await process_frame

func reset_audio() -> void:
	for player in SoundEffects.instance().get_children():
		(player as AudioStreamPlayer).stop()
	await frames()
	cues.clear()

func make_stage() -> StageController:
	var stage := load("res://scenes/gameplay/stage/stage_01.tscn").instantiate() as StageController
	root.add_child(stage)
	stage._enter(StageController.Phase.PLAYING)
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	stage.player.weapon.set_physics_process(false)
	return stage

func _run() -> void:
	content = load("res://data/game_catalog.tres") as GameCatalog
	SoundEffects.instance().cue_played.connect(func(cue: StringName): cues.append(cue))
	var expected := {
		"player_destroyed": "Explosion 51.wav",
		"large_enemy_destroyed": "ButtKnight/BossBodyExplosion.wav",
		"power_up": "ButtKnight/Buff.wav",
		"bomb_pickup": "ButtKnight/BombGet.wav",
		"weapon_switch": "Fantasy_Game_UI_Crafting_Tab_Button_9_Metal.wav",
		"ui_move": "UI Arcane Cursor 01.wav",
		"ui_confirm": "ButtKnight/FinalSelectSound.wav",
		"ui_cancel": "UI Exit Menu.wav",
		"warning": "ButtKnight/Timeout.wav",
		"bomb_detonate": "Explosion 17.wav",
		"shield_gain": "UI Replenish Octave.wav",
		"shield_break": "ButtKnight/Debuff.wav",
		"sortie": "FIRE_Fireball_Whoosh_Slow.wav",
		"player_shot": "ButtKnight/LaserShoot.wav",
		"player_shot_spread": "ButtKnight/LaserShootHard.wav",
		"enemy_hit": "ButtKnight/EnemyHit.wav",
		"small_enemy_destroyed": "ButtKnight/EnemyExplosion_Small.wav",
		"medium_enemy_destroyed": "ButtKnight/EnemyExplosion_Big.wav",
		"player_hit": "ElectImpactQuickB PE1030532.wav",
		"boss_phase_two": "Dark Metallic Transition.wav",
		"enemy_shot": "UI Short Flutter.wav",
		"ricochet_bank": "Blade Clash Impact Blunt 01.wav",
		"bullet_split": "ButtKnight/Poof.wav",
		"siege_charge": "ButtKnight/LaserChargeLong.wav",
		"counter_window": "ButtKnight/Perfect.wav",
		"stage_clear": "ButtKnight/WalletGet.wav",
		"pause_open": "ButtKnight/Pause.wav",
		"pause_close": "ButtKnight/Continue.wav",
		"countdown_tick": "ButtKnight/BeepButtonSelect.wav",
		"message_appear": "UI Message Appear 03.wav",
		"text_blip": "UI Click Taps.wav",
		"result_reveal": "ButtKnight/ScoreIconPop.wav",
	}
	check(SoundEffects.instance().get_child_count() == expected.size(), "Only the %d approved cues are installed" % expected.size())
	for cue in expected:
		var player := SoundEffects.instance().get_node(NodePath(cue)) as AudioStreamPlayer
		check(player.stream != null and player.stream.resource_path.ends_with(expected[cue]), "Approved source: " + cue)
		check(not player.autoplay, "No cue starts without an event: " + cue)

	await reset_audio()
	var launching := load("res://scenes/gameplay/stage/stage_01.tscn").instantiate() as StageController
	root.add_child(launching)
	launching.set_physics_process(false)
	check(launching.phase == StageController.Phase.LAUNCHING and cues == [&"sortie"], "Initial stage entry plays the approved sortie cue once")
	check(paused and (SoundEffects.instance().get_node("sortie") as AudioStreamPlayer).playing, "Sortie audio plays during the paused launch presentation")
	await frames()
	check(cues == [&"sortie"], "Launch animation frames do not retrigger the sortie cue")
	launching._enter(StageController.Phase.PLAYING)
	launching.run.current_sortie.hp = 1
	launching.player.invincibility = 0.0
	launching.player.take_damage(1)
	await frames()
	launching._finish_death()
	await frames()
	check(launching.phase == StageController.Phase.SELECTING_NEXT and cues.count(&"countdown_tick") == 1, "The replacement countdown ticks once for its first second")
	await reset_audio()
	var replacement := launching.run.automatic_choice(launching.run.current_pilot_id)
	launching.select_next(replacement)
	check(launching.phase == StageController.Phase.LAUNCHING and cues == [&"sortie"], "Selecting a replacement pilot plays the same sortie cue")
	launching.select_next(replacement)
	check(cues == [&"sortie"], "Repeated selection while launching does not replay sortie")
	launching.queue_free()
	await frames()
	var stage := make_stage()
	await reset_audio()
	stage.player.collect(Pickup.Kind.POWER)
	check(cues == [&"power_up"], "A real level increase plays Power Up")
	await reset_audio()
	stage.run.current_sortie.power_level = 3
	stage.player.collect(Pickup.Kind.POWER)
	check(cues.is_empty(), "A capped Power Up does not announce another level")
	stage.run.current_sortie.bombs = 3
	stage.player.collect(Pickup.Kind.BOMB)
	check(cues == [&"bomb_pickup"], "An actual bomb refill plays its approved cue")
	await reset_audio()
	stage.player.collect(Pickup.Kind.BOMB)
	check(cues.is_empty(), "Capped bombs stay silent")
	stage.player.collect(Pickup.Kind.SHIELD)
	check(stage.run.current_sortie.shield and cues == [&"shield_gain"], "A newly equipped shield plays its acquisition cue")
	await reset_audio()
	stage.player.collect(Pickup.Kind.SHIELD)
	check(cues.is_empty(), "Picking up an already equipped shield does not replay acquisition")
	var shielded_hp := stage.run.current_sortie.hp
	var shielded_power := stage.run.current_sortie.power_level
	stage.player.invincibility = 0.0
	stage.player.take_damage(1)
	check(not stage.run.current_sortie.shield and cues == [&"shield_break"], "A shield that actually blocks damage plays its break cue once")
	check(stage.run.current_sortie.hp == shielded_hp and stage.run.current_sortie.power_level == shielded_power, "Shield break preserves HP and weapon power")
	await reset_audio()
	stage.player.take_damage(1)
	check(cues.is_empty(), "Ignored hits during invincibility do not replay shield break")
	stage.player.invincibility = 0.0
	stage.player.take_damage(1)
	check(stage.run.current_sortie.hp > 0 and cues == [&"player_hit"], "An unshielded hit that leaves the pilot alive plays the hull-hit cue only")
	await reset_audio()
	stage.run.current_sortie.bombs = 2
	check(stage._bomb() and cues.is_empty(), "Reserving a bomb does not play the unapproved preparation cue")
	stage._advance_bomb(stage.rules.bomb_activation_delay * 0.5)
	check(stage.bomb_pending and cues.is_empty(), "Bomb sound waits for the actual detonation")
	stage.toggle_pause()
	check(cues == [&"pause_open"], "Opening the pause menu plays its cue")
	stage._physics_process(stage.rules.bomb_activation_delay + 1.0)
	check(stage.bomb_pending and cues == [&"pause_open"], "Pausing does not detonate a pending bomb or play its sound")
	stage.toggle_pause()
	check(cues == [&"pause_open", &"pause_close"], "Resuming plays the separate close cue")
	await reset_audio()
	stage._advance_bomb(stage.rules.bomb_activation_delay)
	check(not stage.bomb_pending and cues == [&"bomb_detonate"], "Actual bomb damage and bullet clearing play Explosion 17 once")
	stage._detonate_bomb()
	check(cues == [&"bomb_detonate"], "Repeated calls after detonation do not replay the explosion")
	await reset_audio()
	stage.bomb_cooldown_left = 0.0
	check(stage._bomb(), "A fresh bomb can be reserved for the cancellation check")
	stage._enter(StageController.Phase.CLEARING)
	stage._advance_bomb(stage.rules.bomb_activation_delay)
	check(not stage.bomb_pending and cues.is_empty(), "Clearing the stage cancels a reserved bomb without an explosion sound")
	stage._enter(StageController.Phase.PLAYING)
	var weapon_before := stage.run.current_sortie.active_weapon
	stage._switch_weapon()
	check(stage.run.current_sortie.active_weapon != weapon_before and cues == [&"weapon_switch"], "HUD weapon changes use the shared cue")
	await reset_audio()
	weapon_before = stage.run.current_sortie.active_weapon
	Input.action_press("switch_weapon")
	stage.player.weapon._physics_process(0.0)
	Input.action_release("switch_weapon")
	check(stage.run.current_sortie.active_weapon != weapon_before and cues == [&"weapon_switch"], "Keyboard weapon changes use the same cue once")
	await reset_audio()
	stage.run.current_sortie.active_weapon = SortieState.WeaponType.STRAIGHT
	stage.player.weapon.fire()
	check(cues == [&"player_shot"], "Straight fire uses LaserShoot")
	await reset_audio()
	stage.run.current_sortie.active_weapon = SortieState.WeaponType.SPREAD
	stage.player.weapon.fire()
	check(cues == [&"player_shot_spread"], "Spread fire uses LaserShootHard")
	await reset_audio()
	stage.toggle_pause()
	weapon_before = stage.run.current_sortie.active_weapon
	stage._switch_weapon()
	check(cues == [&"pause_open"] and stage.run.current_sortie.active_weapon == weapon_before, "Paused weapon changes stay silent")
	SoundEffects.instance().play(&"ui_cancel")
	check((SoundEffects.instance().get_node("ui_cancel") as AudioStreamPlayer).playing, "UI audio works while the combat tree is paused")
	stage.toggle_pause()
	await reset_audio()
	stage.run.current_sortie.hp = 1
	stage.run.current_sortie.shield = false
	stage.player.invincibility = 0.0
	stage.player.take_damage(1)
	await frames()
	check(stage.phase == StageController.Phase.PLAYER_DYING and cues == [&"player_destroyed"], "Player death uses Explosion 51 exactly once")
	check(paused and (SoundEffects.instance().get_node("player_destroyed") as AudioStreamPlayer).playing, "The death cue continues during the paused death presentation")
	stage.queue_free()
	await frames()
	check((SoundEffects.instance().get_node("player_destroyed") as AudioStreamPlayer).playing, "Deleting the stage does not cut the death cue")
	await reset_audio()

	stage = make_stage()
	await reset_audio()
	var small := stage._spawn_enemy(load("res://scenes/enemies/z1_wedge.tscn"), stage.view_bounds.get_center())
	small.take_damage(small.maximum_hp + 1)
	check(cues == [&"enemy_hit", &"small_enemy_destroyed"], "A zako's killing hit ticks, then uses the small explosion")
	await frames(6)
	cues.clear()
	var normal := stage._spawn_enemy(load("res://scenes/enemies/n1_interceptor.tscn"), stage.view_bounds.get_center())
	normal.take_damage(1)
	check(cues == [&"enemy_hit"], "A surviving enemy plays only the hit tick")
	await frames(1)
	normal.take_damage(1)
	check(cues == [&"enemy_hit"], "A second hit inside min_interval does not restart the tick")
	await frames(6)
	cues.clear()
	normal.take_damage(normal.maximum_hp + 1)
	check(cues == [&"enemy_hit", &"medium_enemy_destroyed"], "N-class enemies use the larger ButtKnight explosion")
	await frames(6)
	cues.clear()
	var mid := stage._spawn_enemy(load("res://scenes/enemies/m2_wing.tscn"), stage.view_bounds.get_center())
	mid.take_damage(mid.maximum_hp + 1)
	check(cues == [&"enemy_hit", &"large_enemy_destroyed"], "A midboss death uses the large-enemy cue")
	await reset_audio()
	stage._begin_boss_intro()
	check(cues == [&"warning"] and paused, "Boss introduction plays the approved alert during its paused presentation")
	await reset_audio()
	stage._enter(StageController.Phase.PLAYING)
	stage.boss.take_damage(stage.boss.maximum_hp * (1.0 - stage.boss.phase_threshold) + 1.0)
	check(stage.boss.phase_two and cues == [&"enemy_hit", &"boss_phase_two"], "Crossing the boss threshold announces phase two")
	await frames(6)
	cues.clear()
	stage.boss.take_damage(stage.boss.maximum_hp + 1)
	await frames()
	check(cues == [&"enemy_hit", &"large_enemy_destroyed", &"stage_clear"], "Final boss destruction uses the large-enemy source, then the clear jingle")
	await reset_audio()
	stage._next_victory_line()
	check(cues == [&"message_appear"], "A survivor's victory line announces its message panel")
	stage.queue_free()
	await frames()
	await reset_audio()

	var projectiles := Node2D.new()
	root.add_child(projectiles)
	var shooter := EnemyShooter.new()
	shooter.projectiles = projectiles
	shooter.bounds = content.rules.playfield
	shooter.position = shooter.bounds.get_center()
	root.add_child(shooter)
	shooter.set_physics_process(false)
	var step := PatternStep.new()
	step.pattern = load("res://data/patterns/aimed.tres") as AttackPattern
	shooter.set_sequence([step])
	shooter.timer = 0.0
	shooter._physics_process(0.01)
	check(shooter.warning and cues.is_empty(), "Ordinary attack telegraphs remain silent")
	step = PatternStep.new()
	step.pattern = load("res://data/patterns/ricochet.tres") as AttackPattern
	shooter.set_sequence([step])
	shooter.timer = 0.0
	shooter._physics_process(0.01)
	check(cues == [&"warning"], "The ricochet telegraph plays its approved alert")
	await frames()
	shooter._physics_process(0.01)
	check(cues == [&"warning"], "A persistent warning does not replay the alert every frame")
	await reset_audio()
	shooter._fire_volley(load("res://data/patterns/aimed.tres") as AttackPattern, PI)
	check(cues == [&"enemy_shot"], "A spawned enemy volley plays the shared shot cue")
	shooter.queue_free()
	projectiles.queue_free()
	await frames()
	await reset_audio()
	stage = make_stage()
	await reset_audio()
	var siege := stage._spawn_enemy(load("res://scenes/enemies/m1_carapace.tscn"), stage.view_bounds.get_center())
	siege.movement.reached_hold = true
	var siege_shooter := siege.shooter as SiegeShooter
	siege_shooter.set_physics_process(false)
	siege_shooter.timer = 0.0
	siege_shooter._physics_process(0.01)
	check(cues == [&"warning", &"siege_charge"], "M1's custom attack cycle plays the shared warning with its laser charge")
	await reset_audio()
	siege_shooter.cycle_phase = SiegeShooter.Phase.WAIT_CLEAR
	siege_shooter.timer = 0.0
	siege_shooter._physics_process(0.01)
	check(cues == [&"counter_window"], "An emptied siege cycle announces the counter window")
	await reset_audio()
	var brood := load("res://scenes/projectiles/brood_core.tscn").instantiate() as BroodCore
	brood.bounds = stage.view_bounds
	brood.position = stage.view_bounds.get_center()
	stage.projectiles.add_child(brood)
	brood.hatch()
	check(cues == [&"bullet_split"], "A hatching brood core plays the split cue")
	stage.queue_free()
	await frames()
	await reset_audio()

	var title = load("res://scenes/title/title.tscn").instantiate()
	title.catalog = content
	root.add_child(title)
	var opening := InputEventKey.new()
	opening.keycode = KEY_ENTER
	opening.pressed = true
	title._reveal_menu(opening)
	await frames()
	check(cues == [&"ui_confirm"], "Opening the title menu plays confirmation without an extra focus beep")
	await reset_audio()
	title.get_node("%Endings").grab_focus()
	await frames()
	check(cues == [&"ui_move"], "Keyboard focus navigation plays the cursor cue")
	await reset_audio()
	title.get_node("%Exit").mouse_entered.emit()
	await frames()
	check(cues == [&"ui_move"], "Mouse hover navigation plays the same cursor cue")
	await reset_audio()
	title._show_endings()
	await frames()
	check(cues == [&"ui_confirm"], "Opening the collection plays confirmation once")
	await reset_audio()
	title._hide_endings()
	await frames()
	check(cues == [&"ui_cancel"], "Closing the collection plays cancellation without another cursor beep")
	title.queue_free()
	await frames()
	await reset_audio()
	var select = load("res://scenes/character_select/character_select.tscn").instantiate()
	select.catalog = content
	root.add_child(select)
	await reset_audio()
	select._move_selection(1)
	await frames()
	check(cues == [&"ui_move"], "Pilot navigation plays the cursor cue")
	await reset_audio()
	select._open_pilot(select.selected)
	await frames()
	check(cues == [&"ui_confirm"], "Opening pilot details plays confirmation once")
	await reset_audio()
	select._close_details()
	await frames()
	check(cues == [&"ui_cancel"], "Closing pilot details plays cancellation once")
	select.queue_free()
	await frames()
	await reset_audio()
	var typewriter := TypewriterLabel.new()
	root.add_child(typewriter)
	typewriter.set_process(false)
	typewriter.reveal("ABCDEFGHI")
	typewriter._process(2.5 / typewriter.characters_per_second)
	check(cues.is_empty(), "The first two characters type silently")
	typewriter._process(1.0 / typewriter.characters_per_second)
	check(cues == [&"text_blip"], "The third character plays one blip")
	typewriter.queue_free()
	await reset_audio()
	var result = load("res://scenes/ui/result.tscn").instantiate()
	root.add_child(result)
	check(cues == [&"result_reveal"], "The result screen plays its reveal cue once")
	result.queue_free()
	await frames()
	await reset_audio()
	GameMusic.stop()
	await SoundEffects.shutdown()
	print("SFX: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
