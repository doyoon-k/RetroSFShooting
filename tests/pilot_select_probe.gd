extends SceneTree
## godot --headless --path . --script tests/pilot_select_probe.gd
## Use a rendering driver and append -- --screenshots for the two reference states.

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

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

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
	var scene := load("res://scenes/character_select/character_select.tscn") as PackedScene
	var screen := scene.instantiate() as Control
	root.add_child(screen)
	await frames()
	var details := screen.get_node("Layout/Details") as Control
	var portrait := screen.get_node("Layout/Details/PortraitPanel/Portrait") as TextureRect
	var name_label := screen.get_node("Layout/Details/PilotName") as Label
	var marker := screen.get_node("Layout/SelectionMarker") as TextureRect
	var sorties: Array[StringName] = []
	screen.sortie_requested.connect(func(id: StringName): sorties.append(id))
	check(screen.selected == &"P1" and not details.visible, "Initial state shows P1 and keeps information closed")
	await capture("pilot_select_base")

	key(KEY_LEFT)
	check(screen.selected == &"P6" and not details.visible, "Keyboard navigation wraps left without opening information")
	gamepad(JOY_BUTTON_DPAD_RIGHT)
	check(screen.selected == &"P1", "Gamepad D-pad wraps right")
	click(screen.slots[1])
	check(screen.selected == &"P2" and details.visible, "A mouse click on the second silhouette opens P2")
	check(portrait.texture == content.pilots[1].normal and name_label.text == "P2", "Information uses the selected pilot's existing portrait and name")
	key(KEY_RIGHT)
	check(screen.selected == &"P3" and details.visible and portrait.texture == content.pilots[2].normal, "Navigation updates the open information panel")
	var slot: Control = screen.slots[2]
	check(is_equal_approx(marker.get_global_rect().get_center().x, slot.get_global_rect().get_center().x), "The marker stays centered above the selected silhouette")
	click(screen.get_node("Layout/Details/CloseDetails"))
	check(not details.visible and screen.selected == &"P3", "The X button closes information and preserves selection")
	key(KEY_ENTER)
	check(details.visible and sorties.is_empty(), "First Enter opens information without launching")
	key(KEY_ESCAPE)
	check(not details.visible, "Escape closes information")
	gamepad(JOY_BUTTON_A)
	check(details.visible and sorties.is_empty(), "Gamepad A opens information without launching")
	gamepad(JOY_BUTTON_B)
	check(not details.visible, "Gamepad B closes information")
	click(screen.get_node("Layout/MoveLeft"))
	check(screen.selected == &"P2" and not details.visible, "The left arrow changes selection without opening information")
	click(screen.get_node("Layout/MoveRight"))
	check(screen.selected == &"P3", "The mirrored right arrow is clickable")

	click(screen.slots[0])
	var first := content.pilots[0]
	var original := first.hangar_portrait
	first.hangar_portrait = content.pilots[1].normal
	check(portrait.texture == content.pilots[1].normal, "Changing the selected pilot's optional portrait updates the panel")
	first.hangar_portrait = original
	check(portrait.texture == first.normal, "Clearing the override restores the normal portrait")
	await frames(20)
	await capture("pilot_select_information")
	click(screen.slots[5])
	await frames(20)
	await capture("pilot_select_information_p6")

	var original_size := screen.size
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(1600, 1000)
	await frames()
	var layout := screen.get_node("Layout") as Control
	check(layout.scale.is_equal_approx(Vector2.ONE * (1600.0 / 1920.0)) and is_equal_approx(layout.position.y, 50.0), "A taller viewport keeps the reference layout centered at 16:9")
	click(screen.slots[3])
	check(screen.selected == &"P4", "Silhouette hit areas still work after scaling the layout")
	screen.size = original_size
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await frames()

	screen._focus_pilot(&"P1")
	screen.run.mark_dead(&"P1")
	screen.run.mark_dead(&"P3")
	check(screen.selected == &"P2" and screen.slots[0].disabled and portrait.texture == content.pilots[1].normal, "A lost selected pilot falls back to a living pilot and updates information")
	key(KEY_RIGHT)
	check(screen.selected == &"P4", "Navigation skips lost pilots")
	click(screen.slots[0])
	check(screen.selected == &"P4", "Lost pilots cannot be selected by mouse")
	key(KEY_ENTER)
	key(KEY_ENTER)
	click(screen.get_node("Layout/Details/Sortie"))
	check(sorties == [&"P4"], "Confirmation emits one sortie for the selected living pilot")
	screen.queue_free()
	await frames()

	var empty := scene.instantiate() as Control
	empty.run = RunState.new(content)
	for pilot in content.pilots:
		empty.run.mark_dead(pilot.id)
	root.add_child(empty)
	await frames()
	key(KEY_ENTER)
	check(empty.selected == &"" and not empty.get_node("Layout/Details").visible and not empty.get_node("Layout/SelectionMarker").visible, "An empty roster has no selectable pilot or information panel")
	empty.queue_free()
	await frames()
	print("PILOT SELECT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
