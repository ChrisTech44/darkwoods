extends SceneTree
## Seed/topology, native navigation, isolated rule fixtures, and real rendered tour.

var checks: int = 0
var failures: int = 0
var level: Node2D
var player: CampPlayer
var capture: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	_seed_checks()
	var session: Node = root.get_node("Session")
	session.mode = "woods"
	session.next_seed = 42
	session.load_game()
	while current_scene == null or current_scene.name != "LoadingScreen":
		await process_frame
	if capture:
		current_scene.set_process(false)
		await _snapshot("woods_loading")
		current_scene.set_process(true)
	await _wait_world()
	await _navigation_checks()
	await _rules()
	if capture:
		await _tour()
	var signature: String = level.plan.woods.signature()
	level.retry_round()
	await process_frame
	await _wait_world()
	_check(level.plan.seed_value == 42 and level.plan.woods.signature() == signature, "retry_preserves_seed_and_maze")
	_check(get_nodes_in_group("survivors").size() == 1 and get_nodes_in_group("cryptids").size() == 4 and get_nodes_in_group("flares").is_empty() and get_nodes_in_group("hazards").is_empty(), "retry_frees_old_actors_and_flares")
	level.restart_round()
	await process_frame
	await _wait_world()
	_check(level.plan.seed_value != 42 and level.plan.woods.signature() != signature, "another_night_selects_new_seed_and_maze")
	# A second explicit topology is baked and checked in the native physics world.
	session.next_seed = 2026
	session.load_game()
	await process_frame
	await _wait_world()
	await _navigation_checks()
	level.return_to_menu()
	await _frames(3)
	_check(current_scene.name == "MainMenu" and get_nodes_in_group("killers").is_empty() and get_nodes_in_group("survivors").is_empty(), "woods_menu_return_cleans_up")
	print(JSON.stringify({"event": "test_result", "suite": "woods_replay", "checks": checks, "failures": failures}))
	quit(0 if failures == 0 else 1)


func _seed_checks() -> void:
	var previous := ""
	var found_species: Dictionary = {}
	var found_weather: Dictionary = {}
	for seed_value in [1, 7, 42, 99, 2026, 6789, 12345, 76543]:
		var a := RoundPlan.new()
		var b := RoundPlan.new()
		a.generate(seed_value, "woods")
		b.generate(seed_value, "woods")
		_check(a.woods.signature() == b.woods.signature() and a.loot == b.loot and a.encounters == b.encounters, "seed_%d_reproducible" % seed_value)
		_check(a.woods.signature() != previous, "seed_%d_changes_trails" % seed_value)
		previous = a.woods.signature()
		_check(a.woods.links.size() == 100 and a.woods.distances_from(WoodsLayout.ENTRY).size() == 100, "seed_%d_all_100_clearings_connected" % seed_value)
		_check(a.woods.landmarks.size() == 6, "seed_%d_six_spaced_landmarks" % seed_value)
		_check(a.required.size() == 5, "seed_%d_five_part_repair" % seed_value)
		var counts: Dictionary = {}
		var locked := 0
		for item in a.loot:
			counts[item["kind"]] = counts.get(item["kind"], 0) + 1
			if item["locked"]:
				locked += 1
		for kind in a.required:
			_check(counts[kind] == 1, "seed_%d_one_%s" % [seed_value, kind])
		_check(locked == 3 and counts["boltcutters"] == 1 and counts["battery_pack"] == 5, "seed_%d_cache_tools_and_supplies" % seed_value)
		_check(a.encounters.size() == 4 and a.encounters[0]["species"] == "vampire" and a.encounters[1]["species"] == "witch" and a.encounters[2]["species"] != a.encounters[3]["species"], "seed_%d_four_distinct_cryptids" % seed_value)
		_check(a.woods.zones.size() == 3 and a.woods.zones[0]["bounds"].size == Vector2(416,256), "seed_%d_three_expanded_sites" % seed_value)
		for encounter in a.encounters:
			found_species[encounter["species"]] = true
		found_weather[a.weather] = true
	_check(found_species.size() == 6 and found_weather.size() == 3, "seeds_vary_all_creatures_and_weather")


func _wait_world() -> void:
	while current_scene == null or current_scene.name != "ForestLevel":
		await process_frame
	level = current_scene
	player = level.player
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	for attempt in range(240):
		var path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, player.position, WoodsLayout.ORIGIN + Vector2(80, 400), true)
		if path.size() > 1:
			break
		await physics_frame


func _navigation_checks() -> void:
	_check(get_nodes_in_group("cryptids").size() == 4 and get_nodes_in_group("killers").size() == 5, "night_%d_five_enemies" % level.plan.seed_value)
	for enemy: CampKiller in get_nodes_in_group("killers"):
		var sight: float = 150
		var hearing: float = 220
		if enemy is CampCryptid:
			sight = {"werewolf": 125.0, "bigfoot": 95.0, "lantern_moth": 220.0, "vampire":165.0, "witch":190.0, "briar_revenant":155.0}[enemy.species]
			hearing = {"werewolf": 210.0, "bigfoot": 300.0, "lantern_moth": 80.0, "vampire":190.0, "witch":210.0, "briar_revenant":160.0}[enemy.species]
		if level.plan.weather == "fog":
			sight *= 0.72
		elif level.plan.weather == "rain":
			hearing *= 0.7
		_check(is_equal_approx(enemy.config.sight_radius, sight) and is_equal_approx(enemy.config.hearing_radius, hearing), "night_%d_weather_affects_enemy_%d" % [level.plan.seed_value, enemy.get_index()])
	for pickup: CampPickup in level.pickups:
		var path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, player.global_position, pickup.global_position, true)
		_check(path.size() > 1 and path[-1].distance_to(pickup.global_position) < 4, "night_%d_reachable_%s_%d" % [level.plan.seed_value, pickup.kind, pickup.get_index()])
	for landmark: Dictionary in level.plan.woods.landmarks:
		var path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, player.global_position, landmark["position"], true)
		_check(path.size() > 1 and path[-1].distance_to(landmark["position"]) < 4, "night_%d_landmark_%s" % [level.plan.seed_value, landmark["label"]])


	var all_reachable := true
	for cell: Vector2i in level.plan.woods.links:
		var destination: Vector2 = level.plan.woods.center(cell)
		# An abstract clearing may now contain a furnished hut; use its walkable edge.
		destination = NavigationServer2D.map_get_closest_point(level.get_world_2d().navigation_map, destination)
		var path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, player.global_position, destination, true)
		if path.size() < 2 or path[-1].distance_to(destination) > 4:
			all_reachable = false
	_check(all_reachable, "night_%d_all_100_clearings_reachable_in_native_bake" % level.plan.seed_value)


func _rules() -> void:
	var cache: CampPickup
	var cutters: CampPickup
	for pickup: CampPickup in level.pickups:
		if pickup.kind == "fuel":
			cache = pickup
		if pickup.kind == "boltcutters":
			cutters = pickup
	player.position = cache.position
	await _frames(2)
	_check(not level.try_interact(player) and cache.available, "locked_cache_rejects_missing_tool")
	player.position = cutters.position
	await _frames(2)
	_check(level.try_interact(player) and "boltcutters" in player.inventory, "maintenance_awards_cutters")
	_check(not level.try_interact(player), "tool_cannot_be_awarded_twice")
	_check(not level.try_interact(player) and cache.available, "tool_does_not_allow_remote_cache_pickup")
	player.position = cache.position
	await _frames(2)
	_check(level.try_interact(player) and "fuel" in player.inventory and not cache.available, "tool_unlocks_nearby_cache")
	player.position = Vector2(1660, 520)
	player.facing = Vector2.RIGHT
	player.flashlight_charge = 2
	await _frames(60)
	_check(player.flashlight_charge < 1.1 and player.flashlight_charge > 0.8, "woods_drains_flashlight_charge")
	await _key(KEY_ESCAPE)
	var before: float = player.flashlight_charge
	await _frames(60)
	_check(level.paused and is_equal_approx(player.flashlight_charge, before), "pause_stops_battery_drain")
	_check(not level.use_supply(player, "flare"), "paused_supply_use_rejected")
	await _key(KEY_ESCAPE)
	await _frames(90)
	_check(player.flashlight_charge == 0 and not player.flashlight_on, "empty_flashlight_turns_off")
	await _key(KEY_F)
	_check(not player.flashlight_on, "empty_flashlight_cannot_be_toggled_on")
	var batteries: int = player.supplies["battery_pack"]
	await _key(KEY_R)
	_check(player.flashlight_charge > 69 and player.flashlight_on and player.supplies["battery_pack"] == batteries - 1, "r_consumes_one_battery_and_restores_light")
	player.stamina = 0.0
	player.exhausted = true
	await _key(KEY_C)
	_check(player.stamina == level.config.stamina_max and not player.exhausted and player.supplies["rations"] == 0, "c_consumes_rations_and_restores_stamina")
	_check(not level.use_supply(player, "rations"), "empty_supply_use_rejected")
	var flare_count: int = player.supplies["flare"]
	await _key(KEY_Q)
	_check(get_nodes_in_group("flares").size() == 1 and player.supplies["flare"] == flare_count - 1, "q_places_one_flare")
	var flare: Node2D = get_first_node_in_group("flares")
	await _key(KEY_ESCAPE)
	var life: float = flare.remaining
	await _frames(60)
	_check(is_equal_approx(flare.remaining, life), "pause_freezes_flare_lifetime")
	await _key(KEY_ESCAPE)
	await _creature_rules(flare)
	# Downed actors cannot consume survival tools.
	player.set_status(CampPlayer.Status.DOWNED)
	_check(not level.use_supply(player, "flare"), "downed_supply_use_rejected")
	player.set_status(CampPlayer.Status.ALIVE)
	# Controlled teammate fixture: no connected co-op is implied.
	var teammate: CampPlayer = load("res://scenes/actors/player.tscn").instantiate()
	teammate.local_input = false
	teammate.position = player.position + Vector2(0, 10)
	level.world_objects.add_child(teammate)
	teammate.set_status(CampPlayer.Status.DOWNED)
	player.supplies["medkit"] = 1
	level.advance_revive(player, teammate, true, 0.6)
	level.advance_revive(player, teammate, false, 0.0)
	_check(player.supplies["medkit"] == 1 and teammate.status == CampPlayer.Status.DOWNED, "interrupted_revive_does_not_consume_medkit")
	level.advance_revive(player, teammate, true, 1.21)
	_check(player.supplies["medkit"] == 0 and teammate.status == CampPlayer.Status.ALIVE, "medkit_shortens_completed_revive_and_consumes_once")
	teammate.queue_free()
	await _frames(1)


func _creature_rules(flare: Node2D) -> void:
	player.position = Vector2(1660, 520)
	for species in ["werewolf", "bigfoot", "lantern_moth"]:
		var enemy: CampCryptid = load("res://scenes/actors/cryptid.tscn").instantiate()
		enemy.species = species
		enemy.position = Vector2(1580, 520)
		enemy.enabled = false
		level.world_objects.add_child(enemy)
		await _frames(2)
		player.flashlight_on = false
		_check(enemy.sense_visible_target() == (null if species == "lantern_moth" else player), species + "_darkness_sensing_rule")
		player.flashlight_on = true
		_check(enemy.sense_visible_target() == player, species + "_sees_lit_survivor_with_clear_sight")
		flare.position = Vector2(1608, 520)
		_check((enemy.nearby_flare() != Vector2.INF) == (species != "lantern_moth"), species + "_flare_response")
		if species == "bigfoot":
			_check(enemy.config.hearing_radius > level.config.hearing_radius, "bigfoot_has_extended_hearing")
		elif species == "lantern_moth":
			player.flashlight_on = false
			flare.position = Vector2(1760, 520)
			enemy.enabled = true
			enemy._physics_process(0.01)
			_check(enemy.state == CampKiller.State.INVESTIGATE and enemy.last_seen == flare.position, "moth_investigates_visible_flare_beyond_hearing_range")
		else:
			enemy.enabled = true
			enemy.hunt_clock = 0.7
			enemy._physics_process(0.01)
			var burst: float = enemy.config.killer_chase_speed
			enemy.hunt_clock = 1.6
			enemy._physics_process(0.01)
			_check(burst > level.config.sprint_speed and enemy.config.killer_chase_speed < level.config.walk_speed, "wolf_charge_has_slow_recovery_window")
		enemy.queue_free()
		await _frames(1)
	flare.queue_free()
	await _frames(1)


func _tour() -> void:
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	for hazard in get_nodes_in_group("hazards"):
		hazard.queue_free()
	level.message_time = 0
	player.flashlight_charge = 90
	player.position = Vector2(1538, 536)
	player.flashlight_on = true
	player.facing = Vector2(1, -1).normalized()
	await _frames(5)
	await _snapshot("woods_gate")
	player.position = level.plan.woods.center(Vector2i(4, 4))
	player.facing = Vector2.RIGHT
	player.flashlight_on = true
	await _frames(5)
	var lit := await _snapshot("woods_light_on")
	player.flashlight_on = false
	await _frames(5)
	var dark := await _snapshot("woods_light_off")
	var probe := Vector2i(player.get_global_transform_with_canvas().origin + Vector2(32, -12))
	var on := lit.get_pixelv(probe).get_luminance()
	var off := dark.get_pixelv(probe).get_luminance()
	print(JSON.stringify({"event": "woods_lighting", "on": on, "off": off}))
	_check(on > off * 2 + 0.02 and off < 0.06, "woods_needs_local_light")
	player.flashlight_on = true
	# Compose close art-inspection fixtures below the HUD, with the native camera.
	player.get_node("Camera2D").offset = Vector2(0, -32)
	for species in ["werewolf", "bigfoot", "lantern_moth", "vampire", "witch", "briar_revenant"]:
		player.position = level.plan.woods.center(Vector2i(4, 4)) + Vector2(0, 28)
		player.facing = Vector2.UP
		var enemy: CampCryptid = load("res://scenes/actors/cryptid.tscn").instantiate()
		enemy.species = species
		enemy.enabled = false
		enemy.position = player.position + Vector2(0, -42)
		level.world_objects.add_child(enemy)
		await _frames(5)
		await _snapshot("woods_" + species)
		enemy.queue_free()
		await _frames(1)
	player.get_node("Camera2D").offset = Vector2.ZERO
	for index in [0, 2, 4]:
		player.position = level.plan.woods.landmarks[index]["position"] + Vector2(0, 30)
		player.facing = Vector2.UP
		await _frames(5)
		await _snapshot("woods_landmark_%d" % index)
	level.hud.inventory_label.show()
	level.hud.chart.show()
	await _frames(2)
	await _snapshot("woods_field_notes")
	level.hud.inventory_label.hide()
	level.hud.chart.hide()
	level.finish_round(false, "The trails claimed another camper. Try a different route.")
	await _frames(2)
	await _snapshot("woods_results")


func _snapshot(label: String) -> Image:
	await process_frame
	RenderingServer.force_draw(true)
	var result := root.get_texture().get_image()
	_check(result.save_png("res://artifacts/verification/%s.png" % label) == OK, "capture_" + label)
	return result


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(1)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": condition}))
