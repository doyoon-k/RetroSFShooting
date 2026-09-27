extends Sprite2D

@export_range(-2.0, 2.0, 0.05) var angular_speed: float = 0.45

func _process(delta: float) -> void:
	rotation += angular_speed * delta
