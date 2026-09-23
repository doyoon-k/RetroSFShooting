extends Control

signal sortie_requested(pilot_id: StringName)
@export var catalog: GameCatalog
var run: RunState
var selected: StringName
var confirmed: bool = false

func _ready() -> void:
	if run == null:
		run = RunState.new(catalog)
	%Roster.configure(catalog, run)
	%Roster.pilot_focused.connect(_focus_pilot)
	%Roster.selectable = true
	%Roster.refresh()
	%Sortie.pressed.connect(_sortie)
	%Roster.focus_first()
	for i in catalog.pilots.size():
		var actor := %Hangar.get_child(i)
		actor.get_node("Name").text = catalog.pilots[i].callsign
		var animation := actor.get_node("AnimationPlayer") as AnimationPlayer
		if animation.has_animation(catalog.pilots[i].hangar_animation):
			animation.play(catalog.pilots[i].hangar_animation)

func _focus_pilot(id: StringName) -> void:
	selected = id
	var pilot := catalog.pilot_by_id(id)
	%PilotName.text = pilot.display_name + " / " + pilot.callsign
	%PilotName.modulate = pilot.accent
	%Description.reveal(pilot.description)
	%Sortie.text = "SORTIE  /  %s 출격" % pilot.display_name

func _sortie() -> void:
	if not confirmed and selected != &"":
		confirmed = true
		sortie_requested.emit(selected)
