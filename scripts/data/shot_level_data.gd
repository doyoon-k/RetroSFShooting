class_name ShotLevelData
extends Resource

@export var projectile_scene: PackedScene
@export_range(0.03, 2.0, 0.01) var interval: float = 0.16
@export var angles: PackedFloat32Array = PackedFloat32Array([0.0])
@export_range(1, 100) var damage: int = 1
