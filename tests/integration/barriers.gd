extends SceneTree
## F4b-2: shortcut gates (latched from the region side) and vaultable fences.
var checks := 0
var failures := 0
var capture := false
var level: Node2D
var player: CampPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	_layout_checks()
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
	level.night_clock.director_enabled = false
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	for attempt in range(240):
		if NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, Vector2(96, 384), level.plan.woods.zones[2]["position"], true).size() > 1:
			break
		await physics_frame
	await _fence_checks()
	await _gate_checks()
	root.get_node("Session").select_survivor(previous_role)
	print(JSON.stringify({"event":"test_result","suite":"barriers","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _layout_checks() -> void:
	for seed_value in [1, 42, 99, 2026, 76543]:
		var woods := WoodsLayout.new()
		woods.generate(seed_value)
		_check(woods.gates.size() >= 2 and woods.fences.size() >= 30, "seed_%d_%d_gates_%d_fences" % [seed_value, woods.gates.size(), woods.fences.size()])
		_check(woods.fences.all(func(fence: Dictionary) -> bool: return fence["detour"] >= WoodsLayout.FENCE_DETOUR), "seed_%d_every_fence_has_a_real_detour" % seed_value)
		# With every gate and fence closed, every clearing is still reachable from camp.
		var seen := {WoodsLayout.ENTRY: true}
		var queue: Array[Vector2i] = [WoodsLayout.ENTRY]
		var cursor := 0
		while cursor < queue.size():
			var cell := queue[cursor]
			cursor += 1
			for next: Vector2i in woods.links[cell]:
				if not seen.has(next) and not woods.blocked.has([cell, next]):
					seen[next] = true
					queue.append(next)
		_check(seen.size() == woods.links.size(), "seed_%d_woods_connected_with_all_barriers_closed" % seed_value)


func _side(fence: Dictionary, sign_value: float) -> Vector2:
	return fence["position"] + fence["travel"] * sign_value * 26.0


func _fence_checks() -> void:
	var fence: Dictionary = level.plan.woods.fences[0]
	var near := _side(fence, -1.0)
	var far := _side(fence, 1.0)
	player.position = near
	await physics_frame
	for step in range(60):
		player.apply_intent(fence["travel"], false, 1.0 / 60.0)
	_check((player.global_position - fence["position"]).dot(fence["travel"]) < 0.0, "fence_blocks_walking")
	_check(level.clear_path(near, far), "fence_does_not_block_sight")
	var hunter: CampKiller = level.killer
	hunter.position = near
	await physics_frame
	_check(hunter.test_move(hunter.global_transform, fence["travel"] * 60.0), "fence_stops_creatures")
	player.position = near
	player.facing = fence["travel"]
	await _frames(2)
	_check(level.context_prompt().contains("VAULT FENCE"), "vault_prompt")
	hunter.enabled = true
	hunter.transition(CampKiller.State.PATROL)
	hunter.position = near - fence["travel"] * 150.0
	player.sprinting = false
	if capture:
		await _barrier_shot(fence["rect"], "barrier_vault")
		player.position = near
		player.facing = fence["travel"]
		await _frames(2)
	_check(level.try_interact(player) and player.vault_time > 0.0, "vault_starts")
	# physics_frame fires before nodes update; two frames let the sound watcher see the hop.
	await physics_frame
	await physics_frame
	_check(hunter.state == CampKiller.State.PATROL, "walking_vault_is_quiet")
	level.props.advance(ChaseProps.VAULT_SECONDS + 0.05)
	_check((player.global_position - fence["position"]).dot(fence["travel"]) > 0.0 and player.vault_time == 0.0, "vault_lands_on_far_side")
	await physics_frame
	_check(level.soundscape.played_counts.get("thud", 0) >= 1, "vault_landing_thud")
	_check(player.collision_mask & CampPlayer.BARRIER_LAYER != 0, "barrier_collision_restored_after_vault")
	player.sprinting = true
	level.try_interact(player)
	_check(hunter.state == CampKiller.State.INVESTIGATE, "sprint_vault_is_loud")
	level.props.advance(ChaseProps.VAULT_SECONDS + 0.05)
	player.sprinting = false
	hunter.enabled = false
	hunter.position = Vector2(600, 520)


func _path_length(from: Vector2, to: Vector2) -> float:
	var map := level.get_world_2d().navigation_map
	NavigationServer2D.map_force_update(map)
	var path := NavigationServer2D.map_get_path(map, from, to, true)
	var total := 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total if path.size() > 1 and path[-1].distance_to(to) < 8 else INF


func _gate_checks() -> void:
	var gate: Dictionary = level.plan.woods.gates[0]
	var toward: Vector2 = gate["toward_zone"]
	var road_side: Vector2 = gate["position"] - toward * 22.0
	var zone_side: Vector2 = gate["position"] + toward * 22.0
	player.position = road_side
	await _frames(2)
	_check(level.context_prompt().contains("LATCHED FROM THE FAR SIDE"), "gate_latched_from_road_side")
	_check(not level.try_interact(player) and not gate["open"], "road_side_cannot_open")
	var before := _path_length(road_side, zone_side)
	player.position = zone_side
	await _frames(2)
	_check(level.context_prompt().contains("OPEN SHORTCUT"), "gate_prompt_from_region_side")
	if capture:
		await _barrier_shot(gate["rect"], "barrier_gate")
		player.position = zone_side
		await _frames(2)
	var opened: bool = level.try_interact(player)
	if not (opened and gate["open"]):
		print(JSON.stringify({"event":"gate_debug","prompt":level.context_prompt(),"notice":player.notice,"pos":player.position,"gate":gate["position"],"toward":toward}))
	_check(opened and gate["open"] and level.message.contains("Shortcut open"), "region_side_opens_gate_for_team")
	await physics_frame
	await physics_frame
	var after := _path_length(road_side, zone_side)
	print(JSON.stringify({"event":"shortcut","zone":level.plan.woods.zones[gate["zone"]]["kind"],"closed_px":before,"open_px":after}))
	_check(before > 300.0 and after < 120.0, "opened_gate_creates_short_route_%d_to_%d" % [mini(int(before), 99999), int(after)])
	player.position = zone_side
	await physics_frame
	_check(not player.test_move(player.global_transform, -toward * 56.0), "open_gate_lets_survivors_through")
	_check(level.props.snapshot()["gates"][0] == true, "gate_state_in_snapshot")


## Stand below (or right of) a barrier and face it, so it shows above the HUD belt.
func _barrier_shot(rect: Rect2, label: String) -> void:
	var horizontal := rect.size.x > rect.size.y
	player.position = rect.get_center() + (Vector2(0, 56) if horizontal else Vector2(56, 0))
	player.facing = Vector2.UP if horizontal else Vector2.LEFT
	player.flashlight_on = true
	await _snapshot(label)


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
