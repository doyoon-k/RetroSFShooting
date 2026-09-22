class_name SortieState
extends RefCounted

signal changed

var hp: int
var power_level: int = 1
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

func collect(kind: int, maximum_level: int) -> void:
	match kind:
		0: power_level = mini(power_level + 1, maximum_level)
		1: bombs += 1
		2: shield = true
	changed.emit()
