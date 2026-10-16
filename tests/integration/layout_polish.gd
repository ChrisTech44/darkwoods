extends SceneTree
## Native navigation across seeded camps; reservations and graphically inspected lots.
var checks := 0
var failures := 0
var capture := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	var signatures := {}
	for value in [1, 7, 42, 99, 2026, 6789, 12345, 76543]:
		var a := CampLayout.new()
		var b := CampLayout.new()
		a.generate(value, true)
		b.generate(value, true)
		_check(a.signature() == b.signature(), "seed_%d_camp_reproducible" % value)
		signatures[a.signature()] = true
		var quick := RoundPlan.new()
		quick.generate(value, "camp")
		_check(quick.camp.signature() == a.signature(), "seed_%d_both_modes_use_random_camp" % value)
		for index in range(a.entries.size()):
			var rect: Rect2 = a.entries[index][0]
			var clear := true
			for road in a.roads:
				clear = clear and not rect.intersects(road)
			for other in range(a.entries.size()):
				if other != index:
					clear = clear and not rect.grow(10).intersects(a.entries[other][0])
			_check(clear, "seed_%d_building_%d_clear_of_paths_and_roofs" % [value, index])
		root.get_node("Session").mode = "woods"
		root.get_node("Session").next_seed = value
		change_scene_to_file("res://scenes/world/forest_level.tscn")
		await process_frame
		await physics_frame
		var level: Node2D = current_scene
		for enemy in get_nodes_in_group("killers"):
			enemy.enabled = false
		for attempt in range(240):
			await physics_frame
			if _reachable(level, level.plan.loot[0]["position"]):
				break
		NavigationServer2D.map_force_update(level.get_world_2d().navigation_map)
		for building in level.camp_map.buildings:
			var goal: Vector2 = building.door - Vector2(0, 36)
			_check(_reachable(level, goal), "seed_%d_door_%s_reachable" % [value, building.label])
		for item in level.pickups:
			_check(_reachable(level, item.position), "seed_%d_loot_%s_reachable" % [value, item.kind])
		if capture and value in [42, 2026]:
			level.player.position = Vector2(768, 440)
			level.sight.enabled = false
			level.sight.hide()
			level.player.get_node("Camera2D").zoom = Vector2(0.24, 0.24)
			for child in level.get_children():
				if child.get_script() == load("res://scripts/ui/night_overlay.gd"):
					child.set_process(false)
					child.ambient.color = Color(0.55, 0.55, 0.55)
			for frame in range(30):
				await physics_frame
			await process_frame
			RenderingServer.force_draw(true)
			_check(root.get_texture().get_image().save_png("res://artifacts/verification/camp_layout_%d.png" % value) == OK, "capture_seed_%d" % value)
	_check(signatures.size() == 8, "eight_different_camp_layouts")
	print(JSON.stringify({"event": "test_result", "suite": "layout_polish", "checks": checks, "failures": failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)

func _reachable(level: Node2D, goal: Vector2) -> bool:
	var path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, level.player.position, goal, true)
	return path.size() > 1 and path[-1].distance_to(goal) < 4

func _check(passed: bool, label: String) -> void:
	checks += 1
	failures += 0 if passed else 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": passed}))
