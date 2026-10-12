extends SceneTree
## Input-only P2 route through a single authored burst, real damage, no bombs.
## Predicts the known wall rhythm; isolates curtains from other boss attacks.
var hits := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var catalog := load("res://data/game_catalog.tres") as GameCatalog
	var arena := catalog.rules.playfield
	var trials: Array[Dictionary] = []
	for name in ["siege_curtain", "command_curtain"]:
		var pattern := load("res://data/patterns/" + name + ".tres") as AttackPattern
		for distance in [360.0, 650.0, 900.0]:
			for fraction in [0.15, 0.35, 0.65, 0.85]:
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
				step.wait_after = 100.0
				shooter.set_sequence([step])
				hits = 0
				var first_fire := -1.0
				var wall := 0
				var crossed := 0
				var duration: float = 1.0 + distance / 300.0 + pattern.volley_interval * (pattern.volley_count - 1) + 0.5
				for frame in ceili(duration * 60.0):
					await physics_frame
					var time := frame / 60.0
					if shooter.volleys_fired > 0 and first_fire < 0.0: first_fire = time
					# Hold the corridor until the preceding wall fully passes the ship,
					# then move towards the next corridor's predicted arrival height.
					var arrival: float = first_fire + wall * pattern.volley_interval + distance / 300.0
					if first_fire >= 0.0 and time > arrival + 40.0 / 300.0:
						crossed = wall + 1
						wall = mini(wall + 1, pattern.volley_count - 1)
					var gap := pattern.corridor_y(arena, wall)
					gap += pattern.sway_for_volley(wall) * sin(distance / 300.0 * TAU / pattern.curtain_sway_period)
					Input.action_release("move_up")
					Input.action_release("move_down")
					if absf(gap - player.position.y) > player.move_speed / 120.0:
						Input.action_press("move_up" if gap < player.position.y else "move_down")
				trials.append({"pattern": name, "distance": distance, "start_fraction": fraction,
					"hits": hits, "walls_crossed": crossed, "expected_walls": pattern.volley_count,
					"fired_walls": shooter.volleys_fired, "move_speed": player.move_speed})
				Input.action_release("move_up")
				Input.action_release("move_down")
				container.queue_free()
				await process_frame
	var report := {"method": "P2 input-only route; real collisions, no invincibility or bombs; isolated curtains only", "trials": trials}
	DirAccess.make_dir_recursive_absolute("res://build/validation")
	var file := FileAccess.open("res://build/validation/curtain_motion.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit()
