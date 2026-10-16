extends SceneTree
## Layout/boarding regressions and a graphical art/lighting inspection tour.

var checks: int = 0
var failures: int = 0
var level: Node2D
var player: CampPlayer
var capture: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await _frames(4)
	level = current_scene
	player = level.player
	level.killer.enabled = false
	for attempt in range(240):
		var ready_path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, player.position, CampMap.PICKUP_POSITIONS[0], true)
		if ready_path.size() > 1:
			break
		await physics_frame
	_check(CampMap.WORLD_SIZE.x * CampMap.WORLD_SIZE.y == 4.0 * 768 * 480, "map_has_four_times_original_area")
	_check(level.camp_map.buildings.size() == 10, "ten_authored_buildings")
	_check(level.camp_map.trees.size() > 100, "dense_forest_layout")
	_check(level.camp_map.get_node("GroundTiles") is TileMapLayer, "native_pixel_tile_ground")
	for pickup: CampPickup in level.pickups:
		var path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, player.global_position, pickup.global_position, true)
		_check(path.size() > 1 and path[-1].distance_to(pickup.global_position) < 4, "reachable_" + pickup.kind)
	for building: CampBuilding in level.camp_map.buildings:
		var destination := building.door - Vector2(0, 36)
		var path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, player.global_position, destination, true)
		_check(path.size() > 1 and path[-1].distance_to(destination) < 8, "entrance_reachable_" + building.kind)
	var lodge: CampBuilding = level.camp_map.buildings[6]
	player.position = Vector2(592, 784)
	await _frames(20)
	_check(lodge.roof.modulate.a < 0.05, "roof_cuts_away_inside_lodge")
	player.position = Vector2(600, 872)
	await _frames(20)
	_check(lodge.roof.modulate.a > 0.95, "roof_restores_outside_lodge")
	if capture:
		await _tour()
	await _boarding()
	print(JSON.stringify({"event": "test_result", "suite": "camp_upgrade", "checks": checks, "failures": failures}))
	quit(0 if failures == 0 else 1)


func _boarding() -> void:
	player.position = level.van.interaction_point()
	await _frames(2)
	_check(not level.van.board(player), "cannot_board_before_engine_starts")
	level.van.installed.assign(CampVan.PARTS)
	level.van.advance_start(player, true, level.config.start_hold_seconds)
	var other: CampPlayer = load("res://scenes/actors/player.tscn").instantiate()
	other.local_input = false
	other.position = Vector2(360, 300)
	level.world_objects.add_child(other)
	_check(not level.van.board(other), "distant_boarding_rejected")
	_check(level.try_interact(player), "e_interaction_boards_nearby_survivor")
	_check(player.status == CampPlayer.Status.BOARDED, "boarding_status_explicit")
	_check(not level.van.board(player), "duplicate_boarding_rejected")
	other.position = level.van.global_position + Vector2(-30, 4)
	await _frames(2)
	_check(level.try_interact(other), "second_survivor_boards_at_side_door")
	_check(level.van.passengers.size() == 2, "two_passengers_counted_once")
	var standby: CampPlayer = load("res://scenes/actors/player.tscn").instantiate()
	standby.local_input = false
	standby.position = level.van.interaction_point() + Vector2(12, 0)
	level.world_objects.add_child(standby)
	standby.set_status(CampPlayer.Status.DOWNED)
	_check(not level.van.board(standby), "downed_survivor_cannot_board")
	standby.set_status(CampPlayer.Status.ALIVE)
	player.receive_hit()
	other.receive_hit()
	_check(player.status == CampPlayer.Status.BOARDED and other.status == CampPlayer.Status.BOARDED, "passengers_cannot_be_downed")
	var before := player.position
	Input.action_press("move_right")
	await _frames(10)
	Input.action_release("move_right")
	_check(player.position == before, "passenger_cannot_walk_out_of_van")
	if capture:
		await _snapshot("upgrade_boarded")
	await _frames(ceili(level.config.extraction_seconds * 60) + 10)
	_check(level.won and player.status == CampPlayer.Status.ESCAPED and other.status == CampPlayer.Status.ESCAPED, "all_boarded_survivors_extract")
	_check(standby.status == CampPlayer.Status.LEFT_BEHIND, "standing_near_van_does_not_silently_count_as_boarding")


func _tour() -> void:
	player.position = Vector2(112, 366)
	player.facing = Vector2.RIGHT
	await _frames(20)
	await _snapshot("upgrade_campsite")
	player.position = Vector2(592, 720)
	player.facing = Vector2.UP
	await _frames(20)
	await _snapshot("upgrade_lodge")
	player.position = Vector2(1300, 316)
	player.facing = Vector2.UP
	await _frames(20)
	await _snapshot("upgrade_workshop")
	player.position = Vector2(944, 420)
	player.facing = Vector2.UP
	await _frames(20)
	await _snapshot("upgrade_mess_hall")
	player.position = Vector2(368, 736)
	player.facing = Vector2.UP
	await _frames(20)
	await _snapshot("upgrade_bathhouse")
	player.position = Vector2(1312, 856)
	player.facing = Vector2.UP
	await _frames(20)
	await _snapshot("upgrade_lakeshore")
	level.hud.inventory_label.show()
	level.hud.chart.show()
	await _frames(2)
	await _snapshot("upgrade_field_map")
	level.hud.inventory_label.hide()
	level.hud.chart.hide()
	player.position = Vector2(360, 300)
	player.facing = Vector2.RIGHT
	player.flashlight_on = true
	await _frames(5)
	var lit := await _snapshot("upgrade_flashlight_on")
	player.flashlight_on = false
	await _frames(5)
	var dark := await _snapshot("upgrade_flashlight_off")
	var screen := player.get_global_transform_with_canvas().origin
	var probe := Vector2i(screen + Vector2(70, -12))
	var on_brightness := lit.get_pixelv(probe).get_luminance()
	var off_brightness := dark.get_pixelv(probe).get_luminance()
	print(JSON.stringify({"event": "lighting_measurement", "on": on_brightness, "off": off_brightness}))
	_check(on_brightness > off_brightness * 2.0 + 0.02, "flashlight_materially_lights_world")
	_check(off_brightness < 0.06, "unlit_forest_is_much_darker")
	player.flashlight_on = true
	player.facing = Vector2.UP
	level.killer.position = player.position + Vector2(10, -42)
	level.killer.facing = Vector2.DOWN
	await _frames(5)
	await _snapshot("upgrade_characters")


func _snapshot(label: String) -> Image:
	await process_frame
	RenderingServer.force_draw(true)
	var result := root.get_texture().get_image()
	_check(result.save_png("res://artifacts/verification/%s.png" % label) == OK, "capture_" + label)
	return result


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": condition}))
