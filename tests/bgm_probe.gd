extends SceneTree
## Approved BGM through the real screen, combat, pause and ending transitions.

var failures: Array[String] = []
var checks: int = 0
var loops: Array[StringName] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func frames(count: int = 2) -> void:
	for index in count:
		await process_frame

func playback_id(music: GameMusic) -> int:
	var playback := music.active_player().get_stream_playback()
	return playback.get_instance_id() if playback != null else 0

func playing_count(music: GameMusic) -> int:
	var count := 0
	for player in music.channels:
		if player.playing:
			count += 1
	return count

func replace_pilot(stage: StageController, music: GameMusic, cue: StringName) -> void:
	var before := playback_id(music)
	stage._enter(StageController.Phase.PLAYING)
	stage.run.current_sortie.hp = 1
	stage.run.current_sortie.shield = false
	stage.player.invincibility = 0.0
	stage.player.take_damage(1)
	await frames()
	check(stage.phase == StageController.Phase.PLAYER_DYING, "A real hit starts the death presentation: " + cue)
	check(music.current_cue == cue and not music.active_player().stream_paused, "Music continues through the paused death presentation: " + cue)
	stage._finish_death()
	check(stage.phase == StageController.Phase.SELECTING_NEXT and music.current_cue == cue, "Replacement selection preserves the combat cue: " + cue)
	stage.select_next(stage.run.automatic_choice(stage.run.current_pilot_id))
	stage.player.set_physics_process(false)
	stage.player.weapon.set_physics_process(false)
	check(stage.phase == StageController.Phase.LAUNCHING and playback_id(music) == before, "Re-sortie preserves the exact playback instance: " + cue)

func _run() -> void:
	var music := GameMusic.instance()
	music.track_looped.connect(func(cue: StringName): loops.append(cue))
	var expected := {
		&"title": "TheSpaceIsFullOf$tars.wav",
		&"select": "CaptChipPants.wav",
		&"stage": "FightForYourLives.wav",
		&"boss": "Decisive Battle (wav).wav",
		&"clear": "VictoryAtLast.wav",
		&"ending": "YetAnotherJourney.wav",
		&"somber_ending": "Lilith's Elegy (wav).wav",
	}
	for cue in expected:
		var source := music._source_for(cue)
		check(source != null and source.resource_path.ends_with(expected[cue]), "Approved BGM source: " + cue)
	check(music.process_mode == Node.PROCESS_MODE_ALWAYS, "Screen and combat presentation pauses do not stop BGM processing")

	var main = load("res://scenes/main/main.tscn").instantiate()
	var save_path := "user://test_bgm_%d.cfg" % OS.get_process_id()
	(main.get_node("SaveStore") as SaveStore).save_path = save_path
	root.add_child(main)
	check(music.current_cue == &"title" and music.active_player().playing, "The actual title starts title BGM")
	var before := playback_id(music)
	main.start_new_game()
	check(music.current_cue == &"title" and playback_id(music) == before, "The intro continues title BGM without restarting it")
	var original_loop := (music.select_track as AudioStreamWAV).loop_mode
	main.show_select()
	check(music.current_cue == &"select" and music.active_player().playing, "Pilot selection starts Capt Chip Pants")
	music._process(music.crossfade_seconds + 0.01)
	check(playing_count(music) == 1, "Only the selected voice remains after the screen crossfade")
	check((music.active_player().stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "The seamless selection track uses native sample looping")
	check(music.active_player().stream != music.select_track and (music.select_track as AudioStreamWAV).loop_mode == original_loop, "Playback loop settings do not modify the original resource")

	main.start_stage(main.catalog.pilots[0].id)
	var stage := main.current_screen as StageController
	stage.set_process(false)
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	stage.player.weapon.set_physics_process(false)
	check(music.current_cue == &"stage" and paused and not music.active_player().stream_paused, "Launch starts Fight For Your Lives during the paused presentation")
	stage._enter(StageController.Phase.PLAYING)
	before = playback_id(music)
	var remaining := music.fade_remaining
	stage.toggle_pause()
	check(music.music_paused and music.channels[0].stream_paused and music.channels[1].stream_paused, "Manual pause suspends both crossfade voices")
	music._process(1.0)
	check(is_equal_approx(music.fade_remaining, remaining), "Manual pause also suspends the fade")
	stage.toggle_pause()
	check(not music.music_paused and playback_id(music) == before, "Resume continues the same playback instance")
	await replace_pilot(stage, music, &"stage")
	stage._enter(StageController.Phase.PLAYING)
	stage._begin_boss_intro()
	check(music.current_cue == &"boss" and paused and music.active_player().playing, "Final boss introduction starts Decisive Battle")
	await replace_pilot(stage, music, &"boss")
	stage._enter(StageController.Phase.PLAYING)
	stage.boss.take_damage(stage.boss.maximum_hp + 1)
	await frames()
	check(stage.phase == StageController.Phase.CLEARING and music.current_cue == &"clear", "Defeating the boss switches to Victory At Last")

	var ai: PilotData
	var human: PilotData
	for pilot in main.catalog.pilots:
		if pilot.is_ai:
			ai = pilot
		else:
			human = pilot
	var branches := {
		&"extinction": [],
		&"last_signal": [human],
		&"betrayal": [human, ai],
		&"unknown_horizon": main.catalog.pilots.slice(0, 3),
		&"cost_of_dawn": main.catalog.pilots.slice(0, 5),
		&"new_home": main.catalog.pilots,
	}
	for id in branches:
		var fixture := RunState.new(main.catalog)
		fixture.boss_cleared = id != &"extinction"
		for pilot in main.catalog.pilots:
			if not branches[id].has(pilot):
				fixture.mark_dead(pilot.id)
		main.run = fixture
		main.show_ending()
		var expected_cue := &"somber_ending" if id in [&"extinction", &"last_signal", &"betrayal"] else &"ending"
		check(fixture.ending_id == id and music.current_cue == expected_cue, "Real ending resolution chooses its approved music: " + id)
		before = playback_id(music)
		main.show_result()
		var result_cue := &"somber_ending" if expected_cue == &"somber_ending" else &"clear"
		check(music.current_cue == result_cue, "Result music matches the outcome: " + id)
		if expected_cue == &"somber_ending":
			check(playback_id(music) == before, "A somber result continues its ending track: " + id)
	main.show_title()
	check(music.current_cue == &"title", "Returning from results restores title BGM")
	main.queue_free()
	await frames()
	DirAccess.remove_absolute(save_path)

	GameMusic.play(&"select")
	GameMusic.play(&"boss")
	GameMusic.play(&"stage")
	music._process(music.crossfade_seconds + 0.01)
	check(music.current_cue == &"stage" and playing_count(music) == 1, "Rapid screen changes settle on the latest request with one active voice")
	before = playback_id(music)
	GameMusic.play(&"stage")
	check(playback_id(music) == before, "Repeated requests for the same cue do not restart it")
	check((music.active_player().stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED, "Full-length stage music uses a crossfade rather than an abrupt native loop")
	music.active_player().seek(music.loop_end(&"stage") - 0.02)
	var deadline := Time.get_ticks_msec() + 2000
	while loops.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(loops == [&"stage"] and playing_count(music) >= 1, "Reaching the end of a full track starts its loop transition")
	music._process(music.loop_crossfade_seconds + 0.01)
	check(playing_count(music) == 1 and music.current_cue == &"stage", "The loop crossfade releases the outgoing voice")
	music.active_player().stop()
	music._process(0.0)
	check(music.active_player().playing and music.current_cue == &"stage", "An unexpectedly ended stream restarts the current cue")
	GameMusic.stop()
	check(music.current_cue == &"" and playing_count(music) == 0, "Stopping clears both playback voices")
	await SoundEffects.shutdown()
	print("BGM: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
