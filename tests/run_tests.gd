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
	await _test_proximity_damage()
	await _test_ship_sprites()
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
	check(run.begin_sortie(&"P1"), "Living pilot can launch")
	var old := run.current_sortie
	old.collect(0, 3)
	old.collect(0, 3)
	old.collect(0, 3)
	check(old.current_power_level() == 3 and old.weapon_levels[SortieState.WeaponType.SPREAD] == 1, "Power caps at level three for the active weapon only")
	old.switch_weapon()
	old.collect(0, 3)
	check(old.current_power_level() == 2 and old.weapon_levels[SortieState.WeaponType.STRAIGHT] == 3, "Spread power upgrades independently of straight power")
	old.switch_weapon()
	check(old.current_power_level() == 3 and old.recoverable_powerups() == 3, "Switching retains both weapon levels")
	old.collect(2, 3)
	old.damage()
	check(old.hp == 2 and not old.shield, "Shield absorbs exactly one hit")
	old.damage()
	check(old.hp == 1, "Next hit damages the hull")
	old.spend_bomb()
	run.mark_dead(&"P1")
	run.mark_dead(&"P1")
	check(run.survivors().size() == 5, "Death is idempotent")
	check(not run.begin_sortie(&"P1"), "Dead pilot cannot launch")
	check(run.automatic_choice(&"P1") == &"P2", "Invalid timeout focus falls back to first living pilot")
	check(run.automatic_choice(&"P6") == &"P6", "Valid timeout focus is preserved")
	run.begin_sortie(&"P2")
	check(run.current_sortie != old and run.current_sortie.hp == 2 and run.current_sortie.current_power_level() == 1 and run.current_sortie.weapon_levels[SortieState.WeaponType.SPREAD] == 1 and run.current_sortie.active_weapon == SortieState.WeaponType.STRAIGHT and run.current_sortie.bombs == 2 and not run.current_sortie.shield, "New sortie resets all transient stats")
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
	check(not InputMap.has_action("special"), "Removed charge action is absent")
	var gamepad_switch := InputEventJoypadButton.new()
	gamepad_switch.button_index = JOY_BUTTON_Y
	check(InputMap.event_is_action(gamepad_switch, "switch_weapon"), "Former special gamepad button switches weapons")
	var old_switch_key := InputEventKey.new()
	old_switch_key.physical_keycode = KEY_C
	check(not InputMap.event_is_action(old_switch_key, "switch_weapon"), "Old C key no longer switches weapons")
	for entry in [[KEY_LEFT, "move_left"], [KEY_RIGHT, "move_right"], [KEY_UP, "move_up"], [KEY_DOWN, "move_down"], [KEY_ESCAPE, "pause"], [KEY_SPACE, "story_advance"], [KEY_W, "ui_up"], [KEY_D, "ui_right"], [KEY_H, "switch_weapon"]]:
		var event := InputEventKey.new()
		event.physical_keycode = entry[0]
		check(InputMap.event_is_action(event, entry[1]), "Expected physical key is mapped to " + entry[1])

func _test_proximity_damage() -> void:
	var enemy_scene := load("res://scenes/enemies/fighter.tscn") as PackedScene
	var bullet_scene := load("res://scenes/projectiles/player_bullet.tscn") as PackedScene
	var enemies: Array[EnemyShip] = []
	for distance in [120.0, 400.0, 760.0]:
		var origin := Vector2(200.0, 1500.0 + enemies.size() * 100.0)
		var enemy := enemy_scene.instantiate() as EnemyShip
		enemy.maximum_hp = 10
		enemy.bounds = Rect2(0, 0, 2400, 2000)
		root.add_child(enemy)
		enemy.global_position = origin + Vector2(distance, 0.0)
		enemy.set_physics_process(false)
		enemy.movement.set_physics_process(false)
		enemies.append(enemy)
		var bullet := bullet_scene.instantiate() as Projectile
		bullet.friendly = true
		bullet.damage = 1
		bullet.bounds = Rect2(0, 0, 2400, 2000)
		bullet.proximity_points = [Vector2(160.0, 2.0), Vector2(640.0, 1.0)]
		root.add_child(bullet)
		bullet.global_position = enemy.global_position
		bullet.damage_origin = origin
		# Exercise the projectile's collision handler at each impact distance.
		bullet._on_area_entered(enemy)
	await frames()
	var near_damage := 10.0 - enemies[0].hp
	var middle_damage := 10.0 - enemies[1].hp
	var far_damage := 10.0 - enemies[2].hp
	check(is_equal_approx(near_damage, 2.0), "Point-blank player bullet deals double damage on collision")
	check(middle_damage > 1.0 and middle_damage < 2.0, "Middle-range player bullet deals fractional bonus damage")
	check(is_equal_approx(far_damage, 1.0), "Distant player bullet deals base damage on collision")
	var sample := bullet_scene.instantiate() as Projectile
	sample.proximity_points = [Vector2(160.0, 2.0), Vector2(400.0, 1.8), Vector2(640.0, 1.0)]
	check(is_equal_approx(sample.proximity_multiplier(400.0), 1.8), "An added damage tier changes the multiplier at its distance")
	sample.proximity_points.remove_at(1)
	check(is_equal_approx(sample.proximity_multiplier(400.0), 1.5), "Removing a damage tier reconnects its neighbors")
	sample.proximity_points.remove_at(1)
	check(is_equal_approx(sample.proximity_multiplier(200.0), 1.0), "A single close-range tier falls back to base damage beyond its distance")
	sample.proximity_points.clear()
	check(is_equal_approx(sample.proximity_multiplier(120.0), 1.0), "No damage tiers means base damage at every range")
	sample.free()
	for enemy in enemies:
		enemy.queue_free()
	await frames()

func _test_ship_sprites() -> void:
	var normal := load("res://assets/Pilots_sprites/Player/Robot_Nomal.png") as Texture2D
	var normal_back := load("res://assets/Pilots_sprites/Player/Robot_Nomal_Back.png") as Texture2D
	var normal_forward := load("res://assets/Pilots_sprites/Player/Robot_Nomal_Forward.png") as Texture2D
	var damaged := load("res://assets/Pilots_sprites/Player/Robot_Demaged.png") as Texture2D
	var damaged_back := load("res://assets/Pilots_sprites/Player/Robot_Demaged_Back.png") as Texture2D
	var damaged_forward := load("res://assets/Pilots_sprites/Player/Robot_Demaged_Forward.png") as Texture2D
	for pilot in content.pilots:
		var ship := pilot.ship_scene.instantiate() as PlayerShip
		ship.state = SortieState.new(content.rules)
		ship.rules = content.rules
		ship.bounds = Rect2(0, 0, 1920, 1080)
		ship.position = Vector2(500, 500)
		root.add_child(ship)
		var sprite := ship.get_node("Visuals") as Sprite2D
		var label := String(pilot.id)
		check(sprite.texture == normal, label + " starts with the common normal sprite")
		Input.action_press("move_right")
		await frames()
		check(sprite.texture == normal_forward, label + " uses the forward sprite while moving right")
		Input.action_release("move_right")
		Input.action_press("move_left")
		await frames()
		check(sprite.texture == normal_back, label + " uses the back sprite while moving left")
		Input.action_release("move_left")
		Input.action_press("move_right")
		await frames()
		ship.state.shield = true
		ship.take_damage()
		check(sprite.texture == damaged_forward, label + " switches to damaged art after a shielded hit")
		Input.action_release("move_right")
		Input.action_press("move_left")
		await frames()
		check(sprite.texture == damaged_back, label + " uses the damaged back sprite")
		Input.action_release("move_left")
		await frames()
		check(sprite.texture == damaged, label + " keeps damaged art when movement stops")
		ship.queue_free()
		await frames()

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
	var hangar: Node = main.current_screen.get_node("Hangar")
	check(hangar.get_child_count() == content.pilots.size(), "Hangar has one slot per pilot")
	for actor in hangar.get_children():
		var pilot: PilotData = actor.get("pilot") as PilotData
		check(pilot == content.pilot_by_id(pilot.id), "Hangar slot points to catalog pilot data")
		var expected_portrait: Texture2D = pilot.hangar_portrait if pilot.hangar_portrait != null else pilot.normal
		check(actor.get_node("Portrait").texture == expected_portrait, "Hangar portrait comes from pilot data or its normal fallback")
		check(actor.get_node("Name").text == pilot.callsign, "Hangar name comes from pilot data")
	var first_pilot: PilotData = hangar.get_child(0).get("pilot") as PilotData
	var first_portrait := hangar.get_child(0).get_node("Portrait") as Sprite2D
	var original_hangar_portrait: Texture2D = first_pilot.hangar_portrait
	first_pilot.hangar_portrait = content.pilots[1].normal
	check(first_portrait.texture == content.pilots[1].normal, "Hangar preview updates when pilot data changes")
	first_pilot.hangar_portrait = original_hangar_portrait
	check(first_portrait.texture == first_pilot.normal, "Clearing hangar portrait restores the normal fallback")
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
	main.start_stage(&"P1")
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
	var initial_progress := stage.progress_x
	var dormant := stage.placed_enemies.get_node("HunterTop") as EnemyShip
	var dormant_x := dormant.position.x
	var guide := stage.get_node("Simulation/StageGuide")
	var linear_preview: PackedVector2Array = guide.call("_movement_points", dormant.movement, dormant.global_position)
	check(linear_preview.size() > 2 and linear_preview[1].x < linear_preview[0].x, "Editor preview follows the linear movement preset")
	var fighter_preview := load("res://scenes/enemies/fighter.tscn").instantiate() as EnemyShip
	var sine_preview: PackedVector2Array = guide.call("_movement_points", fighter_preview.get_node("Movement"), Vector2(3000, 300))
	check(sine_preview.size() > 20 and not is_equal_approx(sine_preview[5].y, sine_preview[15].y), "Editor preview shows the sine movement preset")
	fighter_preview.free()
	await frames(6)
	check(stage.progress_x > initial_progress and stage.player.position.x > initial_x, "Player and camera advance without directional input")
	check(dormant.get_parent() == stage.placed_enemies and is_equal_approx(dormant.position.x, dormant_x) and dormant.process_mode == Node.PROCESS_MODE_DISABLED, "Distant placed enemy remains dormant")
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
	var progress := stage.progress_x
	await frames(20)
	check(is_equal_approx(lifetime, item.lifetime) and is_equal_approx(progress, stage.progress_x), "Pause freezes item lifetime and stage travel")
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
	var straight := stage.player.weapon.data
	var spread := stage.player.weapon.spread_data
	check(straight.levels.size() == 3 and spread.levels.size() == 3, "Both weapons have three authored levels")
	var authored_tiers := stage.player.weapon.proximity_tiers
	check(authored_tiers.size() == 2 and authored_tiers[0].distance == 160.0 and authored_tiers[1].distance == 640.0, "Player ship authors two editable proximity damage tiers")
	for level in straight.levels:
		check(level.angles.size() == 1 and is_zero_approx(level.angles[0]), "Straight weapon remains a single forward shot at every level")
	for level in spread.levels:
		check(level.angles.size() == 3 and is_zero_approx(level.angles[1]) and is_equal_approx(level.angles[0], -level.angles[2]), "Spread weapon fires a symmetric three-way fan at every level")
	var bullet_count := stage.projectiles.get_child_count()
	stage.player.weapon.fire()
	check(stage.projectiles.get_child_count() == bullet_count + 1, "Straight weapon fires one projectile")
	var straight_bullet := stage.projectiles.get_child(bullet_count) as Projectile
	check(straight_bullet.proximity_points.size() == 2 and straight_bullet.proximity_points[0].y == 2.0 and straight_bullet.damage_origin.is_equal_approx(stage.player.weapon.global_position), "Straight shot captures proximity tiers and firing origin")
	Input.action_press("switch_weapon")
	await frames(2)
	Input.action_release("switch_weapon")
	check(stage.run.current_sortie.active_weapon == SortieState.WeaponType.SPREAD, "Switch input selects spread weapon")
	bullet_count = stage.projectiles.get_child_count()
	stage.player.weapon.fire()
	check(stage.projectiles.get_child_count() == bullet_count + 3, "Spread weapon fires exactly three projectiles")
	check(stage.projectiles.get_child(bullet_count).direction.y < 0.0 and stage.projectiles.get_child(bullet_count + 1).direction.y == 0.0 and stage.projectiles.get_child(bullet_count + 2).direction.y > 0.0, "Spread projectiles fan above, forward, and below")
	check((stage.projectiles.get_child(bullet_count) as Projectile).proximity_points.size() == 2 and (stage.projectiles.get_child(bullet_count + 2) as Projectile).damage_origin.is_equal_approx(stage.player.weapon.global_position), "All spread shots inherit proximity tiers")
	var extra_tier := ProximityDamageTier.new()
	extra_tier.distance = 400.0
	extra_tier.multiplier = 1.8
	var custom_tiers := authored_tiers.duplicate()
	custom_tiers.insert(0, extra_tier)
	stage.player.weapon.proximity_tiers = custom_tiers
	bullet_count = stage.projectiles.get_child_count()
	stage.player.weapon.fire()
	var custom_bullet := stage.projectiles.get_child(bullet_count) as Projectile
	check(custom_bullet.proximity_points.size() == 3 and custom_bullet.proximity_points[1] == Vector2(400.0, 1.8), "Weapon sorts and applies a newly added tier to fired shots")
	custom_tiers.erase(extra_tier)
	bullet_count = stage.projectiles.get_child_count()
	stage.player.weapon.fire()
	check((stage.projectiles.get_child(bullet_count) as Projectile).proximity_points.size() == 2 and custom_bullet.proximity_points.size() == 3, "Removing a tier changes new shots without rewriting shots already fired")
	stage.player.weapon.proximity_tiers = authored_tiers
	stage.player.collect(Pickup.Kind.POWER)
	check(stage.run.current_sortie.current_power_level() == 2 and stage.run.current_sortie.weapon_levels[SortieState.WeaponType.STRAIGHT] == 1, "Power pickup upgrades the selected weapon")
	bullet_count = stage.projectiles.get_child_count()
	stage.player.weapon.fire()
	check((stage.projectiles.get_child(bullet_count) as Projectile).damage == 2, "Spread shot uses its upgraded damage")
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
	await capture("04_stage")
	stage.player.collect(Pickup.Kind.POWER)
	stage.player.collect(Pickup.Kind.POWER)
	Input.action_press("switch_weapon")
	await frames(2)
	Input.action_release("switch_weapon")
	check(stage.run.current_sortie.active_weapon == SortieState.WeaponType.STRAIGHT, "Second switch restores straight weapon")
	stage.player.collect(Pickup.Kind.POWER)
	stage.player.collect(Pickup.Kind.POWER)
	check(stage.run.current_sortie.recoverable_powerups() == 4, "Two level-three weapons store four recoverable upgrades")
	bullet_count = stage.projectiles.get_child_count()
	stage.player.weapon.fire()
	check((stage.projectiles.get_child(bullet_count) as Projectile).damage == 3, "Straight shot uses its own level-three damage")
	var item_count := stage.items.get_child_count()
	stage.player.invincibility = 0
	stage.player.take_damage()
	stage.player.invincibility = 0
	stage.player.take_damage()
	await frames(3)
	check(stage.phase == StageController.Phase.PLAYER_DYING, "Lethal hit enters death presentation")
	check(stage.items.get_child_count() == item_count + 4, "Death drops both weapons' recoverable power-ups")
	await capture("06_death")
	stage.phase_left = 0
	await frames(3)
	check(stage.phase == StageController.Phase.SELECTING_NEXT and not stage.run.is_alive(&"P1"), "Death completes before next selection")
	check(stage.roster.cards[0].disabled, "Dead portrait cannot be selected")
	lifetime = item.lifetime
	await frames(6)
	check(is_equal_approx(lifetime, item.lifetime), "Selection freezes existing pickups")
	stage.roster.highlighted_id = &"P6"
	stage.phase_left = 0
	await frames(16)
	check(stage.run.current_pilot_id == &"P6" and stage.phase == StageController.Phase.PLAYING, "Timeout launches highlighted living pilot")
	check(stage.run.current_sortie.current_power_level() == 1 and stage.run.current_sortie.weapon_levels[SortieState.WeaponType.SPREAD] == 1 and stage.run.current_sortie.bombs == 2 and stage.run.current_sortie.hp == 2, "Respawn starts with fresh sortie stats")
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
		stage.select_next(&"P2")
		await frames(30)
		check(is_instance_valid(stage.boss), "Boss spawn survives death in either callback order")
		stage.queue_free()
		await frames()

func _test_full_stage() -> void:
	var stage := _create_stage()
	await frames(16)
	stage.player.invincibility = 300.0
	Input.action_press("shoot")
	# Run the entire authored route without moving the camera manually.
	for i in 4150:
		await process_frame
		if i % 120 == 0 and is_instance_valid(stage.player):
			stage.player.position.y = 532 + sin(i * 0.006) * 260
	Input.action_release("shoot")
	check(stage.waves.boss_sent and is_instance_valid(stage.boss), "Travel reaches the placed boss marker")
	var emitted := 0
	for wave in stage.waves.get_children():
		if wave is EnemyWave:
			check(wave.emitted == wave.count, "Spatial group emits all enemies: " + wave.name)
			emitted += wave.emitted
	check(emitted + stage.placed_activated == 45, "Spatial groups and placed enemies activate all 45 non-boss enemies")
	check(stage.placed_activated == 2 and stage.placed_enemies.get_child_count() == 0, "Placed enemy scenes activate when the camera reaches them")
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
