class_name GameRules
extends Resource
## Shared tuning. Runtime code must never modify this resource.

@export_group("Sortie")
@export_range(1, 10) var starting_hp: int = 2
@export_range(0, 10) var starting_bombs: int = 2
@export_range(0.0, 5.0, 0.05) var spawn_invincibility: float = 1.5
@export_range(0.0, 5.0, 0.05) var hit_invincibility: float = 0.75
@export_range(0.1, 15.0, 0.1) var selection_seconds: float = 5.0
@export_range(0.1, 5.0, 0.1) var launch_seconds: float = 1.2
@export_range(0.1, 10.0, 0.1) var death_seconds: float = 2.8
@export_range(0.1, 10.0, 0.1) var victory_line_seconds: float = 2.0
@export_group("Bomb")
@export_range(1, 100, 1) var bomb_damage: int = 10
@export_range(0.0, 5.0, 0.05) var bomb_invincibility: float = 1.0
@export var bomb_clears_bullets: bool = true
@export_group("Playfield")
@export var playfield: Rect2 = Rect2(48, 100, 1440, 864)
@export var spawn_position: Vector2 = Vector2(230, 532)

