class_name WaveSequence
extends Node2D

signal enemy_requested(wave: EnemyWave, index: int)
signal boss_requested

@export_range(5.0, 1200.0, 1.0) var boss_time: float = 65.0
@export var boss_scene: PackedScene
var elapsed: float = 0.0
var boss_sent: bool = false

func _physics_process(delta: float) -> void:
	if boss_sent:
		return
	elapsed += delta
	for child in get_children():
		if child is EnemyWave:
			child.advance(elapsed, _request_enemy)
	if elapsed >= boss_time:
		boss_sent = true
		boss_requested.emit()

func _request_enemy(wave: EnemyWave, index: int) -> void:
	enemy_requested.emit(wave, index)

