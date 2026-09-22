extends SceneTree
## Run with: godot --headless --path . --script tests/run_tests.gd --fixed-fps 60
## Append -- --screenshots with a rendering driver to capture the tested screens.

var failures: Array[String] = []
var checks: int = 0
var content: GameCatalog
var screenshots: bool = false
var save_test_path: String

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func frames(count: int = 2) -> void:
	for i in count:
		await process_frame

func capture(name: String) -> void:
	if screenshots and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://build/screenshots")
		root.get_texture().get_image().save_png("res://build/screenshots/" + name + ".png")

func _run() -> void:
	screenshots = OS.get_cmdline_user_args().has("--screenshots")
	content = load("res://data/game_catalog.tres") as GameCatalog
	save_test_path = "user://test_endings_%d.cfg" % OS.get_process_id()
	_test_endings()
	_test_sorties()
	_test_patterns()
	_test_input_map()
	_test_save()
	await _test_game_flow()
	await _test_bad_ending_flow()
	await _test_stage()
	await _test_simultaneous_outcomes()
	await _test_full_stage()
	await frames(3)
	if FileAccess.file_exists(save_test_path):
		DirAccess.remove_absolute(save_test_path)
	print("TEST RESULT: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		print(" - " + failure)
	quit(0 if failures.is_empty() else 1)

func _test_endings() -> void:
	var counts := {&"extinction": 0, &"last_signal": 0, &"betrayal": 0, &"unknown_horizon": 0, &"cost_of_dawn": 0, &"new_home": 0}
	check(content.pilots.size() == 6, "Six editable pilots exist")
	for mask in 64:
		var run := RunState.new(content)
		for i in 6:
			if mask & (1 << i) == 0:
				run.mark_dead(content.pilots[i].id)
		if mask != 0:
			check(EndingResolver.resolve(run) == &"", "Survival alone does not unlock a clear ending")
		run.boss_cleared = true
		var ending := EndingResolver.resolve(run)
		check(content.ending_by_id(ending) != null, "Every survivor combination has authored ending data")
		counts[ending] += 1
	check(counts == {&"extinction": 1, &"last_signal": 6, &"betrayal": 5, &"unknown_horizon": 30, &"cost_of_dawn": 21, &"new_home": 1}, "All 64 survivor combinations partition into the six expected endings")

func _test_sorties() -> void:
	var run := RunState.new(content)
	check(run.begin_sortie(&"serin"), "Living pilot can launch")
	var old := run.current_sortie
	old.collect(0, 3)
	old.collect(0, 3)
	old.collect(0, 3)
	check(old.power_level == 3, "Power caps at weapon level count")
	old.collect(2, 3)
	old.damage()
	check(old.hp == 2 and not old.shield, "Shield absorbs exactly one hit")
	old.damage()
	check(old.hp == 1, "Next hit damages the hull")
	old.spend_bomb()
	run.mark_dead(&"serin")
	run.mark_dead(&"serin")
	check(run.survivors().size() == 5, "Death is idempotent")
	check(not run.begin_sortie(&"serin"), "Dead pilot cannot launch")
	check(run.automatic_choice(&"serin") == &"jihoon", "Invalid timeout focus falls back to first living pilot")
	check(run.automatic_choice(&"echo") == &"echo", "Valid timeout focus is preserved")
	run.begin_sortie(&"jihoon")
	check(run.current_sortie != old and run.current_sortie.hp == 2 and run.current_sortie.power_level == 1 and run.current_sortie.bombs == 2 and not run.current_sortie.shield, "New sortie resets all transient stats")
	check(content.rules.starting_hp == 2 and content.rules.starting_bombs == 2, "Runtime changes do not mutate shared rules")
	var durable := SortieState.new(content.rules)
	check(not durable.damage(0) and durable.hp == 2, "Zero damage does not consume health or shield")
	durable.damage(2)
	check(durable.hp == 0, "Authored projectile damage amount is honored")

func _test_patterns() -> void:
	var fan := load("res://data/patterns/fan.tres") as AttackPattern
	var angles := fan.angles_for_volley(PI, 0)
	check(angles.size() == 3 and is_equal_approx(angles[1], PI), "Aimed fan is symmetric around its target")
	var ring := load("res://data/patterns/ring.tres") as AttackPattern
	angles = ring.angles_for_volley(0, 0)
	check(angles.size() == 12 and not is_equal_approx(angles[0], angles[11]), "Ring does not duplicate its first bullet at 360 degrees")
	var spiral := load("res://data/patterns/spiral.tres") as AttackPattern
	check(is_equal_approx(spiral.angles_for_volley(0, 1)[0], deg_to_rad(17)), "Rotating pattern advances the volley angle")

func _test_save() -> void:
	var save := SaveStore.new()
	save.save_path = save_test_path
	check(save.load_progress() == OK, "Missing save starts clean")
	check(save.unlock(&"new_home") == OK, "Ending can be persisted")
	check(save.unlock(&"new_home") == OK and save.unlocked.size() == 1, "Repeated unlock is idempotent and replacement save succeeds")
	var reloaded := SaveStore.new()
	reloaded.save_path = save_test_path
	check(reloaded.load_progress() == OK and reloaded.unlocked == [&"new_home"], "Saved ending survives a new store instance")
	var bad_path := save_test_path + ".corrupt"
	var file := FileAccess.open(bad_path, FileAccess.WRITE)
	file.store_string("[save]\nversion=999\nendings=[]\n")
	file.close()
	reloaded.save_path = bad_path
	check(reloaded.load_progress() == ERR_INVALID_DATA, "Unknown save version is rejected")
	check(reloaded.unlock(&"last_signal") == ERR_FILE_CANT_WRITE, "Unreadable save is not overwritten")
	check(FileAccess.get_file_as_string(bad_path).contains("999"), "Original unsupported save bytes remain intact")
	DirAccess.remove_absolute(bad_path)
	save.free()
	reloaded.free()

func _test_input_map() -> void:
	for entry in [[KEY_LEFT, "move_left"], [KEY_RIGHT, "move_right"], [KEY_UP, "move_up"], [KEY_DOWN, "move_down"], [KEY_ESCAPE, "pause"], [KEY_SPACE, "story_advance"], [KEY_W, "ui_up"], [KEY_D, "ui_right"]]:
		var event := InputEventKey.new()
		event.physical_keycode = entry[0]
		check(InputMap.event_is_action(event, entry[1]), "Expected physical key is mapped to " + entry[1])

func _test_game_flow() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	main.get_node("SaveStore").save_path = save_test_path
	root.add_child(main)
	await frames(25)
	check(main.current_screen.name == "Title", "Main boots into Title")
	await capture("01_title")
	main.current_screen.get_node("Menu/Endings").pressed.emit()
	await frames()
	check(main.current_screen.get_node("Collection").visible, "Title opens ending collection")
	check(main.current_screen.get_node("Collection/CollectionText").text.contains("???"), "Undiscovered endings are hidden")
	main.current_screen.get_node("Collection/CollectionBack").pressed.emit()
	main.current_screen.get_node("Menu/NewGame").pressed.emit()
	await frames(25)
	var story: Node = main.current_screen
	check(story.name == "StoryScreen", "New Game opens Intro")
	await capture("02_intro")
	story.advance()
	check(story.page_index == 0 and not story.get_node("StoryPanel/StoryText").typing, "First advance completes typing without changing page")
	story.advance()
	check(story.page_index == 1, "Second advance changes page")
	story.advance()
	story.advance()
	story.advance()
	story.advance()
	await frames(25)
	check(main.current_screen.name == "CharacterSelect", "Intro ends in Character Select")
	await capture("03_character_select")
	main.current_screen.get_node("Sortie").pressed.emit()
	await frames(100)
	check(main.current_screen is StageController and main.current_screen.phase == StageController.Phase.PLAYING, "Sortie opens playable Stage")
	# Drive the normal boss-clear and ending signals without waiting for the full wave schedule.
	var stage := main.current_screen as StageController
	stage.run.boss_cleared = true
	stage._start_clear()
	stage.phase_left = 0.0
	await frames()
	await capture("07_victory")
	for i in 8:
		if main.current_screen is StageController:
			main.current_screen.phase_left = 0.0
		await frames()
	await frames(25)
	check(main.current_screen.name == "StoryScreen", "Clear proceeds to Ending story")
	main.current_screen.advance()
	main.current_screen.advance()
	await frames(25)
	check(main.current_screen.name == "Result", "Ending completes into Result")
	await capture("08_result")
	check(main.save_store.unlocked.has(&"new_home"), "Result persists discovered ending")
	main.current_screen.get_node("Return").pressed.emit()
	await frames()
	check(main.current_screen.name == "Title" and not paused, "Result returns to unpaused Title")
	main.queue_free()
	await frames()

func _create_stage() -> StageController:
	var stage := load("res://scenes/gameplay/stage/stage_01.tscn").instantiate() as StageController
	stage.catalog = content.duplicate() as GameCatalog
	stage.catalog.rules = content.rules.duplicate() as GameRules
	stage.catalog.rules.launch_seconds = 0.15
	stage.catalog.rules.death_seconds = 0.3
	stage.catalog.rules.selection_seconds = 0.4
	stage.boss_intro_seconds = 0.1
	root.add_child(stage)
	return stage

func _test_bad_ending_flow() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	main.catalog = content.duplicate()
	main.catalog.rules = content.rules.duplicate()
	main.catalog.rules.launch_seconds = 0.15
	main.get_node("SaveStore").save_path = save_test_path
	root.add_child(main)
	main.run = RunState.new(main.catalog)
	main.start_stage(&"serin")
	await frames(16)
	for i in 6:
		var stage: StageController = main.current_screen
		stage.player.invincibility = 0
		stage.run.current_sortie.hp = 1
		stage.player.take_damage()
		await frames(3)
		stage.phase_left = 0
		await frames(3)
		if i < 5:
			check(stage.phase == StageController.Phase.SELECTING_NEXT, "Surviving crew can replace each lost pilot")
			stage.phase_left = 0
			await frames(16)
	check(main.current_screen.name == "StoryScreen" and main.run.ending_id == &"extinction", "All six deaths transition through Main to Bad Ending")
	main.current_screen.advance()
	main.current_screen.advance()
	await frames(25)
	check(main.current_screen.name == "Result" and main.run.survivors().is_empty(), "Bad Ending result reports zero survivors")
	check(main.save_store.unlocked.has(&"extinction"), "Bad Ending is also persisted")
	await capture("10_bad_ending_result")
	main.queue_free()
	await frames()

func _test_stage() -> void:
	var stage := _create_stage()
	await frames(16)
	check(stage.phase == StageController.Phase.PLAYING and not paused, "Launch resumes simulation")
	check(stage.player.invincibility > 1.0, "Spawn protection starts after launch")
	var initial_x := stage.player.position.x
	Input.action_press("move_right")
	Input.action_press("shoot")
	await frames(24)
	Input.action_release("move_right")
	Input.action_release("shoot")
	check(stage.player.position.x > initial_x + 80, "Input moves ship")
	check(stage.projectiles.get_child_count() > 0, "Normal fire creates projectiles")
	var item := stage._spawn_pickup(stage.recovery_pickup, Vector2(900, 700))
	stage.toggle_pause()
	var lifetime := item.lifetime
	var wave_time := stage.waves.elapsed
	await frames(20)
	check(is_equal_approx(lifetime, item.lifetime) and is_equal_approx(wave_time, stage.waves.elapsed), "Pause freezes item lifetime and wave clock")
	await capture("05_pause")
	stage.toggle_pause()
	stage.run.current_sortie.shield = true
	stage.player.invincibility = 0
	stage.player.take_damage()
	stage.player.take_damage()
	check(stage.run.current_sortie.hp == 2 and not stage.run.current_sortie.shield, "Shield break grants protection against simultaneous hits")
	stage.player.grant_invincibility(2.0)
	stage.player.grant_invincibility(0.5)
	check(is_equal_approx(stage.player.invincibility, 2.0), "Short invulnerability never shortens a longer one")
	var bombs := stage.run.current_sortie.bombs
	stage._bomb()
	check(stage.run.current_sortie.bombs == bombs - 1, "Bomb consumes exactly one stock")
	# Exercise actual Area2D collision with a fired player bullet.
	var enemy := stage._spawn_enemy(load("res://scenes/enemies/scout.tscn"), stage.player.position + Vector2(190, 0))
	enemy.movement.set_physics_process(false)
	stage.player.weapon.fire()
	await frames(24)
	check(not is_instance_valid(enemy) or enemy.hp < enemy.maximum_hp, "Player projectile collision damages enemy")
	# Both emitters share the preset but own independent runtime counters.
	var a := stage._spawn_enemy(load("res://scenes/enemies/fighter.tscn"), Vector2(1200, 350))
	var b := stage._spawn_enemy(load("res://scenes/enemies/fighter.tscn"), Vector2(1300, 730))
	check(a.shooter.steps[0] == b.shooter.steps[0], "Enemies can share immutable pattern steps")
	a.shooter.timer = 0
	b.shooter.timer = 10
	await frames(4)
	check(b.shooter.timer > 9 and a.shooter.timer < 3, "Shared pattern does not share firing timers")
	stage.player.invincibility = 10.0
	Input.action_press("special")
	await frames(70)
	check(stage.player.weapon.charge >= stage.player.weapon.data.charge_seconds, "Holding special completes its charge")
	var charge_target := stage._spawn_enemy(load("res://scenes/enemies/gunner.tscn"), stage.player.position + Vector2(220, 0))
	charge_target.movement.set_physics_process(false)
	var hostile := load("res://scenes/projectiles/enemy_bullet.tscn").instantiate() as Projectile
	hostile.speed = 0
	hostile.bounds = stage.rules.playfield
	stage.projectiles.add_child(hostile)
	hostile.position = stage.player.position + Vector2(170, 0)
	Input.action_release("special")
	await frames(5)
	check(not is_instance_valid(charge_target) or charge_target.hp == 0, "Released full charge damages enemies in front")
	check(not is_instance_valid(hostile), "Charge clears hostile bullets within its range")
	check(stage.player.weapon.special_cooldown > 0.0, "Charge attack starts its cooldown")
	await capture("04_stage")
	stage.run.current_sortie.power_level = 3
	var item_count := stage.items.get_child_count()
	stage.player.invincibility = 0
	stage.player.take_damage()
	stage.player.invincibility = 0
	stage.player.take_damage()
	await frames(3)
	check(stage.phase == StageController.Phase.PLAYER_DYING, "Lethal hit enters death presentation")
	check(stage.items.get_child_count() == item_count + 2, "LV3 death drops two recoverable power-ups")
	await capture("06_death")
	stage.phase_left = 0
	await frames(3)
	check(stage.phase == StageController.Phase.SELECTING_NEXT and not stage.run.is_alive(&"serin"), "Death completes before next selection")
	check(stage.roster.cards[0].disabled, "Dead portrait cannot be selected")
	lifetime = item.lifetime
	await frames(6)
	check(is_equal_approx(lifetime, item.lifetime), "Selection freezes existing pickups")
	stage.roster.highlighted_id = &"echo"
	stage.phase_left = 0
	await frames(16)
	check(stage.run.current_pilot_id == &"echo" and stage.phase == StageController.Phase.PLAYING, "Timeout launches highlighted living pilot")
	check(stage.run.current_sortie.power_level == 1 and stage.run.current_sortie.bombs == 2 and stage.run.current_sortie.hp == 2, "Respawn starts with fresh sortie stats")
	stage.queue_free()
	await frames()

func _test_simultaneous_outcomes() -> void:
	for last_pilot in [false, true]:
		for boss_first in [false, true]:
			var stage := _create_stage()
			await frames(16)
			if last_pilot:
				for pilot in content.pilots:
					if pilot.id != stage.run.current_pilot_id:
						stage.run.mark_dead(pilot.id)
			stage.player.invincibility = 0
			stage.run.current_sortie.hp = 1
			var enemy := stage._spawn_enemy(load("res://scenes/enemies/boss.tscn"), Vector2(1100, 532))
			if boss_first:
				enemy.take_damage(9999)
				stage.player.take_damage()
			else:
				stage.player.take_damage()
				enemy.take_damage(9999)
			await frames(3)
			check(stage.phase == StageController.Phase.PLAYER_DYING, "Simultaneous kill always presents pilot death first")
			stage.phase_left = 0
			await frames(3)
			var expected := &"extinction" if last_pilot else &"cost_of_dawn"
			check(EndingResolver.resolve(stage.run) == expected, "Simultaneous outcome is independent of signal order")
			stage.queue_free()
			await frames()
	# Check both callback orders when a spawn and lethal hit share a frame.
	for boss_first in [false, true]:
		var stage := _create_stage()
		await frames(16)
		stage.player.invincibility = 0
		stage.run.current_sortie.hp = 1
		if boss_first:
			stage._request_boss_intro()
			stage.player.take_damage()
		else:
			stage.player.take_damage()
			stage._request_boss_intro()
		await frames(3)
		stage.phase_left = 0
		await frames(3)
		stage.select_next(&"jihoon")
		await frames(30)
		check(is_instance_valid(stage.boss), "Boss spawn survives death in either callback order")
		stage.queue_free()
		await frames()

func _test_full_stage() -> void:
	var stage := _create_stage()
	await frames(16)
	stage.player.invincibility = 300.0
	Input.action_press("shoot")
	# Run the entire authored schedule without moving its clock manually.
	for i in 4150:
		await process_frame
		if i % 120 == 0 and is_instance_valid(stage.player):
			stage.player.position.y = 532 + sin(i * 0.006) * 260
	Input.action_release("shoot")
	check(stage.waves.boss_sent and is_instance_valid(stage.boss), "Complete wave schedule reaches its boss")
	var emitted := 0
	for wave in stage.waves.get_children():
		check(wave.emitted == wave.count, "Authored wave emits all enemies: " + wave.name)
		emitted += wave.emitted
	check(emitted == 45, "Stage emits the expected 45 non-boss enemies")
	var boss := stage.boss
	if is_instance_valid(boss):
		boss.take_damage(130)
		check(boss.phase_two and boss.shooter.steps == boss.second_phase, "Boss swaps to phase-two sequence at its HP threshold")
		await frames(120)
		await capture("09_boss")
		boss.take_damage(9999)
		await frames(3)
		check(stage.phase == StageController.Phase.CLEARING and stage.run.boss_cleared, "Boss damage, death signal and clear transition are connected")
	stage.queue_free()
	await frames()
