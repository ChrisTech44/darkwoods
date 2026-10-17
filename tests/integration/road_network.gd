extends SceneTree
## F4a: ring road and spokes. Determinism, clear surfaces, lit inner roads on camp
## power, field-map printing and measured walking times along native navigation.
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
	await _surface_checks()
	await _travel_checks()
	await _lamp_checks()
	if capture:
		await _captures()
	root.get_node("Session").select_survivor(previous_role)
	print(JSON.stringify({"event":"test_result","suite":"road_network","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _layout_checks() -> void:
	var first := WoodsLayout.new()
	first.generate(1)
	for seed_value in [42, 2026]:
		var woods := WoodsLayout.new()
		woods.generate(seed_value)
		# Same roads every night; lamps skip region clearings, which shift a cell per seed.
		_check(woods.roads == first.roads and absi(woods.lamps.size() - first.lamps.size()) <= 3, "seed_%d_same_road_network_every_night" % seed_value)
		_check(woods.links.size() == 2410 and woods.distances_from(WoodsLayout.ENTRY).size() == 2410, "seed_%d_all_clearings_still_connected" % seed_value)
	var ring := 0
	for cell: Vector2i in first.road_cells:
		if cell.x in [WoodsLayout.RING.position.x, WoodsLayout.RING.end.x] or cell.y in [WoodsLayout.RING.position.y, WoodsLayout.RING.end.y]:
			ring += 1
	_check(ring >= 60, "ring_road_loops_camp_%d_cells" % ring)
	for index in range(4):
		var edge: Vector2i = WoodsLayout.ENTRIES[index]
		var reached_edge := false
		for cell: Vector2i in first.road_cells:
			if (index < 2 and cell.y == edge.y and cell.x in [1, WoodsLayout.SIZE.x - 2]) or (index >= 2 and cell.x == edge.x and cell.y in [1, WoodsLayout.SIZE.y - 2]):
				reached_edge = true
		_check(reached_edge, "spoke_%d_reaches_map_edge" % index)
	var linked := true
	for road: Rect2 in first.roads:
		var a := first.cell_at(road.get_center() - (road.size - Vector2.ONE * WoodsLayout.CELL).max(Vector2.ZERO) * 0.5 * Vector2(1 if road.size.x > road.size.y else 0, 1 if road.size.y > road.size.x else 0))
		linked = linked and first.road_cells.has(a)
	_check(linked and first.lamps.size() >= 25, "roads_on_road_cells_and_%d_lamps" % first.lamps.size())
	# Paths lose clearance where a wall edge lies exactly on a nav chunk seam.
	var seams_x := {}
	var seams_y := {}
	for step in range(0, 9):
		seams_x[CampMap.nav_seam_start(0) + CampMap.NAV_CHUNK * step] = true
		seams_y[CampMap.nav_seam_start(1) + CampMap.NAV_CHUNK * step] = true
	# Gameplay targets (stalker patrol line, test exits) must sit outside the 14px off-mesh seam strip.
	for target in [Vector2(96, 520), Vector2(600, 520), Vector2(96, 384), Vector2(96, 300)]:
		var clear := true
		for seam: int in seams_y:
			clear = clear and absf(target.y - seam) > 8
		for seam: int in seams_x:
			clear = clear and absf(target.x - seam) > 8
		_check(clear, "target_%d_%d_off_seam_strip" % [target.x, target.y])
	_check(seams_x.has(CampMap.NAV_SEAM.x) and seams_y.has(CampMap.NAV_SEAM.y) and CampMap.nav_seam_start(0) <= int(WoodsLayout.WORLD_BOUNDS.position.x), "nav_seams_run_down_camp_road_centres")
	for seed_value in [1, 3, 42]:
		var woods := WoodsLayout.new()
		woods.generate(seed_value)
		var on_seam := 0
		for wall: Rect2 in woods.walls:
			if seams_x.has(int(wall.position.x)) or seams_x.has(int(wall.end.x)) or seams_y.has(int(wall.position.y)) or seams_y.has(int(wall.end.y)):
				if WoodsLayout.WORLD_BOUNDS.grow(-1).intersects(wall):
					on_seam += 1
		_check(on_seam == 0, "seed_%d_no_woods_wall_edge_on_nav_seam_%d" % [seed_value, on_seam])
	var objectives := 0
	for zone in first.zones.slice(0, 3):
		for cell: Vector2i in first.road_cells:
			if zone["bounds"].has_point(first.center(cell)):
				objectives += 1
				break
	_check(objectives == 3, "ring_passes_through_all_three_objective_regions")


func _surface_checks() -> void:
	var woods: WoodsLayout = level.plan.woods
	var clear := true
	var paved := true
	var segments := 0
	for road: Rect2 in woods.roads:
		var middle := road.get_center()
		if not woods.zone_at(middle).is_empty():
			continue
		var long := road.size.x > road.size.y
		var from := middle - (Vector2(road.size.x * 0.5 - 70, 0) if long else Vector2(0, road.size.y * 0.5 - 70))
		var to := middle + (Vector2(road.size.x * 0.5 - 70, 0) if long else Vector2(0, road.size.y * 0.5 - 70))
		if not woods.zone_at(from).is_empty() or not woods.zone_at(to).is_empty():
			continue
		segments += 1
		for lane in [-50, 0, 50]:
			var shift := Vector2(0, lane) if long else Vector2(lane, 0)
			clear = clear and level.clear_path(from + shift, to + shift)
		paved = paved and woods.on_road(middle)
	_check(segments >= 100 and clear, "road_surfaces_clear_three_lanes_wide_%d_segments" % segments)
	_check(paved, "road_tiles_marked_outside_regions")


func _travel_checks() -> void:
	var start := Vector2(768, 520)
	var map := level.get_world_2d().navigation_map
	for zone in level.plan.woods.zones:
		var path := NavigationServer2D.map_get_path(map, start, NavigationServer2D.map_get_closest_point(map, zone["position"]), true)
		var length := 0.0
		for index in range(1, path.size()):
			length += path[index - 1].distance_to(path[index])
		var seconds: float = length / level.config.walk_speed
		print(JSON.stringify({"event":"travel_time","zone":zone["kind"],"pixels":int(length),"walk_seconds":snappedf(seconds, 0.1)}))
		if zone["kind"] in ["village", "bog", "graveyard"]:
			_check(path.size() > 1 and seconds <= 60.0, "walk_to_%s_under_60s_%ds" % [zone["kind"], int(seconds)])


func _lamp_checks() -> void:
	var lamps: Array[PointLight2D] = level.camp_map.camp_lamps
	var road_lamps := 0
	for lamp in lamps:
		if CampMap.is_woods(lamp.position):
			road_lamps += 1
	_check(road_lamps == level.plan.woods.lamps.size(), "road_lamps_on_camp_power_%d" % road_lamps)
	level.night_clock._start_event("blackout")
	await _frames(2)
	_check(lamps.all(func(lamp: PointLight2D) -> bool: return not lamp.enabled), "blackout_darkens_roads_too")
	level.night_clock.blackout = false
	await _frames(2)
	_check(lamps.all(func(lamp: PointLight2D) -> bool: return lamp.enabled), "road_lamps_return_with_power")


func _captures() -> void:
	var lamp: Vector2 = level.plan.woods.lamps[6]
	player.position = NavigationServer2D.map_get_closest_point(level.get_world_2d().navigation_map, lamp + Vector2(0, 40))
	player.facing = Vector2.UP
	player.flashlight_on = false
	await _frames(6)
	_check(level.hud.location_label.text == "THE WOODS / LIT ROAD", "location_reads_lit_road")
	await _snapshot("roads_lit_ring")
	level.hud.inventory_label.visible = true
	level.hud.chart.visible = true
	await _frames(4)
	await _snapshot("roads_field_map")
	level.hud.inventory_label.visible = false
	level.hud.chart.visible = false


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
