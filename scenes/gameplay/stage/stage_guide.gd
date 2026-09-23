@tool
extends Node2D
## Editor-only ruler, enemy silhouettes, and movement previews for a spatial stage.

@export_range(1440.0, 100000.0, 100.0) var length: float = 13400.0
@export var show_enemy_previews: bool = true
@export var show_trajectories: bool = true
@export_range(1.0, 20.0, 0.5) var preview_seconds: float = 9.0
@export_range(0.05, 0.5, 0.05) var preview_step: float = 0.1
var redraw_left: float = 0.0

func _ready() -> void:
	set_process(Engine.is_editor_hint())

func _process(delta: float) -> void:
	redraw_left -= delta
	if redraw_left <= 0.0:
		redraw_left = 0.2
		queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	_draw_ruler()
	var simulation := get_parent()
	if simulation == null:
		return
	var sequence := simulation.get_node_or_null("WaveSequence")
	if sequence != null:
		for child in sequence.get_children():
			if child is EnemyWave:
				_draw_group(child as EnemyWave)
		_draw_boss(sequence)
	var placed := simulation.get_node_or_null("PlacedEnemies")
	if placed != null:
		for child in placed.get_children():
			if child is Node2D and child.get_node_or_null("Movement") != null:
				_draw_placed(child as Node2D)

func _draw_ruler() -> void:
	var area := Rect2(48.0, 100.0, length, 864.0)
	draw_rect(area, Color(0.24, 0.62, 0.74, 0.5), false, 3.0)
	for index in ceili(length / 1440.0):
		var x := area.position.x + index * 1440.0
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color(0.24, 0.62, 0.74, 0.2), 2.0)

func _draw_group(wave: EnemyWave) -> void:
	if wave.enemy_scene == null:
		return
	var enemy := wave.enemy_scene.instantiate() as Node2D
	if enemy == null:
		return
	var movement := enemy.get_node_or_null("Movement")
	var route := wave.get_node_or_null("Path2D") as Path2D
	var color := _enemy_color(enemy)
	for index in wave.count:
		var offset := wave.spawn_offset * index
		var start := wave.global_position + offset
		if route != null and route.curve != null:
			start = route.to_global(route.curve.sample_baked(0.0)) + offset
		if show_trajectories:
			var points := _path_points(route, offset) if route != null and route.curve != null else _movement_points(movement, start)
			_draw_trajectory(points, color, index == 0)
		if show_enemy_previews:
			_draw_enemy_visual(enemy, start)
			if index == 0:
				_draw_label(start, wave.enemy_scene.resource_path.get_file().get_basename(), color)
	enemy.free()

func _draw_placed(enemy: Node2D) -> void:
	var color := _enemy_color(enemy)
	if show_trajectories:
		_draw_trajectory(_movement_points(enemy.get_node("Movement"), enemy.global_position), color, true)
	if show_enemy_previews:
		_draw_label(enemy.global_position, enemy.name, color)

func _draw_boss(sequence: Node) -> void:
	var marker := sequence.get_node_or_null("BossMarker") as Marker2D
	var scene: PackedScene = sequence.get("boss_scene")
	if marker == null or scene == null:
		return
	var enemy := scene.instantiate() as Node2D
	if enemy == null:
		return
	var color := _enemy_color(enemy)
	if show_trajectories:
		_draw_trajectory(_movement_points(enemy.get_node_or_null("Movement"), marker.global_position), color, true)
	if show_enemy_previews:
		_draw_enemy_visual(enemy, marker.global_position)
		_draw_label(marker.global_position, "BOSS", color)
	enemy.free()

func _path_points(route: Path2D, offset: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var path_length := route.curve.get_baked_length()
	var steps := maxi(1, ceili(path_length / 32.0))
	for index in steps + 1:
		var distance := path_length * float(index) / float(steps)
		points.append(to_local(route.to_global(route.curve.sample_baked(distance)) + offset))
	return points

func _movement_points(movement: Node, start: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	if movement == null:
		return points
	var mode_value: Variant = movement.get("mode")
	if mode_value == null:
		return points
	var mode: int = mode_value
	var speed: float = movement.get("speed")
	var direction: Vector2 = movement.get("direction")
	direction = direction.normalized()
	var steps := maxi(1, ceili(preview_seconds / preview_step))
	var position := start
	var hold_position: Vector2 = movement.get("hold_position")
	hold_position.x += _activation_progress(start.x)
	var hold_seconds: float = movement.get("hold_seconds")
	var stay_forever: bool = movement.get("stay_forever")
	var exit_direction: Vector2 = movement.get("exit_direction")
	var amplitude: float = movement.get("amplitude")
	var frequency: float = movement.get("frequency")
	var reached_hold := false
	var held := 0.0
	for index in steps + 1:
		var age := float(index) * preview_step
		match mode:
			EnemyMovement.Mode.LINEAR:
				position = start + direction * speed * age
			EnemyMovement.Mode.SINE:
				position = start + direction * speed * age + direction.orthogonal() * sin(age * TAU * frequency) * amplitude
			EnemyMovement.Mode.ENTER_HOLD_EXIT:
				if index > 0:
					if not reached_hold:
						position = position.move_toward(hold_position, speed * preview_step)
						reached_hold = position.is_equal_approx(hold_position)
					elif not stay_forever:
						held += preview_step
						if held >= hold_seconds:
							position += exit_direction.normalized() * speed * preview_step
			EnemyMovement.Mode.PATH:
				return points
		points.append(to_local(position))
		if mode == EnemyMovement.Mode.ENTER_HOLD_EXIT and stay_forever and reached_hold:
			break
	return points

func _activation_progress(spawn_x: float) -> float:
	var simulation := get_parent()
	var playfield := simulation.get_node_or_null("Playfield") as Control
	var stage := simulation.get_parent()
	var right := playfield.offset_right if playfield != null else 1488.0
	var margin := float(stage.get("activation_margin")) if stage != null else 80.0
	return maxf(0.0, spawn_x - right - margin)

func _draw_trajectory(points: PackedVector2Array, color: Color, primary: bool) -> void:
	if points.size() < 2:
		return
	var line_color := Color(color, 0.55 if primary else 0.25)
	draw_polyline(points, line_color, 4.0, true)
	if primary:
		for fraction in [0.33, 0.66, 1.0]:
			var index := mini(points.size() - 1, maxi(1, roundi((points.size() - 1) * fraction)))
			var forward := (points[index] - points[index - 1]).normalized()
			if forward != Vector2.ZERO:
				var wing := forward.orthogonal() * 8.0
				draw_line(points[index] - forward * 18.0 + wing, points[index], line_color, 2.0)
				draw_line(points[index] - forward * 18.0 - wing, points[index], line_color, 2.0)

func _enemy_color(enemy: Node2D) -> Color:
	var visual := enemy.get_node_or_null("Visual") as Polygon2D
	if visual != null:
		return visual.color
	var sprite := enemy.get_node_or_null("Visual") as Sprite2D
	return sprite.modulate if sprite != null else Color(0.7, 0.85, 0.9)

func _draw_enemy_visual(enemy: Node2D, start: Vector2) -> void:
	for name in ["Visual", "Core"]:
		var polygon := enemy.get_node_or_null(name) as Polygon2D
		if polygon != null:
			var points := PackedVector2Array()
			for point in polygon.polygon:
				points.append(to_local(start + polygon.transform * point))
			if points.size() >= 3:
				draw_colored_polygon(points, polygon.color)
	var sprite := enemy.get_node_or_null("Visual") as Sprite2D
	if sprite != null and sprite.texture != null:
		var source := sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, Vector2(sprite.texture.get_size()))
		var columns := maxi(1, sprite.hframes)
		var rows := maxi(1, sprite.vframes)
		var size := source.size / Vector2(columns, rows)
		var frame := clampi(sprite.frame, 0, columns * rows - 1)
		source = Rect2(source.position + Vector2(frame % columns, floori(float(frame) / float(columns))) * size, size)
		var top_left := -size * 0.5 if sprite.centered else Vector2.ZERO
		draw_set_transform(to_local(start) + sprite.position + sprite.offset, sprite.rotation, sprite.scale)
		draw_texture_rect_region(sprite.texture, Rect2(top_left, size), source, sprite.modulate)
		draw_set_transform(Vector2.ZERO)

func _draw_label(start: Vector2, label: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, to_local(start) + Vector2(40, -24), label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, color)
