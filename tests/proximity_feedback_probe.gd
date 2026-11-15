extends SceneTree
## Real weapon -> projectile collision -> damage, label, theme and pause integration.

var stage: StageController
var checks: int = 0
var failures: Array[String] = []
var strong_hits: int = 0

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func frames(count: int = 2) -> void:
	for index in count:
		await process_frame

func record_cue(cue: StringName) -> void:
	if cue == &"enemy_hit_strong":
		strong_hits += 1

func make_enemy() -> EnemyShip:
	var enemy := stage._spawn_enemy(load("res://scenes/enemies/n4_armor.tscn"), Vector2(1500, 500))
	enemy.maximum_hp = 100
	enemy.hp = 100
	enemy.movement.set_physics_process(false)
	if enemy.shooter != null:
		enemy.shooter.set_physics_process(false)
	return enemy

func shoot_at(enemy: EnemyShip, distance: float) -> Projectile:
	var start := stage.projectiles.get_child_count()
	stage.player.weapon.fire()
	var bullet := stage.projectiles.get_child(start) as Projectile
	for index in range(start + 1, stage.projectiles.get_child_count()):
		stage.projectiles.get_child(index).queue_free()
	enemy.global_position = bullet.damage_origin + Vector2(distance, 0)
	bullet.global_position = enemy.global_position
	bullet._on_area_entered(enemy)
	return bullet

func capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://build/screenshots")
		root.get_texture().get_image().save_png("res://build/screenshots/proximity_" + name + ".png")

func run() -> void:
	stage = load("res://scenes/gameplay/stage/stage_01.tscn").instantiate() as StageController
	root.add_child(stage)
	stage.set_physics_process(false)
	stage._enter(StageController.Phase.PLAYING)
	stage.player.set_physics_process(false)
	stage.player.auto_advance_speed = 0
	stage.player.position = Vector2(900, 530)
	stage.player.weapon.proximity_feedback = stage.player.weapon.proximity_feedback.duplicate()
	var style := stage.player.weapon.proximity_feedback
	var hud_font := (load("res://scenes/ui/game_theme.tres") as Theme).get_font("font", &"ArcadeLabel")
	SoundEffects.instance().cue_played.connect(record_cue)
	for entry in [[400, 1], [240, 2], [120, 3], [60, 4]]:
		var enemy := make_enemy()
		var bullet := shoot_at(enemy, entry[0])
		var feedback := enemy._damage_feedback
		expect(enemy.hp == 100 - entry[1], "Fired shot applies x%d damage" % entry[1])
		expect(feedback != null and feedback.label.text == "x%d" % entry[1], "Label contains only x and the actual damage multiplier")
		expect(feedback.label.get_theme_font("font") == hud_font, "Multiplier uses the exact shared HUD numeric font")
		expect(feedback.label.get_theme_color("font_color") == style.color_for(entry[1]), "Hit label uses its editor-configured color")
		var hp := enemy.hp
		bullet._on_area_entered(enemy)
		expect(enemy.hp == hp, "Spent projectile cannot damage or refresh feedback twice")
		await capture("x%d" % entry[1])
		enemy.queue_free()
		feedback.queue_free()
		await frames()
	var enemy := make_enemy()
	style.x3_color = Color(0.65, 0.45, 1)
	var bullet := shoot_at(enemy, 120)
	var feedback := enemy._damage_feedback
	expect(feedback.label.get_theme_color("font_color") == style.x3_color, "Editing a multiplier color reaches fired shots without code changes")
	var previous_origin := bullet.damage_origin
	stage.player.position += Vector2(-100, 50)
	expect(bullet.damage_origin == previous_origin, "Player movement does not rewrite a fired projectile's distance origin")
	feedback._process(0.1)
	var pop := feedback.pop_left
	shoot_at(enemy, 120)
	expect(enemy._damage_feedback == feedback and feedback.pop_left == pop, "Repeated pellets reuse one label without restarting the pop")
	expect(is_equal_approx(feedback.left, style.duration), "Repeated hits extend the label's lifetime")
	feedback._process(0.02)
	shoot_at(enemy, 60)
	expect(feedback.label.text == "x4" and feedback.pop_left == 0.12, "A new tier updates and pops the same label immediately")
	var accents := strong_hits
	await frames(10)
	shoot_at(enemy, 60)
	expect(strong_hits == accents, "Holding x4 does not retrigger the strong-hit accent")
	enemy.global_position += Vector2(12, 10)
	feedback._process(0)
	expect(feedback.impact_position.is_equal_approx(enemy.to_global(feedback.impact_offset)), "Label follows the enemy's moving hit location")
	enemy.global_position = stage.view_bounds.end - Vector2(1, 1)
	feedback.show_hit(enemy, enemy.global_position, 4, style, stage.view_bounds)
	expect(stage.view_bounds.encloses(feedback.label.get_global_rect()), "Multiplier stays inside the playfield at the edge")
	var left := feedback.left
	paused = true
	await frames(5)
	expect(is_equal_approx(feedback.left, left), "Combat pause freezes the label and pop timers")
	paused = false
	var hp_before_bomb := enemy.hp
	enemy.take_damage(10)
	expect(enemy.hp == hp_before_bomb - 10 and enemy.last_hit_multiplier == 1, "Bomb/direct damage stays unmultiplied after a close-range hit")
	expect(is_equal_approx(feedback.left, left), "Bomb/direct damage does not refresh a shot multiplier label")
	enemy.take_projectile_damage(100, 4, style, enemy.global_position)
	await frames()
	expect(not is_instance_valid(enemy) and is_instance_valid(feedback), "A killing-hit label survives removal of its enemy")
	await frames(30)
	expect(not is_instance_valid(feedback), "A detached killing-hit label expires without leaking")
	stage.queue_free()
	await frames()
	GameMusic.stop()
	await SoundEffects.shutdown()
	print("PROXIMITY: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
