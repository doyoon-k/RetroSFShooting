extends SceneTree
## Input-only P2 routes through isolated authored bursts, real damage, no bombs.
## Predicts the known wall rhythm; isolates curtains from other boss attacks.
var hits := 0
var catalog: GameCatalog

func _initialize() -> void:
	call_deferred("run")

func seed_for_routes(routes: Array[int], count: int) -> int:
	# Exercise the real random selector while covering every authored route/pair.
	for candidate in 1000:
		seed(candidate)
		var first := randi_range(0, count - 1)
		if first != routes[0]: continue
		if routes.size() == 1: return candidate
		var second := randi_range(0, count - 2)
		if second >= first: second += 1
		if second == routes[1]: return candidate
	assert(false, "Could not seed an authored route pair")
	return 0

func trial(name: String, pattern: AttackPattern, routes: Array[int], distance: float, fraction: float) -> Dictionary:
	var arena := catalog.rules.playfield
	var container := Node2D.new()
	root.add_child(container)
	var bullets := Node2D.new()
	container.add_child(bullets)
	var player := catalog.pilot_by_id(&"P2").ship_scene.instantiate() as PlayerShip
	player.state = SortieState.new(catalog.rules)
	player.rules = catalog.rules
	player.bounds = arena
	player.position = Vector2(arena.position.x + 120, arena.position.y + arena.size.y * fraction)
	container.add_child(player)
	player.weapon.set_physics_process(false)
	player.hit.connect(func(): hits += 1)
	var shooter := EnemyShooter.new()
	shooter.bounds = arena
	shooter.projectiles = bullets
	shooter.position = Vector2(player.position.x + distance, arena.get_center().y)
	shooter.initial_delay = 0.5
	container.add_child(shooter)
	var step := PatternStep.new()
	step.pattern = pattern
	step.repetitions = routes.size()
	step.wait_after = 100.0
	shooter.set_sequence([step])
	seed(seed_for_routes(routes, pattern.corridor_routes.size()))
	hits = 0
	var selected := {}
	var fire_times: Array[float] = []
	var wall := 0
	var expected_walls := pattern.volley_count * routes.size()
	var cycle := (pattern.volley_count - 1) * pattern.volley_interval + pattern.recovery + shooter.telegraph_seconds
	var duration: float = 1.0 + distance / 300.0 + pattern.volley_interval * (pattern.volley_count - 1) + cycle * (routes.size() - 1) + 0.7
	for frame in ceili(duration * 60.0):
		await physics_frame
		var time := frame / 60.0
		if shooter.warning and shooter.volley == 0 and not selected.has(shooter.bursts_completed):
			selected[shooter.bursts_completed] = shooter.curtain_route_index
		if shooter.volleys_fired > fire_times.size(): fire_times.append(time)
		# Follow the route revealed by the cue, holding it until the current wall
		# clears the real enlarged collider before moving into the next corridor.
		if wall < fire_times.size() and time > fire_times[wall] + distance / 300.0 + 45.0 / 300.0:
			wall += 1
		Input.action_release("move_up")
		Input.action_release("move_down")
		var burst := floori(float(wall) / pattern.volley_count)
		if wall < expected_walls and selected.has(burst):
			var volley := wall % pattern.volley_count
			var gap := pattern.corridor_y(arena, volley, selected[burst])
			gap += pattern.sway_for_volley(volley) * sin(distance / 300.0 * TAU / pattern.curtain_sway_period)
			if absf(gap - player.position.y) > player.move_speed / 120.0:
				Input.action_press("move_up" if gap < player.position.y else "move_down")
	var actual_routes: Array[int] = []
	for burst in routes.size(): actual_routes.append(selected.get(burst, -1))
	var result := {"pattern": name, "distance": distance, "start_fraction": fraction,
		"hits": hits, "walls_crossed": wall, "expected_walls": expected_walls,
		"fired_walls": shooter.volleys_fired, "move_speed": player.move_speed,
		"expected_routes": routes, "selected_routes": actual_routes}
	Input.action_release("move_up")
	Input.action_release("move_down")
	container.queue_free()
	await process_frame
	return result

func run() -> void:
	catalog = load("res://data/game_catalog.tres") as GameCatalog
	var trials: Array[Dictionary] = []
	for name in ["siege_curtain", "command_curtain"]:
		var pattern := load("res://data/patterns/" + name + ".tres") as AttackPattern
		for route in pattern.corridor_routes.size():
			for distance in [360.0, 450.0, 650.0, 900.0, 1300.0]:
				for fraction in [0.15, 0.35, 0.65, 0.85]:
					trials.append(await trial(name, pattern, [route], distance, fraction))
			for next_route in pattern.corridor_routes.size():
				if next_route == route: continue
				for distance in [450.0, 1300.0]:
					trials.append(await trial(name, pattern, [route, next_route], distance, 0.5))
	var report := {"method": "P2 input-only route from visible cues; real collisions, no invincibility or bombs; all routes and consecutive route pairs; isolated curtains only", "trials": trials}
	DirAccess.make_dir_recursive_absolute("res://build/validation")
	var file := FileAccess.open("res://build/validation/curtain_motion.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0)
