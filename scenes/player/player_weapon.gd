class_name PlayerWeapon
extends Node2D

@export var data: WeaponData
@export var spread_data: WeaponData
@export_group("Proximity Damage")
@export var proximity_tiers: Array[ProximityDamageTier] = []
var state: SortieState
var projectiles: Node2D
var bounds: Rect2
var cooldown: float = 0.0

func _physics_process(delta: float) -> void:
	if state == null or state.hp <= 0:
		return
	cooldown = maxf(0.0, cooldown - delta)
	if Input.is_action_just_pressed("switch_weapon"):
		state.switch_weapon()
		cooldown = 0.0
	if Input.is_action_pressed("shoot") and cooldown <= 0.0:
		fire()

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
	var proximity_points: Array[Vector2] = []
	for tier in proximity_tiers:
		if tier != null:
			proximity_points.append(Vector2(maxf(0.0, tier.distance), maxf(1.0, tier.multiplier)))
	proximity_points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for angle in level.angles:
		var bullet := level.projectile_scene.instantiate() as Projectile
		bullet.friendly = true
		bullet.damage = level.damage
		bullet.direction = Vector2.RIGHT.rotated(deg_to_rad(angle))
		bullet.bounds = bounds
		bullet.proximity_points = proximity_points.duplicate()
		projectiles.add_child(bullet)
		bullet.global_position = global_position
		bullet.damage_origin = global_position
