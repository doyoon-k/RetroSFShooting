class_name CurtainBullet
extends Projectile
## Every row in a volley shares its age, preserving the gap while it sways.
var sway_amplitude: float = 0.0
var sway_period: float = 6.0
var sway_offset: float = 0.0

func _physics_process(delta: float) -> void:
	if spent or is_queued_for_deletion(): return
	# Move/cull along the straight flight path; edge guard rows must survive
	# their temporary excursion beyond the arena before moving back inside.
	global_position.y -= sway_offset
	super._physics_process(delta)
	sway_offset = sway_amplitude * sin(age * TAU / maxf(sway_period, 0.01))
	global_position.y += sway_offset

func _draw() -> void:
	if sway_amplitude <= 0.0: return
	var tint := Color(0.65, 1.0, 1.0, 0.85)
	# A small pair of chevrons distinguishes the moving wall from fixed rows.
	for side in [-1.0, 1.0]:
		draw_polyline(PackedVector2Array([
			Vector2(-3, side * 10), Vector2(0, side * 13), Vector2(3, side * 10)
		]), tint, 1.0)
