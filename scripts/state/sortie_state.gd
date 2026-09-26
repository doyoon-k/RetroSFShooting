class_name SortieState
extends RefCounted

signal changed

enum WeaponType { STRAIGHT, SPREAD }

var hp: int
var active_weapon: WeaponType = WeaponType.STRAIGHT
var weapon_levels: PackedInt32Array = PackedInt32Array([1, 1])
var bombs: int
var shield: bool = false

func _init(rules: GameRules = null) -> void:
	if rules != null:
		hp = rules.starting_hp
		bombs = rules.starting_bombs

func damage(amount: int = 1) -> bool:
	if hp <= 0 or amount <= 0:
		return false
	if shield:
		shield = false
	else:
		hp = maxi(0, hp - amount)
	changed.emit()
	return true

func spend_bomb() -> bool:
	if bombs <= 0 or hp <= 0:
		return false
	bombs -= 1
	changed.emit()
	return true

func switch_weapon() -> void:
	active_weapon = WeaponType.SPREAD if active_weapon == WeaponType.STRAIGHT else WeaponType.STRAIGHT
	changed.emit()

func current_power_level() -> int:
	return weapon_levels[active_weapon]

func recoverable_powerups() -> int:
	return (weapon_levels[WeaponType.STRAIGHT] - 1) + (weapon_levels[WeaponType.SPREAD] - 1)

func collect(kind: int, maximum_level: int) -> void:
	match kind:
		0: weapon_levels[active_weapon] = mini(current_power_level() + 1, maximum_level)
		1: bombs += 1
		2: shield = true
	changed.emit()
