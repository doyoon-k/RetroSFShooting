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
	_test_portraits()
	_test_patterns()
	await _test_enemy_profiles()
	await _test_attack_fairness()
	await _test_redesigned_encounters()
	await _test_fleet_patterns()
	_test_input_map()
	await _test_proximity_damage()
	await _test_enemy_hit_effect()
	await _test_ship_sprites()
	await _test_pickup_bounces()
	_test_save()
	await _test_game_flow()
	await _test_bad_ending_flow()
	await _test_stage()
	await _test_combat_layout()
	await _test_playfield_edges()
	await _test_simultaneous_outcomes()
	await _test_full_stage()
	await frames(3)
	if FileAccess.file_exists(save_test_path):
		DirAccess.remove_absolute(save_test_path)
	print("TEST RESULT: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		print(" - " + failure)
	quit(0 if failures.is_empty() else 1)

func _test_fleet_patterns() -> void:
	var arena := Rect2(440, 24, 1464, 952)
	var curtain := load("res://data/patterns/command_curtain.tres") as AttackPattern
	var last_gap := curtain.corridor_y(arena, 0)
	for volley in curtain.volley_count:
		var gap := curtain.corridor_y(arena, volley)
		var shots := curtain.shots_for_volley(Vector2(1600, 500), arena, PI, volley)
		check(shots.size() > 8, "Blockade covers both sides of its corridor")
		for shot in shots:
			check(absf(shot.position.y - gap) >= curtain.corridor_width * 0.5, "Curtain leaves its authored corridor open")
		check(absf(gap - last_gap) / 460.0 < curtain.volley_interval - 0.2, "Slow pilot can move between successive stationary blockade corridors")
		last_gap = gap
	var container := Node2D.new()
	root.add_child(container)
	var core := load("res://scenes/projectiles/brood_core.tscn").instantiate() as BroodCore
	core.position = Vector2(1500, 500)
	core.bounds = arena
	container.add_child(core)
	core.set_physics_process(false)
	core._physics_process(core.travel_seconds)
	var stop := core.position
	core._physics_process(core.incubation_seconds * 0.5)
	check(container.get_child_count() == 1 and core.position.is_equal_approx(stop), "Brood core stops and gives a visible incubation interval before hatching")
	var expected := core.child_count
	core._physics_process(core.incubation_seconds * 0.5 + 0.001)
	core.hatch()
	check(container.get_child_count() == expected + 1, "Core hatches one bounded generation, never duplicates on repeated calls")
	for child in container.get_children():
		if child == core: continue
		check(child is Projectile and not child is BroodCore and child.bounds == arena, "Offspring are ordinary bounded projectiles")
	container.queue_free()
	await frames()
	var stage := load("res://scenes/gameplay/stage/stage_01.tscn").instantiate() as StageController
	root.add_child(stage)
	var cancelled := load("res://scenes/projectiles/brood_core.tscn").instantiate() as BroodCore
	cancelled.position = stage.view_bounds.get_center()
	cancelled.bounds = stage.view_bounds
	stage.projectiles.add_child(cancelled)
	stage._clear_projectiles(false)
	cancelled.hatch()
	await frames()
	check(stage.projectiles.get_child_count() == 0, "Clearing a brood core cancels pending offspring")
	stage.queue_free()
	await frames()

func _test_attack_fairness() -> void:
	var enemy := load("res://scenes/enemies/n1_interceptor.tscn").instantiate() as EnemyShip
	var target := Node2D.new()
	var bullets := Node2D.new()
	root.add_child(target)
	root.add_child(bullets)
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.movement.set_physics_process(false)
	var shooter := enemy.shooter
	shooter.set_physics_process(false)
	shooter.bounds = Rect2(48, 100, 1440, 864)
	shooter.projectiles = bullets
	shooter.target_provider = func(): return target
	target.position = Vector2(300, 532)
	enemy.position = Vector2(1600, 532)
	check(not shooter.can_fire(), "Offscreen enemy cannot fire")
	enemy.position = Vector2(250, 532)
	check(not shooter.can_fire(), "Normal enemy behind the player cannot fire")
	enemy.position = Vector2(430, 532)
	check(not shooter.can_fire(), "Normal enemy does not point-blank fire within 160px")
	enemy.position = Vector2(1200, 532)
	shooter.timer = 0.0
	shooter._physics_process(0.01)
	check(shooter.warning and bullets.get_child_count() == 0, "A burst gives a visible warning before any projectile")
	var angle := shooter.locked_angle
	target.position.y = 800
	shooter._physics_process(shooter.telegraph_seconds + 0.01)
	check(bullets.get_child_count() == 1 and (bullets.get_child(0) as Projectile).direction.is_equal_approx(Vector2.from_angle(angle)), "Locked burst keeps its warned aim after player movement")
	shooter.set_sequence((load("res://data/sequences/tracking_stream.tres") as AttackSequence).steps)
	shooter.timer = 0.0
	shooter._physics_process(0.01)
	target.position.y = 300
	shooter._physics_process(shooter.telegraph_seconds + 0.01)
	var tracked_direction := shooter.global_position.direction_to(target.position)
	check((bullets.get_child(1) as Projectile).direction.is_equal_approx(tracked_direction), "Tracking stream deliberately resamples the target after its warning")
	var homing := load("res://scenes/projectiles/homing_bullet.tscn").instantiate() as Projectile
	root.add_child(homing)
	homing.set_physics_process(false)
	homing.position = Vector2(900, 532)
	homing.target = target
	homing.age = homing.homing_seconds + 0.1
	var old_direction := homing.direction
	homing._physics_process(0.1)
	check(homing.direction == old_direction, "Homing bullet stops turning after its tracking window")
	homing.queue_free()
	enemy.queue_free()
	target.queue_free()
	bullets.queue_free()
	await frames()

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
	check(old.current_power_level() == 3 and old.recoverable_powerups() == 2, "One shared power level caps at three")
	old.switch_weapon()
	check(old.current_power_level() == 3, "Switching weapons preserves the shared power level")
	old.switch_weapon()
	old.collect(2, 3)
	old.damage()
	check(old.hp == 2 and not old.shield and old.current_power_level() == 3, "Shield absorbs a hit without reducing shared power")
	old.damage()
	check(old.hp == 1 and old.current_power_level() == 2, "Hull hit reduces shared power by one level")
	old.switch_weapon()
	check(old.current_power_level() == 2, "Both weapons use the reduced level after switching")
	old.spend_bomb()
	run.mark_dead(&"P1")
	run.mark_dead(&"P1")
	check(run.survivors().size() == 5, "Death is idempotent")
	check(not run.begin_sortie(&"P1"), "Dead pilot cannot launch")
	check(run.automatic_choice(&"P1") == &"P2", "Invalid timeout focus falls back to first living pilot")
	check(run.automatic_choice(&"P6") == &"P6", "Valid timeout focus is preserved")
	run.begin_sortie(&"P2")
	check(run.current_sortie != old and run.current_sortie.hp == 2 and run.current_sortie.current_power_level() == 1 and run.current_sortie.active_weapon == SortieState.WeaponType.STRAIGHT and run.current_sortie.bombs == 2 and not run.current_sortie.shield, "New sortie resets all transient stats")
	check(content.rules.starting_hp == 2 and content.rules.starting_bombs == 2, "Runtime changes do not mutate shared rules")
	var stocked := SortieState.new(content.rules)
	for pickup in 6:
		stocked.collect(Pickup.Kind.BOMB, 3)
	check(stocked.bombs == 4, "Repeated bomb pickups cannot exceed four stocks")
	check(stocked.spend_bomb() and stocked.bombs == 3, "A full bomb stock still spends exactly one bomb")
	stocked.collect(Pickup.Kind.BOMB, 3)
	check(stocked.bombs == 4, "A spent slot can be refilled after reaching the cap")
	var overstocked_rules := content.rules.duplicate() as GameRules
	overstocked_rules.starting_bombs = 6
	check(SortieState.new(overstocked_rules).bombs == 4 and overstocked_rules.starting_bombs == 6, "Starting stocks are capped without mutating authored rules")
	var durable := SortieState.new(content.rules)
	check(not durable.damage(0) and durable.hp == 2, "Zero damage does not consume health or shield")
	durable.damage(2)
	check(durable.hp == 0, "Authored projectile damage amount is honored")

func _test_portraits() -> void:
	for pilot in content.pilots:
		check(pilot.normal != null and pilot.one_dead != null and pilot.two_dead != null and pilot.four_dead != null and pilot.damaged != null and pilot.dead != null, "All portrait states are assigned for " + String(pilot.id))
		check(pilot.portrait(0) == pilot.normal and pilot.portrait(1) == pilot.one_dead, "Zero and one loss portraits match " + String(pilot.id))
		check(pilot.portrait(2) == pilot.two_dead and pilot.portrait(3) == pilot.two_dead, "Two and three losses share the portrait for " + String(pilot.id))
		check(pilot.portrait(4) == pilot.four_dead and pilot.portrait(5) == pilot.four_dead, "Four and five losses share the portrait for " + String(pilot.id))
		check(pilot.portrait(5, true) == pilot.damaged and pilot.portrait(5, true, true) == pilot.dead, "Damaged and dead portraits take precedence for " + String(pilot.id))

	var run := RunState.new(content)
	var roster := load("res://scenes/ui/pilot_roster.tscn").instantiate() as PilotRoster
	root.add_child(roster)
	roster.configure(content, run)
	check(roster.cards.size() == 6, "Roster creates six portrait cards")
	var first_portrait := roster.cards[0].get_node("Portrait") as TextureRect
	check(first_portrait.texture == content.pilots[0].normal, "Roster starts with the zero-loss portrait")
	run.begin_sortie(&"P1")
	run.current_sortie.collect(2, 3)
	run.current_sortie.damage()
	check(first_portrait.texture == content.pilots[0].normal, "Shield hit leaves portrait normal")
	run.current_sortie.damage()
	check(first_portrait.texture == content.pilots[0].damaged, "Half HP changes the active portrait to damaged")
	run.current_sortie.damage()
	check(first_portrait.texture == content.pilots[0].dead, "Fatal hit shows the dead portrait")
	run.mark_dead(&"P1")
	check((roster.cards[1].get_node("Portrait") as TextureRect).texture == content.pilots[1].one_dead, "One death updates every survivor")
	run.mark_dead(&"P2")
	check((roster.cards[2].get_node("Portrait") as TextureRect).texture == content.pilots[2].two_dead, "Two deaths use the two-loss portrait")
	run.mark_dead(&"P3")
	check((roster.cards[3].get_node("Portrait") as TextureRect).texture == content.pilots[3].two_dead, "Three deaths keep the two-loss portrait")
	run.mark_dead(&"P4")
	check((roster.cards[4].get_node("Portrait") as TextureRect).texture == content.pilots[4].four_dead, "Four deaths use the four-loss portrait")
	run.mark_dead(&"P5")
	check((roster.cards[5].get_node("Portrait") as TextureRect).texture == content.pilots[5].four_dead, "Five deaths keep the four-loss portrait")
	roster.free()

func _test_patterns() -> void:
	var fan := load("res://data/patterns/fan.tres") as AttackPattern
	var angles := fan.angles_for_volley(PI, 0)
	check(angles.size() == 5 and is_equal_approx(angles[2], PI) and is_equal_approx(PI - angles[0], angles[4] - PI), "Aimed fan is symmetric around its target")
	var ring := load("res://data/patterns/ring.tres") as AttackPattern
	angles = ring.angles_for_volley(0, 0)
	check(angles.size() == 12 and not is_equal_approx(angles[0], angles[11]), "Ring does not duplicate its first bullet at 360 degrees")
	var spiral := load("res://data/patterns/spiral.tres") as AttackPattern
	check(is_equal_approx(spiral.angles_for_volley(0, 1)[0], deg_to_rad(17)), "Rotating pattern advances the volley angle")

func _test_enemy_profiles() -> void:
	var sine := load("res://data/movement/sine_pass.tres") as MovementProfile
	var hold := load("res://data/movement/hold_fire.tres") as MovementProfile
	var aimed := load("res://data/sequences/aimed.tres") as AttackSequence
	var silent := load("res://data/sequences/silent.tres") as AttackSequence
	check(sine != null and aimed != null and aimed.steps.size() == 1, "Movement and attack presets load as editable resources")
	var planned_enemies := {
		"z1_wedge": 2, "z2_spine": 2, "z3_eye": 3, "z4_crescent": 2, "z5_chain": 3,
		"n1_interceptor": 10, "n2_crawler": 18, "n3_claw": 22, "n4_armor": 28, "n5_tendril": 20,
		"m1_carapace": 160, "m2_wing": 150, "m3_star_eye": 180,
	}
	for enemy_name in planned_enemies:
		var planned_scene := load("res://scenes/enemies/%s.tscn" % enemy_name) as PackedScene
		var planned_enemy := planned_scene.instantiate() as EnemyShip
		check(planned_enemy.maximum_hp == planned_enemies[enemy_name] and planned_enemy.get_node_or_null("Visual") != null and planned_enemy.get_node_or_null("Movement") != null, "Enemy scene has distinct combat data: " + enemy_name)
		var sprite := planned_enemy.get_node_or_null("Visual") as Sprite2D
		var image_prefix: String = {"z": "S", "n": "M", "m": "L"}[enemy_name.left(1)]
		var image_name: String = image_prefix + enemy_name.substr(1, 1) + ".png"
		check(sprite != null and sprite.texture != null and sprite.texture.resource_path.ends_with("/Enemy/" + image_name), "Enemy uses the supplied sprite: " + enemy_name)
		planned_enemy.free()
	var stage := _create_stage()
	await frames(16)
	var wave := EnemyWave.new()
	wave.enemy_scene = load("res://scenes/enemies/scout.tscn")
	wave.position = Vector2(1260, 532) + stage.waves.position
	wave.movement_profile = sine
	wave.attack_sequence = aimed
	stage._spawn_wave_enemy(wave, 0)
	var scout := stage.actors.get_child(stage.actors.get_child_count() - 1) as EnemyShip
	check(scout.movement.mode == EnemyMovement.Mode.SINE and is_equal_approx(scout.movement.amplitude, sine.amplitude), "Wave movement preset overrides the enemy scene")
	check(scout.shooter != null and scout.shooter.steps[0] == aimed.steps[0], "Attack override can add a shooter to a silent enemy")
	var first_timer := scout.shooter.timer
	stage._spawn_wave_enemy(wave, 0)
	var other := stage.actors.get_child(stage.actors.get_child_count() - 1) as EnemyShip
	scout.shooter.timer = 7.0
	check(other.shooter.timer == first_timer and aimed.steps.size() == 1, "Shared attack settings keep independent runtime timers")
	wave.enemy_scene = load("res://scenes/enemies/fighter.tscn")
	wave.movement_profile = hold
	wave.attack_sequence = silent
	stage._spawn_wave_enemy(wave, 0)
	var fighter := stage.actors.get_child(stage.actors.get_child_count() - 1) as EnemyShip
	check(fighter.movement.mode == EnemyMovement.Mode.ENTER_HOLD_EXIT and fighter.movement.hold_position.is_equal_approx(hold.hold_position + stage.waves.position + Vector2(stage.progress_x, 0)), "Hold preset receives the arena and current world offset")
	check(fighter.shooter.steps.is_empty(), "An empty attack preset disables a scene's default shooter")
	var route := Path2D.new()
	route.name = "Path2D"
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(-300, 100))
	route.curve = curve
	wave.add_child(route)
	wave.movement_profile = sine
	stage._spawn_wave_enemy(wave, 0)
	var path_enemy := stage.actors.get_child(stage.actors.get_child_count() - 1) as EnemyShip
	check(path_enemy.movement.mode == EnemyMovement.Mode.PATH and path_enemy.movement.path == route, "A wave Path2D takes priority over its movement preset")
	await frames(110)
	check(stage.projectiles.get_child_count() > 0, "A wave attack override actually fires enemy projectiles")
	var mid := stage._spawn_enemy(load("res://scenes/enemies/m2_wing.tscn"), Vector2(stage.view_bounds.end.x + 80, 532))
	var paused_progress := stage.progress_x
	await frames(8)
	check(stage.mid_enemy == mid and is_equal_approx(stage.progress_x, paused_progress) and stage.player.auto_advance_speed == 0.0, "Middle enemy pauses camera and player auto-advance")
	mid.take_damage(9999)
	await frames(5)
	check(stage.mid_enemy == null and stage.progress_x > paused_progress and stage.player.auto_advance_speed == stage.scroll_speed, "Defeating a middle enemy resumes scrolling")
	wave.free()
	stage.queue_free()
	await frames()

	var lab := load("res://scenes/gameplay/enemy_lab/enemy_lab.tscn").instantiate() as EnemyLab
	root.add_child(lab)
	await frames()
	check(lab.enemy_scenes.size() == 14 and lab.movement_presets.size() == 5 and lab.attack_presets.size() == 18, "F6 lab exposes all enemies and new strafe, tracking, gate and sweep presets")
	lab.get_node("Canvas/Panel/Controls/MovementPicker").select(2)
	lab.get_node("Canvas/Panel/Controls/AttackPicker").select(2)
	var lab_enemy := lab.spawn_sample() as EnemyShip
	check(lab_enemy.movement.mode == EnemyMovement.Mode.SINE and lab_enemy.shooter != null, "Lab applies selected presets to a spawned enemy")
	lab.get_node("Canvas/Panel/Controls/PathToggle").button_pressed = true
	lab_enemy = lab.spawn_sample() as EnemyShip
	check(lab_enemy.movement.mode == EnemyMovement.Mode.PATH and lab_enemy.movement.path == lab.get_node("Route"), "Lab path switch overrides the selected movement preset")
	lab.get_node("Canvas/Panel/Controls/PowerPicker").select(2)
	lab.call("_set_power", 2)
	check(lab.state.current_power_level() == 3, "Lab changes player weapon level without restarting")
	lab_enemy.queue_free()
	await frames(52)
	var lab_enemy_count := 0
	for actor in lab.actors.get_children():
		if actor is EnemyShip and not actor.is_queued_for_deletion():
			lab_enemy_count += 1
	check(lab_enemy_count == 1, "Lab respawns an enemy after its movement ends")
	lab.clear_sample()
	await frames(52)
	lab_enemy_count = 0
	for actor in lab.actors.get_children():
		if actor is EnemyShip and not actor.is_queued_for_deletion():
			lab_enemy_count += 1
	check(lab_enemy_count == 0, "Lab Clear stops automatic respawning")
	lab.spawn_sample()
	await capture("enemy_lab")
	lab.queue_free()
	await frames()
	if screenshots:
		var gallery := Node2D.new()
		root.add_child(gallery)
		var backdrop := ColorRect.new()
		backdrop.color = Color(0.035, 0.045, 0.08)
		backdrop.size = Vector2(1920, 1080)
		gallery.add_child(backdrop)
		var names := planned_enemies.keys()
		names.sort()
		for index in names.size():
			var name: String = names[index]
			var scene := load("res://scenes/enemies/%s.tscn" % name) as PackedScene
			var enemy := scene.instantiate() as EnemyShip
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			enemy.position = Vector2(230 + index % 4 * 470, 150 + floori(float(index) / 4.0) * 240)
			gallery.add_child(enemy)
			var label := Label.new()
			label.position = enemy.position + Vector2(-120, 110)
			label.text = name.to_upper()
			label.add_theme_font_size_override("font_size", 28)
			gallery.add_child(label)
		await capture("enemy_roster")
		gallery.queue_free()
		await frames()

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
	for entry in [[KEY_LEFT, "move_left"], [KEY_RIGHT, "move_right"], [KEY_UP, "move_up"], [KEY_DOWN, "move_down"], [KEY_ESCAPE, "pause"], [KEY_SPACE, "story_advance"], [KEY_W, "ui_up"], [KEY_D, "ui_right"], [KEY_K, "switch_weapon"]]:
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
		check(sprite.texture == normal_forward, label + " keeps normal forward art after a shielded hit")
		check(ship.state.hp == content.rules.starting_hp and not ship.state.shield and not ship.has_taken_hit, label + " consumes only the shield without marking hull damage")
		Input.action_release("move_right")
		Input.action_press("move_left")
		await frames()
		check(sprite.texture == normal_back, label + " keeps normal back art after the shield breaks")
		Input.action_release("move_left")
		await frames()
		check(sprite.texture == normal, label + " keeps normal idle art after the shield breaks")
		Input.action_press("move_right")
		await frames()
		ship.invincibility = 0.0
		ship.take_damage()
		check(ship.state.hp == content.rules.starting_hp - 1 and sprite.texture == damaged_forward, label + " switches to damaged art only after losing HP")
		Input.action_release("move_right")
		Input.action_press("move_left")
		await frames()
		check(sprite.texture == damaged_back, label + " uses the damaged back sprite")
		Input.action_release("move_left")
		await frames()
		check(sprite.texture == damaged, label + " keeps damaged art when movement stops")
		ship.state.shield = true
		ship.invincibility = 0.0
		ship.take_damage(99)
		check(ship.state.hp == content.rules.starting_hp - 1 and not ship.state.shield and sprite.texture == damaged, label + " keeps existing hull damage when a new shield absorbs a hit")
		ship.queue_free()
		await frames()

func _test_pickup_bounces() -> void:
	var stage := _create_stage()
	await frames(16)
	stage.set_physics_process(false)
	stage.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	for scene in [stage.recovery_pickup, stage.recovery_bomb]:
		var item := stage._spawn_pickup(scene, stage.view_bounds.get_center())
		item.attraction = 0.0
		var area := item.bounds.grow(-item.boundary_padding)
		var center := area.get_center()
		var cases: Array[Dictionary] = [
			{"position": Vector2(area.position.x + 10, center.y), "velocity": Vector2(-40, 30), "expected": Vector2(40, 30)},
			{"position": Vector2(area.end.x - 10, center.y), "velocity": Vector2(40, 30), "expected": Vector2(-40, 30)},
			{"position": Vector2(center.x, area.position.y + 10), "velocity": Vector2(30, -40), "expected": Vector2(30, 40)},
			{"position": Vector2(center.x, area.end.y - 10), "velocity": Vector2(30, 40), "expected": Vector2(30, -40)},
			{"position": area.position + Vector2(10, 10), "velocity": Vector2(-40, -40), "expected": Vector2(40, 40)},
			{"position": area.end - Vector2(10, 10), "velocity": Vector2(40, 40), "expected": Vector2(-40, -40)},
		]
		for entry in cases:
			item.position = entry.position
			item.velocity = entry.velocity
			item._physics_process(0.25)
			check(item.velocity.is_equal_approx(entry.expected), "Bomb and power pickups reflect the contacted axes, including exact edge and corner contact")
			check(is_equal_approx(item.velocity.length(), entry.velocity.length()), "Boundary reflection preserves pickup speed")
			var contact_position := item.position
			item._physics_process(0.1)
			check(item.position.is_equal_approx(contact_position + Vector2(entry.expected) * 0.1), "Pickup moves back into the arena after bouncing")
		# Begin just inside the moving left edge: the old world-space drift stuck here.
		item.position = Vector2(area.position.x + 1, center.y)
		item.velocity = Vector2(-50, 40)
		var initial_screen_x := item.position.x - stage.progress_x
		for frame_index in 120:
			stage.progress_x += stage.scroll_speed / 60.0
			stage._sync_world_bounds()
			item._physics_process(1.0 / 60.0)
		check(item.velocity.x > 0.0 and item.position.x - stage.progress_x > initial_screen_x + 90.0, "Pickup bounces away from the left edge while the camera advances faster than its drift")
		var before_stop := item.position
		item._physics_process(0.1)
		check(item.position.is_equal_approx(before_stop + item.velocity * 0.1), "Pickup keeps drifting normally when camera scrolling stops")
		item.queue_free()
	stage.queue_free()
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
	var select_screen: Node = main.current_screen
	var select_roster := select_screen.get_node("Roster") as PilotRoster
	select_roster.cards[1].pressed.emit()
	select_roster.cards[5].mouse_entered.emit()
	check(select_screen.get("selected") == &"P2" and select_roster.highlighted_id == &"P2", "Passing over another card does not change the selected pilot")
	main.current_screen.get_node("Sortie").pressed.emit()
	await frames(100)
	check(main.current_screen is StageController and main.current_screen.phase == StageController.Phase.PLAYING, "Sortie opens playable Stage")
	# Drive the normal boss-clear and ending signals without waiting for the full wave schedule.
	var stage := main.current_screen as StageController
	check(stage.run.current_pilot_id == &"P2" and stage.roster.cards[1].get_node("Status").text == "IN FLIGHT", "Selected P2 remains the active pilot in Stage")
	check(stage.player.scene_file_path == "res://scenes/player/P2_ship.tscn", "Stage instantiates the selected pilot's ship scene")
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


func _test_enemy_hit_effect() -> void:
	var stage := _create_stage()
	await frames(16)
	var enemy := stage._spawn_enemy(load("res://scenes/enemies/scout.tscn"), Vector2(1000, 500))
	enemy.movement.set_physics_process(false)
	var effects := stage.get_node("Simulation/Effects")
	enemy.take_damage(1)
	check(effects.get_child_count() == 1, "A nonlethal enemy hit creates one sprite effect")
	if effects.get_child_count() == 1:
		var effect := effects.get_child(0) as AnimatedSprite2D
		check(effect != null and effect.is_playing() and effect.sprite_frames.get_frame_count(&"hit") == 4, "Enemy hit plays four sprite frames")
		if effect != null:
			for index in 4:
				var texture := load("res://assets/Pilots_sprites/Fx/BloodyAttacked_S%d.png" % (index + 1)) as Texture2D
				check(effect.sprite_frames.get_frame_texture(&"hit", index) == texture, "Enemy hit frame %d uses the requested image" % (index + 1))
	await frames(25)
	check(effects.get_child_count() == 0, "Enemy hit effect frees itself after playback")
	enemy.take_damage(1)
	check(effects.get_child_count() == 1 and effects.get_child(0) is AnimatedSprite2D, "Lethal enemy hit has no old explosion effect")
	stage.queue_free()
	await frames()

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
	var dormant := stage.placed_enemies.get_node("N5Upper") as EnemyShip
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
	var straight_texture := load("res://assets/Pilots_sprites/Player/Projectile_Strait.png") as Texture2D
	var radial_texture := load("res://assets/Pilots_sprites/Player/Projectile_Radial.png") as Texture2D
	check(straight.levels.size() == 3 and spread.levels.size() == 3, "Both weapons have three authored levels")
	var authored_tiers := stage.player.weapon.proximity_tiers
	check(authored_tiers.size() == 2 and authored_tiers[0].distance == 80.0 and authored_tiers[1].distance == 360.0, "Player ship limits bonus damage to close range")
	for level_index in straight.levels.size():
		var level := straight.levels[level_index]
		check(level.angles.size() == level_index + 2, "Straight weapon gains one parallel shot per level")
		check(is_equal_approx(level.interval, 0.16) and level.damage == 1, "Straight upgrades retain their base fire rate and per-bullet damage")
		for angle in level.angles:
			check(is_zero_approx(angle), "Every straight projectile travels forward")
		var shot := level.projectile_scene.instantiate() as Projectile
		check((shot.get_node("Visual") as Sprite2D).texture == straight_texture, "Every straight level uses Projectile_Strait")
		shot.free()
	for level_index in spread.levels.size():
		var level := spread.levels[level_index]
		check(level.angles.size() == 3 + level_index * 2 and is_zero_approx(level.angles[level.angles.size() / 2]), "Spread weapon gains two rays per level")
		check(is_equal_approx(level.angles[0], -level.angles[level.angles.size() - 1]) and is_equal_approx(level.angles[0], -18.0), "Spread fan keeps the same symmetric width")
		check(is_equal_approx(level.interval, 0.22) and level.damage == 1, "Spread upgrades retain their base fire rate and per-bullet damage")
		var shot := level.projectile_scene.instantiate() as Projectile
		check((shot.get_node("Visual") as Sprite2D).texture == radial_texture, "Every spread level uses Projectile_Radial")
		shot.free()
	var bullet_count := stage.projectiles.get_child_count()
	stage.player.weapon.fire()
	check(stage.projectiles.get_child_count() == bullet_count + 2, "Straight LV1 fires two projectiles")
	var straight_bullet := stage.projectiles.get_child(bullet_count) as Projectile
	var second_straight_bullet := stage.projectiles.get_child(bullet_count + 1) as Projectile
	check(is_equal_approx(straight_bullet.global_position.x, second_straight_bullet.global_position.x) and is_equal_approx(straight_bullet.global_position.y, stage.player.weapon.global_position.y - 21.0) and is_equal_approx(second_straight_bullet.global_position.y, stage.player.weapon.global_position.y + 21.0), "Straight bullets spawn in two parallel rows on the enlarged ship")
	check((straight_bullet.get_node("Visual") as Sprite2D).texture == straight_texture, "Fired straight bullet shows the straight image")
	check(straight_bullet.proximity_points.size() == 2 and is_equal_approx(straight_bullet.proximity_points[0].y, 1.6) and straight_bullet.damage_origin.is_equal_approx(straight_bullet.global_position), "Straight shot captures proximity tiers and its own firing origin")
	check(is_equal_approx(straight_bullet.proximity_multiplier(360), 1.0) and is_equal_approx(straight_bullet.proximity_multiplier(80), 1.6), "Fired shots retain base damage at range and cap the close bonus at 1.6")
	await capture("straight_lv1")
	Input.action_press("switch_weapon")
	await frames(2)
	Input.action_release("switch_weapon")
	check(stage.run.current_sortie.active_weapon == SortieState.WeaponType.SPREAD, "Switch input selects spread weapon")
	bullet_count = stage.projectiles.get_child_count()
	stage.player.weapon.fire()
	check(stage.projectiles.get_child_count() == bullet_count + 3, "Spread weapon fires exactly three projectiles")
	check((stage.projectiles.get_child(bullet_count).get_node("Visual") as Sprite2D).texture == radial_texture, "Fired spread bullet shows the radial image")
	check(stage.projectiles.get_child(bullet_count).direction.y < 0.0 and stage.projectiles.get_child(bullet_count + 1).direction.y == 0.0 and stage.projectiles.get_child(bullet_count + 2).direction.y > 0.0, "Spread projectiles fan above, forward, and below")
	check((stage.projectiles.get_child(bullet_count) as Projectile).proximity_points.size() == 2 and (stage.projectiles.get_child(bullet_count + 2) as Projectile).damage_origin.is_equal_approx(stage.player.weapon.global_position), "All spread shots inherit proximity tiers")
	var extra_tier := ProximityDamageTier.new()
	extra_tier.distance = 200.0
	extra_tier.multiplier = 1.8
	var custom_tiers := authored_tiers.duplicate()
	custom_tiers.insert(0, extra_tier)
	stage.player.weapon.proximity_tiers = custom_tiers
	bullet_count = stage.projectiles.get_child_count()
	stage.player.weapon.fire()
	var custom_bullet := stage.projectiles.get_child(bullet_count) as Projectile
	check(custom_bullet.proximity_points.size() == 3 and custom_bullet.proximity_points[1] == Vector2(200.0, 1.8), "Weapon sorts and applies a newly added tier to fired shots")
	custom_tiers.erase(extra_tier)
	bullet_count = stage.projectiles.get_child_count()
	stage.player.weapon.fire()
	check((stage.projectiles.get_child(bullet_count) as Projectile).proximity_points.size() == 2 and custom_bullet.proximity_points.size() == 3, "Removing a tier changes new shots without rewriting shots already fired")
	stage.player.weapon.proximity_tiers = authored_tiers
	stage.player.collect(Pickup.Kind.POWER)
	check(stage.run.current_sortie.current_power_level() == 2, "Power pickup upgrades both weapon patterns")
	bullet_count = stage.projectiles.get_child_count()
	stage.player.weapon.fire()
	check(stage.projectiles.get_child_count() == bullet_count + 5 and (stage.projectiles.get_child(bullet_count) as Projectile).damage == 1, "Spread LV2 fires five base-damage projectiles")
	stage.run.current_sortie.switch_weapon()
	bullet_count = stage.projectiles.get_child_count()
	stage.player.weapon.fire()
	check(stage.projectiles.get_child_count() == bullet_count + 3, "Straight LV2 immediately uses the shared power level")
	stage.run.current_sortie.switch_weapon()
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
	bullet_count = stage.projectiles.get_child_count()
	stage.player.weapon.fire()
	check(stage.projectiles.get_child_count() == bullet_count + 7, "Spread LV3 fires seven projectiles")
	Input.action_press("switch_weapon")
	await frames(2)
	Input.action_release("switch_weapon")
	check(stage.run.current_sortie.active_weapon == SortieState.WeaponType.STRAIGHT, "Second switch restores straight weapon")
	check(stage.run.current_sortie.current_power_level() == 3 and stage.run.current_sortie.recoverable_powerups() == 2, "Both weapons share two recoverable upgrades at LV3")
	bullet_count = stage.projectiles.get_child_count()
	stage.player.weapon.fire()
	check(stage.projectiles.get_child_count() == bullet_count + 4 and (stage.projectiles.get_child(bullet_count) as Projectile).damage == 1, "Straight LV3 fires four base-damage projectiles")
	check(is_equal_approx((stage.projectiles.get_child(bullet_count) as Projectile).global_position.y, stage.player.weapon.global_position.y - 63.0) and is_equal_approx((stage.projectiles.get_child(bullet_count + 3) as Projectile).global_position.y, stage.player.weapon.global_position.y + 63.0), "Straight LV3 keeps four visibly separated rows on the enlarged ship")
	await capture("straight_lv3")
	stage.player.collect(Pickup.Kind.BOMB)
	check(stage.run.current_sortie.bombs == 2, "Bomb pickup restores one spent bomb")
	stage.player.invincibility = 0
	stage.player.take_damage()
	check(stage.run.current_sortie.hp == 1 and stage.run.current_sortie.current_power_level() == 2, "A nonlethal hit lowers both weapons from LV3 to LV2")
	check((stage.roster.cards[0].get_node("Portrait") as TextureRect).texture == content.pilots[0].damaged, "Actual player hit shows the damaged Flight Crew portrait")
	stage.player.collect(Pickup.Kind.POWER)
	check(stage.run.current_sortie.current_power_level() == 3, "Power pickup restores both weapons after damage")
	var item_count := stage.items.get_child_count()
	stage.player.invincibility = 0
	stage.player.take_damage()
	await frames(3)
	check(stage.phase == StageController.Phase.PLAYER_DYING, "Lethal hit enters death presentation")
	check((stage.roster.cards[0].get_node("Portrait") as TextureRect).texture == content.pilots[0].dead, "Lethal player hit shows the dead Flight Crew portrait")
	check(stage.items.get_child_count() == item_count + 4, "Death drops two power-ups and two unspent bombs")
	var death_powerups := 0
	var death_bombs := 0
	var recovery_power: Pickup
	var recovery_bomb: Pickup
	for index in range(item_count, stage.items.get_child_count()):
		var dropped := stage.items.get_child(index) as Pickup
		if dropped.kind == Pickup.Kind.POWER:
			death_powerups += 1
			if recovery_power == null:
				recovery_power = dropped
		elif dropped.kind == Pickup.Kind.BOMB:
			death_bombs += 1
			if recovery_bomb == null:
				recovery_bomb = dropped
	check(death_powerups == 2 and death_bombs == 2, "Death recovery items contain the correct power and bomb types")
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
	check(stage.run.current_sortie.current_power_level() == 1 and stage.run.current_sortie.bombs == 2 and stage.run.current_sortie.hp == 2, "Respawn starts with fresh sortie stats")
	var old_power_position := recovery_power.position
	var old_bomb_position := recovery_bomb.position
	await frames(10)
	check(recovery_power.position.distance_to(old_power_position) > 1.0 and recovery_bomb.position.distance_to(old_bomb_position) > 1.0, "Death power-up and bomb move through the playfield after respawn")
	await capture("07_recovery")
	stage.player.position = recovery_power.position
	await frames(3)
	check(stage.run.current_sortie.current_power_level() == 2, "Next pilot can collect a dropped power-up")
	stage.player.position = recovery_bomb.position
	await frames(3)
	check(stage.run.current_sortie.bombs == 3, "Next pilot can collect a dropped bomb")
	item_count = stage.items.get_child_count()
	stage.run.current_sortie.power_level = 1
	stage.run.current_sortie.bombs = 0
	stage.run.current_sortie.hp = 1
	stage.player.invincibility = 0
	stage.player.take_damage()
	await frames(3)
	check(stage.items.get_child_count() == item_count + 2, "Death at LV1 with zero bombs still drops one of each recovery item")
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

func _test_combat_layout() -> void:
	var stage := _create_stage()
	await frames(16)
	var hud := stage.hud
	var card := stage.roster.cards[0]
	check(stage.roster.get_global_rect().end.x < stage.rules.playfield.position.x, "Combat roster stays left of the playable arena")
	check(card.get_node("OnSortie").visible and not card.get_node("Portrait").visible, "Active pilot slot shows the sortie artwork")
	check(hud.get_node("ActivePilot/ActivePortrait").texture == content.pilots[0].normal, "Cockpit initially shows the active pilot")
	check(hud.bomb_slots.size() == 4 and hud.bomb_slots[0].texture == hud.bomb_ready and hud.bomb_slots[1].texture == hud.bomb_on and hud.bomb_slots[2].texture == hud.bomb_off and hud.bomb_slots[3].texture == hud.bomb_off, "Four bomb slots initially show two filled stocks and two empty stocks")
	var first_wave := stage.waves.get_node("Wave01_Z1") as EnemyWave
	var first_activation := first_wave.global_position.x - stage.rules.playfield.end.x - stage.activation_margin
	check(is_equal_approx(first_activation / stage.scroll_speed, 1.0), "Moving the arena preserves the first wave's one-second arrival")
	# Existing keyboard actions and the console buttons share the same state.
	hud.get_node("BombButton").pressed.emit()
	await frames(2)
	check(stage.run.current_sortie.bombs == 1 and hud.get_node("BombButton/BombTwo").texture == hud.bomb_off, "Bomb console spends one bomb and switches off the second indicator")
	stage.run.current_sortie.collect(Pickup.Kind.BOMB, 3)
	stage.run.current_sortie.collect(Pickup.Kind.BOMB, 3)
	await frames(2)
	check(stage.run.current_sortie.bombs == 3 and hud.bomb_slots[2].texture == hud.bomb_on and hud.bomb_slots[3].texture == hud.bomb_off, "A third bomb fills the third slot and leaves the fourth empty")
	stage.run.current_sortie.collect(Pickup.Kind.BOMB, 3)
	await frames(2)
	check(stage.run.current_sortie.bombs == 4 and hud.bomb_slots[3].texture == hud.bomb_on, "A fourth bomb fills all four console slots")
	await capture("04_combat_bombs_full")
	stage.run.current_sortie.collect(Pickup.Kind.BOMB, 3)
	await frames(2)
	check(stage.run.current_sortie.bombs == 4 and hud.bomb_slots[3].texture == hud.bomb_on, "An extra bomb pickup keeps the full console at four")
	hud.get_node("BombButton").pressed.emit()
	await frames(2)
	check(stage.run.current_sortie.bombs == 3 and hud.bomb_slots[2].texture == hud.bomb_on and hud.bomb_slots[3].texture == hud.bomb_off, "Spending from full stock turns off only the fourth slot")
	hud.get_node("WeaponChange").pressed.emit()
	await frames(2)
	check(stage.run.current_sortie.active_weapon == SortieState.WeaponType.SPREAD and hud.get_node("WeaponBox/WeaponOne").texture == hud.spread_icon, "Change console selects the spread weapon and updates its icon")
	hud.get_node("PauseButton").pressed.emit()
	await frames(2)
	var bombs := stage.run.current_sortie.bombs
	hud.get_node("BombButton").pressed.emit()
	hud.get_node("WeaponChange").pressed.emit()
	check(stage.user_paused and stage.run.current_sortie.bombs == bombs and stage.run.current_sortie.active_weapon == SortieState.WeaponType.SPREAD, "Paused console cannot spend bombs or change weapons")
	hud.get_node("PauseButton").pressed.emit()
	stage.run.current_sortie.collect(Pickup.Kind.SHIELD, 3)
	stage.player.invincibility = 0
	stage.player.take_damage()
	stage.player.take_damage()
	await frames(2)
	check(stage.run.current_sortie.hp == content.rules.starting_hp and not stage.run.current_sortie.shield, "Shield hit preserves HP and protects against simultaneous hits")
	check(stage.player.visuals.texture == stage.player.normal_sprite, "Shield hit keeps the combat ship's normal sprite")
	check(hud.get_node("ActivePilot/ActivePortrait").texture == content.pilots[0].normal and card.get_node("Portrait").texture == content.pilots[0].normal, "Shield hit keeps both cockpit and roster portraits normal")
	stage.player.invincibility = 0
	stage.player.take_damage()
	await frames(2)
	check(hud.get_node("ActivePilot/ActivePortrait").texture == content.pilots[0].damaged and card.get_node("OnSortie").visible, "Damage changes the cockpit portrait while keeping the sortie slot")
	stage.run.current_sortie.bombs = 0
	await frames(2)
	check(hud.get_node("BombButton").disabled and hud.bomb_slots.all(func(slot: TextureRect) -> bool: return slot.texture == hud.bomb_off), "Empty bomb stock disables the console and all four indicators")
	await capture("04_combat_damage")
	stage.player.invincibility = 0
	stage.player.take_damage()
	await frames(3)
	check(card.get_node("Portrait").visible and not card.get_node("OnSortie").visible and hud.get_node("ActivePilot/ActivePortrait").texture == content.pilots[0].dead, "Pilot death restores the lost slot and cockpit portrait")
	stage.queue_free()
	await frames()

func _test_playfield_edges() -> void:
	var stage := _create_stage()
	await frames(16)
	stage.set_physics_process(false)
	stage.simulation.process_mode = Node.PROCESS_MODE_DISABLED
	stage.player.invincibility = 0.0
	stage.player.auto_advance_speed = 0.0
	check(stage.rules.playfield == stage.presentation_bounds, "Movement covers the complete battle frame interior")
	for progress in [0.0, 1200.0]:
		stage.progress_x = progress
		stage._sync_world_bounds()
		for corner in [Vector2(-10000, -10000), Vector2(10000, -10000), Vector2(-10000, 10000), Vector2(10000, 10000)]:
			stage.player.position = corner + Vector2(progress, 0)
			stage.player._physics_process(0.0)
			var expected_x := 1844.0 if corner.x > 0 else 500.0
			var expected_y := 931.0 if corner.y > 0 else 69.0
			check(stage.player.position.is_equal_approx(Vector2(expected_x + progress, expected_y)), "Ship reaches the frame edge at each corner before and after scrolling")
			for texture in [stage.player.normal_sprite, stage.player.normal_back_sprite, stage.player.normal_forward_sprite, stage.player.damaged_sprite, stage.player.damaged_back_sprite, stage.player.damaged_forward_sprite]:
				var artwork := Rect2(texture.get_image().get_used_rect())
				artwork.position -= Vector2(texture.get_size()) * 0.5
				var world_artwork: Rect2 = stage.player.visuals.global_transform * artwork
				check(stage.view_bounds.encloses(world_artwork), "Every normal and damaged pose remains inside the expanded playfield")
			if is_zero_approx(progress):
				await capture("playfield_edge_%s_%s" % ["right" if corner.x > 0 else "left", "bottom" if corner.y > 0 else "top"])
		for location in [Vector2(510, 850), Vector2(650, 925), Vector2(1000, 925), Vector2(1250, 925), Vector2(1740, 925)]:
			stage.player.position = location + Vector2(progress, 0)
			stage.player._physics_process(0.0)
			check(stage.player.position.is_equal_approx(location + Vector2(progress, 0)), "Overlapping the cockpit frame or any console does not displace the ship")
		stage.player.position = Vector2(500 + progress, 931)
		Input.action_press("move_right")
		var stayed_at_bottom := true
		for frame_index in 180:
			stage.player._physics_process(1.0 / 60.0)
			stayed_at_bottom = stayed_at_bottom and is_equal_approx(stage.player.position.y, 931.0)
		Input.action_release("move_right")
		check(stayed_at_bottom and is_equal_approx(stage.player.position.x, 1844 + progress), "Ship crosses the entire bottom edge without being pushed by UI")
	stage.progress_x = 0.0
	stage._sync_world_bounds()
	stage.player.position = Vector2(850, 500)
	stage._spawn_enemy(load("res://scenes/enemies/z1_wedge.tscn"), Vector2(1200, 260))
	stage._spawn_enemy(load("res://scenes/enemies/n1_interceptor.tscn"), Vector2(1550, 270))
	stage._spawn_enemy(load("res://scenes/enemies/m2_wing.tscn"), Vector2(1500, 620))
	await capture("04_ship_sizes")
	stage.queue_free()
	await frames()

func _test_full_stage() -> void:
	var stage := _create_stage()
	await frames(16)
	var authored_waves := 0
	var authored_enemies := 0
	var featured_types := {}
	var early_power_supplies := 0
	var total_power_supplies := 0
	for wave in stage.waves.get_children():
		if wave is EnemyWave:
			if wave.drop_scene != null and wave.drop_scene.resource_path == "res://scenes/items/power_up.tscn" and wave.drop_mode == EnemyWave.DropMode.GUARANTEED:
				total_power_supplies += wave.count
				if wave.position.x < 1568 + 34 * 180: early_power_supplies += wave.count
			authored_waves += 1
			authored_enemies += wave.count
			check(wave.enemy_scene != null, "Authored wave has an enemy scene: " + wave.name)
			if wave.enemy_scene != null:
				featured_types[wave.enemy_scene.resource_path.get_file().get_basename()] = true
	check(authored_waves == 97 and authored_enemies == 298, "Stage keeps all 97 configured waves and 298 wave enemies")
	check(featured_types.size() == 13, "Every planned enemy type appears in the one stage")
	check(early_power_supplies == 1 and total_power_supplies == 5, "Authored supplies reach only LV2 before the first middle and retain later recovery drops")
	stage.player.invincibility = 300.0
	# Fast-forward traversal for the longer one-stage route; keep the ship with the camera.
	stage.scroll_speed = 720.0
	stage.player.auto_advance_speed = 720.0
	Input.action_press("shoot")
	# Run the entire authored route without moving the camera manually.
	var mid_encounters := 0
	for i in 4150:
		await process_frame
		if is_instance_valid(stage.mid_enemy):
			mid_encounters += 1
			stage.mid_enemy.take_damage(9999)
		if stage.waves.boss_sent and is_instance_valid(stage.boss):
			break
		if i % 120 == 0 and is_instance_valid(stage.player):
			stage.player.position.y = 532 + sin(i * 0.006) * 260
	Input.action_release("shoot")
	check(mid_encounters == 3, "All three middle enemy encounters pause the route")
	check(stage.waves.boss_sent and is_instance_valid(stage.boss), "Travel reaches the placed boss marker")
	var emitted := 0
	for wave in stage.waves.get_children():
		if wave is EnemyWave:
			check(wave.emitted == wave.count, "Spatial group emits all enemies: " + wave.name)
			emitted += wave.emitted
	check(emitted + stage.placed_activated == 300, "Spatial groups and placed enemies activate all 300 non-boss enemies")
	check(stage.placed_activated == 2 and stage.placed_enemies.get_child_count() == 0, "Placed enemy scenes activate when the camera reaches them")
	var boss := stage.boss
	if is_instance_valid(boss):
		await frames(150)
		boss.take_damage(boss.maximum_hp * 0.55)
		check(boss.phase_two and boss.shooter.steps == boss.second_phase, "Boss swaps to phase-two sequence at its HP threshold")
		await frames(120)
		await capture("09_boss")
		boss.take_damage(9999)
		await frames(3)
		check(stage.phase == StageController.Phase.CLEARING and stage.run.boss_cleared, "Boss damage, death signal and clear transition are connected")
	stage.queue_free()
	await frames()

func _test_redesigned_encounters() -> void:
	var enemy := load("res://scenes/enemies/n4_armor.tscn").instantiate() as EnemyShip
	var profile := load("res://data/movement/strafe_center.tres") as MovementProfile
	enemy.position = profile.hold_position
	enemy.bounds = Rect2(48, 100, 1440, 864)
	enemy.get_node("Movement").apply_profile(profile)
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.shooter.set_physics_process(false)
	var movement := enemy.movement
	movement.set_physics_process(false)
	movement._physics_process(0.1)
	check(movement.reached_hold, "Strafing enemy reaches its firing station")
	var original := enemy.position
	enemy.bounds.position.x += 18.0
	movement._physics_process(0.1)
	check(is_equal_approx(enemy.position.x - original.x, 18.0), "Strafing enemy follows camera motion while holding")
	check(enemy.position.y > original.y, "Strafe creates a moving muzzle rather than a static hold")
	check(is_equal_approx(profile.hold_position.x, 1160.0), "Movement does not mutate the shared profile")
	check(enemy.shooter.can_fire(), "Strafing battery can attack while stationed")
	movement.hold_elapsed = movement.hold_seconds
	var exit_x := enemy.position.x
	movement._physics_process(0.1)
	check(enemy.position.x > exit_x, "Unkilled strafing enemy retreats forward instead of trapping the rear")
	check(not enemy.shooter.can_fire(), "Retreating battery stops shooting before the recovery lane")
	enemy.queue_free()
	var gate := load("res://data/patterns/gate_fan.tres") as AttackPattern
	var gate_angles := gate.angles_for_volley(PI, 0)
	var centre_gap := 2.0 * 300.0 * sin((gate_angles[2] - gate_angles[1]) * 0.5)
	check(gate_angles[1] < PI and gate_angles[2] > PI and centre_gap > 90.0, "Gate leaves a usable centre gap at 300px before combining other hazards")
	var sweep := load("res://data/patterns/sweep_fan.tres") as AttackPattern
	check(sweep.recovery > (sweep.volley_count - 1) * sweep.volley_interval + 1.0, "Sweeping battery has a deliberate approach window after its burst")
	var stage := _create_stage()
	await frames(2)
	var first_homing := INF
	for wave in stage.waves.get_children():
		if wave is EnemyWave and wave.enemy_scene.resource_path.ends_with("n5_tendril.tscn"):
			first_homing = minf(first_homing, (wave.global_position.x - stage.rules.playfield.end.x - stage.activation_margin) / stage.scroll_speed)
	for placed in stage.placed_enemies.get_children():
		if placed is EnemyShip and placed.scene_file_path.ends_with("n5_tendril.tscn"):
			first_homing = minf(first_homing, (placed.global_position.x - stage.rules.playfield.end.x - stage.activation_margin) / stage.scroll_speed)
	check(is_equal_approx(first_homing, 85.0), "Homing enemies cannot precede their isolated lesson at scroll second 85")
	stage.queue_free()
	await frames()
