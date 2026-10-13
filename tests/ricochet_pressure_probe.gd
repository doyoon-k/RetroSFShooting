extends SceneTree
## Stationary contact pressure before/after; known-cue P2 movement with real damage.
var content: GameCatalog
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func contact(area: Area2D, clock: Dictionary) -> void:
	if area is PlayerShip and clock.cooldown <= 0.0:
		clock.contacts += 1
		clock.cooldown = 0.75

func release_inputs() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)

func trial(before: bool, x: float, y: float, above: bool, moving: bool) -> Dictionary:
	var arena := content.rules.playfield
	var container := Node2D.new()
	root.add_child(container)
	var bullets := Node2D.new()
	container.add_child(bullets)
	var player := content.pilot_by_id(&"P2").ship_scene.instantiate() as PlayerShip
	player.state = SortieState.new(content.rules)
	player.rules = content.rules
	player.bounds = arena
	player.position = arena.position + arena.size * Vector2(x, y)
	player.invincibility = 0.0 if moving else 100.0
	container.add_child(player)
	player.weapon.set_physics_process(false)
	player.set_physics_process(moving)
	var clock := {"contacts": 0, "cooldown": 0.0, "hits": 0, "peak": 0, "launches": 0}
	player.hit.connect(func(): clock.hits += 1)
	var family: Array[Projectile] = []
	var core: RicochetCore
	var next_launch := 0.6
	var destination := player.position
	release_inputs()
	for frame in 960:
		await physics_frame
		clock.cooldown = maxf(0.0, clock.cooldown - 1.0 / 60.0)
		for index in range(family.size() - 1, -1, -1):
			if not is_instance_valid(family[index]) or family[index].is_queued_for_deletion(): family.remove_at(index)
		if family.is_empty():
			if moving and clock.launches > 0: break
			next_launch -= 1.0 / 60.0
			if next_launch <= 0.0:
				core = load("res://scenes/projectiles/ricochet_core.tscn").instantiate() as RicochetCore
				core.position = Vector2(arena.end.x - 490, arena.get_center().y)
				core.bounds = arena
				core.target = player
				core.starts_above = above if clock.launches % 2 == 0 else not above
				if before:
					core.speed = 520.0
					core.speed_retention = 0.9
					core.bank_pause_seconds = 0.25
					core.child_count = 5
					core.middle_child_count = 5
					core.final_child_count = 7
					core.child_spread = 60.0
					core.child_speed = 270.0
					core.child_lifetime = 2.2
					core.aimed_fans = false
				core.area_entered.connect(contact.bind(clock))
				core.offspring_spawned.connect(func(child: Projectile):
					family.append(child)
					child.area_entered.connect(contact.bind(clock)))
				family.append(core)
				bullets.add_child(core)
				clock.launches += 1
				next_launch = 1.5 if before else 1.0
		clock.peak = maxi(clock.peak, bullets.get_child_count())
		if moving:
			if is_instance_valid(core) and not core.is_queued_for_deletion() and core._fan_bank > 0:
				var fraction := 0.5
				var horizontal := 0.38 if core._fan_bank == 2 else 0.16
				if core._fan_bank == 1: fraction = 0.08 if core.starts_above else 0.92
				elif core._fan_bank == 3: fraction = 0.92 if core.starts_above else 0.08
				destination = arena.position + arena.size * Vector2(horizontal, fraction)
			release_inputs()
			var difference := destination - player.position
			var threshold := player.move_speed / 120.0
			if absf(difference.x) > threshold: Input.action_press("move_left" if difference.x < 0 else "move_right")
			if absf(difference.y) > threshold: Input.action_press("move_up" if difference.y < 0 else "move_down")
	var result := {"before": before, "x_fraction": x, "y_fraction": y, "above": above, "moving": moving,
		"contacts": clock.contacts, "hits": clock.hits, "launches": clock.launches, "peak_bullets": clock.peak}
	release_inputs()
	container.queue_free()
	await process_frame
	await process_frame
	return result

func run() -> void:
	content = load("res://data/game_catalog.tres") as GameCatalog
	var old_trials: Array[Dictionary] = []
	var new_trials: Array[Dictionary] = []
	var moving_trials: Array[Dictionary] = []
	var old_contacts := 0
	var new_contacts := 0
	var old_safe := 0
	var new_safe := 0
	for x in [0.16, 0.3, 0.45]:
		for y in [0.15, 0.5, 0.85]:
			var old := await trial(true, x, y, true, false)
			var current := await trial(false, x, y, true, false)
			old_trials.append(old)
			new_trials.append(current)
			old_contacts += old.contacts
			new_contacts += current.contacts
			if old.contacts == 0: old_safe += 1
			if current.contacts == 0: new_safe += 1
	for x in [0.16, 0.3]:
		for y in [0.35, 0.5, 0.65]:
			for above in [true, false]:
				moving_trials.append(await trial(false, x, y, above, true))
	var no_hit := 0
	for entry in moving_trials:
		if entry.hits == 0: no_hit += 1
		if is_equal_approx(float(entry.x_fraction), 0.3) and entry.hits > 0:
			failures.append("The center-column cue route must work at all three starting heights and both mirrors")
	if new_contacts <= old_contacts or new_safe > 0:
		failures.append("The revised pattern must pressure all stationary samples and increase total contacts")
	if no_hit < 6: failures.append("Higher pressure must still leave the six center-column input routes")
	var report := {"method": "16s isolated bank attack at nine stationary points, 0.75s contact limit with invulnerability; twelve P2 input-only one-shot routes using visible bank cues, no shooting/bombs/invulnerability; does not establish human difficulty",
		"old_contacts": old_contacts, "new_contacts": new_contacts, "old_safe_samples": old_safe, "new_safe_samples": new_safe,
		"moving_no_hit": no_hit, "moving_trials": moving_trials, "old_trials": old_trials, "new_trials": new_trials, "failures": failures}
	DirAccess.make_dir_recursive_absolute("res://build/validation")
	FileAccess.open("res://build/validation/ricochet_pressure.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
