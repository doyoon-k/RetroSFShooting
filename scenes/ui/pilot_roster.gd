class_name PilotRoster
extends GridContainer

signal pilot_focused(id: StringName)
signal pilot_selected(id: StringName)
@export var portrait_scene: PackedScene
var catalog: GameCatalog
var run: RunState
var selectable: bool = false
var show_survived_status: bool = false
var highlighted_id: StringName
var cards: Array[PilotPortrait] = []
var observed_sortie: SortieState

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
	if observed_sortie != run.current_sortie:
		if observed_sortie != null and observed_sortie.changed.is_connected(refresh):
			observed_sortie.changed.disconnect(refresh)
		observed_sortie = run.current_sortie
		if observed_sortie != null:
			observed_sortie.changed.connect(refresh)
	for i in cards.size():
		var pilot := catalog.pilots[i]
		var alive := _is_display_alive(pilot)
		cards[i].display(pilot, portrait_for(pilot), pilot.id == run.current_pilot_id and alive, alive, show_survived_status)
		cards[i].disabled = not selectable or not alive
		cards[i].focus_mode = Control.FOCUS_ALL if selectable and alive else Control.FOCUS_NONE
		cards[i].modulate = Color.WHITE if highlighted_id == pilot.id or not selectable else Color(0.8, 0.85, 0.9)

func portrait_for(pilot: PilotData) -> Texture2D:
	var dead_count := catalog.pilots.size() - run.survivors().size()
	var current := pilot.id == run.current_pilot_id and run.current_sortie != null
	var damaged := current and run.current_sortie.hp > 0 and run.current_sortie.hp * 2 <= catalog.rules.starting_hp
	return pilot.portrait(dead_count, damaged, not _is_display_alive(pilot))

func _is_display_alive(pilot: PilotData) -> bool:
	return run.is_alive(pilot.id) and not (pilot.id == run.current_pilot_id and run.current_sortie != null and run.current_sortie.hp <= 0)

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
