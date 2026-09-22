class_name Pickup
extends Area2D

enum Kind { POWER, BOMB, SHIELD }
@export var kind: Kind = Kind.POWER
@export_range(0.1, 30.0, 0.1) var lifetime: float = 7.0
@export_range(0.0, 200.0, 1.0) var attraction: float = 24.0
@export_range(0.0, 400.0, 5.0) var maximum_speed: float = 95.0
@export var initial_velocity: Vector2 = Vector2(-50, 40)
@export_range(1.0, 100.0, 1.0) var boundary_padding: float = 24.0
var bounds: Rect2
var target: PlayerShip
var velocity: Vector2
var taken: bool = false

func _ready() -> void:
	velocity = initial_velocity
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	if is_instance_valid(target) and not target.death_reported:
		velocity += global_position.direction_to(target.global_position) * attraction * delta
	velocity = velocity.limit_length(maximum_speed)
	position += velocity * delta
	var area := bounds.grow(-boundary_padding)
	if position.x < area.position.x or position.x > area.end.x:
		velocity.x = -velocity.x
	if position.y < area.position.y or position.y > area.end.y:
		velocity.y = -velocity.y
	position = position.clamp(area.position, area.end)
	modulate.a = 0.35 if lifetime < 2.0 and fmod(lifetime, 0.25) < 0.125 else 1.0

func _on_area_entered(area: Area2D) -> void:
	if not taken and area is PlayerShip and area.state != null and area.state.hp > 0 and not get_tree().paused:
		taken = true
		area.collect(kind)
		queue_free()
