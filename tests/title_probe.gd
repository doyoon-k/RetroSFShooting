extends SceneTree
## godot --headless --path . --script tests/title_probe.gd
## Append -- --screenshots with a rendering driver, or -- --exit-test to exercise EXIT.

var checks: int = 0
var failures: Array[String] = []
var screenshots: bool = false

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func frames(count: int = 3) -> void:
	for index in count:
		await process_frame

func capture(name: String) -> void:
	if screenshots and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://build/screenshots")
		root.get_texture().get_image().save_png("res://build/screenshots/" + name + ".png")

func key_event(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	root.push_input(event)

func key(code: Key) -> void:
	key_event(code, true)
	key_event(code, false)

func gamepad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform() * (control.get_global_transform_with_canvas() * (control.size * 0.5))
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func _run() -> void:
	screenshots = OS.get_cmdline_user_args().has("--screenshots")
	var content := load("res://data/game_catalog.tres") as GameCatalog
	var scene := load("res://scenes/title/title.tscn") as PackedScene
	if OS.get_cmdline_user_args().has("--exit-test"):
		var screen := scene.instantiate() as Control
		root.add_child(screen)
		await frames()
		click(screen.get_node("%Exit"))
		check(screen.get_node("%Menu").visible, "A first click over EXIT only reveals the menu")
		if not failures.is_empty():
			quit(1)
			return
		print("TITLE EXIT: first click reveals the menu; second click exits")
		click(screen.get_node("%Exit"))
		var deadline := Time.get_ticks_msec() + 1000
		while Time.get_ticks_msec() < deadline:
			await process_frame
		push_error("EXIT did not terminate the application")
		quit(1)
		return

	for mode in range(3):
		var screen := scene.instantiate() as Control
		screen.unlocked.append(content.endings[0].id)
		var launches := [0]
		screen.new_game_requested.connect(func(): launches[0] += 1)
		root.add_child(screen)
		await frames()
		var menu := screen.get_node("%Menu") as Control
		var prompt := screen.get_node("%StartPrompt") as TextureRect
		var collection := screen.get_node("%Collection") as Control
		check(prompt.visible and not menu.visible and not collection.visible, "Every fresh Title starts at the prompt")
		check(prompt.texture.resource_path == "res://assets/Pilots_sprites/UI/Press Any key.png", "Start prompt uses the supplied PRESS ANY BUTTON sprite")
		var motion := InputEventMouseMotion.new()
		root.push_input(motion)
		var stick := InputEventJoypadMotion.new()
		stick.axis = JOY_AXIS_LEFT_X
		stick.axis_value = 0.8
		root.push_input(stick)
		key(KEY_CTRL)
		check(not menu.visible, "Mouse movement, stick movement and modifiers do not dismiss the prompt")
		if mode == 0:
			await capture("title_waiting")
			var crew := screen.get_node("%Portraits") as Sprite2D
			var ship := screen.get_node("%Ship") as Control
			var original_y := ship.position.y
			var seen := {}
			for index in range(120):
				await frames(1)
				var artwork := crew.texture
				if not seen.has(artwork.resource_path):
					seen[artwork.resource_path] = true
					if artwork.resource_path.ends_with("TitleBG2.png"):
						await capture("title_crew_flash")
					elif artwork.resource_path.ends_with("TitleBG3.png"):
						await capture("title_crew_skull")
			check(seen.size() == 3, "The reference animation plays normal, flash and skull artwork")
			check(not is_equal_approx(ship.position.y, original_y) and absf(ship.position.y - screen.ship_origin.y) <= screen.ship_float_pixels, "The ship floats within its authored range")
			key_event(KEY_ENTER, true)
			key_event(KEY_ENTER, true, true)
			key_event(KEY_ENTER, false)
		elif mode == 1:
			click(screen.get_node("%NewGame"))
		else:
			gamepad(JOY_BUTTON_A)
		check(menu.visible and not prompt.visible and launches[0] == 0, "First keyboard, mouse or gamepad input opens only the menu")
		check(screen.get_node("%NewGame").has_focus(), "Opening the menu focuses NEW GAME")
		if mode == 0:
			await capture("title_menu")
			key(KEY_S)
			check(screen.get_node("%Endings").has_focus(), "WASD moves menu focus")
			key(KEY_ENTER)
		elif mode == 1:
			click(screen.get_node("%Endings"))
		else:
			gamepad(JOY_BUTTON_DPAD_DOWN)
			check(screen.get_node("%Endings").has_focus(), "D-pad moves menu focus")
			gamepad(JOY_BUTTON_A)
		check(collection.visible and not menu.visible and not prompt.visible, "ENDINGS opens the archive from all three input methods")
		await frames()
		var archive_text: String = screen.get_node("%CollectionText").text
		check(archive_text.contains(content.endings[0].title) and archive_text.contains("???") and archive_text.contains("1 / 6"), "Archive distinguishes unlocked endings and hidden endings")
		var archive_label := screen.get_node("%CollectionText") as Label
		var back_button := screen.get_node("%CollectionBack") as Button
		check(archive_label.get_global_rect().end.y < back_button.get_global_rect().position.y, "All six archive entries fit above BACK")
		if mode == 0:
			await capture("title_archive")
			key(KEY_ESCAPE)
		elif mode == 1:
			click(screen.get_node("%CollectionBack"))
		else:
			gamepad(JOY_BUTTON_B)
		check(menu.visible and not collection.visible and not prompt.visible and screen.get_node("%Endings").has_focus(), "BACK, Escape and B return to the menu with ENDINGS focused")
		if mode == 0:
			key(KEY_W)
			key(KEY_ENTER)
		elif mode == 1:
			screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			screen.size = Vector2(1600, 1000)
			await frames()
			var layout := screen.get_node("%Layout") as Control
			check(layout.scale.is_equal_approx(Vector2.ONE * (1600.0 / 1920.0)) and is_equal_approx(layout.position.y, 50.0), "A taller viewport preserves and centers the reference layout")
			click(screen.get_node("%NewGame"))
		else:
			gamepad(JOY_BUTTON_DPAD_UP)
			gamepad(JOY_BUTTON_A)
		check(launches[0] == 1, "A separate confirmation starts New Game through keyboard, mouse or gamepad")
		key(KEY_ENTER)
		click(screen.get_node("%NewGame"))
		check(launches[0] == 1, "Repeated confirmation cannot emit a duplicate New Game request")
		screen.queue_free()
		await frames()

	GameMusic.stop()
	await SoundEffects.shutdown()
	print("TITLE: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
