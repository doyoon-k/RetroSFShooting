class_name EnemyShip
extends Area2D

signal destroyed(enemy: EnemyShip)
signal health_changed(current: int, maximum: int)

@export_range(1, 2000) var maximum_hp: int = 3
@export_range(0, 10) var contact_damage: int = 1
@export_range(0.0, 1000.0, 10.0) var despawn_margin: float = 320.0
@export var death_effect: PackedScene
@export var death_animation: StringName = &""
@export_range(0.0, 5.0, 0.05) var death_animation_seconds: float = 0.0
@export var is_boss: bool = false
@export_range(0.05, 0.95, 0.05) var phase_threshold: float = 0.5
@export var second_phase: Array[PatternStep] = []
var hp: int
var bounds: Rect2
var drop_scene: PackedScene
var drop_chance: float = 0.0
var phase_two: bool = false
var dying: bool = false
var death_left: float = 0.0
@onready var movement: EnemyMovement = $Movement
@onready var shooter: EnemyShooter = get_node_or_null("Shooter") as EnemyShooter

func _ready() -> void:
	hp = maximum_hp

func _physics_process(delta: float) -> void:
	if dying:
		death_left -= delta
		if death_left <= 0.0:
			queue_free()
	elif not is_boss and not bounds.grow(despawn_margin).has_point(global_position):
		queue_free()

func take_damage(amount: int) -> void:
	if dying or hp <= 0 or get_tree().paused:
		return
	hp = maxi(0, hp - amount)
	health_changed.emit(hp, maximum_hp)
	if is_boss and not phase_two and float(hp) / maximum_hp <= phase_threshold:
		phase_two = true
		if shooter != null and not second_phase.is_empty():
			shooter.set_sequence(second_phase)
	if hp == 0:
		dying = true
		movement.set_physics_process(false)
		if shooter != null:
			shooter.set_physics_process(false)
		set_deferred("monitorable", false)
		destroyed.emit(self)
		var animation := get_node_or_null("AnimationPlayer") as AnimationPlayer
		if animation != null and animation.has_animation(death_animation):
			animation.play(death_animation)
		death_left = death_animation_seconds
		if death_left <= 0.0:
			queue_free()
