class_name PlayerShip
extends Area2D

signal died(position: Vector2, power_level: int)
signal bomb_requested
signal hit

@export_range(50.0, 1200.0, 10.0) var move_speed: float = 490.0
@export var boundary_padding: Vector2 = Vector2(24, 24)
@export_group("Ship Sprites")
@export var normal_sprite: Texture2D
@export var normal_back_sprite: Texture2D
@export var normal_forward_sprite: Texture2D
@export var damaged_sprite: Texture2D
@export var damaged_back_sprite: Texture2D
@export var damaged_forward_sprite: Texture2D
var auto_advance_speed: float = 0.0
var state: SortieState
var rules: GameRules
var bounds: Rect2
var invincibility: float = 0.0
var death_reported: bool = false
var has_taken_hit: bool = false
var horizontal_input: float = 0.0
@onready var weapon: PlayerWeapon = $Weapon
@onready var visuals: Sprite2D = $Visuals

func _ready() -> void:
	_update_sprite()
	area_entered.connect(_on_contact)

func _physics_process(delta: float) -> void:
	if state == null or state.hp <= 0:
		return
	invincibility = maxf(0.0, invincibility - delta)
	var motion := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	horizontal_input = motion.x
	position += (Vector2(auto_advance_speed, 0.0) + motion * move_speed) * delta
	position = position.clamp(bounds.position + boundary_padding, bounds.end - boundary_padding)
	_update_sprite()
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
	has_taken_hit = true
	_update_sprite()
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

func _update_sprite() -> void:
	var next_texture: Texture2D
	if horizontal_input > 0.0:
		next_texture = damaged_forward_sprite if has_taken_hit else normal_forward_sprite
	elif horizontal_input < 0.0:
		next_texture = damaged_back_sprite if has_taken_hit else normal_back_sprite
	else:
		next_texture = damaged_sprite if has_taken_hit else normal_sprite
	if visuals.texture != next_texture:
		visuals.texture = next_texture
