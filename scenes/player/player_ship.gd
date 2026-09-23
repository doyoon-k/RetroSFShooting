class_name PlayerShip
extends Area2D

signal died(position: Vector2, power_level: int)
signal bomb_requested
signal hit

@export_range(50.0, 1200.0, 10.0) var move_speed: float = 490.0
@export var tint: Color = Color("6de5ed")
@export var ship_scale: Vector2 = Vector2.ONE
@export var boundary_padding: Vector2 = Vector2(24, 24)
var auto_advance_speed: float = 0.0
var state: SortieState
var rules: GameRules
var bounds: Rect2
var invincibility: float = 0.0
var death_reported: bool = false
@onready var weapon: PlayerWeapon = $Weapon
@onready var visuals: Node2D = $Visuals

func _ready() -> void:
	visuals.modulate = tint
	visuals.scale = ship_scale
	area_entered.connect(_on_contact)

func _physics_process(delta: float) -> void:
	if state == null or state.hp <= 0:
		return
	invincibility = maxf(0.0, invincibility - delta)
	var motion := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += (Vector2(auto_advance_speed, 0.0) + motion * move_speed) * delta
	position = position.clamp(bounds.position + boundary_padding, bounds.end - boundary_padding)
	visuals.modulate = tint if state.hp > 1 else tint.lerp(Color("ff765e"), 0.65)
	visuals.modulate.a = 0.4 if invincibility > 0.0 and fmod(invincibility, 0.14) < 0.07 else 1.0
	$Shield.visible = state.shield
	if Input.is_action_just_pressed("bomb"):
		bomb_requested.emit()

func grant_invincibility(seconds: float) -> void:
	invincibility = maxf(invincibility, seconds)

func take_damage(amount: int = 1) -> void:
	if state == null or death_reported or invincibility > 0.0 or get_tree().paused:
		return
	if not state.damage(amount):
		return
	hit.emit()
	grant_invincibility(rules.hit_invincibility)
	if state.hp == 0:
		death_reported = true
		died.emit(global_position, state.power_level)

func collect(kind: int) -> void:
	if state != null and state.hp > 0:
		state.collect(kind, weapon.data.levels.size())

func _on_contact(area: Area2D) -> void:
	if area is EnemyShip and area.hp > 0:
		take_damage(area.contact_damage)
