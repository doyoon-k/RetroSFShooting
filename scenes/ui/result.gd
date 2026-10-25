extends Control

signal return_requested
@export var preview_catalog: GameCatalog
var run: RunState
var ending: EndingData
var save_error: Error = OK

func _ready() -> void:
	if run == null:
		run = RunState.new(preview_catalog)
		run.boss_cleared = true
		ending = preview_catalog.ending_by_id(&"new_home")
	var ending_music := GameMusic.ending_cue(ending.id)
	GameMusic.play(&"clear" if ending_music == &"ending" else ending_music)
	SoundEffects.play(&"result_reveal")
	%Heading.text = ending.number + " / " + ending.title
	%Survivors.text = "SURVIVORS  %d / %d" % [run.survivors().size(), run.catalog.pilots.size()]
	%Roster.configure(run.catalog, run)
	%Roster.show_survived_status = true
	%Roster.refresh()
	%SaveStatus.text = "엔딩 기록이 저장되었습니다." if save_error == OK else "엔딩 기록 저장에 실패했습니다. 기존 저장 파일은 보존됩니다."
	%Return.pressed.connect(_return_to_title)
	%Return.grab_focus()
	SoundEffects.bind_navigation(%Return)

func _return_to_title() -> void:
	SoundEffects.play(&"ui_confirm")
	return_requested.emit()
