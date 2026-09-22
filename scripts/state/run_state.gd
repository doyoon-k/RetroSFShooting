class_name RunState
extends RefCounted

signal roster_changed

var catalog: GameCatalog
var current_pilot_id: StringName
var dead_pilot_ids: Array[StringName] = []
var current_sortie: SortieState
var boss_cleared: bool = false
var ending_id: StringName

func _init(content: GameCatalog = null) -> void:
	catalog = content

func survivors() -> Array[PilotData]:
	var result: Array[PilotData] = []
	for pilot in catalog.pilots:
		if is_alive(pilot.id):
			result.append(pilot)
	return result

func is_alive(id: StringName) -> bool:
	return catalog.pilot_by_id(id) != null and not dead_pilot_ids.has(id)

func begin_sortie(id: StringName) -> bool:
	if not is_alive(id):
		return false
	current_pilot_id = id
	current_sortie = SortieState.new(catalog.rules)
	roster_changed.emit()
	return true

func mark_dead(id: StringName) -> void:
	if is_alive(id):
		dead_pilot_ids.append(id)
		roster_changed.emit()

func automatic_choice(preferred: StringName) -> StringName:
	if is_alive(preferred):
		return preferred
	var living := survivors()
	return living[0].id if not living.is_empty() else &""

