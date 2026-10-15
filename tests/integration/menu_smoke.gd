extends SceneTree
## Run with --script; add -- --capture for real graphical viewport captures.

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var bindings := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT], "interact": [KEY_E], "flashlight": [KEY_F],
		"inventory": [KEY_TAB], "pause": [KEY_ESCAPE]
	}
	for action: String in bindings:
		_check(InputMap.has_action(action), "action_exists_" + action)
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			_check(InputMap.action_has_event(action, event), "binding_%s_%d" % [action, key])
	_check(ProjectSettings.get_setting("display/window/size/viewport_width") == 384,
		"viewport_width")
	_check(ProjectSettings.get_setting("display/window/size/viewport_height") == 216,
		"viewport_height")
	_check(ProjectSettings.get_setting("display/window/stretch/scale_mode") == "integer",
		"integer_scaling")
	_check(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 0,
		"nearest_filter")
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	_check(scene != null, "main_scene_loads")
	if scene == null:
		_finish()
		return
	var menu: Control = scene.instantiate()
	root.add_child(menu)
	await process_frame
	_check(menu.is_visible_in_tree(), "menu_visible")
	_check(menu.get_node("Menu/Play").disabled, "unfinished_play_disabled")
	_check(menu.get_node("Menu/Controls").has_focus(), "keyboard_focus_on_controls")
	var capture := "--capture" in OS.get_cmdline_user_args()
	if capture:
		await _capture("menu")
	# Activate the focused Controls button through Godot's input pipeline.
	await _key(KEY_ENTER)
	_check(menu.get_node("ControlsPanel").visible, "enter_opens_controls")
	_check(not menu.get_node("Menu").visible, "menu_hidden_behind_controls")
	_check(menu.get_node("ControlsPanel/Margin/Content/Back").has_focus(), "focus_on_back")
	if capture:
		await _capture("controls")
	await _key(KEY_ESCAPE)
	_check(not menu.get_node("ControlsPanel").visible, "escape_closes_controls")
	_check(menu.get_node("Menu/Controls").has_focus(), "focus_restored")
	await _key(KEY_ENTER)
	await _key(KEY_ENTER)
	_check(not menu.get_node("ControlsPanel").visible, "back_button_closes_controls")
	_check(menu.get_node("Menu").visible, "menu_restored")
	menu.queue_free()
	await process_frame
	_finish()


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		_check(false, "capture_requires_graphical_display")
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/verification")
	var image := root.get_texture().get_image()
	var path := "res://artifacts/verification/%s.png" % label
	_check(image.save_png(path) == OK, "capture_" + label)
	print(JSON.stringify({"event": "screenshot", "path": path}))


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": condition}))


func _finish() -> void:
	print(JSON.stringify({"event": "test_result", "suite": "menu_smoke",
		"checks": checks, "failures": failures}))
	quit(0 if failures == 0 else 1)
