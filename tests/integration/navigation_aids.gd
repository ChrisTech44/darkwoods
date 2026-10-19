extends SceneTree
## F1 navigation: signposts, skyline markers, wall-map regions, team pins and spare lock tools.
var checks := 0
var failures := 0
var capture := false
var level: Node2D
var player: CampPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	_signpost_checks()
	_skyline_math()
	var previous_role: String = root.get_node("Session").survivor
	root.get_node("Session").survivor = "john"
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	while current_scene == null or current_scene.name != "ForestLevel":
		await process_frame
	level = current_scene
	player = level.player
	player.local_input = false
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	await _frames(4)
	await _level_checks()
	await _tool_checks()
	await _pin_checks()
	if capture:
		await _captures()
	root.get_node("Session").select_survivor(previous_role)
	print(JSON.stringify({"event":"test_result","suite":"navigation_aids","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _signpost_checks() -> void:
	for seed_value in [1, 42, 2026, 76543]:
		var woods := WoodsLayout.new()
		woods.generate(seed_value)
		var again := WoodsLayout.new()
		again.generate(seed_value)
		_check(woods.signposts == again.signposts, "seed_%d_signposts_reproducible" % seed_value)
		_check(woods.signposts.size() >= 60, "seed_%d_signposts_cover_the_woods_%d" % [seed_value, woods.signposts.size()])
		# Independent distance fields: every arrow must lead one trail step closer to its place.
		var to_camp := woods.distances_from_many(WoodsLayout.ENTRIES)
		var fields: Array[Dictionary] = []
		for zone in woods.zones:
			fields.append(woods.distances_from(zone["cell"]))
		var honest := true
		var spaced := true
		var clear := true
		for post: Dictionary in woods.signposts:
			var cell: Vector2i = post["cell"]
			clear = clear and woods.walkable(post["position"]) and woods.zone_at(post["position"]).is_empty()
			for other: Dictionary in woods.signposts:
				if other != post and other["position"].distance_to(post["position"]) < WoodsLayout.SIGN_SPACING:
					spaced = false
			for target: Dictionary in post["targets"]:
				var next: Vector2i = cell + target["step"]
				if target["label"] == "CAMP":
					honest = honest and (to_camp[cell] == 0 and WoodsLayout.CAMP_CELLS.has_point(next) or next in woods.links[cell] and to_camp[next] < to_camp[cell])
				else:
					var field: Dictionary = fields[target["zone"]]
					honest = honest and next in woods.links[cell] and field[next] < field[cell]
		_check(honest, "seed_%d_every_sign_arrow_follows_a_shortest_trail" % seed_value)
		_check(spaced and clear, "seed_%d_signs_spaced_on_open_trail_outside_regions" % seed_value)


func _skyline_math() -> void:
	var view := Vector2(384, 216)
	var inside := Vector2(200, 100)
	_check(Skyline.edge_point(inside, view) == inside, "skyline_on_screen_marker_stays_in_place")
	for far in [Vector2(5000, 100), Vector2(-3000, -4000), Vector2(192, 9000), Vector2(-50, 108)]:
		var at := Skyline.edge_point(far, view)
		_check(Skyline.EDGE.grow(0.01).has_point(at), "skyline_edge_clamp_%s" % far)
		_check((at - view * 0.5).normalized().dot((far - view * 0.5).normalized()) > 0.999, "skyline_edge_keeps_bearing_%s" % far)
	var plan := RoundPlan.new()
	plan.generate(42, "woods")
	var from: Vector2 = plan.woods.zones[1]["position"] + Vector2(-700, 0)
	var list := Skyline.beacons(plan, from)
	_check(list[0]["kind"] == "camp" and list.size() <= 1 + Skyline.MAX_LANDMARKS, "skyline_camp_plus_bounded_landmarks")
	var bounded := true
	for beacon in list.slice(1):
		bounded = bounded and from.distance_to(beacon["position"]) <= Skyline.RANGE
	_check(bounded and list.any(func(beacon: Dictionary) -> bool: return beacon["kind"] == "bog"), "skyline_shows_only_nearby_tall_regions")


func _level_checks() -> void:
	var post: Dictionary = level.plan.woods.signposts[0]
	player.position = post["position"] + Vector2(0, 24)
	await _frames(3)
	_check(level.hud.location_label.text.begins_with("SIGNPOST · CAMP"), "standing_at_sign_reads_directions")
	_check(level.hud.chart.level == level, "field_map_receives_level_for_pins")
	var skyline: Skyline
	for child in level.hud.root.get_children():
		if child is Skyline:
			skyline = child
	_check(skyline != null and skyline.get_index() == 0, "skyline_drawn_beneath_hud_text")


func _tool_checks() -> void:
	level.night_clock.reveal_all()
	var cutters: Array[CampPickup] = []
	var crowbar: CampPickup
	var cache: CampPickup
	for pickup: CampPickup in level.pickups:
		if pickup.kind == "boltcutters":
			cutters.append(pickup)
		elif pickup.kind == "crowbar":
			crowbar = pickup
		elif pickup.locked and cache == null:
			cache = pickup
	_check(cutters.size() == 2 and cutters.filter(func(p: CampPickup) -> bool: return CampMap.is_woods(p.position)).size() == 1, "one_camp_and_one_woods_boltcutters")
	_check(crowbar != null and not CampMap.is_woods(crowbar.position), "crowbar_in_camp")
	for pickup in [cutters[0], cutters[1], crowbar]:
		var path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, Vector2(96, 384), pickup.position, true)
		_check(path.size() > 1 and path[-1].distance_to(pickup.position) < 4, "spare_tool_reachable_%s_%d" % [pickup.kind, pickup.get_index()])
	player.position = crowbar.position
	await _frames(2)
	_check(level.try_interact(player) and "crowbar" in player.inventory, "crowbar_collected")
	# Crowbar opens a locked cache, loudly enough to pull a distant listener.
	var listener: CampKiller = level.killer
	listener.position = cache.position + Vector2(420, 0)
	listener.enabled = true
	listener.state = CampKiller.State.PATROL
	player.position = cache.position
	await _frames(2)
	_check(level.context_prompt().contains("PRY CACHE"), "crowbar_prompt_warns_noise")
	var part: String = cache.kind
	_check(level.try_interact(player) and part in player.inventory and not cache.available, "crowbar_pries_locked_cache")
	_check(listener.state == CampKiller.State.INVESTIGATE, "pried_cache_noise_reaches_420px")
	listener.enabled = false
	player.position = cutters[0].position
	await _frames(2)
	_check(level.try_interact(player) and "boltcutters" in player.inventory, "first_cutters_collected")
	player.position = cutters[1].position
	await _frames(2)
	_check(not level.try_interact(player) and cutters[1].available, "second_cutters_left_for_teammate")
	_check(level.plan.toolbox_hint.length() in [1, 2], "toolbox_bearing_hint_%s" % level.plan.toolbox_hint)


func _pin_checks() -> void:
	player.position = level.plan.woods.zones[1]["position"]
	await _frames(2)
	await _tap(KEY_M)
	_check(level.pins.size() == 1 and level.pins[0]["place"] == "WITCH'S BOG", "m_key_pins_named_place")
	for index in range(3):
		player.position += Vector2(0, 40)
		await _tap(KEY_M)
	_check(level.pins.size() == Skyline.PIN_COLORS.size() - 1 and level.pins[0]["position"] != level.plan.woods.zones[1]["position"].round(), "pins_capped_at_three_oldest_replaced")
	player.set_status(CampPlayer.Status.DOWNED)
	_check(not level.place_pin(player, 1, "You"), "downed_survivor_cannot_pin")
	player.set_status(CampPlayer.Status.ALIVE)


func _captures() -> void:
	level.sight.enabled = true
	var post: Dictionary = level.plan.woods.signposts[3]
	player.position = post["position"] + Vector2(40, 8)
	player.facing = Vector2.LEFT
	player.flashlight_on = true
	await _frames(6)
	await _snapshot("nav_signpost")
	player.position = level.plan.woods.zones[1]["position"] + Vector2(-900, 0)
	player.position = NavigationServer2D.map_get_closest_point(level.get_world_2d().navigation_map, player.position)
	await _frames(6)
	await _snapshot("nav_skyline")
	level.hud.notebook.open_view("map")
	await _frames(4)
	await _snapshot("nav_field_map")


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _tap(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)


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
