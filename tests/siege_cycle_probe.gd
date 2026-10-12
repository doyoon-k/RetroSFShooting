extends SceneTree
## Known-cue P2 movement, real collisions, no shooting, bombs, or invincibility.
## Isolates M1; this does not measure whole-stage survival or human difficulty.

var catalog: GameCatalog
var failures: Array[String] = []
var hits := 0

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func setup_enemy(container: Node2D, bullets: Node2D, target: Node2D) -> EnemyShip:
	var enemy := load("res://scenes/enemies/m1_carapace.tscn").instantiate() as EnemyShip
	enemy.position = Vector2(catalog.rules.playfield.position.x + 1136, catalog.rules.playfield.get_center().y)
	enemy.bounds = catalog.rules.playfield
	container.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.movement.set_physics_process(false)
	enemy.movement.reached_hold = true
	var shooter := enemy.shooter as SiegeShooter
	# Isolate the three existing wall combinations, then observe the bank charge.
	shooter.cycle_index = SiegeShooter.Cycle.LURE
	shooter.projectiles = bullets
	shooter.bounds = catalog.rules.playfield
	shooter.target_provider = func(): return target
	return enemy

func contracts() -> void:
	var container := Node2D.new()
	root.add_child(container)
	var bullets := Node2D.new()
	var target := Node2D.new()
	container.add_child(bullets)
	container.add_child(target)
	target.position = catalog.rules.playfield.position + Vector2(200, 750)
	var enemy := setup_enemy(container, bullets, target)
	var shooter := enemy.shooter as SiegeShooter
	shooter.set_physics_process(false)
	expect(enemy.maximum_hp == 360 and is_equal_approx(shooter.counter_seconds, 2.0), "M1 keeps 360 HP and a two-second counter window")
	enemy.movement.reached_hold = false
	expect(not shooter.can_fire(), "M1 waits at its station before starting the compound attacks")
	enemy.movement.reached_hold = true
	shooter.timer = 0.0
	shooter._physics_process(0.01)
	var expected_direction := shooter.global_position.direction_to(target.position)
	target.position.y = catalog.rules.playfield.position.y + 150
	shooter._physics_process(shooter.telegraph_seconds + 0.01)
	shooter._physics_process(shooter.lure_interval + 0.01)
	expect(bullets.get_child_count() == 2, "Lure emits exactly two shots")
	for bullet: Projectile in bullets.get_children():
		bullet.set_physics_process(false)
		expect(bullet.direction.is_equal_approx(expected_direction), "Both lure shots keep the aim shown before the player moves")
	shooter._physics_process(shooter.opening_pause + shooter.telegraph_seconds + 0.01)
	for index in 2: shooter._physics_process(0.86)
	for bullet: Projectile in bullets.get_children(): bullet.set_physics_process(false)
	var count := bullets.get_child_count()
	shooter._physics_process(30.0)
	expect(bullets.get_child_count() == count and shooter.cycle_phase == SiegeShooter.Phase.WAIT_WALL, "Elapsed time cannot release a follow-up while walls still exist")
	for bullet in bullets.get_children(): bullet.queue_free()
	await process_frame
	shooter._physics_process(0.01)
	shooter._physics_process(0.01)
	expect(shooter.cycle_phase == SiegeShooter.Phase.RECOVERY and is_equal_approx(shooter.timer, 2.0), "Recovery starts only after the preceding hazards clear")
	shooter._physics_process(1.99)
	expect(shooter.cycle_phase == SiegeShooter.Phase.RECOVERY and bullets.get_child_count() == 0, "The two-second recovery has no early shot")
	shooter._physics_process(0.02)
	expect(shooter.cycle_index == SiegeShooter.Cycle.CROSS and shooter.warning and bullets.get_child_count() == 0, "The next cycle is cross, with a fresh warning")
	var core := load("res://scenes/projectiles/siege_core.tscn").instantiate() as BroodCore
	core.position = catalog.rules.playfield.get_center()
	core.bounds = catalog.rules.playfield
	core.hatch_held = true
	bullets.add_child(core)
	core.set_physics_process(false)
	core._physics_process(core.travel_seconds)
	core._physics_process(5.0)
	core.hatch()
	expect(not core.hatched and is_zero_approx(core.incubation_elapsed) and not core.incubation_hints.visible, "A stopped core waits for wall clearance without hatching or consuming its cue")
	core.hatch_held = false
	core._physics_process(0.3)
	expect(not core.hatched and core.incubation_hints.visible, "Release begins a visible incubation, not an instant hatch")
	core._physics_process(0.36)
	expect(core.hatched and bullets.get_child_count() == 6, "Released siege core hatches one five-shot generation")
	for bullet in bullets.get_children(): bullet.queue_free()
	await process_frame
	var cancelled := load("res://scenes/projectiles/siege_core.tscn").instantiate() as BroodCore
	cancelled.position = catalog.rules.playfield.get_center()
	cancelled.bounds = catalog.rules.playfield
	cancelled.hatch_held = true
	bullets.add_child(cancelled)
	cancelled.queue_free()
	cancelled.hatch_held = false
	cancelled.hatch()
	await process_frame
	expect(bullets.get_child_count() == 0, "Projectile clearing cancels a held core without delayed offspring")
	enemy.apply_attack_sequence(load("res://data/sequences/aimed.tres"))
	shooter.timer = 0.0
	shooter._physics_process(0.01)
	shooter._physics_process(shooter.telegraph_seconds + 0.01)
	expect(not shooter.wall_cycles_enabled and bullets.get_child_count() == 1, "An explicit lab attack preset overrides M1's compound cycle")
	enemy.apply_attack_sequence(load("res://data/sequences/silent.tres"))
	expect(shooter.steps.is_empty(), "Silent lab preset disables M1 attacks")
	container.queue_free()
	await process_frame

func seed_for_route(route: int, count: int, cross_route: int) -> int:
	for candidate in 1000:
		seed(candidate)
		if randi_range(0, count - 1) != route: continue
		var next := randi_range(0, count - 2)
		if next >= route: next += 1
		if next == cross_route: return candidate
	return 0

func observe_shot(child: Node, shooter: SiegeShooter, clock: Dictionary) -> void:
	if child is CurtainBullet:
		var times: Array = clock.wall_times
		if times.is_empty() or not is_equal_approx(times[-1], clock.time): times.append(clock.time)
	elif child is BroodCore:
		clock.cores += 1
	elif child is Projectile:
		if shooter.cycle_phase == SiegeShooter.Phase.RECOVERY: clock.unsafe_shots += 1
		if shooter.cycle_index != SiegeShooter.Cycle.LURE:
			for wall in shooter._walls:
				if is_instance_valid(wall) and not wall.is_queued_for_deletion(): clock.followup_overlap += 1
		if shooter.cycle_index == SiegeShooter.Cycle.LURE: clock.lure += 1
		elif shooter.cycle_index == SiegeShooter.Cycle.CROSS: clock.cross += 1
		else:
			if clock.children % 5 == 0: clock.hatches.append(clock.time)
			clock.children += 1

func guide(player: PlayerShip, shooter: SiegeShooter, clock: Dictionary, bullets: Node2D, distance: float) -> float:
	var arena := catalog.rules.playfield
	var pattern := shooter.steps[0].pattern
	if shooter.cycle_phase == SiegeShooter.Phase.WAIT: return player.position.y
	if shooter.cycle_phase == SiegeShooter.Phase.RECOVERY: return arena.get_center().y
	var index: int = clock.wall_index
	if index >= 3:
		return arena.position.y + arena.size.y * 0.16 if shooter.cycle_index == SiegeShooter.Cycle.CROSS else pattern.corridor_y(arena, 2, shooter.curtain_route_index)
	var gap := pattern.corridor_y(arena, index, shooter.curtain_route_index)
	gap += pattern.sway_for_volley(index) * sin(distance / 300.0 * TAU / pattern.curtain_sway_period)
	if shooter.cycle_index == SiegeShooter.Cycle.LURE and index == 0:
		var incoming := shooter.cycle_phase == SiegeShooter.Phase.LURE
		for bullet in bullets.get_children():
			if bullet is Projectile and not bullet is CurtainBullet and bullet.global_position.x > player.position.x - 60.0:
				incoming = true
		var aimed_y := shooter.global_position.y + tan(shooter._lure_angle) * (player.position.x - shooter.global_position.x)
		if incoming and absf(gap - aimed_y) < 140.0:
			gap = clampf(gap + 180.0, arena.position.y + 60.0, arena.end.y - 60.0)
	return gap

func trial(route: int, distance: float, fraction: float) -> Dictionary:
	var arena := catalog.rules.playfield
	var container := Node2D.new()
	root.add_child(container)
	var bullets := Node2D.new()
	container.add_child(bullets)
	var player := catalog.pilot_by_id(&"P2").ship_scene.instantiate() as PlayerShip
	player.state = SortieState.new(catalog.rules)
	player.rules = catalog.rules
	player.bounds = arena
	player.position = Vector2(arena.position.x + 926 - distance, arena.position.y + arena.size.y * fraction)
	container.add_child(player)
	player.weapon.set_physics_process(false)
	player.hit.connect(func(): hits += 1)
	var enemy := setup_enemy(container, bullets, player)
	var shooter := enemy.shooter as SiegeShooter
	shooter.timer = 0.4
	var clock := {"time": 0.0, "wall_times": [], "wall_index": 0, "crossed": 0, "cores": 0, "lure": 0, "cross": 0, "children": 0, "hatches": [], "unsafe_shots": 0, "followup_overlap": 0}
	var starts: Array[Dictionary] = []
	var windows: Array[Dictionary] = []
	bullets.child_entered_tree.connect(observe_shot.bind(shooter, clock))
	shooter.cycle_started.connect(func(index: int):
		starts.append({"index": index, "time": clock.time, "route": shooter.curtain_route_index})
		clock.wall_times = []
		clock.wall_index = 0)
	shooter.counter_window_started.connect(func(index: int): windows.append({"index": index, "time": clock.time}))
	var variation := (0 if distance < 500.0 else 1) + (0 if fraction < 0.3 else (1 if fraction < 0.7 else 2))
	var cross_route := (route + 1 + variation % 3) % 4
	seed(seed_for_route(route, shooter.steps[0].pattern.corridor_routes.size(), cross_route))
	hits = 0
	var peak := 0
	for frame in 3000:
		await physics_frame
		clock.time = frame / 60.0
		peak = maxi(peak, bullets.get_child_count())
		while clock.wall_index < clock.wall_times.size() and clock.time > float(clock.wall_times[clock.wall_index]) + distance / 300.0 + 0.15:
			clock.wall_index += 1
			clock.crossed += 1
		Input.action_release("move_up")
		Input.action_release("move_down")
		if starts.size() >= 4: break
		var target_y := guide(player, shooter, clock, bullets, distance)
		if absf(target_y - player.position.y) > player.move_speed / 120.0:
			Input.action_press("move_up" if target_y < player.position.y else "move_down")
	var order: Array[int] = []
	for entry in starts: order.append(entry.index)
	var recovery_ok := windows.size() == 3 and starts.size() == 4
	if recovery_ok:
		for index in 3:
			recovery_ok = recovery_ok and float(starts[index + 1].time) - float(windows[index].time) >= 1.99
	var result := {"first_route": route, "distance": distance, "start_fraction": fraction, "hits": hits,
		"order": order, "recovery_ok": recovery_ok, "starts": starts, "windows": windows,
		"walls_crossed": clock.crossed, "lure_shots": clock.lure, "cross_shots": clock.cross,
		"cores": clock.cores, "offspring": clock.children, "hatches": clock.hatches,
		"followup_overlap": clock.followup_overlap, "unsafe_shots": clock.unsafe_shots,
		"expected_cross_route": cross_route, "peak_bullets": peak, "move_speed": player.move_speed}
	Input.action_release("move_up")
	Input.action_release("move_down")
	container.queue_free()
	await process_frame
	return result

func run() -> void:
	catalog = load("res://data/game_catalog.tres") as GameCatalog
	await contracts()
	var pattern := load("res://data/patterns/siege_curtain.tres") as AttackPattern
	var authored := pattern.corridor_routes.duplicate(true)
	var trials: Array[Dictionary] = []
	for route in 4:
		for distance in [450.0, 726.0]:
			for fraction in [0.15, 0.5, 0.85]:
				var result := await trial(route, distance, fraction)
				trials.append(result)
				expect(result.hits == 0 and result.order == [0, 1, 2, 3] and result.recovery_ok and result.walls_crossed == 9 and result.lure_shots == 2 and result.cross_shots == 6 and result.cores == 2 and result.offspring == 10, "M1 input-only cycle failed: " + JSON.stringify(result))
				expect(result.followup_overlap == 0 and result.unsafe_shots == 0 and result.hatches.size() == 2 and float(result.hatches[1]) - float(result.hatches[0]) >= 0.55 and result.starts[0].route == route and result.starts[1].route == result.expected_cross_route, "M1 wall clearance, stagger, or route coverage failed: " + JSON.stringify(result))
	expect(pattern.corridor_routes == authored, "Compound cycles keep the shared wall resource immutable")
	var report := {"method": "P2 input-only known-cue routes starting from lure; three existing wall cycles up to bank charge; actual M1 and collisions; no shooting, bombs, invincibility, or teleporting; isolated M1, not human validation", "failures": failures, "trials": trials}
	DirAccess.make_dir_recursive_absolute("res://build/validation")
	FileAccess.open("res://build/validation/siege_cycles.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
