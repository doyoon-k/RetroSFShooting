extends SceneTree
## Compare authored flyby HP with the preceding revision; no game data is mutated.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var report: Array[Dictionary] = []
	var old_hp := {"n1_interceptor": 52, "n2_crawler": 60, "n5_tendril": 64}
	for baseline in [true, false]:
		for enemy_name in old_hp:
			for weapon in [0, 1]:
				for power in [1, 3]:
					var stage := load("res://scenes/gameplay/stage/stage_01.tscn").instantiate() as StageController
					root.add_child(stage)
					stage.set_physics_process(false)
					stage._enter(StageController.Phase.PLAYING)
					stage.player.auto_advance_speed = 0
					stage.player.position = Vector2(750, 500)
					stage.player.state.active_weapon = weapon
					stage.player.state.power_level = power
					var enemy := stage._spawn_enemy(load("res://scenes/enemies/" + enemy_name + ".tscn"), Vector2(1800, 500))
					if baseline:
						enemy.maximum_hp = old_hp[enemy_name]
						enemy.hp = enemy.maximum_hp
					var destroyed := [false]
					enemy.destroyed.connect(func(_ship: EnemyShip): destroyed[0] = true)
					var duration := 0.0
					var outcome := "timeout"
					for frame in 600:
						await physics_frame
						duration = frame / 60.0
						stage.player.invincibility = 2
						if destroyed[0]:
							outcome = "destroyed"
							break
						if not is_instance_valid(enemy):
							outcome = "despawned"
							break
						if enemy.dying:
							outcome = "destroyed"
							break
						if enemy.global_position.x <= stage.player.global_position.x + 80:
							outcome = "passed"
							break
						# Shift this sine path to represent 180px/s camera-relative scrolling.
						enemy.movement.origin.x -= 180.0 / 60.0
						enemy.position.x -= 180.0 / 60.0
						if frame >= 21:
							Input.action_press("shoot")
							stage.player.position.y = move_toward(stage.player.position.y, enemy.global_position.y, 460.0 / 60.0)
					Input.action_release("shoot")
					report.append({"baseline": baseline, "enemy": enemy_name, "weapon": weapon, "power": power, "outcome": outcome, "seconds": snappedf(duration, 0.01)})
					stage.queue_free()
					await process_frame
	DirAccess.make_dir_recursive_absolute("res://build/validation")
	var file := FileAccess.open("res://build/validation/flyby.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit()
