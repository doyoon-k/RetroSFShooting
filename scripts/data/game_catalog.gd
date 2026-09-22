class_name GameCatalog
extends Resource
## The editable content manifest used by Main and the stage preview.

@export var rules: GameRules
@export var pilots: Array[PilotData] = []
@export var intro: StoryData
@export var endings: Array[EndingData] = []

func pilot_by_id(id: StringName) -> PilotData:
	for pilot in pilots:
		if pilot.id == id:
			return pilot
	return null

func ending_by_id(id: StringName) -> EndingData:
	for ending in endings:
		if ending.id == id:
			return ending
	return null

