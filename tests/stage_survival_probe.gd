extends SceneTree
## Reactive input-only pilot. It sees current hazards, never future spawns.
## Approximate straight-line prediction is NOT a proof of human playability.

var stage: StageController
var elapsed := 0.0
var hits := 0
var deaths := 0
var bombs := 0
var forced_recovery := false
var seen_players := {}
var damage_events: Array[Dictionary] = []
var captures := {}
var args: PackedStringArray
var last_direction := Vector2.ZERO
var pilot_id := "P2"
var weapon_mode := "mixed"
var starting_power := 1
var phase_name := ""
var observed_positions := {}
var density := {}
var recent_shots := {}
var observed_volleys := {}
var empty_start := -1.0
var empty_spans: Array[Dictionary] = []
var power_history: Array[Dictionary] = []
var last_power := -1
var power_frames := {1: 0, 2: 0, 3: 0}
var observed_enemies := {}
var shooter_kills := 0
var killed_before_firing := 0

func record_enemy_kill(enemy: EnemyShip) -> void:
	if enemy.shooter != null and not enemy.shooter.steps.is_empty() and not enemy.is_midboss and not enemy.is_boss:
		shooter_kills += 1
		if enemy.shooter.volleys_fired == 0: killed_before_firing += 1

func finish_empty_span() -> void:
	if empty_start < 0: return
	var end := stage.progress_x / stage.scroll_speed
	if end - empty_start >= 1.0:
		empty_spans.append({"start": snappedf(empty_start, 0.1), "end": snappedf(end, 0.1)})
	empty_start = -1.0

func sample_density() -> void:
	# Only active scrolling combat; exclude launch, death and stationary bosses.
	if stage.phase != StageController.Phase.PLAYING or is_instance_valid(stage.mid_enemy) or is_instance_valid(stage.boss):
		finish_empty_span()
		for sample in density.values():
			sample.empty_run = 0
		recent_shots.clear()
		return
	var scroll := stage.progress_x / stage.scroll_speed
	var section := "intro_0_20" if scroll < 20 else ("early_20_50" if scroll < 50 else ("middle_50_120" if scroll < 120 else "late_120_150"))
	if scroll >= 150:
		finish_empty_span()
		return # Deliberate pre-boss supply break.
	if not density.has(section):
		density[section] = {"frames": 0, "visible_sum": 0, "peak_visible": 0, "empty_frames": 0, "empty_run": 0, "longest_empty": 0, "overlap_frames": 0}
	var visible := 0
	for actor in stage.actors.get_children():
		if not actor is EnemyShip or actor.dying: continue
		if stage.view_bounds.has_point(actor.position): visible += 1
		if actor.shooter != null:
			var id := actor.get_instance_id()
			if actor.shooter.volleys_fired > observed_volleys.get(id, 0):
				recent_shots[id] = elapsed
				observed_volleys[id] = actor.shooter.volleys_fired
	var sources := 0
	for id in recent_shots:
		if elapsed - recent_shots[id] <= 2.0: sources += 1
	var sample: Dictionary = density[section]
	sample.frames += 1
	sample.visible_sum += visible
	sample.peak_visible = maxi(sample.peak_visible, visible)
	if visible == 0:
		if empty_start < 0: empty_start = scroll
		sample.empty_frames += 1
		sample.empty_run += 1
		sample.longest_empty = maxi(sample.longest_empty, sample.empty_run)
	else:
		finish_empty_span()
		sample.empty_run = 0
	if sources >= 2: sample.overlap_frames += 1

func density_report() -> Dictionary:
	var result := {}
	for section in density:
		var sample: Dictionary = density[section]
		result[section] = {"seconds": snappedf(sample.frames / 60.0, 0.1), "mean_visible": snappedf(float(sample.visible_sum) / sample.frames, 0.01), "peak_visible": sample.peak_visible, "no_target_percent": snappedf(100.0 * sample.empty_frames / sample.frames, 0.1), "longest_no_target_seconds": snappedf(sample.longest_empty / 60.0, 0.1), "two_source_window_percent": snappedf(100.0 * sample.overlap_frames / sample.frames, 0.1)}
	return result

func _initialize() -> void:
	args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--pilot="):
			pilot_id = arg.trim_prefix("--pilot=")
		if arg.begins_with("--weapon="):
			weapon_mode = arg.trim_prefix("--weapon=")
	starting_power = 3 if args.has("--power3") else 1
	call_deferred("run_probe")

func record_hit() -> void:
	hits += 1
	var cause := "projectile"
	for actor in stage.actors.get_children():
		if actor is EnemyShip and not actor.dying and actor.position.distance_to(stage.player.position) < radius(actor) + radius(stage.player) + 5.0:
			cause = "contact:" + actor.scene_file_path.get_file()
			break
	if args.has("--recovery") and forced_recovery and stage.player.state.hp == 0 and absf(stage.progress_x / stage.scroll_speed - 100.0) < 0.1:
		cause = "injected_recovery_death"
	damage_events.append({"seconds": snappedf(elapsed, 0.1), "scroll_seconds": snappedf(stage.progress_x / stage.scroll_speed, 0.1), "encounter": phase_name, "cause": cause, "position": [snappedf(stage.player.position.x - stage.progress_x, 1), snappedf(stage.player.position.y, 1)]})

func record_death(_location: Vector2, _powerups: int, _bombs: int) -> void:
	deaths += 1

func radius(node: Node2D) -> float:
	var collider := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider != null and collider.shape is CircleShape2D:
		return collider.shape.radius * maxf(absf(collider.global_scale.x), absf(collider.global_scale.y))
	return 30.0

func steer() -> void:
	var player := stage.player
	var bounds := stage.view_bounds
	var preferred := Vector2(bounds.position.x + 310.0, bounds.get_center().y)
	var target: EnemyShip
	var best_priority := -INF
	for actor in stage.actors.get_children():
		if not actor is EnemyShip or actor.dying or actor.position.x <= player.position.x + 80 or not bounds.has_point(actor.position):
			continue
		var priority: float = (500.0 if actor.is_midboss or actor.is_boss else 100.0) - absf(actor.position.y - player.position.y) * 0.16 - (actor.position.x - player.position.x) * 0.025
		if actor.shooter != null and not actor.shooter.steps.is_empty():
			priority += 55.0
		if priority > best_priority:
			best_priority = priority
			target = actor
	if is_instance_valid(target):
		preferred.y = target.position.y
		# Approach only during a long, visible recovery interval.
		if args.has("--aggressive") and target.shooter != null and not target.shooter.warning and target.shooter.starting and target.shooter.timer > 1.0:
			preferred.x = minf(target.position.x - radius(target) - 115.0, bounds.end.x - 180.0)
	if not args.has("--no-pickups"):
		for item in stage.items.get_children():
			if item.position.distance_to(player.position) < 340.0:
				preferred = item.position
				break
	var hazards: Array[Dictionary] = []
	for bullet in stage.projectiles.get_children():
		if not bullet.friendly and bullet.position.distance_to(player.position) < 900.0:
			hazards.append({"p": bullet.position, "v": bullet.direction * bullet.speed, "r": radius(bullet) + radius(player) + 14.0})
			# Optional learned-pattern diagnostic: only the rays already drawn
			# during incubation, never an unseen future enemy or launch.
			if args.has("--read-cues") and bullet is BroodCore and bullet.age >= bullet.travel_seconds:
				var child := bullet.child_scene.instantiate() as Projectile
				var child_speed := child.speed
				var child_radius := radius(child)
				child.free()
				for index in bullet.child_count:
					var ray: Vector2 = bullet.direction.rotated(deg_to_rad(bullet.child_spread) * (float(index) / (bullet.child_count - 1) - 0.5))
					hazards.append({"p": bullet.position, "v": ray * child_speed, "r": child_radius + radius(player) + 14.0, "delay": maxf(0.0, bullet.travel_seconds + bullet.incubation_seconds - bullet.age)})
	for actor in stage.actors.get_children():
		if actor is EnemyShip and not actor.dying and actor.position.distance_to(player.position) < 700.0:
			var velocity := Vector2.ZERO
			var id := actor.get_instance_id()
			if observed_positions.has(id):
				var observation: Dictionary = observed_positions[id]
				velocity = (actor.position - observation.p) / maxf(0.001, elapsed - observation.t)
			observed_positions[id] = {"p": actor.position, "t": elapsed}
			hazards.append({"p": actor.position, "v": velocity, "r": radius(actor) + radius(player) + 26.0})
	var best_cost := INF
	var best_move := Vector2.ZERO
	var danger_now := INF
	for hazard in hazards:
		if hazard.get("delay", 0.0) > 0.0: continue
		danger_now = minf(danger_now, player.position.distance_to(hazard.p) - hazard.r)
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var direction := Vector2(dx, dy).normalized()
			var cost := 0.0
			var velocity := direction * player.move_speed + Vector2(player.auto_advance_speed, 0.0)
			for sample in [0.12, 0.3, 0.55, 0.8]:
				var point: Vector2 = player.position + velocity * sample
				var arena_shift := Vector2(player.auto_advance_speed * sample, 0.0)
				var safe := Rect2(bounds.position + arena_shift + Vector2(65, 50), bounds.size - Vector2(130, 100))
				if not safe.has_point(point):
					cost += 3000.0
				for hazard in hazards:
					var delay: float = hazard.get("delay", 0.0)
					if sample < delay: continue
					var separation: float = point.distance_to(hazard.p + hazard.v * (sample - delay)) - hazard.r
					if separation < 0.0:
						cost += 10000.0 / (1.0 + sample)
					elif separation < 100.0:
						cost += (100.0 - separation) * 3.0 / (1.0 + sample)
			cost += (player.position + direction * player.move_speed * 0.3).distance_to(preferred) * 0.4
			if direction != last_direction:
				cost += 8.0
			if cost < best_cost:
				best_cost = cost
				best_move = direction
	if not args.has("--no-bombs") and danger_now < 65.0 and best_cost > 7000.0 and player.invincibility <= 0 and player.state.bombs > 0:
		stage._bomb()
		bombs += 1
	last_direction = best_move
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if best_move.x < 0: Input.action_press("move_left")
	if best_move.x > 0: Input.action_press("move_right")
	if best_move.y < 0: Input.action_press("move_up")
	if best_move.y > 0: Input.action_press("move_down")

func run_probe() -> void:
	seed(20261005)
	stage = load("res://scenes/gameplay/stage/stage_01.tscn").instantiate() as StageController
	var catalog := load("res://data/game_catalog.tres") as GameCatalog
	stage.run = RunState.new(catalog)
	stage.run.begin_sortie(StringName(pilot_id))
	root.add_child(stage)
	Input.action_press("shoot")
	var max_bullets := 0
	var peak_sources := 0
	var encounters: Array[Dictionary] = []
	var tracked_id := 0
	var encounter_start := 0.0
	for frame in 27000:
		await physics_frame
		elapsed = frame / 60.0
		if is_instance_valid(stage.player):
			var id := stage.player.get_instance_id()
			if not seen_players.has(id):
				seen_players[id] = true
				stage.player.hit.connect(record_hit)
				stage.player.died.connect(record_death)
				if seen_players.size() == 1:
					stage.player.state.power_level = starting_power
			if args.has("--power1"):
				stage.player.state.power_level = 1
			if args.has("--no-bombs"):
				stage.player.state.bombs = 0
			var power := stage.player.state.current_power_level()
			if power != last_power:
				power_history.append({"seconds": snappedf(elapsed, 0.1), "scroll_seconds": snappedf(stage.progress_x / stage.scroll_speed, 0.1), "power": power})
				last_power = power
			if stage.phase == StageController.Phase.PLAYING: power_frames[power] += 1
			stage.player.state.active_weapon = SortieState.WeaponType.SPREAD if weapon_mode == "spread" or (weapon_mode == "mixed" and not is_instance_valid(stage.mid_enemy) and not is_instance_valid(stage.boss)) else SortieState.WeaponType.STRAIGHT
			if stage.phase == StageController.Phase.PLAYING:
				if frame % 6 == 0:
					steer()
				if args.has("--recovery") and not forced_recovery and stage.progress_x / stage.scroll_speed >= 100.0:
					forced_recovery = true
					stage.player.invincibility = 0.0
					stage.player.state.shield = false
					stage.player.state.bombs = 0
					stage.player.take_damage(99)
		var encounter: EnemyShip = stage.mid_enemy if is_instance_valid(stage.mid_enemy) else stage.boss
		phase_name = encounter.scene_file_path.get_file() if is_instance_valid(encounter) else "waves"
		if is_instance_valid(encounter):
			if tracked_id != encounter.get_instance_id():
				tracked_id = encounter.get_instance_id()
				encounter_start = elapsed
				encounters.append({"scene": phase_name, "duration": 0.0})
			encounters[-1]["duration"] = snappedf(elapsed - encounter_start, 0.01)
		var bullets := 0
		for bullet in stage.projectiles.get_children():
			if not bullet.friendly: bullets += 1
		max_bullets = maxi(max_bullets, bullets)
		var sources := 0
		for actor in stage.actors.get_children():
			if actor is EnemyShip and not observed_enemies.has(actor.get_instance_id()):
				observed_enemies[actor.get_instance_id()] = true
				actor.destroyed.connect(record_enemy_kill)
			if actor is EnemyShip and not actor.dying and actor.shooter != null and not actor.shooter.steps.is_empty() and actor.shooter.can_fire():
				sources += 1
		peak_sources = maxi(peak_sources, sources)
		sample_density()
		if args.has("--screenshots") and stage.phase == StageController.Phase.PLAYING and DisplayServer.get_name() != "headless":
			var key := ""
			if is_instance_valid(encounter) and elapsed - encounter_start > 4.0:
				key = phase_name.get_basename()
			elif stage.progress_x / stage.scroll_speed >= 54 and stage.progress_x / stage.scroll_speed <= 57:
				key = "strafe_and_gate"
			elif stage.progress_x / stage.scroll_speed >= 139 and stage.progress_x / stage.scroll_speed <= 142:
				key = "final_overlap"
			if not key.is_empty() and not captures.has(key):
				captures[key] = true
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://build/screenshots")
				root.get_texture().get_image().save_png("res://build/screenshots/balance_" + key + ".png")
		if stage.run.boss_cleared or stage.phase == StageController.Phase.FINISHED:
			break
	for action in ["shoot", "move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	var report := {"method": "input-only reactive pilot; actual damage and death; approximate 0.8s hazard prediction, 0.1s decisions; NOT human validation", "args": Array(args), "clear": stage.run.boss_cleared, "seconds": snappedf(elapsed, 0.01), "scroll_seconds": snappedf(stage.progress_x / stage.scroll_speed, 0.01), "hits": hits, "deaths": deaths, "bombs_used": bombs, "forced_recovery": forced_recovery, "defeated": stage.defeated, "peak_bullets": max_bullets, "peak_active_shooters": peak_sources, "encounters": encounters, "damage_events": damage_events}
	DirAccess.make_dir_recursive_absolute("res://build/validation")
	report["density"] = density_report()
	report["no_target_spans_over_one_second"] = empty_spans
	report["reads_incubation_cues"] = args.has("--read-cues")
	report["power_history"] = power_history
	report["power_combat_seconds"] = {"lv1": snappedf(power_frames[1] / 60.0, 0.1), "lv2": snappedf(power_frames[2] / 60.0, 0.1), "lv3": snappedf(power_frames[3] / 60.0, 0.1)}
	report["normal_shooter_kills"] = shooter_kills
	report["normal_killed_before_firing"] = killed_before_firing
	var name := "survival_" + pilot_id + "_" + weapon_mode + ("_lv1" if args.has("--power1") else ("_lv3" if starting_power == 3 else "_natural")) + ("_recovery" if args.has("--recovery") else "") + ("_nobombs" if args.has("--no-bombs") else "") + ("_aggressive" if args.has("--aggressive") else "")
	if args.has("--read-cues"): name += "_cues"
	var file := FileAccess.open("res://build/validation/" + name + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	stage.queue_free()
	await process_frame
	quit(0)
