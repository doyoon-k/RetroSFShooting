extends Control

signal sortie_requested(pilot_id: StringName)
@export var catalog: GameCatalog
var run: RunState
var selected: StringName
var confirmed: bool = false
var slots: Array[HangarPilot] = []

const DESIGN_SIZE := Vector2(1920, 1080)

func _ready() -> void:
	if run == null:
		run = RunState.new(catalog)
	for child in %Hangar.get_children():
		if child is HangarPilot:
			var index := slots.size()
			child.pilot = catalog.pilots[index] if index < catalog.pilots.size() else null
			slots.append(child)
			if child.pilot != null:
				child.focus_entered.connect(_focus_pilot.bind(child.pilot.id))
				child.pressed.connect(_open_pilot.bind(child.pilot.id))
				child.pilot.changed.connect(_refresh_details)
	%MoveLeft.pressed.connect(_move_selection.bind(-1))
	%MoveRight.pressed.connect(_move_selection.bind(1))
	%CloseDetails.pressed.connect(_close_details)
	%Sortie.pressed.connect(_sortie)
	run.roster_changed.connect(_refresh_roster)
	resized.connect(_fit_layout)
	_fit_layout()
	_refresh_roster()
	_focus_selected_slot()
	for slot in slots:
		SoundEffects.bind_navigation(slot)
	for button in [%MoveLeft, %MoveRight, %CloseDetails, %Sortie]:
		SoundEffects.bind_navigation(button)

func _fit_layout() -> void:
	var ratio := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	%Layout.scale = Vector2.ONE * ratio
	%Layout.position = (size - DESIGN_SIZE * ratio) * 0.5

func _refresh_roster() -> void:
	for slot in slots:
		slot.visible = slot.pilot != null
		if slot.pilot == null:
			continue
		var alive := run.is_alive(slot.pilot.id)
		slot.disabled = confirmed or not alive
		slot.focus_mode = Control.FOCUS_ALL if not slot.disabled else Control.FOCUS_NONE
		slot.modulate = Color.WHITE if alive else Color(0.28, 0.28, 0.28)
	selected = run.automatic_choice(selected)
	%MoveLeft.disabled = confirmed or run.survivors().size() < 2
	%MoveRight.disabled = %MoveLeft.disabled
	%Sortie.disabled = confirmed or selected == &""
	%CloseDetails.disabled = confirmed
	%SelectionMarker.visible = selected != &""
	if selected == &"":
		%Details.hide()
	_refresh_selection()

func _focus_pilot(id: StringName) -> void:
	if confirmed or not run.is_alive(id) or selected == id:
		return
	selected = id
	_refresh_selection()

func _refresh_selection() -> void:
	for slot in slots:
		if slot.pilot != null and slot.pilot.id == selected:
			%SelectionMarker.position.x = %Hangar.position.x + (slot.position.x + slot.size.x * 0.5) * %Hangar.scale.x - %SelectionMarker.size.x * 0.5
			%SelectionMarker.position.y = %Hangar.position.y - %SelectionMarker.size.y
			break
	_refresh_details()

func _focus_selected_slot() -> void:
	for slot in slots:
		if slot.pilot != null and slot.pilot.id == selected and not slot.disabled:
			slot.grab_focus()
			return

func _move_selection(direction: int) -> void:
	if confirmed or selected == &"":
		return
	var current := 0
	for index in slots.size():
		if slots[index].pilot != null and slots[index].pilot.id == selected:
			current = index
			break
	for step in range(1, slots.size() + 1):
		var slot := slots[posmod(current + direction * step, slots.size())]
		if slot.pilot != null and run.is_alive(slot.pilot.id):
			_focus_pilot(slot.pilot.id)
			_focus_selected_slot()
			return

func _refresh_details() -> void:
	var pilot := catalog.pilot_by_id(selected)
	if pilot == null:
		return
	%Portrait.texture = pilot.hangar_portrait if pilot.hangar_portrait != null else pilot.normal
	%PilotName.text = pilot.display_name if pilot.display_name == pilot.callsign else pilot.display_name + " / " + pilot.callsign
	if %Details.visible:
		%Description.reveal(pilot.description)
	%Sortie.tooltip_text = "%s 출격 (Enter / A)" % pilot.display_name

func _open_pilot(id: StringName) -> void:
	if confirmed or not run.is_alive(id):
		return
	_focus_pilot(id)
	%Details.show()
	_refresh_details()
	%Sortie.grab_focus()
	SoundEffects.play(&"ui_confirm")

func _close_details() -> void:
	if confirmed or not %Details.visible:
		return
	SoundEffects.play(&"ui_cancel")
	%Details.hide()
	_focus_selected_slot()

func _sortie() -> void:
	if confirmed or not %Details.visible or not run.is_alive(selected):
		return
	confirmed = true
	SoundEffects.play(&"ui_confirm")
	_refresh_roster()
	sortie_requested.emit(selected)

func _input(event: InputEvent) -> void:
	if confirmed:
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_move_selection(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_move_selection(1)
	elif event.is_action_pressed("ui_accept"):
		if not %Details.visible:
			_open_pilot(selected)
		elif %CloseDetails.has_focus():
			_close_details()
		else:
			_sortie()
	elif event.is_action_pressed("ui_cancel") and %Details.visible:
		_close_details()
	else:
		return
	get_viewport().set_input_as_handled()
