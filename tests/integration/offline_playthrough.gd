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
	root.get_node("Session").mode = "camp"
	root.get_node("Session").next_seed = 42
	capture = "--capture" in OS.get_cmdline_user_args()
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await _frames(3)
	current_scene.get_node("Menu/RandomNight").button_pressed = false
	current_scene.get_node("Menu/Seed").text = "42"
	current_scene.get_node("Menu/Play").pressed.emit()
	current_scene.get_node("SurvivorSelection/Start").grab_focus()
	await _tap(KEY_ENTER)
	while current_scene == null or current_scene.name != "ForestLevel":
		await process_frame
	level = current_scene
	_check(level.name == "ForestLevel", "menu_play_enters_real_round")
	player = level.player
	var original_light := player.flashlight_on
	await _tap(KEY_F)
	_check(player.flashlight_on != original_light, "flashlight_key_toggles")
	await _tap(KEY_F)
	await _tap(KEY_TAB)
	_check(level.hud.inventory_label.visible, "inventory_key_opens_pack")
	_check(level.hud.chart.visible, "inventory_key_opens_camp_map")
	await _tap(KEY_TAB)
	_check(not level.hud.chart.visible, "inventory_key_closes_camp_map")
	await _tap(KEY_ESCAPE)
	var killer_position: Vector2 = level.killer.position
	await _frames(60)
	_check(level.paused and level.killer.position == killer_position, "pause_freezes_killer")
	await _tap(KEY_ESCAPE)
	_check(not level.paused, "escape_resumes_round")
	# Visit the authored objectives via the native navigation mesh, using input.
	for index in [2, 0, 1]:
		var pickup: CampPickup = level.pickups[index]
		if not await _navigate_to(pickup.global_position):
			_finish()
			return
		await _tap(KEY_E)
		_check(pickup.kind in player.inventory, "explored_building_and_collected_" + pickup.kind)
		if capture:
			await _snapshot("playthrough_" + pickup.kind)
		if not await _navigate_to(level.van.interaction_point()):
			_finish()
			return
		await _tap(KEY_E)
		_check(pickup.kind in level.van.installed, "returned_and_installed_" + pickup.kind)
	_check(level.van.installed.size() == 3, "all_components_installed_via_input")
	await _hold(KEY_E, 130)
	await _frames(ceili(level.config.extraction_seconds * 60.0) + 10)
	_check(level.finished and level.won and player.status == CampPlayer.Status.ESCAPED, "complete_input_only_win_with_active_killer")
	if capture:
		await _snapshot("playthrough_win")
	await _tap(KEY_ENTER)
	await _frames(4)
	_check(current_scene.name == "MainMenu", "another_night_returns_to_selection_flow")
	current_scene.get_node("Menu/Play").pressed.emit()
	current_scene.get_node("SurvivorSelection/Start").grab_focus()
	await _tap(KEY_ENTER)
	while current_scene == null or current_scene.name != "ForestLevel":
		await process_frame
	level = current_scene
	player = level.player
	_check(not level.finished and level.van.installed.is_empty(), "result_enter_restarts_round")
	# Deliberately wait on the killer's patrol route to verify a complete loss.
	if not await _navigate_to(Vector2(360, 216)):
		_finish()
		return
	for index in range(3600):
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


func _navigate_to(destination: Vector2) -> bool:
	NavigationServer2D.map_force_update(level.get_world_2d().navigation_map)
	var path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, player.global_position, destination, true)
	for attempt in range(240):
		if path.size() >= 2:
			break
		await physics_frame
		path = NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, player.global_position, destination, true)
	print(JSON.stringify({"event": "path_probe", "count": path.size(), "destination": [destination.x, destination.y], "end": [path[-1].x, path[-1].y] if not path.is_empty() else []}))
	_check(path.size() >= 2 and path[-1].distance_to(destination) < 4.0, "objective_has_reachable_navigation_path")
	if path.size() < 2:
		return false
	return await _leg(Array(path))


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
			if level.killer.global_position.distance_to(player.global_position) < 45 and level.killer.nearby_flare() == Vector2.INF and player.supplies["flare"] > 0:
				await _tap(KEY_Q)
			if player.stamina < 0.5 and player.supplies["rations"] > 0:
				await _tap(KEY_C)
			if level.killer.state == CampKiller.State.CHASE:
				Input.action_press("sprint")
			else:
				Input.action_release("sprint")
			if absf(offset.x) > 1.0:
				Input.action_press("move_right" if offset.x > 0 else "move_left", absf(offset.x) / maxf(absf(offset.x), absf(offset.y)))
			if absf(offset.y) > 1.0:
				Input.action_press("move_down" if offset.y > 0 else "move_up", absf(offset.y) / maxf(absf(offset.x), absf(offset.y)))
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
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)
