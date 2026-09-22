class_name EndingResolver
extends RefCounted

static func resolve(run: RunState) -> StringName:
	var living := run.survivors()
	if living.is_empty():
		return &"extinction"
	if not run.boss_cleared:
		return &""
	match living.size():
		1: return &"last_signal"
		2:
			for pilot in living:
				if pilot.is_ai:
					return &"betrayal"
			return &"unknown_horizon"
		3: return &"unknown_horizon"
		4, 5: return &"cost_of_dawn"
		_: return &"new_home"

