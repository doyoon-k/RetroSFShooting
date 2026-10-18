class_name GameMusic
extends Node
## Persistent BGM with two voices for screen changes and non-looping source tracks.

signal track_changed(cue: StringName)
signal track_looped(cue: StringName)

@export_group("Approved Tracks")
@export var title_track: AudioStream
@export var select_track: AudioStream
@export var stage_track: AudioStream
@export var boss_track: AudioStream
@export var clear_track: AudioStream
@export var ending_track: AudioStream
@export var somber_ending_track: AudioStream
@export_group("Playback")
@export_range(-40.0, 0.0, 0.5) var volume_db: float = -18.0
@export_range(0.0, 3.0, 0.1) var crossfade_seconds: float = 0.5
@export_range(0.05, 3.0, 0.05) var loop_crossfade_seconds: float = 1.0
## Authored seamless tracks use native sample looping to preserve their rhythm.
@export var native_loop_cues: Array[StringName] = [&"select"]
## Optional end positions exclude near-silent tails from the loop transition.
@export var loop_end_seconds: Dictionary = {}
@export var somber_ending_ids: Array[StringName] = [&"extinction", &"last_signal", &"betrayal"]

var current_cue: StringName
var music_paused: bool = false
var active_index: int = 0
var fade_remaining: float = 0.0
var _fade_duration: float = 0.0
var _outgoing_gain: float = 0.0
var _stream_cache: Dictionary = {}
var _source_ids: Dictionary = {}
@onready var channels: Array[AudioStreamPlayer] = [$ChannelA, $ChannelB]

static func instance() -> GameMusic:
	var tree := Engine.get_main_loop() as SceneTree
	var music := tree.root.get_node_or_null("Music") as GameMusic
	if music == null:
		music = (load("res://scenes/audio/game_music.tscn") as PackedScene).instantiate() as GameMusic
		tree.root.add_child(music)
	return music

static func play(cue: StringName) -> void:
	instance()._request(cue)

static func set_paused(value: bool) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var music := tree.root.get_node_or_null("Music") as GameMusic
	if music != null:
		music._set_paused(value)

static func stop() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var music := tree.root.get_node_or_null("Music") as GameMusic
	if music != null:
		music._stop()

static func ending_cue(id: StringName) -> StringName:
	return &"somber_ending" if instance().somber_ending_ids.has(id) else &"ending"

func active_player() -> AudioStreamPlayer:
	return channels[active_index]

func _source_for(cue: StringName) -> AudioStream:
	match cue:
		&"title": return title_track
		&"select": return select_track
		&"stage": return stage_track
		&"boss": return boss_track
		&"clear": return clear_track
		&"ending": return ending_track
		&"somber_ending": return somber_ending_track
	return null

func loop_end(cue: StringName) -> float:
	var source := _source_for(cue)
	if source == null:
		return 0.0
	return clampf(float(loop_end_seconds.get(cue, source.get_length())), 0.1, source.get_length())

func _playback_stream(cue: StringName) -> AudioStream:
	var source := _source_for(cue)
	if source == null:
		return null
	if _source_ids.get(cue, 0) != source.get_instance_id():
		var copy := source.duplicate() as AudioStream
		if copy is AudioStreamWAV:
			copy.loop_mode = AudioStreamWAV.LOOP_FORWARD if native_loop_cues.has(cue) else AudioStreamWAV.LOOP_DISABLED
			copy.loop_begin = 0
			copy.loop_end = maxi(1, roundi(loop_end(cue) * copy.mix_rate) - 1)
		_stream_cache[cue] = copy
		_source_ids[cue] = source.get_instance_id()
	return _stream_cache[cue]

func _request(cue: StringName) -> void:
	_set_paused(false)
	if cue == current_cue and active_player().playing:
		return
	if _source_for(cue) == null:
		_stop()
		return
	_begin(cue, crossfade_seconds)

func _begin(cue: StringName, duration: float, looping: bool = false) -> void:
	var outgoing := active_player()
	var incoming_index := 1 - active_index
	var incoming := channels[incoming_index]
	var changed := cue != current_cue
	incoming.stop()
	incoming.stream = _playback_stream(cue)
	incoming.stream_paused = false
	incoming.volume_db = -80.0
	_outgoing_gain = db_to_linear(outgoing.volume_db) if outgoing.playing else 0.0
	active_index = incoming_index
	current_cue = cue
	_fade_duration = maxf(0.0, duration)
	fade_remaining = _fade_duration
	incoming.play()
	if _fade_duration <= 0.0:
		outgoing.stop()
		outgoing.stream = null
		incoming.volume_db = volume_db
	if changed:
		track_changed.emit(cue)
	elif looping:
		track_looped.emit(cue)

func _process(delta: float) -> void:
	if current_cue == &"" or music_paused:
		return
	var incoming := active_player()
	if fade_remaining > 0.0:
		fade_remaining = maxf(0.0, fade_remaining - delta)
		var progress := 1.0 - fade_remaining / _fade_duration
		var outgoing := channels[1 - active_index]
		incoming.volume_db = linear_to_db(maxf(0.0001, db_to_linear(volume_db) * sqrt(progress)))
		outgoing.volume_db = linear_to_db(maxf(0.0001, _outgoing_gain * sqrt(1.0 - progress)))
		if fade_remaining <= 0.0:
			outgoing.stop()
			outgoing.stream = null
	else:
		incoming.volume_db = volume_db
	if not incoming.playing:
		_begin(current_cue, 0.0, true)
		return
	if fade_remaining > 0.0 or native_loop_cues.has(current_cue):
		return
	var end := loop_end(current_cue)
	var overlap := minf(loop_crossfade_seconds, end * 0.25)
	if incoming.get_playback_position() >= end - overlap:
		_begin(current_cue, overlap, true)

func _set_paused(value: bool) -> void:
	music_paused = value
	for player in channels:
		player.stream_paused = value

func _stop() -> void:
	current_cue = &""
	fade_remaining = 0.0
	music_paused = false
	for player in channels:
		player.stop()
		player.stream = null
		player.stream_paused = false
