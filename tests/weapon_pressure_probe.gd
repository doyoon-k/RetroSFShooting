extends SceneTree
## Stationary, invincible, sustained fire: isolates real collision/TTK from dodging.
## Distances are ship-center to enemy-center, not projectile travel distance.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var report: Array[Dictionary] = []
	var enemies := ["n1_interceptor", "n2_crawler", "n3_claw", "n4_armor", "n5_tendril", "m2_wing", "m1_carapace", "m3_star_eye", "boss"] if args.has("--durability") else ["n2_crawler", "n4_armor", "boss"]
	if args.has("--mediums"): enemies = ["n1_interceptor", "n2_crawler", "n3_claw", "n4_armor", "n5_tendril"]
	for enemy_name in enemies:
		var distances := [400.0, 650.0] if args.has("--mediums") else ([400.0] if args.has("--durability") else [400.0, 650.0, 900.0])
		for distance in distances:
			for weapon in [0, 1]:
				for power in ([1, 2, 3] if args.has("--mediums") else [1, 3]):
					var stage := load("res://scenes/gameplay/stage/stage_01.tscn").instantiate() as StageController
					root.add_child(stage)
					stage.set_physics_process(false)
					stage._enter(StageController.Phase.PLAYING)
					stage.player.auto_advance_speed = 0
					stage.player.position = Vector2(1500.0 - distance, 500)
					stage.player.state.active_weapon = weapon
					stage.player.state.power_level = power
					if args.has("--tight-proximity") or args.has("--baseline-proximity"):
						var near := ProximityDamageTier.new()
						near.distance = 160 if args.has("--baseline-proximity") else 80
						near.multiplier = 2
						var far := ProximityDamageTier.new()
						far.distance = 640 if args.has("--baseline-proximity") else 360
						far.multiplier = 1
						stage.player.weapon.proximity_tiers = [near, far]
					var enemy := stage._spawn_enemy(load("res://scenes/enemies/" + enemy_name + ".tscn"), Vector2(1500, 500))
					enemy.movement.set_physics_process(false)
					var duration := 0.0
					var first_volley := -1.0
					var completed := 0
					Input.action_press("shoot")
					for frame in 5400:
						await physics_frame
						duration = frame / 60.0
						stage.player.invincibility = 2
						if is_instance_valid(enemy): completed = enemy.shooter.bursts_completed
						if not is_instance_valid(enemy) or enemy.dying: break
						if enemy.shooter.volleys_fired > 0 and first_volley < 0: first_volley = duration
					Input.action_release("shoot")
					var defeated := not is_instance_valid(enemy) or enemy.dying
					report.append({"enemy": enemy_name, "distance": distance, "weapon": "straight" if weapon == 0 else "spread", "power": power, "defeated": defeated, "seconds_to_kill": snappedf(duration, 0.01) if defeated else null, "trial_seconds": snappedf(duration, 0.01), "bursts_completed": completed, "first_volley_seconds": snappedf(first_volley, 0.01)})
					stage.queue_free()
					await process_frame
	var suffix := "before" if args.has("--baseline-proximity") else ("tight" if args.has("--tight-proximity") else "after")
	if args.has("--durability"): suffix = "durability"
	if args.has("--mediums"): suffix = "mediums"
	var file := FileAccess.open("res://build/validation/weapon_pressure_" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit()
