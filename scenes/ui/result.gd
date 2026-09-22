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
	%Heading.text = ending.number + " / " + ending.title
	%Survivors.text = "SURVIVORS  %d / %d" % [run.survivors().size(), run.catalog.pilots.size()]
	%Roster.configure(run.catalog, run)
	%Roster.expression_override = &"victory"
	%Roster.refresh()
	%SaveStatus.text = "엔딩 기록이 저장되었습니다." if save_error == OK else "엔딩 기록 저장에 실패했습니다. 기존 저장 파일은 보존됩니다."
	%Return.pressed.connect(func(): return_requested.emit())
	%Return.grab_focus()
