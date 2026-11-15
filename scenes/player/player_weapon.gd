class_name PlayerWeapon
extends Node2D

const GAME_THEME: Theme = preload("res://scenes/ui/game_theme.tres")

@export var data: WeaponData
@export var spread_data: WeaponData
@export_group("Shot Pattern")
@export_range(0.0, 100.0, 1.0) var straight_shot_spacing: float = 28.0
@export_group("Proximity Damage")
@export var proximity_tiers: Array[ProximityDamageTier] = []
## Expand this resource to edit x1/x2/x3/x4 colors together.
@export var proximity_feedback: ProximityFeedbackStyle
var state: SortieState
var projectiles: Node2D
var bounds: Rect2
var cooldown: float = 0.0
var _guide_left: float = 0.0

func _physics_process(delta: float) -> void:
	if _guide_left > 0.0:
		_guide_left = maxf(0.0, _guide_left - delta)
		queue_redraw()
	if state == null or state.hp <= 0:
		_guide_left = 0.0
		queue_redraw()
		return
	cooldown = maxf(0.0, cooldown - delta)
	if Input.is_action_just_pressed("switch_weapon"):
		switch_weapon()
	if Input.is_action_pressed("shoot") and cooldown <= 0.0:
		fire()

func switch_weapon() -> void:
	if state == null or state.hp <= 0:
		return
	state.switch_weapon()
	cooldown = 0.0
	SoundEffects.play(&"weapon_switch")

func active_data() -> WeaponData:
	if state != null and state.active_weapon == SortieState.WeaponType.SPREAD:
		return spread_data
	return data

func fire() -> void:
	var weapon := active_data()
	if state == null or weapon == null or weapon.levels.is_empty() or not is_instance_valid(projectiles):
		return
	var level := weapon.levels[clampi(state.current_power_level() - 1, 0, weapon.levels.size() - 1)]
	if level.projectile_scene == null:
		return
	cooldown = level.interval
	_guide_left = level.interval + 0.1
	queue_redraw()
	var proximity_points: Array[Vector2] = []
	for tier in proximity_tiers:
		if tier != null:
			proximity_points.append(Vector2(maxf(0.0, tier.distance), maxf(1.0, tier.multiplier)))
	proximity_points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for index in level.angles.size():
		var angle := level.angles[index]
		var offset := Vector2.ZERO
		if state.active_weapon == SortieState.WeaponType.STRAIGHT:
			offset.y = (float(index) - float(level.angles.size() - 1) * 0.5) * straight_shot_spacing
		var bullet := level.projectile_scene.instantiate() as Projectile
		bullet.friendly = true
		bullet.damage = level.damage
		bullet.direction = Vector2.RIGHT.rotated(deg_to_rad(angle))
		bullet.bounds = bounds
		bullet.proximity_points = proximity_points.duplicate()
		bullet.proximity_feedback = proximity_feedback
		projectiles.add_child(bullet)
		bullet.global_position = to_global(offset)
		bullet.damage_origin = bullet.global_position
	SoundEffects.play(&"player_shot_spread" if state.active_weapon == SortieState.WeaponType.SPREAD else &"player_shot")

func _draw() -> void:
	if _guide_left <= 0.0 or proximity_feedback == null or not proximity_feedback.show_guides:
		return
	# Weapon inherits the ship's 1.5 scale; thresholds and font stay in world pixels.
	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE / global_scale)
	var font := GAME_THEME.get_font("font", &"ArcadeLabel")
	for tier in proximity_tiers:
		if tier == null or tier.multiplier <= 1 or tier.distance <= 0:
			continue
		var color := proximity_feedback.color_for(tier.multiplier)
		color.a *= proximity_feedback.guide_opacity
		var segment := PackedVector2Array()
		for step in 49:
			var point := Vector2.from_angle(lerpf(-PI * 0.5, PI * 0.5, step / 48.0)) * tier.distance
			if not bounds.has_area() or bounds.has_point(global_position + point):
				segment.append(point)
			else:
				if segment.size() > 1:
					draw_polyline(segment, color, 1.0, true)
				segment.clear()
		if segment.size() > 1:
			draw_polyline(segment, color, 1.0, true)
		var point := Vector2(tier.distance - 30, -12)
		if not bounds.has_area() or bounds.encloses(Rect2(global_position + point - Vector2(0, 16), Vector2(30, 20))):
			draw_string(font, point, "x%d" % tier.multiplier, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
