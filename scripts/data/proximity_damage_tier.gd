class_name ProximityDamageTier
extends Resource

## Inclusive maximum travel distance for this damage step, in world pixels.
@export_range(0.0, 5000.0, 1.0) var distance: float = 80.0
@export_range(1, 4, 1) var multiplier: int = 4
