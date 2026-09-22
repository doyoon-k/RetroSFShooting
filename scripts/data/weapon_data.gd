class_name WeaponData
extends Resource

@export var levels: Array[ShotLevelData] = []
@export_group("Charge attack")
@export_range(0.1, 10.0, 0.05) var charge_seconds: float = 1.0
@export_range(0.0, 10.0, 0.05) var charge_cooldown: float = 1.5
@export_range(1, 100) var charge_damage: int = 12
@export var charge_size: Vector2 = Vector2(390, 200)
@export var charge_color: Color = Color("aaffcf")

