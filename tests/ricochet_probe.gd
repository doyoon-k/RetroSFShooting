extends SceneTree
## Deterministic bank geometry, real player contact, pause, cancellation and recovery.
var failures: Array[String] = []
var checks := 0
var content: GameCatalog

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func cleanup(node: Node) -> void:
	node.queue_free()
	await process_frame
	await process_frame

func setup_core(parent: Node2D, arena: Rect2, origin: Vector2, above: bool) -> RicochetCore:
	var core := load("res://scenes/projectiles/ricochet_core.tscn").instantiate() as RicochetCore
	core.position = parent.to_local(origin)
	core.bounds = arena
	core.starts_above = above
	parent.add_child(core)
	core.set_physics_process(false)
	return core

func geometry() -> void:
	for offset in [Vector2.ZERO, Vector2(26000, 0)]:
		var arena := content.rules.playfield
		arena.position += offset
		for x in [0.55, 0.75, 0.9]:
			for y in [0.18, 0.5, 0.82]:
				for above in [true, false]:
					var parent := Node2D.new()
					parent.position = offset + Vector2(13, 7)
					root.add_child(parent)
					var origin := arena.position + arena.size * Vector2(x, y)
					var core := setup_core(parent, arena, origin, above)
					var walls: Array[Vector2] = []
					var counts := [0, 0, 0]
					core.banked.connect(func(_index: int, normal: Vector2): walls.append(normal))
					core.offspring_spawned.connect(func(child: Projectile):
						child.set_physics_process(false)
						counts[core.bank_count - 1] += 1
						expect(not child is RicochetCore and not child is BroodCore and child.bounds == arena, "Banks spawn only one ordinary generation")
						expect(is_equal_approx(child.speed, 360.0) and is_equal_approx(child.lifetime, 3.8), "Residual bullets keep their stronger speed and bounded lifetime")
						expect(child.direction.dot(walls[-1]) >= -0.0001, "Every fan bullet travels inward, even for a shallow bank"))
					var initial_direction := core.direction
					var bank := core.next_bank()
					core._physics_process(maxf(0.0, float(bank.distance) / core.speed - 0.4))
					expect(core.bank_count == 0 and float(core.next_bank().distance) / core.speed <= core.bank_warning_seconds, "The first bank is announced before impact")
					expect(core.direction.is_equal_approx(initial_direction), "Flight keeps the launch direction until a physical wall bank")
					for frame in 900:
						if core.is_queued_for_deletion(): break
						core._physics_process(1.0 / 60.0)
						expect(core.bank_arena.grow(0.01).has_point(core.global_position), "Bank integration never overshoots a wall")
					var expected_walls := [Vector2.DOWN, Vector2.RIGHT, Vector2.UP] if above else [Vector2.UP, Vector2.RIGHT, Vector2.DOWN]
					expect(walls == expected_walls and counts == [7, 9, 11] and core.is_queued_for_deletion(), "Both mirrored routes produce exactly three banks and 27 offspring")
					expect(is_equal_approx(core.speed, 640.0 * pow(0.96, 3)) and core.collision_layer == 0, "The core retains pressure through later banks and exhaustion removes its hitbox")
					await cleanup(parent)

func cancellation_and_pause() -> void:
	var parent := Node2D.new()
	root.add_child(parent)
	var arena := content.rules.playfield
	for after_bank in [false, true]:
		var core := setup_core(parent, arena, arena.position + Vector2(1050, 476), true)
		if after_bank:
			core._physics_process(float(core.next_bank().distance) / core.speed + 0.001)
			expect(core.bank_count == 1 and parent.get_child_count() == 1, "A bank gives a 0.18-second fan cue before creating children")
		core.queue_free()
		core._physics_process(10.0)
		await process_frame
		expect(parent.get_child_count() == 0, "Clearing the core during flight or a fan cue cancels pending offspring")
	var core := setup_core(parent, arena, arena.position + Vector2(1050, 476), true)
	core.set_physics_process(true)
	paused = true
	var age_before := core.age
	var position_before := core.global_position
	for frame in 3: await process_frame
	expect(core.age == age_before and core.global_position == position_before, "Pause freezes bank travel and its lifetime")
	paused = false
	for frame in 3: await physics_frame
	expect(core.age > age_before, "Bank travel resumes after pause")
	await cleanup(parent)
	parent = Node2D.new()
	root.add_child(parent)
	core = setup_core(parent, arena, arena.position + Vector2(1050, 476), true)
	var player := content.pilot_by_id(&"P2").ship_scene.instantiate() as PlayerShip
	player.state = SortieState.new(content.rules)
	player.rules = content.rules
	player.bounds = arena
	player.position = core.global_position + core.direction * 120.0
	parent.add_child(player)
	player.set_physics_process(false)
	player.weapon.set_physics_process(false)
	core.set_physics_process(true)
	for frame in 40: await physics_frame
	expect(player.state.hp == content.rules.starting_hp - 1 and parent.get_child_count() == 1, "Real player contact consumes the core once without creating offspring")
	await cleanup(parent)

func recovery() -> void:
	var arena := content.rules.playfield
	var parent := Node2D.new()
	root.add_child(parent)
	var bullets := Node2D.new()
	parent.add_child(bullets)
	var shooter := EnemyShooter.new()
	shooter.position = arena.position + Vector2(1050, 476)
	shooter.bounds = arena
	shooter.projectiles = bullets
	parent.add_child(shooter)
	shooter.set_physics_process(false)
	shooter.set_sequence((load("res://data/sequences/ricochet.tres") as AttackSequence).steps)
	shooter.timer = 0.0
	shooter._physics_process(0.01)
	expect(shooter.warning and is_equal_approx(shooter.timer, 0.6), "Bank charge uses the pattern's 0.6-second warning")
	shooter._physics_process(0.59)
	expect(bullets.get_child_count() == 0, "Charge does not emit prematurely")
	shooter._physics_process(0.02)
	var core := bullets.get_child(0) as RicochetCore
	core.set_physics_process(false)
	expect(core.starts_above and not shooter.ricochet_starts_above, "The first route is upper and the next route is its mirror")
	core._physics_process(float(core.next_bank().distance) / core.speed + core.bank_pause_seconds + 0.01)
	for bullet: Projectile in bullets.get_children(): bullet.set_physics_process(false)
	core.queue_free()
	await process_frame
	shooter._physics_process(30.0)
	expect(shooter._waiting_for_clear and is_equal_approx(shooter.timer, 1.0) and bullets.get_child_count() == 7, "Recovery waits for offspring even after the core has gone")
	shooter.set_sequence((load("res://data/sequences/ricochet.tres") as AttackSequence).steps)
	shooter._physics_process(10.0)
	expect(shooter._waiting_for_clear and bullets.get_child_count() == 7, "A sequence change preserves the pending family barrier")
	for bullet in bullets.get_children(): bullet.queue_free()
	await process_frame
	shooter._physics_process(0.1)
	shooter._physics_process(0.99)
	expect(not shooter.warning and bullets.get_child_count() == 0, "The full one-second counter window starts after the final residual bullet")
	shooter._physics_process(0.02)
	expect(shooter.warning and bullets.get_child_count() == 0, "The next charge starts only after the counter window")
	shooter._physics_process(0.61)
	expect((bullets.get_child(0) as RicochetCore).starts_above == false, "Route alternation survives sequence changes")
	await cleanup(parent)
	parent = Node2D.new()
	root.add_child(parent)
	bullets = Node2D.new()
	parent.add_child(bullets)
	shooter = EnemyShooter.new()
	shooter.position = arena.position + Vector2(1050, 476)
	shooter.bounds = arena
	shooter.projectiles = bullets
	parent.add_child(shooter)
	shooter.set_physics_process(false)
	shooter.set_sequence((load("res://data/sequences/ricochet.tres") as AttackSequence).steps)
	shooter.timer = 0.0
	shooter._fire_volley(load("res://data/patterns/siege_curtain.tres"), PI)
	for bullet: Projectile in bullets.get_children(): bullet.set_physics_process(false)
	var wall_count := bullets.get_child_count()
	shooter._physics_process(30.0)
	expect(not shooter.warning and bullets.get_child_count() == wall_count, "A bank charge waits for the preceding curtain's residual bullets")
	for bullet in bullets.get_children(): bullet.queue_free()
	await process_frame
	shooter._physics_process(0.01)
	expect(shooter.warning and is_equal_approx(shooter.timer, 0.6), "Curtain clearance starts a fresh, full bank charge")
	await cleanup(parent)
	parent = Node2D.new()
	root.add_child(parent)
	bullets = Node2D.new()
	parent.add_child(bullets)
	var enemy := load("res://scenes/enemies/m2_wing.tscn").instantiate() as EnemyShip
	enemy.position = arena.position + Vector2(1260, 476)
	enemy.bounds = arena
	parent.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.movement.set_physics_process(false)
	enemy.movement.reached_hold = true
	shooter = enemy.shooter
	expect(shooter.steps[0].pattern.shape == AttackPattern.Shape.RICOCHET, "The L2 winged enemy introduces the bank pattern in its opening attack")
	expect((enemy.get_node("Visual") as Sprite2D).texture.resource_path.ends_with("/Enemy/L2.png"), "The bank attack belongs to the pictured Mutalisk-shaped enemy")
	shooter.set_physics_process(false)
	shooter.bounds = arena
	shooter.projectiles = bullets
	shooter.timer = 0.0
	shooter._physics_process(0.01)
	expect(shooter.warning and is_equal_approx(shooter.timer, 0.6), "M2 includes the bank cycle with its full charge")
	shooter._physics_process(0.61)
	core = bullets.get_child(0) as RicochetCore
	core.set_physics_process(false)
	core._physics_process(float(core.next_bank().distance) / core.speed + core.bank_pause_seconds + 0.01)
	for bullet: Projectile in bullets.get_children(): bullet.set_physics_process(false)
	shooter._physics_process(30.0)
	expect(shooter._waiting_for_clear and shooter.volleys_fired == 1, "M2 waits for the bank family before wing-cross volleys")
	for bullet in bullets.get_children(): bullet.queue_free()
	await process_frame
	shooter._physics_process(0.01)
	expect(not shooter._waiting_for_clear and is_equal_approx(shooter.timer, 1.0), "M2's counter window starts only after residual bullets disappear")
	shooter._physics_process(0.99)
	expect(bullets.get_child_count() == 0 and not shooter.warning, "M2 cannot shoot inside the bank counter window")
	shooter._physics_process(0.02)
	expect(shooter.warning and shooter.steps[shooter.step_index].pattern.shape != AttackPattern.Shape.RICOCHET, "M2 resumes its original wing attack after the bank counter window")
	await cleanup(parent)
	var boss := load("res://scenes/enemies/boss.tscn").instantiate() as EnemyShip
	var ricochet_step := load("res://data/patterns/ricochet_step.tres") as PatternStep
	expect(not (boss.get_node("Shooter") as EnemyShooter).steps.has(ricochet_step) and not boss.second_phase.has(ricochet_step), "The bank pattern is removed from both mistaken boss phases")
	boss.free()
	var m1 := load("res://scenes/enemies/m1_carapace.tscn").instantiate() as EnemyShip
	expect((m1.get_node("Shooter") as SiegeShooter).cycle_index == SiegeShooter.Cycle.LURE, "The mistaken M1 opening is restored to lure and walls")
	m1.free()

func aimed_fan() -> void:
	var parent := Node2D.new()
	root.add_child(parent)
	var arena := content.rules.playfield
	var target := Node2D.new()
	target.position = arena.position + Vector2(450, 680)
	parent.add_child(target)
	var core := setup_core(parent, arena, arena.position + Vector2(1050, 476), true)
	core.target = target
	var first_bank := core.next_bank()
	core._physics_process(float(first_bank.distance) / core.speed - 0.4)
	var expected := RicochetCore.fan_direction(Vector2(first_bank.position).direction_to(target.global_position), first_bank.normal, core.child_spread)
	expect(core._fan_bank == 1 and core._fan_center.is_equal_approx(expected), "The first bank locks a fan toward the player during the visible warning")
	var locked := core._fan_center
	target.position = arena.position + Vector2(380, 120)
	var children: Array[Projectile] = []
	core.offspring_spawned.connect(func(child: Projectile):
		child.set_physics_process(false)
		children.append(child))
	core._physics_process(0.4 + core.bank_pause_seconds + 0.01)
	expect(children.size() == 7 and children[3].direction.is_equal_approx(locked), "A player move after the warning cannot secretly retarget the emitted fan")
	var second_bank := core.next_bank()
	core._physics_process(float(second_bank.distance) / core.speed - 0.4)
	expected = RicochetCore.fan_direction(Vector2(second_bank.position).direction_to(target.global_position), second_bank.normal, core.child_spread)
	expect(core._fan_bank == 2 and core._fan_center.is_equal_approx(expected), "The second bank reacquires the player's new position for its own warning")
	await cleanup(parent)

func showcase() -> void:
	if DisplayServer.get_name() == "headless": return
	var stage := load("res://scenes/gameplay/stage/stage_01.tscn").instantiate() as StageController
	root.add_child(stage)
	stage.set_physics_process(false)
	stage._enter(StageController.Phase.PLAYING)
	stage.player.auto_advance_speed = 0.0
	stage.player.position = stage.rules.spawn_position
	stage.player.weapon.set_physics_process(false)
	var enemy := stage._spawn_enemy(load("res://scenes/enemies/m2_wing.tscn"), Vector2(stage.view_bounds.end.x - 280, stage.view_bounds.get_center().y))
	enemy.movement.set_physics_process(false)
	enemy.movement.reached_hold = true
	enemy.shooter.timer = 0.0
	var captured := {}
	DirAccess.make_dir_recursive_absolute("res://build/screenshots")
	for frame in 660:
		await physics_frame
		stage.player.invincibility = 2.0
		var label := ""
		if frame == 18: label = "charge"
		for bullet in stage.projectiles.get_children():
			if bullet is RicochetCore:
				if bullet.bank_wait > 0.04: label = "bank_%d" % bullet.bank_count
		if label.is_empty() or captured.has(label): continue
		captured[label] = true
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/screenshots/ricochet_" + label + ".png")
	expect(captured.size() == 4, "Showcase renders the charge and all three bank cues")
	await cleanup(stage)

func run() -> void:
	content = load("res://data/game_catalog.tres") as GameCatalog
	await geometry()
	await cancellation_and_pause()
	await recovery()
	await aimed_fan()
	if OS.get_cmdline_user_args().has("--screenshots"): await showcase()
	var report := {"checks": checks, "failures": failures, "method": "36 mirrored geometry trials; locked aimed fans; real contact and pause; family clearance, cancellation and M2-only integration"}
	DirAccess.make_dir_recursive_absolute("res://build/validation")
	FileAccess.open("res://build/validation/ricochet.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
