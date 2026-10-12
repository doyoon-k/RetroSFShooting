class_name EnemyHitEffect
extends AnimatedSprite2D

@export_range(0.1, 3.0, 0.05) var size_ratio: float = 1.0
@export_range(0.1, 1.0, 0.05) var size_growth: float = 0.5
@export_range(0.5, 5.0, 0.05) var max_scale: float = 2.25
@export_range(0.0, 0.5, 0.01) var front_inset: float = 0.12
static var _texture_rects: Dictionary = {}

func _ready() -> void:
	animation_finished.connect(queue_free)
	# The first burst sits above the texture center. Anchor that burst, so the
	# rotated animation starts at the impact point and sprays toward the player.
	var texture := sprite_frames.get_frame_texture(&"hit", 0)
	if texture != null:
		var origin := Vector2(texture.get_size()) * 0.5 if centered else Vector2.ZERO
		offset = origin - _texture_rect(texture).get_center()
	play(&"hit")

func fit_to_enemy(enemy: EnemyShip) -> void:
	var visual := enemy.get_node_or_null("Visual") as Node2D
	var sprite := visual as Sprite2D
	var polygon := visual as Polygon2D
	var rect := Rect2()
	if sprite != null and sprite.texture != null:
		rect = sprite.get_rect()
		if not sprite.region_enabled and sprite.hframes == 1 and sprite.vframes == 1:
			var opaque_rect := _texture_rect(sprite.texture)
			rect = Rect2(rect.position + opaque_rect.position, opaque_rect.size)
	elif polygon != null and not polygon.polygon.is_empty():
		rect = Rect2(polygon.polygon[0], Vector2.ZERO)
		for point in polygon.polygon:
			rect = rect.expand(point)
	if visual == null or not rect.has_area():
		return
	var world_rect := Rect2(visual.to_global(rect.position), Vector2.ZERO)
	for corner in [Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		world_rect = world_rect.expand(visual.to_global(corner))
	global_position = Vector2(world_rect.position.x + world_rect.size.x * front_inset, world_rect.get_center().y)
	var reference_extent := 1.0
	for index in sprite_frames.get_frame_count(&"hit"):
		var texture := sprite_frames.get_frame_texture(&"hit", index)
		if texture == null:
			continue
		var frame_size := _texture_rect(texture).size
		reference_extent = maxf(reference_extent, maxf(frame_size.x, frame_size.y))
	var relative_size := maxf(world_rect.size.x, world_rect.size.y) / reference_extent
	# Keep small effects small; compress growth above the native texture size.
	var factor := minf(relative_size, pow(relative_size, size_growth))
	global_scale = Vector2.ONE * minf(factor, max_scale) * size_ratio

static func _texture_rect(texture: Texture2D) -> Rect2:
	if not _texture_rects.has(texture):
		var rect := Rect2(Vector2.ZERO, Vector2(texture.get_size()))
		var image := texture.get_image()
		if image != null and not image.is_empty():
			if not image.is_compressed() or image.decompress() == OK:
				var used_rect := Rect2(image.get_used_rect())
				if used_rect.has_area():
					rect = used_rect
		_texture_rects[texture] = rect
	return _texture_rects[texture]
