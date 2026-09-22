class_name PatternStep
extends Resource

@export var pattern: AttackPattern
@export_range(1, 20) var repetitions: int = 1
@export_range(0.0, 10.0, 0.1) var wait_after: float = 0.0

