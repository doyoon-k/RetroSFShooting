class_name DamageMultiplierFeedback
extends Node2D
## One reusable label per enemy. A sibling keeps a killing hit visible after death.

const GAME_THEME: Theme = preload("res://scenes/ui/game_theme.tres")

var label: Label
var multiplier: int = 0
var style: ProximityFeedbackStyle
var left: float = 0.0
var pop_left: float = 0.0
var target: WeakRef
var impact_offset: Vector2
var impact_position: Vector2
var bounds: Rect2

func _ready() -> void:
	top_level = true
	z_index = 20
	label = Label.new()
	label.theme = GAME_THEME
	label.theme_type_variation = &"ArcadeLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_outline_color", Color(0.025, 0.04, 0.07, 0.95))
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)

func show_hit(enemy: Node2D, hit_position: Vector2, next_multiplier: int, next_style: ProximityFeedbackStyle, playfield: Rect2) -> void:
	var changed := multiplier != next_multiplier or left <= 0.0
	style = next_style
	multiplier = next_multiplier
	target = weakref(enemy)
	impact_offset = enemy.to_local(hit_position)
	impact_position = hit_position
	bounds = playfield
	left = style.duration
	if changed:
		pop_left = 0.12
		if multiplier == 4:
			SoundEffects.play(&"enemy_hit_strong")
	label.text = "x%d" % multiplier
	label.add_theme_color_override("font_color", style.color_for(multiplier))
	label.add_theme_font_size_override("font_size", style.font_size)
	label.reset_size()
	_update_label()

func _process(delta: float) -> void:
	if style == null:
		return
	left = maxf(0.0, left - delta)
	pop_left = maxf(0.0, pop_left - delta)
	if left <= 0.0:
		queue_free()
		return
	var enemy := target.get_ref() as Node2D
	if is_instance_valid(enemy):
		impact_position = enemy.to_global(impact_offset)
		bounds = enemy.bounds
	_update_label()

func _update_label() -> void:
	var enlargement := lerpf(1.0, style.pop_scale, pop_left / 0.12)
	label.scale = Vector2.ONE * enlargement
	var half_size := label.size * enlargement * 0.5
	global_position = impact_position + style.label_offset
	if bounds.has_area():
		global_position = global_position.clamp(bounds.position + half_size + Vector2.ONE * 6, bounds.end - half_size - Vector2.ONE * 6)
	label.position = -half_size
	modulate.a = clampf(left / minf(0.12, style.duration), 0.0, 1.0)
