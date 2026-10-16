extends SceneTree
## Complete production round via input only: no teleports, rule edits, or AI disable.

var checks: int = 0
var failures: int = 0
var level: Node2D
var player: CampPlayer
var capture: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await _frames(3)
	current_scene.get_node("Menu/Play").grab_focus()
	await _tap(KEY_ENTER)
	await _frames(3)
	level = current_scene
	_check(level.name == "ForestLevel", "menu_play_enters_real_round")
	player = level.player
	var original_light := player.flashlight_on
	await _tap(KEY_F)
	_check(player.flashlight_on != original_light, "flashlight_key_toggles")
	await _tap(KEY_F)
	await _tap(KEY_TAB)
	_check(level.hud.inventory_label.visible, "inventory_key_opens_pack")
	await _tap(KEY_TAB)
	await _tap(KEY_ESCAPE)
	var killer_position: Vector2 = level.killer.position
	await _frames(60)
	_check(level.paused and level.killer.position == killer_position, "pause_freezes_killer")
	await _tap(KEY_ESCAPE)
	_check(not level.paused, "escape_resumes_round")
	# Shed first, around its southern doorway. Every waypoint uses real collision.
	if not await _leg([Vector2(132, 384), Vector2(132, 444), Vector2(468, 444), Vector2(468, 360), Vector2(492, 360)]):
		_finish()
		return
	await _tap(KEY_E)
	_check("key" in player.inventory, "walked_to_shed_and_collected_key")
	if capture:
		await _snapshot("playthrough_shed")
	if not await _leg([Vector2(468, 360), Vector2(468, 444), Vector2(132, 444), Vector2(132, 330), Vector2(108, 330)]):
		_finish()
		return
	await _tap(KEY_E)
	_check("key" in level.van.installed, "walked_back_and_installed_key")
	if not await _leg([Vector2(156, 330), Vector2(156, 204), Vector2(204, 204), Vector2(204, 120), Vector2(228, 120)]):
		_finish()
		return
	await _tap(KEY_E)
	_check("battery" in player.inventory, "walked_to_west_cabin_and_collected_battery")
	if not await _leg([Vector2(204, 120), Vector2(204, 204), Vector2(156, 204), Vector2(156, 330), Vector2(108, 330)]):
		_finish()
		return
	await _tap(KEY_E)
	_check("battery" in level.van.installed, "walked_back_and_installed_battery")
	if not await _leg([Vector2(156, 330), Vector2(156, 204), Vector2(540, 204), Vector2(540, 120), Vector2(564, 120)]):
		_finish()
		return
	await _tap(KEY_E)
	_check("fuel" in player.inventory, "walked_to_east_cabin_and_collected_fuel")
	if not await _leg([Vector2(540, 120), Vector2(540, 204), Vector2(156, 204), Vector2(156, 330), Vector2(108, 330)]):
		_finish()
		return
	await _tap(KEY_E)
	_check(level.van.installed.size() == 3, "all_components_installed_via_input")
	await _hold(KEY_E, 130)
	await _frames(310)
	_check(level.finished and level.won and player.status == CampPlayer.Status.ESCAPED, "complete_input_only_win_with_active_killer")
	if capture:
		await _snapshot("playthrough_win")
	await _tap(KEY_ENTER)
	await _frames(3)
	level = current_scene
	player = level.player
	_check(not level.finished and level.van.installed.is_empty(), "result_enter_restarts_round")
	# Deliberately wait on the killer's patrol route to verify a complete loss.
	if not await _leg([Vector2(132, 384), Vector2(132, 444), Vector2(708, 444), Vector2(708, 336), Vector2(684, 336)]):
		_finish()
		return
	for index in range(2400):
		if level.finished:
			break
		await physics_frame
	_check(level.finished and not level.won, "complete_input_only_loss_with_active_killer")
	if capture:
		await _snapshot("playthrough_loss")
	level.hud.result_panel.get_child(0).get_node("Menu").grab_focus()
	await _tap(KEY_ENTER)
	await _frames(3)
	_check(current_scene.name == "MainMenu" and get_nodes_in_group("survivors").is_empty() and get_nodes_in_group("killers").is_empty(), "results_menu_removes_round_actors")
	_finish()


func _leg(points: Array) -> bool:
	for destination: Vector2 in points:
		var reached := false
		for index in range(900):
			var offset := destination - player.position
			if offset.length() < 2.0:
				reached = true
				break
			if player.status != CampPlayer.Status.ALIVE:
				break
			for action in ["move_left", "move_right", "move_up", "move_down"]:
				Input.action_release(action)
			if level.killer.state == CampKiller.State.CHASE:
				Input.action_press("sprint")
			else:
				Input.action_release("sprint")
			if absf(offset.x) > 1.0:
				Input.action_press("move_right" if offset.x > 0 else "move_left")
			if absf(offset.y) > 1.0:
				Input.action_press("move_down" if offset.y > 0 else "move_up")
			await physics_frame
		for action in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(action)
		Input.action_release("sprint")
		await _frames(1)
		print(JSON.stringify({"event": "waypoint", "target": [destination.x, destination.y],
			"actual": [player.position.x, player.position.y], "reached": reached,
			"killer_state": level.killer.state_label()}))
		_check(reached, "walk_to_%d_%d" % [destination.x, destination.y])
		if not reached:
			return false
	return true


func _tap(code: Key) -> void:
	await _hold(code, 2)


func _hold(code: Key, frames: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(frames)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _snapshot(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(true)
	_check(root.get_texture().get_image().save_png("res://artifacts/verification/%s.png" % label) == OK, "capture_" + label)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": condition}))


func _finish() -> void:
	print(JSON.stringify({"event": "test_result", "suite": "offline_playthrough", "checks": checks, "failures": failures}))
	quit(0 if failures == 0 else 1)
