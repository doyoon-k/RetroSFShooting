class_name SaveStore
extends Node

signal save_failed(message: String)

@export var save_path: String = "user://endings.cfg"
var unlocked: Array[StringName] = []
var writable: bool = true

func load_progress() -> Error:
	unlocked.clear()
	var file := ConfigFile.new()
	var error := file.load(save_path)
	writable = error == OK or error == ERR_FILE_NOT_FOUND
	if error == ERR_FILE_NOT_FOUND:
		return OK
	if error != OK:
		save_failed.emit("기록을 읽을 수 없습니다. 기존 파일은 보존됩니다.")
		return error
	if file.get_value("save", "version", 0) != 1:
		writable = false
		save_failed.emit("지원하지 않는 기록 버전입니다. 기존 파일은 보존됩니다.")
		return ERR_INVALID_DATA
	var ids: Variant = file.get_value("save", "endings", [])
	if not ids is Array and not ids is PackedStringArray:
		writable = false
		return ERR_INVALID_DATA
	for id in ids:
		if (id is String or id is StringName) and not unlocked.has(StringName(id)):
			unlocked.append(StringName(id))
	return OK

func unlock(id: StringName) -> Error:
	if id == &"":
		return ERR_INVALID_PARAMETER
	if not unlocked.has(id):
		unlocked.append(id)
	if not writable:
		save_failed.emit("이번 엔딩은 메모리에만 기록되었습니다. 저장 파일을 확인해주세요.")
		return ERR_FILE_CANT_WRITE
	var file := ConfigFile.new()
	file.set_value("save", "version", 1)
	file.set_value("save", "endings", unlocked)
	var temporary := save_path + ".tmp"
	var error := file.save(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(temporary, save_path)
	if error != OK:
		save_failed.emit("엔딩 저장에 실패했습니다. 디스크와 저장 경로를 확인해주세요.")
	return error
