extends SceneTree
## Building plaques, place titles, short names and the skyline layout pass.
## Staged: seed 42, enemies frozen, night clock stopped.
var level: Node2D
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": name, "passed": ok}))

func _frames(count: int) -> void:
	for index in range(count):
		await process_frame
		await physics_frame

func _run() -> void:
	RoundPlan.force_modifiers = []
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await _frames(12)
	level = current_scene
	level.player.local_input = false
	for enemy in get_nodes_in_group("killers"):
		enemy.enabled = false
	level.night_clock.set_physics_process(false)
	# Plaques: outside the roof (bounds grown 8) and the porch awning (door ±24).
	var clear := true
	for building: CampBuilding in level.camp_map.buildings:
		var board := building.plaque_rect()
		var awning := Rect2(building.door - Vector2(24, -2), Vector2(48, 13))
		if board.intersects(building.bounds.grow(8)) or board.intersects(awning):
			clear = false
	_check(clear, "plaques_clear_of_roof_and_awning")
	_check(level.camp_map.buildings.any(func(building: CampBuilding) -> bool: return building.label == "CAMP BOATHOUSE"), "camp_boathouse_named_apart")
	# Short names come from the full names (no DOME/GRAVES/RAILS).
	var readable := true
	for zone: Dictionary in level.plan.woods.zones:
		var short: String = WoodsLayout.SIGN_NAMES[zone["kind"]]
		var first_word := short.split(" ")[0]
		if not zone["label"].contains(first_word) and not (zone["kind"] == "ranger" and short == "RANGER GATE"):
			readable = false
			print(JSON.stringify({"short": short, "label": zone["label"]}))
	_check(readable, "short_names_match_full_names")
	# Place title: entering a building announces it once, after settling.
	var cast: NightBroadcast = level.hud.broadcast
	var workshop: CampBuilding = level.camp_map.buildings.filter(func(building: CampBuilding) -> bool: return building.label == "MAINTENANCE")[0]
	# Let the spawn place settle first (the opening place is never titled).
	await _frames(40)
	level.player.position = workshop.bounds.get_center()
	await _frames(50)
	_check(cast.place_title == "MAINTENANCE" and cast.place_time >= 0.0, "entering_building_shows_title")
	_check(level.hud.location_label.text == "MAINTENANCE", "location_names_building")
	level.player.position = workshop.door + Vector2(0, 30)
	await _frames(10)
	_check(level.hud.location_label.text == "OUTSIDE MAINTENANCE", "location_names_door_approach")
	level.player.position = workshop.bounds.get_center()
	await _frames(50)
	_check(cast.place_title == "MAINTENANCE" and cast.place_seen.has("MAINTENANCE"), "doorstep_does_not_repeat_title")
	# Skyline: a crowded set never overlaps labels; stacked icons merge.
	var view := Vector2(384, 216)
	var markers: Array[Dictionary] = []
	for index in range(8):
		markers.append({"point": Vector2(600, 100 + index * 3), "kind": "pin", "label": "PIN %d" % index, "color": Color.WHITE, "priority": 2})
	markers.append({"point": Vector2(600, 95), "kind": "help", "label": "HELP SAM", "color": Color.RED, "priority": 0})
	for index in range(5):
		markers.append({"point": Vector2(150 + index * 18, -400), "kind": "village", "label": "OBSERVATORY · FUSE", "color": Color.WHITE, "priority": 3})
	var placed := Skyline.layout(markers, view)
	var rects: Array[Rect2] = []
	var overlap := false
	for marker in placed:
		var rect: Rect2 = marker["label_rect"]
		if rect.has_area():
			if rects.any(func(other: Rect2) -> bool: return other.intersects(rect)):
				overlap = true
			rects.append(rect)
	_check(not overlap, "skyline_labels_never_overlap")
	var help: Array = placed.filter(func(marker: Dictionary) -> bool: return marker["kind"] == "help")
	_check(help.size() == 1 and help[0]["extra"] >= 1 and help[0]["label_rect"].has_area(), "help_wins_and_merges_stack")
	_check(rects.all(func(rect: Rect2) -> bool: return rect.position.y >= Skyline.EDGE.position.y - 2.0), "skyline_labels_stay_out_of_top_hud")
	# The place title box is off-limits to optional skyline labels.
	var box := Rect2(130, 118, 124, 25)
	var low: Array[Dictionary] = [{"point": Vector2(192, 600), "kind": "mill", "label": "LOGGING CAMP", "color": Color.WHITE, "priority": 3}]
	var kept := Skyline.layout(low, view, [box])
	_check(kept.size() == 1 and not kept[0]["label_rect"].intersects(box), "skyline_avoids_place_title")
	print(JSON.stringify({"event": "test_result", "suite": "world_labels", "checks": checks, "failures": failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)
