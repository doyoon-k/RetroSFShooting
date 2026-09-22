class_name PilotRoster
extends GridContainer

signal pilot_focused(id: StringName)
signal pilot_selected(id: StringName)
@export var portrait_scene: PackedScene
var catalog: GameCatalog
var run: RunState
var selectable: bool = false
var expression_override: StringName
var highlighted_id: StringName
var cards: Array[PilotPortrait] = []

func configure(content: GameCatalog, run_state: RunState) -> void:
	catalog = content
	run = run_state
	if not run.roster_changed.is_connected(refresh):
		run.roster_changed.connect(refresh)
	if is_node_ready():
		_build()

func _ready() -> void:
	if catalog != null:
		_build()

func _build() -> void:
	if not cards.is_empty():
		refresh()
		return
	for pilot in catalog.pilots:
		var card := portrait_scene.instantiate() as PilotPortrait
		add_child(card)
		cards.append(card)
		card.focus_entered.connect(_focus.bind(pilot.id))
		card.mouse_entered.connect(_focus.bind(pilot.id))
		card.pressed.connect(_select.bind(pilot.id))
	refresh()

func refresh() -> void:
	if run == null:
		return
	var emotion := &"normal"
	match run.survivors().size():
		4, 5: emotion = &"anxious"
		3: emotion = &"angry"
		2: emotion = &"despair"
		1: emotion = &"alone"
	if expression_override != &"":
		emotion = expression_override
	for i in cards.size():
		var pilot := catalog.pilots[i]
		var alive := run.is_alive(pilot.id)
		cards[i].display(pilot, emotion if alive else &"dead", pilot.id == run.current_pilot_id and alive, alive)
		cards[i].disabled = not selectable or not alive
		cards[i].focus_mode = Control.FOCUS_ALL if selectable and alive else Control.FOCUS_NONE
		cards[i].modulate = Color.WHITE if highlighted_id == pilot.id or not selectable else Color(0.8, 0.85, 0.9)

func focus_first() -> void:
	var id := run.automatic_choice(highlighted_id)
	for card in cards:
		if card.pilot.id == id:
			card.grab_focus()
			_focus(id)
			return

func _focus(id: StringName) -> void:
	if not selectable or not run.is_alive(id):
		return
	highlighted_id = id
	refresh()
	pilot_focused.emit(id)

func _select(id: StringName) -> void:
	if selectable and run.is_alive(id):
		_focus(id)
		pilot_selected.emit(id)

