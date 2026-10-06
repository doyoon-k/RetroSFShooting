class_name BroodCore
extends Projectile
## One generation only: travel -> stationary, visible incubation -> hatch.
@export var child_scene: PackedScene
@export_range(0.1, 3.0, 0.05) var travel_seconds := 0.85
@export_range(0.4, 2.0, 0.05) var incubation_seconds := 0.65
@export_range(3, 20) var child_count := 7
@export_range(30.0, 180.0, 1.0) var child_spread := 120.0
var hatched := false

func _physics_process(delta: float) -> void:
	if spent or is_queued_for_deletion(): return
	if age >= travel_seconds: speed = 0.0
	super._physics_process(delta)
	queue_redraw()
	if not is_queued_for_deletion() and age >= travel_seconds + incubation_seconds:
		hatch()

func hatch() -> void:
	if hatched or spent or is_queued_for_deletion(): return
	hatched = true
	# No on-destruction callback: a bomb/clear removes the core without children.
	if child_scene != null and bounds.grow(-24.0).has_point(global_position):
		for index in child_count:
			var child := child_scene.instantiate() as Projectile
			# Prevent accidental recursive spawning through editor configuration.
			if child is BroodCore:
				child.free()
				continue
			child.position = position
			child.bounds = bounds
			child.direction = direction.rotated(deg_to_rad(child_spread) * (float(index) / (child_count - 1) - 0.5))
			get_parent().add_child(child)
	queue_free()

func _draw() -> void:
	var progress := clampf((age - travel_seconds) / incubation_seconds, 0.0, 1.0)
	draw_circle(Vector2.ZERO, 21.0, Color(0.12, 0.04, 0.2))
	draw_circle(Vector2.ZERO, 14.0, Color(0.35 + 0.65 * progress, 0.65, 1.0))
	draw_circle(Vector2.ZERO, 5.0, Color.WHITE)
	draw_arc(Vector2.ZERO, 28.0 - 10.0 * progress, 0.0, TAU * maxf(0.05, progress), 32, Color(0.9, 0.8, 1), 3.0)
	if age >= travel_seconds:
		for index in child_count:
			var ray := Vector2.from_angle(deg_to_rad(child_spread) * (float(index) / (child_count - 1) - 0.5))
			draw_line(ray * 23.0, ray * (42.0 + 15.0 * progress), Color(0.65, 0.7, 1, 0.75), 2.0)
