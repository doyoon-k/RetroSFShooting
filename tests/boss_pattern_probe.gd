extends SceneTree
## 20s no-shoot stationary probes at five y positions. Contacts, not deaths.
## Detects safe camping samples; does not prove human difficulty or solvability.
var contacts := 0
var cooldown := 0.0

func _initialize() -> void:
	call_deferred("run")

func contact(area: Area2D) -> void:
	if area is PlayerShip and cooldown <= 0:
		contacts += 1
		cooldown = 0.75

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := "res://build/validation/before_boss_revision/" if args.has("--before") else "res://scenes/enemies/"
	var report := {}
	var showcase := args.has("--screenshots") and DisplayServer.get_name() != "headless"
	for enemy_name in ["m2_wing", "m1_carapace", "m3_star_eye", "boss", "boss_phase2"]:
		var trials: Array[Dictionary] = []
		for fraction in ([0.5] if showcase else [0.15, 0.325, 0.5, 0.675, 0.85]):
			var stage := load("res://scenes/gameplay/stage/stage_01.tscn").instantiate() as StageController
			root.add_child(stage)
			stage.set_physics_process(false)
			stage._enter(StageController.Phase.PLAYING)
			stage.player.auto_advance_speed = 0
			stage.player.position = Vector2(stage.view_bounds.position.x + 310, stage.view_bounds.position.y + stage.view_bounds.size.y * fraction)
			var path: String = prefix + ("boss" if enemy_name == "boss_phase2" else enemy_name) + ".tscn"
			var enemy := stage._spawn_enemy(load(path), Vector2(stage.view_bounds.end.x - 280, stage.view_bounds.get_center().y))
			enemy.movement.hold_position = enemy.position
			enemy.movement.reached_hold = true
			if enemy_name == "boss_phase2":
				enemy.shooter.set_sequence(enemy.second_phase)
			contacts = 0
			cooldown = 0
			var seen := {}
			var peak := 0
			for frame in (480 if showcase else 1200):
				await physics_frame
				stage.player.invincibility = 2.0
				cooldown = maxf(0, cooldown - 1.0 / 60.0)
				peak = maxi(peak, stage.projectiles.get_child_count())
				for bullet in stage.projectiles.get_children():
					var id := bullet.get_instance_id()
					if not seen.has(id):
						seen[id] = true
						bullet.area_entered.connect(contact)
				if showcase and frame in [228, 360]:
					await RenderingServer.frame_post_draw
					DirAccess.make_dir_recursive_absolute("res://build/screenshots")
					root.get_texture().get_image().save_png("res://build/screenshots/fleet_" + enemy_name + "_" + str(frame) + ".png")
			trials.append({"y_fraction": fraction, "contacts": contacts, "peak_bullets": peak})
			stage.queue_free()
			await process_frame
			report[enemy_name] = trials
	var suffix := "showcase" if showcase else ("before" if args.has("--before") else "after")
	var file := FileAccess.open("res://build/validation/boss_camping_" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit()
