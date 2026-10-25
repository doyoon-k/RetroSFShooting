class_name BroodCore
extends Projectile
## One generation only: travel -> stationary, visible incubation -> hatch.
signal offspring_spawned(child: Projectile)

@export var child_scene: PackedScene
@export var incubation_hint_texture: Texture2D
@export_range(0.1, 3.0, 0.05) var travel_seconds := 0.85
@export_range(0.4, 2.0, 0.05) var incubation_seconds := 0.65
@export_range(3, 20) var child_count := 7
@export_range(30.0, 180.0, 1.0) var child_spread := 120.0
var hatched := false
var hatch_held := false
var incubation_elapsed := 0.0
@onready var visual: Sprite2D = $Visual
@onready var incubation_hints: Node2D = $IncubationHints

func _ready() -> void:
	super._ready()
	for index in child_count:
		var hint := Sprite2D.new()
		hint.texture = incubation_hint_texture
		hint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hint.scale = Vector2(0.2, 0.2)
		hint.rotation = deg_to_rad(child_spread) * (float(index) / (child_count - 1) - 0.5)
		incubation_hints.add_child(hint)

func _physics_process(delta: float) -> void:
	if spent or is_queued_for_deletion(): return
	if age >= travel_seconds: speed = 0.0
	var before_age := age
	super._physics_process(delta)
	if not hatch_held:
		incubation_elapsed += maxf(0.0, age - maxf(before_age, travel_seconds))
	_update_visual()
	if not hatch_held and not is_queued_for_deletion() and incubation_elapsed >= incubation_seconds:
		hatch()

func hatch() -> void:
	if hatched or hatch_held or spent or is_queued_for_deletion(): return
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
			offspring_spawned.emit(child)
		SoundEffects.play(&"bullet_split")
	queue_free()

func _update_visual() -> void:
	if age < travel_seconds:
		visual.self_modulate = Color.WHITE
		incubation_hints.visible = false
		return
	if hatch_held:
		visual.self_modulate = Color(1, 1, 1, 0.85)
		incubation_hints.visible = false
		return
	var progress := clampf(incubation_elapsed / incubation_seconds, 0.0, 1.0)
	# Pulse the authored sprite during incubation without changing its hitbox or size.
	visual.self_modulate = Color(1, 1, 1, 0.7 + 0.3 * absf(cos(progress * TAU * 3.0)))
	incubation_hints.visible = true
	incubation_hints.modulate = Color(1, 1, 1, 0.5 + 0.35 * progress)
	for hint: Sprite2D in incubation_hints.get_children():
		hint.position = Vector2.from_angle(hint.rotation) * (33.0 + 15.0 * progress)
