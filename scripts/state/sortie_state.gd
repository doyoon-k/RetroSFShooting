class_name SortieState
extends RefCounted

signal changed

enum WeaponType { STRAIGHT, SPREAD }

const MAX_BOMBS: int = 4

var hp: int
var active_weapon: WeaponType = WeaponType.STRAIGHT
var power_level: int = 1
var bombs: int = 0:
	set(value):
		bombs = clampi(value, 0, MAX_BOMBS)
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
		power_level = maxi(1, power_level - 1)
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
	return power_level

func recoverable_powerups() -> int:
	return maxi(0, power_level - 1)

func collect(kind: int, maximum_level: int) -> void:
	match kind:
		0: power_level = mini(power_level + 1, maximum_level)
		1: bombs += 1
		2: shield = true
	changed.emit()
