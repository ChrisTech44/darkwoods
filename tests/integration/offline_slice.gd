extends SceneTree
## Real physics/input regression. Explicit placements below are isolated fixtures.

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
	level = load("res://scenes/world/forest_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	player = level.player
	# Isolate movement/item fixtures from the now-central stalker patrol.
	level.killer.enabled=false
	await _frames(3)
	var start := player.position
	await _move(["move_right"], 30)
	var straight := player.position.distance_to(start)
	_check(straight > 32.0 and straight < 38.0, "walk_speed_real_physics")
	player.position = start
	await _frames(2)
	await _move(["move_right", "move_up"], 30)
	var diagonal := player.position.distance_to(start)
	_check(absf(diagonal - straight) < 2.0, "diagonal_speed_normalized")
	_check(player.facing.x > 0.0 and player.facing.y < 0.0, "visible_facing_tracks_movement")
	player.position = CampMap.WORLD_BOUNDS.position + Vector2(36,288)
	await _frames(2)
	await _move(["move_left"], 30)
	_check(player.position.x >= CampMap.WORLD_BOUNDS.position.x + 28.5, "world_boundary_blocks_player")
	player.position = level.camp_map.buildings[0].door + Vector2(0, 12)
	await _frames(2)
	await _move(["move_up"], 70)
	_check(player.position.y < level.camp_map.buildings[0].bounds.end.y - 23, "cabin_door_allows_entry")
	await _move(["move_up"], 60)
	_check(player.position.y >= level.camp_map.buildings[0].bounds.position.y + 28.5, "cabin_wall_blocks_player")
	player.position = Vector2(312, 520)
	player.stamina = player.config.stamina_max
	await _frames(2)
	start = player.position
	await _move(["move_right", "sprint"], 30)
	_check(player.position.distance_to(start) > straight * 1.4, "sprint_faster_than_walk")
	_check(player.stamina < player.config.stamina_max - 0.4, "sprint_consumes_stamina")
	player.stamina = 0.02
	await _move(["move_right", "sprint"], 12)
	_check(player.exhausted and not player.sprinting, "exhaustion_blocks_sprint_bursts")
	await _frames(100)
	_check(player.stamina > player.config.stamina_restart, "stamina_recovers")
	level.paused = true
	player.controls_enabled = false
	start = player.position
	await _move(["move_right"], 15)
	_check(player.position.distance_to(start) < 0.1, "paused_player_stays_put")
	level.paused = false
	player.controls_enabled = true
	player.position = Vector2(96, 336)
	await _frames(3)
	if capture:
		await _snapshot("camp")
	await _objective_checks()
	await _killer_and_revive_checks()
	await _departure_failure_checks()
	level.queue_free()
	await process_frame
	print(JSON.stringify({"event": "test_result", "suite": "offline_slice", "checks": checks, "failures": failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _objective_checks() -> void:
	_check(not level.try_interact(player), "distant_pickup_rejected")
	# Expanded reach is an isolated fixture to make line-of-sight decisive.
	var original_radius: float = level.config.interact_radius
	level.config.interact_radius = 75.0
	player.position = level.plan.camp.remap(Vector2(228, 120)) - Vector2(0, 60)
	await _frames(2)
	_check(not level.try_interact(player) and level.pickups[0].available, "pickup_through_cabin_wall_rejected")
	level.config.interact_radius = original_radius
	for pickup: CampPickup in level.pickups:
		player.position = pickup.position
		await _frames(2)
		_check(level.try_interact(player), "pickup_" + pickup.kind)
		_check(not level.try_interact(player), "duplicate_pickup_rejected_" + pickup.kind)
	_check(player.inventory.size() == 3, "three_distinct_components_carried")
	_check(level.van.deliver(player) == 0, "distant_delivery_rejected")
	player.position = level.van.interaction_point()
	await _frames(2)
	_check(level.try_interact(player), "nearby_delivery_accepted")
	_check(level.van.installed.size() == 3 and player.inventory.is_empty(), "parts_transferred_once")
	_check(level.van.deliver(player) == 0, "duplicate_delivery_rejected")
	Input.action_press("interact")
	await _frames(45)
	Input.action_release("interact")
	await _frames(2)
	_check(not level.van.running and level.van.start_progress == 0.0, "released_hold_resets_start")
	Input.action_press("interact")
	await _frames(125)
	Input.action_release("interact")
	_check(level.van.running and not level.finished, "full_hold_starts_countdown")
	_check(player.status == CampPlayer.Status.BOARDED and player in level.van.passengers, "starting_driver_boards_automatically")
	player.receive_hit()
	_check(player.status == CampPlayer.Status.BOARDED, "boarded_survivor_safe_from_killer")
	if capture:
		await _snapshot("van_countdown")
	await _frames(ceili(level.config.extraction_seconds * 60.0) + 10)
	_check(level.finished and level.won, "living_survivor_wins_round")
	_check(player.status == CampPlayer.Status.ESCAPED, "per_player_escape_recorded")
	if capture:
		await _snapshot("win")
	var previous: WeakRef = weakref(level)
	level.hud.result_panel.get_child(0).get_node("Restart").pressed.emit()
	await _frames(4)
	current_scene.get_node("Menu/Play").pressed.emit()
	current_scene.get_node("SurvivorSelection/Start").pressed.emit()
	await _wait_world()
	level = current_scene
	player = level.player
	_check(previous.get_ref() == null, "restart_frees_old_round")
	_check(get_nodes_in_group("survivors").size() == 1, "restart_has_one_player")
	_check(not level.finished and level.van.installed.is_empty(), "restart_resets_objective_and_phase")
	_check(level.pickups.size() == 3 and level.pickups[0].available, "restart_restores_pickups")
	_check(get_nodes_in_group("killers").size() == 1, "restart_has_one_killer")


func _killer_and_revive_checks() -> void:
	var killer: CampKiller = level.killer
	killer.enabled=true
	player.position = level.plan.camp.remap(Vector2(228, 120))
	killer.position = level.plan.camp.remap(Vector2(228, 120)) - Vector2(0, 72)
	await _frames(3)
	_check(killer.sense_visible_target() == null, "cabin_wall_occludes_killer_sight")
	var noise := killer.position + Vector2(72, 0)
	killer.hear_noise(noise)
	_check(killer.state == CampKiller.State.INVESTIGATE, "nearby_noise_triggers_investigation")
	_check(killer.last_seen == noise, "noise_records_sensed_location")
	killer.hear_noise(Vector2(1000, 1000))
	_check(killer.last_seen == noise, "distant_noise_ignored")
	player.position = Vector2(360, 520)
	killer.position = Vector2(300, 520)
	await _frames(3)
	_check(killer.state == CampKiller.State.CHASE, "clear_sight_triggers_chase")
	_check(killer.memory.has(player.get_instance_id()), "visible_target_enters_memory")
	if capture:
		await _snapshot("chase")
	var sensed := killer.last_seen
	player.position = level.plan.camp.remap(Vector2(228, 120))
	await _frames(3)
	_check(killer.state == CampKiller.State.SEARCH, "lost_sight_enters_search")
	_check(killer.last_seen == sensed, "hidden_player_does_not_update_last_seen")
	await _frames(370)
	_check(killer.state == CampKiller.State.PATROL, "search_timeout_returns_to_patrol")
	_check(killer.memory.is_empty(), "target_memory_decays")
	player.position = Vector2(96, 384)
	killer.position = level.camp_map.buildings[0].door + Vector2(0, 36)
	killer.transition(CampKiller.State.PATROL)
	await _frames(2)
	killer.hear_noise(level.plan.camp.remap(Vector2(228, 120)))
	var entered_cabin := false
	for frame in range(240):
		await physics_frame
		if killer.position.distance_to(level.plan.camp.remap(Vector2(228,120))) < 14:
			entered_cabin = true
			break
	_check(entered_cabin, "navigation_routes_killer_through_cabin_door")
	killer.enabled = false
	var teammate: CampPlayer = load("res://scenes/actors/player.tscn").instantiate()
	teammate.local_input = false
	teammate.position = player.position + Vector2(16, 0)
	level.add_child(teammate)
	teammate.receive_hit()
	_check(teammate.status == CampPlayer.Status.ALIVE and teammate.wounded and teammate.invulnerability > 0, "first_hit_wounds_with_grace")
	teammate.invulnerability = 0.0
	teammate.receive_hit()
	_check(teammate.status == CampPlayer.Status.DOWNED and not get_nodes_in_group("survivors").is_empty(), "second_hit_downs_wounded_survivor")
	teammate.position += Vector2(100, 0)
	level.advance_revive(player, teammate, true, level.config.revive_seconds)
	_check(teammate.status == CampPlayer.Status.DOWNED and level.revive_progress == 0.0, "distant_revive_rejected")
	teammate.position = player.position + Vector2(16, 0)
	Input.action_press("interact")
	await _frames(60)
	Input.action_release("interact")
	await _frames(3)
	_check(teammate.status == CampPlayer.Status.DOWNED and level.revive_progress == 0.0, "interrupted_revive_resets")
	player.pack("medkit")
	Input.action_press("interact")
	await _frames(185)
	Input.action_release("interact")
	_check(teammate.status == CampPlayer.Status.ALIVE and teammate.wounded and player.supplies["medkit"] == 0, "medkit_revive_succeeds_and_leaves_wounded")
	teammate.receive_hit()
	_check(teammate.status == CampPlayer.Status.ALIVE, "revive_grace_prevents_instant_redown")
	await _frames(125)
	teammate.receive_hit()
	teammate.receive_hit()
	_check(teammate.status == CampPlayer.Status.DOWNED, "revived_survivor_downs_on_next_hit_and_never_dies")
	teammate.position = player.position + Vector2(16, 0)
	level.advance_revive(player, teammate, true, player.config.revive_seconds + 0.01)
	_check(teammate.status == CampPlayer.Status.DOWNED and level.revive_progress > 0, "kitless_revive_takes_longer_than_kit_time")
	level.advance_revive(player, teammate, true, player.config.revive_seconds)
	_check(teammate.status == CampPlayer.Status.ALIVE, "kitless_revive_completes_at_double_time")
	teammate.set_status(CampPlayer.Status.DOWNED)
	teammate.set_status(CampPlayer.Status.DOWNED)
	teammate.bleedout = 0.03
	await _frames(4)
	_check(teammate.status == CampPlayer.Status.DOWNED, "unrevived_survivor_stays_downed")
	teammate.queue_free()
	await _frames(2)
	killer.position = player.position + Vector2(8, 0)
	killer.attack_remaining = 0.0
	killer.enabled = true
	await _frames(3)
	_check(player.status == CampPlayer.Status.ALIVE and player.wounded, "killer_attack_wounds_player")
	await _frames(55)
	_check(player.status == CampPlayer.Status.ALIVE, "attack_cooldown_and_grace_prevent_double_hit")
	for frame in range(240):
		if player.status == CampPlayer.Status.DOWNED: break
		await physics_frame
	_check(player.status == CampPlayer.Status.DOWNED, "second_attack_downs_wounded_player")
	if capture:
		await _snapshot("downed")
	await _frames(30)
	_check(not level.finished and level.solo_recovery_available(player), "solo_survivor_gets_last_chance")
	for frame in range(ceili(level.SOLO_LAST_CHANCE * 60.0) + 30):
		if level.finished: break
		await physics_frame
	_check(level.finished and not level.won and player.status == CampPlayer.Status.DOWNED, "all_downed_causes_local_defeat_after_last_chance")
	if capture:
		await _snapshot("loss")
	level.restart_round()
	await _frames(4)
	current_scene.get_node("Menu/Play").pressed.emit()
	current_scene.get_node("SurvivorSelection/Start").pressed.emit()
	await _wait_world()
	level = current_scene
	player = level.player
	_check(not level.finished and get_nodes_in_group("survivors").size() == 1 and get_nodes_in_group("killers").size() == 1, "defeat_restart_cleans_up_all_actors")


func _departure_failure_checks() -> void:
	# Isolate departure rules from AI; the full playthrough keeps the killer active.
	level.killer.enabled = false
	for pickup: CampPickup in level.pickups:
		player.position = pickup.position
		await _frames(2)
		level.try_interact(player)
	player.position = level.van.interaction_point()
	await _frames(2)
	level.try_interact(player)
	# Engine-only fixture: no driver boards, to verify an empty van cannot win.
	level.van.advance_start(player, true, level.config.start_hold_seconds)
	var pause_event := InputEventKey.new()
	pause_event.keycode = KEY_ESCAPE
	pause_event.physical_keycode = KEY_ESCAPE
	pause_event.pressed = true
	Input.parse_input_event(pause_event)
	await _frames(2)
	var countdown: float = level.van.remaining
	await _frames(60)
	_check(level.paused and level.van.remaining == countdown, "pause_freezes_extraction_countdown")
	pause_event = pause_event.duplicate()
	pause_event.pressed = false
	Input.parse_input_event(pause_event)
	await _frames(1)
	pause_event = pause_event.duplicate()
	pause_event.pressed = true
	Input.parse_input_event(pause_event)
	await _frames(1)
	pause_event = pause_event.duplicate()
	pause_event.pressed = false
	Input.parse_input_event(pause_event)
	level.killer.enabled = false
	player.position = Vector2(156, 384)
	await _frames(ceili(level.config.extraction_seconds * 60.0) + 10)
	_check(level.finished and not level.won, "empty_extraction_zone_loses_round")
	_check(player.status == CampPlayer.Status.LEFT_BEHIND, "absent_survivor_recorded_left_behind")


func _wait_world() -> void:
	await process_frame
	while current_scene == null or current_scene.name != "ForestLevel":
		await process_frame
	await _frames(4)


func _move(actions: Array, frames: int) -> void:
	for action: String in actions:
		Input.action_press(action)
	await _frames(frames)
	for action: String in actions:
		Input.action_release(action)
	await _frames(1)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _snapshot(label: String) -> void:
	print(JSON.stringify({"event": "capture_begin", "name": label}))
	await process_frame
	RenderingServer.force_draw(true)
	var path := "res://artifacts/verification/%s.png" % label
	_check(root.get_texture().get_image().save_png(path) == OK, "capture_" + label)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": condition}))
