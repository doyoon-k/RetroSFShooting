class_name ProximityFeedbackStyle
extends Resource
## Shared by the weapon's distance guides and its projectiles' hit labels.

@export_group("Multiplier Colors")
@export var x1_color: Color = Color("dbe7ed")
@export var x2_color: Color = Color("91e4f3")
@export var x3_color: Color = Color("ffe38a")
@export var x4_color: Color = Color("ffb16f")
@export_group("Hit Label")
@export_range(12, 64, 1) var font_size: int = 28
@export_range(0.15, 2.0, 0.05) var duration: float = 0.35
@export_range(1.0, 1.5, 0.01) var pop_scale: float = 1.18
@export var label_offset: Vector2 = Vector2(0, -34)
@export_group("Distance Guides")
@export var show_guides: bool = true
@export_range(0.0, 1.0, 0.01) var guide_opacity: float = 0.22

func color_for(multiplier: int) -> Color:
	match multiplier:
		2: return x2_color
		3: return x3_color
		4: return x4_color
	return x1_color
