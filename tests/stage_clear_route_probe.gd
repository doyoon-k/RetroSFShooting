extends SceneTree
## Damage-opportunity diagnostic: real spawns, movement, shots and natural pickups.
## Input-only, eight-direction routing; no bombs. Invincibility isolates HP
## from dodging. This route is a reproducible example, not a proof of optimal play.
## godot --headless --path . --script tests/stage_clear_route_probe.gd --fixed-fps 60

const PREVIOUS_HP := {"n1_interceptor": 26, "n2_crawler": 30, "n3_claw": 40, "n4_armor": 46, "n5_tendril": 32}
const ACTIONS := ["move_left", "move_right", "move_up", "move_down"]
var stage: StageController
var records := {}
var elapsed := 0.0
var args: PackedStringArray
var power_history: Array[Dictionary] = []
var last_power := 0
var last_switch := -1.0
var switches := 0

func _initialize() -> void:
	args = OS.get_cmdline_user_args()
	call_deferred("run")

func radius(actor: Node2D) -> float:
	var shape := actor.get_node("CollisionShape2D") as CollisionShape2D
	return (shape.shape as CircleShape2D).radius * actor.global_scale.x

func predict(enemy: EnemyShip, seconds: float) -> Vector2:
	var movement := enemy.movement
	var forward := movement.direction.normalized()
	match movement.mode:
		EnemyMovement.Mode.SINE:
			var age := movement.age + seconds
			return movement.origin + forward * movement.speed * age + forward.orthogonal() * sin(age * TAU * movement.frequency) * movement.amplitude
		EnemyMovement.Mode.LINEAR:
			return enemy.position + forward * movement.speed * seconds
		EnemyMovement.Mode.VERTICAL_SWEEP, EnemyMovement.Mode.STRAFE_EXIT, EnemyMovement.Mode.ENTER_HOLD_EXIT:
			var hold := movement.hold_position
			if movement.follow_scroll:
				hold.x += stage.player.auto_advance_speed * seconds
			if not movement.reached_hold:
				return enemy.position.move_toward(hold, movement.speed * seconds)
			var held := movement.hold_elapsed + seconds
			if not movement.stay_forever and held >= movement.hold_seconds and movement.mode != EnemyMovement.Mode.VERTICAL_SWEEP:
				return enemy.position + movement.exit_direction.normalized() * movement.speed * seconds
			if movement.mode != EnemyMovement.Mode.ENTER_HOLD_EXIT:
				hold.y += sin(held * TAU * movement.frequency) * movement.amplitude
			return hold
	return enemy.position

func aim_point(enemy: EnemyShip, muzzle: Vector2) -> Vector2:
	var seconds := maxf(0.0, (enemy.position.x - radius(enemy) - muzzle.x) / 1050.0)
	for iteration in 3:
		seconds = maxf(0.0, (predict(enemy, seconds).x - radius(enemy) - muzzle.x) / 1050.0)
	return predict(enemy, seconds)

func incoming_damage(enemy: EnemyShip) -> float:
	var result := 0.0
	for bullet in stage.projectiles.get_children():
		if not bullet.friendly or bullet.spent or bullet.direction.x <= 0.0:
			continue
		var seconds: float = (enemy.position.x - bullet.position.x) / (bullet.speed * bullet.direction.x + enemy.movement.speed)
		if seconds < 0.0 or seconds > 1.5:
			continue
		var future := predict(enemy, seconds)
		var point: Vector2 = bullet.position + bullet.direction * bullet.speed * seconds
		if point.distance_to(future) <= radius(enemy) * 0.8:
			result += bullet.damage * bullet.proximity_multiplier(point.distance_to(bullet.damage_origin))
	return result

func steer() -> void:
	Input.action_release("switch_weapon")
	var player := stage.player
	var target: EnemyShip
	var best_slack := INF
	for actor in stage.actors.get_children():
		if not actor is EnemyShip or actor.dying or actor.position.x < player.position.x + 100.0:
			continue
		if incoming_damage(actor) >= actor.hp:
			continue # Move to the next lane once a lethal volley is in flight.
		var closing: float = actor.movement.speed + player.auto_advance_speed
		var deadline: float = (actor.position.x - player.position.x - 100.0) / maxf(1.0, closing)
		if actor.is_midboss or actor.is_boss or actor.movement.follow_scroll:
			deadline += 5.0
		var align: float = maxf(0.0, absf(aim_point(actor, player.weapon.global_position).y - player.position.y) - radius(actor) * 0.5) / player.move_speed
		var slack: float = deadline - align - actor.hp / (12.5 * player.state.power_level)
		if slack < best_slack:
			best_slack = slack
			target = actor
	var preferred := Vector2(stage.view_bounds.position.x + 120.0, stage.view_bounds.get_center().y)
	if is_instance_valid(target):
		preferred.y = aim_point(target, player.weapon.global_position).y
		if target.is_midboss or target.is_boss:
			preferred.x = target.position.x - 550.0
		var weapon := SortieState.WeaponType.STRAIGHT if target.scene_file_path.get_file().begins_with("n") or target.is_midboss or target.is_boss else SortieState.WeaponType.SPREAD
		if player.state.active_weapon != weapon and elapsed - last_switch >= 0.22:
			Input.action_press("switch_weapon")
			last_switch = elapsed
			switches += 1
	else:
		for item in stage.items.get_children():
			if item.kind == 0:
				preferred = item.position
				break
	var padding := player.boundary_padding * player.scale.abs()
	preferred = preferred.clamp(stage.view_bounds.position + padding, stage.view_bounds.end - padding)
	var best_move := Vector2.ZERO
	var best_distance := INF
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var motion := Vector2(dx, dy).normalized()
			var point := player.position + motion * player.move_speed / 60.0
			var distance := point.distance_squared_to(preferred)
			if distance < best_distance:
				best_distance = distance
				best_move = motion
	for action in ACTIONS:
		Input.action_release(action)
	if best_move.x < 0: Input.action_press("move_left")
	if best_move.x > 0: Input.action_press("move_right")
	if best_move.y < 0: Input.action_press("move_up")
	if best_move.y > 0: Input.action_press("move_down")

func observe_enemy(actor: Node) -> void:
	if not actor is EnemyShip or records.has(actor.get_instance_id()):
		return
	var name := actor.scene_file_path.get_file().get_basename()
	if args.has("--baseline") and PREVIOUS_HP.has(name):
		actor.maximum_hp = PREVIOUS_HP[name]
		actor.hp = actor.maximum_hp
	var record := {"enemy": name, "spawn_scroll": snappedf(stage.progress_x / stage.scroll_speed, 0.01), "killed": false, "hp": actor.maximum_hp}
	records[actor.get_instance_id()] = record
	actor.destroyed.connect(func(_enemy: EnemyShip): record.killed = true)
	actor.tree_exiting.connect(func():
		if not record.killed:
			record["escaped_scroll"] = snappedf(stage.progress_x / stage.scroll_speed, 0.01))

func run() -> void:
	seed(20261012)
	stage = load("res://scenes/gameplay/stage/stage_01.tscn").instantiate() as StageController
	var catalog := load("res://data/game_catalog.tres") as GameCatalog
	stage.run = RunState.new(catalog)
	stage.run.begin_sortie(&"P2") # The slowest playable ship (460px/s).
	root.add_child(stage)
	stage.actors.child_entered_tree.connect(observe_enemy)
	var expected_spawned := stage.placed_enemies.get_child_count() + 1 # Final boss.
	for wave in stage.waves.get_children():
		if wave is EnemyWave:
			expected_spawned += wave.count
	Input.action_press("shoot")
	for frame in 27000:
		await physics_frame
		elapsed = frame / 60.0
		for actor in stage.actors.get_children(): observe_enemy(actor)
		if is_instance_valid(stage.player):
			stage.player.invincibility = 2.0
			if args.has("--power1"):
				stage.player.state.power_level = 1
			var power := stage.player.state.current_power_level()
			if power != last_power:
				power_history.append({"scroll_seconds": snappedf(stage.progress_x / stage.scroll_speed, 0.01), "power": power})
				last_power = power
			if stage.phase == StageController.Phase.PLAYING:
				steer()
		if stage.run.boss_cleared or stage.phase == StageController.Phase.FINISHED:
			break
	for action in ACTIONS + ["shoot", "switch_weapon"]:
		Input.action_release(action)
	var counts := {}
	var missed: Array[Dictionary] = []
	for record in records.values():
		if not counts.has(record.enemy): counts[record.enemy] = {"spawned": 0, "killed": 0}
		counts[record.enemy].spawned += 1
		if record.killed: counts[record.enemy].killed += 1
		else: missed.append(record)
	var report := {"method": "input-only eight-direction aim route; actual shots, movement and natural pickups; invincible, no bombs; damage-opportunity test, not survival or global optimality proof", "baseline": args.has("--baseline"), "forced_power1": args.has("--power1"), "clear": stage.run.boss_cleared, "seconds": snappedf(elapsed, 0.01), "defeated": stage.defeated, "spawned": records.size(), "expected_spawned": expected_spawned, "by_enemy": counts, "missed": missed, "power_history": power_history, "weapon_switches": switches}
	DirAccess.make_dir_recursive_absolute("res://build/validation")
	var suffix := ("baseline" if args.has("--baseline") else "after") + ("_lv1" if args.has("--power1") else "_natural")
	var file := FileAccess.open("res://build/validation/clear_route_" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	stage.queue_free()
	await process_frame
	quit(0 if report.clear else 1)
