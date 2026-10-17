extends SceneTree
var checks := 0
var failures := 0
var level: Node2D
var player: CampPlayer
var rescue: RadioRescue
var capture := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	var seeded := true
	for seed_value in [1, 2, 42, 104, 908]:
		var a := RoundPlan.new()
		a.generate(seed_value, "woods")
		var b := RoundPlan.new()
		b.generate(seed_value, "woods")
		seeded = seeded and a.loot == b.loot and a.woods.zones == b.woods.zones
		var fuse: Array = a.loot.filter(func(item): return item["kind"] == "rescue_fuse")
		seeded = seeded and fuse.size() == 1 and a.woods.walkable(fuse[0]["position"]) and "rescue_fuse" not in a.required
	_check(seeded, "five_seeds_reproducible_unique_walkable_separate_fuse")
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	while current_scene == null or current_scene.name != "ForestLevel":
		await process_frame
	level = current_scene
	player = level.player
	player.local_input = false
	rescue = level.rescue
	level.night_clock.director_enabled = false
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	await _frames(12)
	var fuse: CampPickup
	for pickup: CampPickup in level.pickups:
		if pickup.kind == "rescue_fuse":
			fuse = pickup
	for point in [fuse.position, rescue.power_point, rescue.relay_point, rescue.landing]:
		var path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, Vector2(96,384), point, true)
		_check(path.size() > 1 and path[-1].distance_to(point) < 4, "native_route_" + str(point))
	for offset in RadioRescue.SOCKET_OFFSETS:
		var goal: Vector2 = rescue.landing + offset
		var path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, rescue.landing, goal, true)
		_check(path.size() > 1 and path[-1].distance_to(goal) < 4, "signal_socket_reachable_" + str(offset))
	player.position = rescue.power_point
	_check(not rescue.interact(player) and not rescue.powered, "substation_requires_fuse")
	player.position = fuse.position
	var belt := player.belt.duplicate()
	_check(level.try_interact(player) and not fuse.available and "rescue_fuse" in player.inventory and player.belt == belt, "pickup_uses_separate_inventory")
	player.wounded = true
	player.invulnerability = 0
	player.receive_hit()
	_check("rescue_fuse" not in player.inventory and level.pickups.any(func(item): return item.kind == "rescue_fuse" and item.available), "down_drops_emergency_fuse")
	player.set_status(CampPlayer.Status.ALIVE)
	# The authoritative drop can be recovered with the same pickup rules.
	for pickup: CampPickup in level.pickups:
		if pickup.kind == "rescue_fuse" and pickup.available:
			player.position = pickup.position
			_check(level.try_interact(player) and "rescue_fuse" in player.inventory, "recover_dropped_fuse")
	player.position = rescue.power_point
	_check(rescue.interact(player) and rescue.powered and "rescue_fuse" not in player.inventory, "fuse_consumed_once_restores_circuit")
	_check(rescue.interact(player) and rescue.powered, "repeated_power_interaction_idempotent")
	player.position = rescue.relay_point
	_check(not rescue.transmitted and rescue.prompt(player).contains("HOLD E"), "transmit_available_once_powered_no_clock_gate")
	level.night_clock.force_phase(2)
	level.night_clock.skip_to(level.night_clock.elapsed + 301.0)
	_check(rescue.powered and level.night_clock.blackout, "camp_blackout_preserves_dedicated_rescue_power")
	player.position = rescue.relay_point
	rescue.advance_transmit(player, 3)
	rescue.advance_transmit(null, 0.1)
	_check(rescue.progress == 0, "release_resets_transmit_hold")
	var teammate: CampPlayer = load("res://scenes/actors/player.tscn").instantiate()
	teammate.local_input = false
	teammate.role = "medic"
	level.world_objects.add_child(teammate)
	teammate.position = rescue.relay_point + Vector2(12,0)
	rescue.advance_transmit(player, 3)
	rescue.advance_transmit(teammate, 1)
	_check(rescue.progress == 1 and rescue.starter == teammate, "operator_change_cannot_inherit_progress")
	rescue.advance_transmit(null, 0)
	player.position = rescue.relay_point
	Input.action_press("interact")
	await _frames(365)
	Input.action_release("interact")
	_check(rescue.transmitted and not rescue.started and not level.finished, "real_hold_sends_distress_without_trapping_solo_runner")
	if capture:
		await _atlas()
		await _snapshot("relay", rescue.relay_point, Vector2(0,-80), 0.7)
		await _snapshot("substation", rescue.power_point, Vector2(0,-75), 0.7)
	player.pack("flare", 5)
	player.position = rescue.landing
	var flares: int = player.supplies["flare"]
	_check(not rescue.interact(player) and not rescue.started, "cannot_start_without_all_signals")
	player.position = rescue.landing + Vector2(280,0)
	_check(not rescue.interact(player) and player.supplies["flare"] == flares, "distant_action_cannot_spend_flare")
	for index in range(3):
		player.position = rescue.landing + RadioRescue.SOCKET_OFFSETS[index]
		_check(rescue.interact(player) and player.supplies["flare"] == flares-index-1, "signal_spends_exactly_one_" + str(index))
		rescue.interact(player)
		_check(player.supplies["flare"] == flares-index-1, "signal_repeat_idempotent_" + str(index))
	_check(not rescue.started and rescue.remaining == 40, "all_signals_wait_for_team_ready_at_circle")
	if capture:
		await _snapshot("landing", rescue.landing, Vector2(0,-8), 0.9)
		rescue.pack_selected = true
		level.hud.inventory_label.show()
		await _snapshot("plan", rescue.landing, Vector2.ZERO, 1.0)
		level.hud.inventory_label.hide()
	var snapshot: Dictionary = rescue.snapshot()
	rescue.powered = false
	rescue.restore(snapshot)
	_check(rescue.powered and rescue.transmitted and rescue.signals.count(true) == 3, "snapshot_restores_objective_state")
	var role_access := true
	for role: String in SurvivorRoster.IDS:
		teammate.role = role
		teammate.position = rescue.landing
		role_access = role_access and not rescue.prompt(teammate).is_empty()
	_check(role_access, "all_roles_can_start_escape")
	player.position = rescue.landing
	_check(rescue.interact(player) and rescue.started, "player_starts_finale_from_landing_circle")
	level.paused = true
	rescue.advance(5)
	_check(rescue.remaining == 40, "offline_pause_freezes_finale")
	level.paused = false
	rescue.advance(39)
	_check(not level.finished and rescue.remaining == 1, "full_holdout_required")
	# Downed teammate anywhere is rescued, a standing player outside is left behind.
	teammate.set_status(CampPlayer.Status.DOWNED)
	teammate.position = Vector2(96,384)
	var outside: CampPlayer = load("res://scenes/actors/player.tscn").instantiate()
	outside.local_input = false
	level.world_objects.add_child(outside)
	outside.position = rescue.landing + Vector2(140,0)
	rescue.advance(1)
	_check(level.finished and level.won and player.status == CampPlayer.Status.ESCAPED and teammate.status == CampPlayer.Status.ESCAPED and outside.status == CampPlayer.Status.LEFT_BEHIND, "extract_inside_rescue_downed_leave_standing_outside")
	print(JSON.stringify({"event":"test_result", "suite":"radio_rescue", "checks":checks, "failures":failures}))
	current_scene.queue_free()
	await _frames(4)
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)

func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(JSON.stringify({"event":"assert", "name":label, "passed":ok}))

func _snapshot(label: String, point: Vector2, offset: Vector2, zoom: float) -> void:
	player.position = point
	player.facing = Vector2.UP
	player.flashlight_on = true
	player.flashlight_charge = 90
	level.message_time = 0
	player.notice_time = 0
	player.set_physics_process(false)
	var camera: Camera2D = player.get_node("Camera2D")
	camera.zoom = Vector2.ONE * zoom
	camera.offset = offset
	camera.force_update_scroll()
	await _frames(4)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://artifacts/verification")
	image.save_png("res://artifacts/verification/rescue_%s.png" % label)
	if label in ["relay", "substation"]:
		var structures: Node2D = rescue.get_child(0)
		# Tall props are depth-sorted world sprites (StandingProps): hide those too.
		var standing: StandingProps = level.get_node("StandingProps")
		var sprites: Array = standing.props.values().filter(func(entry: Dictionary) -> bool: return entry["canvas"] == structures.get_instance_id()).map(func(entry: Dictionary) -> Sprite2D: return entry["sprite"])
		structures.hide()
		for sprite: Sprite2D in sprites:
			sprite.hide()
		await process_frame
		await RenderingServer.frame_post_draw
		var control := root.get_texture().get_image()
		structures.show()
		for sprite: Sprite2D in sprites:
			sprite.show()
		var visible_pixels := 0
		for y in range(40,145):
			for x in range(384):
				if image.get_pixel(x,y).get_luminance()-control.get_pixel(x,y).get_luminance() > 0.03:
					visible_pixels += 1
		_check(visible_pixels > 100, "readable_structure_at_night_" + label)
	player.set_physics_process(true)

func _atlas() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	root.add_child(layer)
	var overview = load("res://tests/integration/surround_world.gd").Overview.new()
	overview.plan = level.plan
	layer.add_child(overview)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/verification/rescue_full_map.png")
	layer.queue_free()
