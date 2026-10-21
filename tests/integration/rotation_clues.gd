extends SceneTree
## F4b-1: rotating objective regions and the camp → note → region clue chain.
var checks := 0
var failures := 0
var capture := false
var level: Node2D
var player: CampPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	_plan_checks()
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
	level.night_clock.director_enabled = false
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	for attempt in range(240):
		if NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, Vector2(96, 384), level.plan.woods.zones[2]["position"], true).size() > 1:
			break
		await physics_frame
	await _clue_checks()
	root.get_node("Session").select_survivor(previous_role)
	print(JSON.stringify({"event":"test_result","suite":"rotation_clues","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _plan_checks() -> void:
	var used := {}
	var all_ok := true
	for seed_value in range(1, 25):
		var plan := RoundPlan.new()
		plan.generate(seed_value, "woods")
		var again := RoundPlan.new()
		again.generate(seed_value, "woods")
		all_ok = all_ok and plan.cache_zone == again.cache_zone and plan.loot == again.loot
		var directions := {}
		var distinct := {}
		for kind: String in plan.cache_zone:
			var index: int = plan.cache_zone[kind]
			used[index] = true
			distinct[index]=true
			directions[plan.cache_direction[kind]] = true
			all_ok = all_ok and plan.cache_direction[kind]==WoodsLayout.cardinal(plan.woods.zones[index].position)
		all_ok = all_ok and plan.cache_zone.size() == 5 and distinct.size()==5 and plan.cache_zone.has("fuel")
		var notes := plan.loot.filter(func(item: Dictionary) -> bool: return item["kind"] == "ranger_note")
		var notes_ok := notes.size() == 8
		for note: Dictionary in notes:
			var region: Vector2 = plan.woods.zones[plan.cache_zone[note["part"]]]["position"]
			notes_ok = notes_ok and note["part"] != "fuel" and plan.woods.walkable(note["position"]) and plan.woods.zone_at(note["position"]).is_empty()
			notes_ok = notes_ok and note["position"].distance_to(region) < CampMap.CAMP_BOUNDS.get_center().distance_to(region)
		all_ok = all_ok and notes_ok
		if not notes_ok:
			print(JSON.stringify({"event":"note_problem","seed":seed_value,"notes":notes}))
	_check(all_ok, "24_seeds_five_distinct_regions_derived_directions_reproducible_notes_toward_regions")
	_check(used.size() >= 7, "rotation_uses_%d_of_14_regions" % used.size())
	var camp := RoundPlan.new()
	camp.generate(42, "camp")
	_check(camp.cache_zone.is_empty() and not camp.loot.any(func(item: Dictionary) -> bool: return item["kind"] == "ranger_note"), "quick_camp_has_no_rotation_or_notes")


func _clue_checks() -> void:
	var plan: RoundPlan = level.plan
	var extras: Array = plan.cache_zone.keys().filter(func(kind: String) -> bool: return kind != "fuel")
	_check(level.clues["fuel"] == 1 and level.clues[extras[0]] == 0 and level.clues[extras[1]] == 0, "corkboard_names_fuel_others_direction_only")
	await _frames(2)
	var pack: String = level.hud.inventory_label.text
	_check(pack.contains("WOODS? FIND A NOTE") and pack.contains("FUEL / RADIO AT NIGHTFALL · " + WoodsLayout.SIGN_NAMES[plan.woods.zones[plan.cache_zone["fuel"]]["kind"]]), "pack_shows_direction_and_named_fuel")
	var note: CampPickup
	for pickup: CampPickup in level.pickups:
		if pickup.kind == "ranger_note" and pickup.get_meta("part", "") == extras[0]:
			note = pickup
	var path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, Vector2(96, 384), note.position, true)
	_check(path.size() > 1 and path[-1].distance_to(note.position) < 4, "ranger_note_reachable")
	player.position = note.position
	await _frames(2)
	_check(level.context_prompt().contains("RANGER NOTE"), "note_prompt")
	if capture:
		player.flashlight_on = true
		await _snapshot("clue_note")
	_check(level.try_interact(player) and not note.available and level.clues[extras[0]] == 1, "reading_note_names_region")
	_check(level.message.contains(plan.region_name(extras[0])), "note_announced_to_team")
	_check(not extras[0] in player.inventory, "notes_are_not_carried")
	# A sealed part's region: walking in names it but can't mark a cache that isn't there yet.
	var late: String = plan.required[4]
	var zone: Dictionary = plan.woods.zones[plan.cache_zone[late]]
	player.position = NavigationServer2D.map_get_closest_point(level.get_world_2d().navigation_map, zone["position"])
	await physics_frame
	await physics_frame
	_check(level.clues[late] == 1, "entering_sealed_region_names_it")
	var beacon := {"kind": zone["kind"], "label": WoodsLayout.SIGN_NAMES[zone["kind"]], "position": zone["position"]}
	_check(not Skyline.beacon_label(level, beacon).contains(late.replace("_", " ").to_upper()), "skyline_hides_unspawned_part")
	level.night_clock.force_phase(3)
	await physics_frame
	await physics_frame
	_check(level.clues[late] == 2, "revealed_cache_marked_when_standing_in_region")
	_check(Skyline.beacon_label(level, beacon).contains(late.replace("_", " ").to_upper()), "skyline_marks_spawned_known_part")
	await _frames(2)
	_check(level.hud.inventory_label.text.contains("(CACHE MAPPED)"), "pack_marks_mapped_cache")
	if capture:
		level.hud.notebook.open_view("map")
		await _snapshot("clue_pack")


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
