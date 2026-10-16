extends SceneTree
## Pixel evidence: flashlight lights its path but cannot leak across solid borders.
var checks := 0
var failures := 0
var capture := false
var level: Node2D
var lighting: Node2D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await _frames(5)
	level = current_scene
	for enemy in get_nodes_in_group("killers"):
		enemy.enabled = false
	for node in level.get_children():
		if node.get_script() == load("res://scripts/ui/night_overlay.gd"):
			lighting = node
	var occluders := 0
	for node in level.camp_map.get_children():
		if node is LightOccluder2D:
			for wall in level.plan.woods.walls:
				if node.position == wall.position and node.occluder.polygon.has(wall.size):
					occluders += 1
	_check(occluders == level.plan.woods.walls.size(), "every_solid_woods_span_has_full_shadow_polygon")
	for cell: Vector2i in level.plan.woods.links:
		var neighbor := cell + Vector2i.RIGHT
		if level.plan.woods.valid(neighbor) and neighbor not in level.plan.woods.links[cell]:
			var at: Vector2 = level.plan.woods.center(cell)
			if level.clear_path(at, at + Vector2(160, 0)):
				continue
			level.player.position = at + Vector2(42, 0)
			level.player.facing = Vector2.RIGHT
			lighting._process(0.016)
			_check(level.clear_path(level.player.position, lighting.flashlight.global_position), "head_offset_cannot_place_flashlight_inside_border")
			break
	if capture:
		await _render_cases()
	print(JSON.stringify({"event": "test_result", "suite": "woods_shadows", "checks": checks, "failures": failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)

func _render_cases() -> void:
	level.sight.enabled = false
	level.sight.hide()
	level.message_time = 0
	# Disable other light sources to measure only the flashlight contribution.
	_disable_lights(level)
	lighting.flashlight.enabled = true
	lighting.set_process(false)
	var cases := 0
	for cell: Vector2i in level.plan.woods.links:
		for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if not level.plan.woods.valid(next) or next in level.plan.woods.links[cell]:
				continue
			var from: Vector2 = level.plan.woods.center(cell)
			var to: Vector2 = level.plan.woods.center(next)
			if not level.plan.woods.zone_at(from).is_empty() or not level.plan.woods.zone_at(to).is_empty() or level.clear_path(from, to):
				continue
			level.player.position = from
			level.player.set_physics_process(false)
			var facing := Vector2(direction)
			# Use the production flashlight transform, preserving body/head offset.
			lighting.flashlight.position = Vector2(0, -12) + facing * 8
			lighting.flashlight.rotation = facing.angle()
			lighting.flashlight.texture_scale = level.config.flashlight_range / 128.0
			level.player.get_node("Camera2D").offset = facing * 40
			await _frames(3)
			lighting.flashlight.enabled = false
			var dark := await _image()
			lighting.flashlight.enabled = true
			var lit := await _image()
			var screen: Vector2 = level.player.get_global_transform_with_canvas().origin
			var near_point := Vector2i(screen + facing * 30 + Vector2(0, -12))
			var far_point := Vector2i(screen + facing * 136 + Vector2(0, -12))
			var near_gain := _patch(lit, near_point) - _patch(dark, near_point)
			var far_gain := _patch(lit, far_point) - _patch(dark, far_point)
			_check(near_gain > 0.025 and far_gain < 0.003, "own_path_lit_adjacent_path_blocked_%d" % cases)
			# Positive control: disabling these borders reproduces light leakage.
			for node in level.camp_map.get_children():
				if node is LightOccluder2D:
					node.visible = false
			var leaking := await _image()
			var leak_gain := _patch(leaking, far_point) - _patch(dark, far_point)
			_check(leak_gain > far_gain + 0.003, "unblocked_control_proves_probe_inside_beam_%d" % cases)
			for node in level.camp_map.get_children():
				if node is LightOccluder2D:
					node.visible = true
			if cases == 0:
				_check(lit.save_png("res://artifacts/verification/woods_border_blocked.png") == OK, "capture_blocked_border")
				_check(leaking.save_png("res://artifacts/verification/woods_border_control.png") == OK, "capture_unblocked_control")
			print(JSON.stringify({"event": "shadow_measurement", "near_gain": near_gain, "far_gain": far_gain, "unblocked_gain": leak_gain, "direction": direction}))
			cases += 1
			if cases >= 4:
				return
	_check(cases >= 4, "four_shadow_cases_available")

func _disable_lights(parent: Node) -> void:
	for node in parent.get_children():
		if node is PointLight2D:
			node.enabled = false
		_disable_lights(node)

func _patch(img: Image, point: Vector2i) -> float:
	var value := 0.0
	for y in range(-2, 3):
		for x in range(-2, 3):
			value += img.get_pixelv(point + Vector2i(x, y)).get_luminance()
	return value / 25

func _image() -> Image:
	await process_frame
	RenderingServer.force_draw(true)
	return root.get_texture().get_image()

func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func _check(passed: bool, label: String) -> void:
	checks += 1
	failures += 0 if passed else 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": passed}))
