class_name Projectile
extends Area2D
## Extend this scene/script for a genuinely new projectile behavior.

@export_range(10.0, 2000.0, 10.0) var speed: float = 380.0
@export_range(0.1, 30.0, 0.1) var lifetime: float = 8.0
@export_range(1, 100) var damage: int = 1
@export_range(0.0, 500.0, 10.0) var despawn_margin: float = 80.0
@export_range(0.0, 8.0, 0.1) var homing_radians_per_second: float = 0.0
var direction := Vector2.LEFT
var friendly: bool = false
var bounds := Rect2(0, 0, 1920, 1080)
var target: Node2D
var spent: bool = false

func _ready() -> void:
	collision_layer = 4 if friendly else 8
	collision_mask = 2 if friendly else 1
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if homing_radians_per_second > 0.0 and is_instance_valid(target):
		var desired := global_position.direction_to(target.global_position).angle()
		direction = Vector2.from_angle(rotate_toward(direction.angle(), desired, homing_radians_per_second * delta))
	rotation = direction.angle()
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0 or not bounds.grow(despawn_margin).has_point(global_position):
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if spent or get_tree().paused:
		return
	if area.has_method("take_damage"):
		spent = true
		area.take_damage(damage)
		queue_free()
