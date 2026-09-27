extends SceneTree
var shooter_kills := 0
var killed_before_firing := 0
var bullet_contacts := 0
var contact_cooldown := 0.0

func record_bullet_contact(area: Area2D) -> void:
	if area is PlayerShip and contact_cooldown <= 0.0:
		bullet_contacts += 1
		contact_cooldown = 0.75

func record_kill(enemy: EnemyShip) -> void:
	if enemy.shooter != null and not enemy.shooter.steps.is_empty() and not enemy.is_midboss and not enemy.is_boss:
		shooter_kills += 1
		if enemy.shooter.volleys_fired == 0:
			killed_before_firing += 1
## Deterministic normal-speed instrumentation, NOT a human-fun or no-hit proof.
## godot --headless --path . --script tests/stage_balance_probe.gd --fixed-fps 60
## Omit --headless and append -- --screenshots to capture authored encounters.

func _initialize() -> void:
	call_deferred("run_probe")

func run_probe() -> void:
	var stage := load("res://scenes/gameplay/stage/stage_01.tscn").instantiate() as StageController
	root.add_child(stage)
	var peak_bullets := 0
	var peak_enemies := 0
	var encounters: Array[Dictionary] = []
	var tracked: EnemyShip
	var began := 0.0
	var captured := false
	var elapsed := 0.0
	var seen := {}
	var last_shot := {}
	var previous_shots := {}
	var combat_frames := 0
	var overlap_frames := 0
	var peak_sources := 0
	var total_volleys := 0
	var bullet_seen := {}
	Input.action_press("shoot")
	for frame in 24000:
		await physics_frame
		elapsed = frame / 60.0
		contact_cooldown = maxf(0.0, contact_cooldown - 1.0 / 60.0)
		if is_instance_valid(stage.player):
			stage.player.invincibility = 2.0
			if OS.get_cmdline_user_args().has("--power3"):
				stage.player.weapon.state.power_level = 3
			elif OS.get_cmdline_user_args().has("--power1"):
				stage.player.weapon.state.power_level = 1
			if OS.get_cmdline_user_args().has("--spread"):
				stage.player.weapon.state.active_weapon = SortieState.WeaponType.SPREAD
			elif OS.get_cmdline_user_args().has("--mixed"):
				stage.player.weapon.state.active_weapon = SortieState.WeaponType.STRAIGHT if is_instance_valid(stage.mid_enemy) or is_instance_valid(stage.boss) else SortieState.WeaponType.SPREAD
			# Follow only the large encounter, otherwise sweep two lanes at player speed.
			var target_y := 532.0 + sin(elapsed * 0.65) * 225.0
			if is_instance_valid(stage.mid_enemy):
				target_y = stage.mid_enemy.position.y
			elif is_instance_valid(stage.boss):
				target_y = stage.boss.position.y
			stage.player.position.y = move_toward(stage.player.position.y, target_y, 490.0 / 60.0)
		var current: EnemyShip = stage.mid_enemy if is_instance_valid(stage.mid_enemy) else stage.boss
		if is_instance_valid(current) and current != tracked:
			tracked = current
			began = elapsed
			encounters.append({"scene": current.scene_file_path.get_file(), "start": elapsed, "duration": 0.0})
		if is_instance_valid(tracked) and not encounters.is_empty():
			encounters[-1]["duration"] = snappedf(elapsed - began, 0.01)
		var hostile := 0
		for enemy in stage.actors.get_children():
			if not enemy is EnemyShip:
				continue
			var id := enemy.get_instance_id()
			if not seen.has(id):
				seen[id] = true
				enemy.destroyed.connect(record_kill)
			if enemy.shooter != null:
				var shots: int = enemy.shooter.volleys_fired
				if shots > previous_shots.get(id, 0):
					last_shot[id] = elapsed
					total_volleys += shots - previous_shots.get(id, 0)
				previous_shots[id] = shots
		if stage.phase == StageController.Phase.PLAYING and not is_instance_valid(stage.mid_enemy) and not is_instance_valid(stage.boss):
			combat_frames += 1
			var sources := 0
			for id in last_shot:
				if elapsed - last_shot[id] <= 2.0:
					sources += 1
			peak_sources = maxi(peak_sources, sources)
			if sources >= 2:
				overlap_frames += 1
		for bullet in stage.projectiles.get_children():
			if not bullet.friendly:
				hostile += 1
				var id := bullet.get_instance_id()
				if not bullet_seen.has(id):
					bullet_seen[id] = true
					bullet.area_entered.connect(record_bullet_contact)
		peak_bullets = maxi(peak_bullets, hostile)
		peak_enemies = maxi(peak_enemies, stage.actors.get_child_count())
		if not captured and stage.progress_x >= 64.0 * 180.0 and OS.get_cmdline_user_args().has("--screenshots"):
			captured = true
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://build/screenshots")
			root.get_texture().get_image().save_png("res://build/screenshots/stage_redesign.png")
		if stage.run.boss_cleared:
			break
	Input.action_release("shoot")
	var report := {"method": "normal-speed invincible scripted aiming; no bombs; real damage and pickups; not survival validation", "clear": stage.run.boss_cleared, "seconds": snappedf(elapsed, 0.01), "peak_hostile_bullets": peak_bullets, "peak_enemy_nodes": peak_enemies, "defeated": stage.defeated, "encounters": encounters}
	report["power3"] = OS.get_cmdline_user_args().has("--power3")
	report["forced_power1"] = OS.get_cmdline_user_args().has("--power1")
	report["spread"] = OS.get_cmdline_user_args().has("--spread")
	report["mixed"] = OS.get_cmdline_user_args().has("--mixed")
	report["bullet_contacts_075_cooldown"] = bullet_contacts
	report["normal_shooter_kills"] = shooter_kills
	report["normal_killed_before_firing"] = killed_before_firing
	report["two_source_window_percent"] = snappedf(100.0 * overlap_frames / maxi(1, combat_frames), 0.1)
	report["peak_sources_in_two_seconds"] = peak_sources
	report["total_volleys"] = total_volleys
	DirAccess.make_dir_recursive_absolute("res://build/validation")
	var suffix := ("lv3" if report.power3 else ("lv1" if report.forced_power1 else "natural")) + ("_mixed" if report.mixed else ("_spread" if report.spread else "_straight"))
	var file := FileAccess.open("res://build/validation/stage_balance_" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	stage.queue_free()
	await process_frame
	quit(0 if report.clear else 1)
