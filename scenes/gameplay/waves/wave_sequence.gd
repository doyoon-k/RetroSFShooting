class_name WaveSequence
extends Node2D

signal enemy_requested(wave: EnemyWave, index: int)
signal boss_requested

@export var boss_scene: PackedScene
var boss_sent: bool = false

func advance(activation_x: float) -> void:
	if boss_sent:
		return
	for child in get_children():
		if child is EnemyWave:
			child.advance(activation_x, _request_enemy)
	var marker := get_node_or_null("BossMarker") as Marker2D
	if marker != null and marker.global_position.x <= activation_x:
		boss_sent = true
		boss_requested.emit()

func _request_enemy(wave: EnemyWave, index: int) -> void:
	enemy_requested.emit(wave, index)
