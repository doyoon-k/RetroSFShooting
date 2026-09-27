class_name AttackSequence
extends Resource
## Reusable, immutable attack settings. EnemyShooter owns the runtime counters.

@export var steps: Array[PatternStep] = []
@export_range(0.0, 10.0, 0.1) var initial_delay: float = 1.0
