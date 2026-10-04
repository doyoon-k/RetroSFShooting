class_name CombatHUD
extends Control

signal bomb_requested
signal weapon_change_requested
signal pause_requested

@export var bomb_on: Texture2D
@export var bomb_ready: Texture2D
@export var bomb_off: Texture2D
@export var straight_icon: Texture2D
@export var spread_icon: Texture2D

@onready var bomb_slots: Array[TextureRect] = [%BombOne, %BombTwo, %BombThree, %BombFour]

func _ready() -> void:
	%BombButton.pressed.connect(func(): bomb_requested.emit())
	%WeaponChange.pressed.connect(func(): weapon_change_requested.emit())
	%PauseButton.pressed.connect(func(): pause_requested.emit())

func display(sortie: SortieState, portrait: Texture2D, can_use: bool) -> void:
	%ActivePortrait.texture = portrait
	for index in bomb_slots.size():
		bomb_slots[index].texture = bomb_off if index >= sortie.bombs else (bomb_ready if index == 0 else bomb_on)
	%BombButton.disabled = not can_use or sortie.bombs <= 0
	%WeaponChange.disabled = not can_use
	var icon := spread_icon if sortie.active_weapon == SortieState.WeaponType.SPREAD else straight_icon
	%WeaponOne.texture = icon
	%WeaponTwo.texture = icon
	%WeaponTwo.rotation = deg_to_rad(18.0) if sortie.active_weapon == SortieState.WeaponType.SPREAD else 0.0
	%WeaponLevel.text = "LV.%d" % sortie.current_power_level()
