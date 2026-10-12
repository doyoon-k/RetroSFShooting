class_name CurtainBullet
extends Projectile
## Every row in a volley shares its age, preserving the gap while it sways.
var sway_amplitude: float = 0.0
var sway_period: float = 6.0
var sway_offset: float = 0.0
@onready var visual: Sprite2D = $Visual

func _physics_process(delta: float) -> void:
	if spent or is_queued_for_deletion(): return
	# Move/cull along the straight flight path; edge guard rows must survive
	# their temporary excursion beyond the arena before moving back inside.
	global_position.y -= sway_offset
	super._physics_process(delta)
	sway_offset = sway_amplitude * sin(age * TAU / maxf(sway_period, 0.01))
	global_position.y += sway_offset
	# Moving rows pulse their sprite; fixed rows keep the original asset opaque.
	var alpha := 0.7 + 0.3 * absf(cos(age * TAU * 2.0)) if sway_amplitude > 0.0 else 1.0
	visual.self_modulate = Color(1, 1, 1, alpha)
