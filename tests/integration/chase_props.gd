extends SceneTree
## F3b: hiding spots with breath and witnesses, slam/break doors, knock-overs.
var checks := 0
var failures := 0
var capture := false
var level: Node2D
var player: CampPlayer
var props: ChaseProps


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	var previous_role: String = root.get_node("Session").survivor
	root.get_node("Session").survivor = "jock"
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	while current_scene == null or current_scene.name != "ForestLevel":
		await process_frame
	level = current_scene
	player = level.player
	player.local_input = false
	props = level.props
	level.night_clock.director_enabled = false
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	for attempt in range(240):
		if NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, Vector2(96, 384), Vector2(700, 520), true).size() > 1:
			break
		await physics_frame
	await _layout_checks()
	await _hide_checks()
	await _door_checks()
	await _knock_checks()
	root.get_node("Session").select_survivor(previous_role)
	print(JSON.stringify({"event":"test_result","suite":"chase_props","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _layout_checks() -> void:
	var camp_spots := props.spots.filter(func(spot: Dictionary) -> bool: return not spot["woods"])
	var woods_spots := props.spots.filter(func(spot: Dictionary) -> bool: return spot["woods"])
	_check(camp_spots.size() >= 10 and woods_spots.size() >= 60, "hiding_spots_in_camp_%d_and_woods_%d" % [camp_spots.size(), woods_spots.size()])
	_check(props.doors.size() == level.camp_map.buildings.size() + level.camp_map.forest_buildings.size(), "every_building_has_a_door")
	var camp_knocks := props.knocks.filter(func(knock: Dictionary) -> bool: return not CampMap.is_woods(knock["position"]))
	_check(camp_knocks.size() >= 4 and props.knocks.size() - camp_knocks.size() >= 20, "woodpiles_and_deadfalls_%d_%d" % [camp_knocks.size(), props.knocks.size() - camp_knocks.size()])
	var reachable := true
	for spot: Dictionary in props.spots:
		var path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, Vector2(96, 384), spot["position"], true)
		if path.size() < 2 or path[-1].distance_to(spot["position"]) > 6:
			reachable = false
			print(JSON.stringify({"event":"unreachable_spot","spot":spot}))
	_check(reachable, "every_hiding_spot_reachable")
	var doors_open := props.doors.all(func(door: Dictionary) -> bool: return door["open"])
	_check(doors_open and level.clear_path(level.camp_map.buildings[0].door + Vector2(0, 12), level.camp_map.buildings[0].door - Vector2(0, 30)), "doors_start_open")


func _spot_in_camp() -> int:
	for index in range(props.spots.size()):
		if not props.spots[index]["woods"]:
			return index
	return -1


func _hide_checks() -> void:
	var index := _spot_in_camp()
	var spot: Vector2 = props.spots[index]["position"]
	player.position = spot + Vector2(0, 6)
	await _frames(2)
	_check(level.context_prompt().begins_with("E · HIDE"), "hide_prompt_%s" % props.spots[index]["label"])
	var hunter: CampKiller = level.killer
	hunter.enabled = true
	hunter.position = spot + Vector2(0, 300)
	hunter.transition(CampKiller.State.PATROL)
	_check(level.try_interact(player) and player.hidden_spot == index and player.position == spot, "hide_snaps_into_spot")
	_check(hunter.state == CampKiller.State.PATROL and props.witnesses[index].is_empty(), "unseen_hiding_has_no_witness")
	if capture:
		await _snapshot("props_hidden")
	hunter.position = spot + Vector2(40, 0)
	_check(hunter.sense_visible_target() == null, "hidden_survivor_invisible_to_hunter")
	player.receive_hit()
	_check(player.status == CampPlayer.Status.ALIVE and not player.wounded, "hidden_survivor_cannot_be_hit")
	player.apply_intent(Vector2.RIGHT, true, 0.5)
	_check(player.position == spot, "hidden_survivor_cannot_move")
	props.advance(2.0)
	_check(player.hidden_spot == index and player.breath < 0.6, "breath_drains_with_hunter_close")
	hunter.transition(CampKiller.State.PATROL)
	hunter.position = spot + Vector2(110, 0)
	props.advance(2.5)
	_check(player.hidden_spot < 0 and hunter.state == CampKiller.State.INVESTIGATE, "out_of_breath_gasps_and_is_heard")
	hunter.position = spot + Vector2(400, 0)
	await _frames(1)
	_check(level.try_interact(player) and player.hidden_spot == index, "hide_again")
	props.advance(4.0)
	_check(player.breath >= 0.9 or is_equal_approx(player.breath, 1.0), "breath_recovers_when_safe")
	_check(level.try_interact(player) and player.hidden_spot < 0 and player.flashlight_on, "e_leaves_hiding_and_restores_light")
	# Hiding in plain sight: a chasing hunter marks the spot and drags you out.
	player.position = spot + Vector2(0, 6)
	hunter.position = spot + Vector2(0, 60)
	hunter.transition(CampKiller.State.PATROL)
	await _frames(1)
	if not hunter.has_line_of_sight(player.global_position):
		hunter.position = spot + Vector2(0, 30)
	hunter.visible_target = player
	hunter.transition(CampKiller.State.CHASE)
	level.try_interact(player)
	_check(props.witnesses[index].size() == 1 and hunter.state == CampKiller.State.INVESTIGATE and hunter.last_seen == spot, "chasing_hunter_witnesses_hiding")
	hunter.position = spot + Vector2(0, 8)
	props.advance(0.1)
	_check(player.hidden_spot < 0, "witness_drags_survivor_out")
	hunter.enabled = false
	player.wounded = false


func _door_checks() -> void:
	var building: CampBuilding = level.camp_map.buildings[0]
	var index := props.doors.find(props.doors.filter(func(door: Dictionary) -> bool: return door["label"] == building.label)[0])
	var door: Dictionary = props.doors[index]
	var outside: Vector2 = building.door + Vector2(0, 16)
	player.position = outside
	player.facing = Vector2.UP
	player.flashlight_on = true
	await _frames(2)
	_check(level.context_prompt().contains("SLAM DOOR"), "slam_prompt")
	_check(level.try_interact(player) and not door["open"], "door_slams")
	await physics_frame
	await physics_frame
	_check(not level.clear_path(outside, building.door - Vector2(0, 30)), "closed_door_blocks_movement_and_sight")
	if capture:
		await _snapshot("props_door")
	var hunter: CampKiller = level.killer
	hunter.enabled = true
	hunter.position = building.door + Vector2(0, 8)
	hunter.transition(CampKiller.State.PATROL)
	player.position = building.bounds.get_center()
	props.advance(ChaseProps.DOOR_BREAK_SECONDS - 0.2)
	_check(not door["open"] and door["progress"] > 2.0, "door_holds_for_a_while")
	props.advance(0.3)
	_check(door["open"] and door["broken"] > 0.0, "hunter_breaks_door")
	await physics_frame
	await physics_frame
	_check(level.clear_path(outside, building.door - Vector2(0, 30)), "broken_door_is_open")
	hunter.enabled = false
	hunter.position = Vector2(600, 520)
	player.position = outside
	await _frames(1)
	_check(not level.try_interact(player) and door["open"], "smashed_door_cannot_close")
	props.advance(ChaseProps.DOOR_BROKEN_SECONDS)
	# Live AI: a real hunter routes to a noise behind a closed door, breaks in and enters.
	player.position = outside + Vector2(30, 0)
	await _frames(1)
	_check(props.toggle_door(player, index) and not door["open"], "door_closed_again_after_repair_window")
	var inside: Vector2 = level.plan.camp.remap(Vector2(228, 120))
	hunter.enabled = true
	hunter.position = building.door + Vector2(0, 70)
	hunter.transition(CampKiller.State.PATROL)
	player.position = Vector2(96, 384)
	await physics_frame
	hunter.hear_stimulus(inside, INF)
	var entered := false
	for frame in range(600):
		await physics_frame
		if door["open"] and hunter.global_position.distance_to(inside) < 20:
			entered = true
			break
	_check(entered and door["broken"] > 0.0, "live_hunter_breaks_in_and_reaches_noise")
	hunter.enabled = false
	hunter.position = Vector2(600, 520)
	props.advance(ChaseProps.DOOR_BROKEN_SECONDS)
	player.position = building.door_rect.get_center()
	_check(not props.toggle_door(player, index) and door["open"], "cannot_close_on_someone_in_doorway")


func _knock_checks() -> void:
	var index := -1
	for candidate in range(props.knocks.size()):
		if not CampMap.is_woods(props.knocks[candidate]["position"]):
			index = candidate
			break
	var knock: Dictionary = props.knocks[index]
	var at: Vector2 = knock["position"]
	player.position = at - Vector2(10, 0)
	player.facing = Vector2.RIGHT
	player.flashlight_on = true
	var hunter: CampCryptid = get_nodes_in_group("cryptids")[0]
	hunter.position = at + Vector2(22, 0)
	hunter.enabled = true
	hunter.stun_remaining = 0.0
	hunter.stun_immunity = 0.0
	await _frames(2)
	_check(level.context_prompt().contains("KNOCK OVER"), "knock_prompt")
	_check(level.try_interact(player) and knock["state"] == 1 and hunter.stun_remaining > 0.0, "knock_over_stuns_pursuer")
	hunter.enabled = false
	hunter.position = at + Vector2(200, 0)
	await physics_frame
	await physics_frame
	var rect: Rect2 = knock["rect"]
	_check(not level.clear_path(rect.get_center() - Vector2(20, 0), rect.get_center() + Vector2(20, 0)), "fallen_pile_blocks_lane")
	if capture:
		await _snapshot("props_knockover")
	props.advance(ChaseProps.KNOCK_BLOCK_SECONDS + 0.1)
	await physics_frame
	await physics_frame
	_check(knock["state"] == 2 and level.clear_path(rect.get_center() - Vector2(20, 0), rect.get_center() + Vector2(20, 0)), "block_clears_after_six_seconds")
	_check(props.knock_near(player) != index, "knock_over_is_one_use")


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _snapshot(label: String) -> void:
	await _frames(3)
	RenderingServer.force_draw(true)
	DirAccess.make_dir_recursive_absolute("res://artifacts/verification")
	_check(root.get_texture().get_image().save_png("res://artifacts/verification/%s.png" % label) == OK, "capture_" + label)


func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures += 1
	print(JSON.stringify({"event":"assertion","name":label,"passed":passed}))
