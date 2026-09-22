class_name PlayerWeapon
extends Node2D

signal charge_changed(ratio: float)
signal special_fired(origin: Vector2, size: Vector2, damage: int)

@export var data: WeaponData
var state: SortieState
var projectiles: Node2D
var bounds: Rect2
var cooldown: float = 0.0
var charge: float = 0.0
var special_cooldown: float = 0.0
var was_charging: bool = false

func _physics_process(delta: float) -> void:
	if state == null or state.hp <= 0:
		return
	cooldown = maxf(0.0, cooldown - delta)
	special_cooldown = maxf(0.0, special_cooldown - delta)
	if Input.is_action_pressed("shoot") and cooldown <= 0.0:
		fire()
	var holding := Input.is_action_pressed("special")
	if holding and special_cooldown <= 0.0:
		charge = minf(data.charge_seconds, charge + delta)
	elif not holding and was_charging:
		if charge >= data.charge_seconds:
			special_fired.emit(global_position, data.charge_size, data.charge_damage)
			special_cooldown = data.charge_cooldown
		charge = 0.0
	was_charging = holding
	charge_changed.emit(charge / maxf(data.charge_seconds, 0.01))

func fire() -> void:
	if data == null or data.levels.is_empty() or not is_instance_valid(projectiles):
		return
	var level := data.levels[clampi(state.power_level - 1, 0, data.levels.size() - 1)]
	if level.projectile_scene == null:
		return
	cooldown = level.interval
	for angle in level.angles:
		var bullet := level.projectile_scene.instantiate() as Projectile
		bullet.friendly = true
		bullet.damage = level.damage
		bullet.direction = Vector2.RIGHT.rotated(deg_to_rad(angle))
		bullet.bounds = bounds
		projectiles.add_child(bullet)
		bullet.global_position = global_position

