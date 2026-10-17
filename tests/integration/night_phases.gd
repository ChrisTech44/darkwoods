extends SceneTree
## F2 night: 60-minute phase clock, radio part reveals, dread, director, events and dawn.
var checks := 0
var failures := 0
var capture := false
var level: Node2D
var player: CampPlayer
var clock: NightClock


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	_plan_checks()
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
	clock = level.night_clock
	clock.director_enabled = false
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	await _frames(4)
	await _dusk_checks()
	await _phase_checks()
	await _event_checks()
	await _director_checks()
	await _dawn_checks()
	root.get_node("Session").select_survivor(previous_role)
	print(JSON.stringify({"event":"test_result","suite":"night_phases","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _plan_checks() -> void:
	for seed_value in [1, 42, 2026]:
		var plan := RoundPlan.new()
		plan.generate(seed_value, "woods")
		var again := RoundPlan.new()
		again.generate(seed_value, "woods")
		_check(plan.reveal_phase == again.reveal_phase and plan.night_events == again.night_events, "seed_%d_night_schedule_reproducible" % seed_value)
		_check(plan.reveal_phase["battery"] == 0 and plan.reveal_phase["key"] == 0 and plan.reveal_phase["fuel"] == 1 and plan.reveal_phase[plan.required[3]] == 2 and plan.reveal_phase[plan.required[4]] == 3, "seed_%d_parts_staged_across_four_phases" % seed_value)
		var windows := [[NightClock.PHASE_STARTS[1], NightClock.PHASE_STARTS[2]], [NightClock.PHASE_STARTS[2], NightClock.PHASE_STARTS[3]], [NightClock.PHASE_STARTS[3], NightClock.DAWN - 600]]
		var placed := plan.night_events.size() == 3
		for index in range(plan.night_events.size()):
			var at: float = plan.night_events[index]["time"]
			placed = placed and at > windows[index][0] and at < windows[index][1] and plan.night_events[index]["kind"] in ["storm", "blackout"]
		_check(placed, "seed_%d_events_inside_their_phases" % seed_value)
	var camp := RoundPlan.new()
	camp.generate(42, "camp")
	_check(camp.reveal_phase.is_empty() and camp.night_events.is_empty(), "quick_camp_has_no_night_schedule")
	_check(NightClock.phase_at(599.9) == 0 and NightClock.phase_at(600) == 1 and NightClock.phase_at(2399) == 2 and NightClock.phase_at(3599) == 3, "phase_boundaries")
	_check(NightClock.clock_text(2405.7) == "40:05", "clock_text_format")


func _dusk_checks() -> void:
	_check(clock.active and clock.phase == 0 and level.hud.title.text.contains("DUSK 00:0"), "night_starts_at_dusk_on_hud")
	var sealed := []
	for pickup: CampPickup in level.pickups:
		if pickup.kind in level.plan.required and level.plan.reveal_phase[pickup.kind] > 0:
			sealed.append(pickup.available or pickup.visible)
	_check(sealed.size() == 3 and not sealed.has(true), "three_parts_sealed_at_dusk")
	_check(level.hud.inventory_label.text.contains("FUEL / RADIO 10:00") and level.hud.inventory_label.text.contains("RADIO 40:00"), "pack_lists_radio_times")
	_check(clock.dread < 15.0, "dusk_dread_low_%d" % int(clock.dread))


func _phase_checks() -> void:
	var stash_before := _count_near(level.plan.camp.remap(Vector2(1304, 312)))
	var hearing: float = level.killer.config.hearing_radius
	var speed: float = level.killer.config.killer_chase_speed
	clock.skip_to(NightClock.PHASE_STARTS[1])
	await _frames(2)
	_check(clock.phase == 1 and level.message.begins_with("NIGHTFALL") and level.message.contains("FUEL"), "nightfall_radio_names_fuel")
	_check(_count_near(level.plan.camp.remap(Vector2(1304, 312))) == stash_before + 4, "phase_supply_drop_at_maintenance")
	var last: String = level.plan.required[4]
	clock.skip_to(NightClock.PHASE_STARTS[3] - 1)
	_check(not _part(last).available, "final_part_sealed_until_40_minutes")
	_check(clock.dread > 45.0, "deep_night_dread_rises_%d" % int(clock.dread))
	clock.skip_to(NightClock.PHASE_STARTS[3])
	await _frames(2)
	_check(_part(last).available and clock.phase == 3, "witching_hour_reveals_last_part")
	_check(level.hud.title.text.contains("WITCHING HOUR 40:0") and (level.hud.title.text.contains("DAWN IN 20:00") or level.hud.title.text.contains("DAWN IN 19:59")), "hud_counts_down_to_dawn")
	_check(is_equal_approx(level.killer.config.hearing_radius, hearing * 1.21) and is_equal_approx(level.killer.config.killer_chase_speed, speed * 1.08), "stalker_grows_bolder")
	_check(level.soundscape.played_counts.get("phase_stinger", 0) >= 1, "phase_change_stinger")
	_check(level.soundscape.played_counts.get("radio_talk", 0) >= 1 and level.soundscape.played_counts.get("radio_static", 0) >= 1, "phase_change_ranger_radio_broadcast")


func _event_checks() -> void:
	# Fresh event state: replay the storm from its scheduled start.
	clock.storm_remaining = 0.0
	clock.blackout = false
	clock._start_event("storm")
	_check(is_equal_approx(clock.hearing_scale(), NightClock.STORM_HEARING), "storm_dampens_ai_hearing")
	var listener: CampKiller = level.killer
	listener.enabled = true
	listener.state = CampKiller.State.PATROL
	listener.position = player.position + Vector2(listener.config.hearing_radius * 0.8, 0)
	level._on_noise(player.position)
	_check(listener.state == CampKiller.State.PATROL, "storm_masks_noise_at_80_percent_range")
	var flashes := 0
	for step in range(240):
		clock.advance(0.1)
		if clock.lightning > 0.0:
			flashes += 1
	_check(flashes > 0 and clock.storm_remaining < NightClock.STORM_SECONDS - 20, "storm_lightning_flashes")
	clock.storm_remaining = 0.0
	level._on_noise(player.position)
	_check(listener.state == CampKiller.State.INVESTIGATE, "clear_weather_hears_same_noise")
	listener.enabled = false
	clock._start_event("blackout")
	await _frames(2)
	_check(not level.camp_map.camp_lamps.is_empty() and level.camp_map.camp_lamps.all(func(lamp: PointLight2D) -> bool: return not lamp.enabled), "blackout_cuts_camp_lamps")
	player.position = clock.generator_point()
	await _frames(2)
	_check(level.context_prompt().contains("RESTART GENERATOR"), "generator_prompt")
	_check(level.try_interact(player) and not clock.blackout, "generator_restores_power")
	await _frames(2)
	_check(level.camp_map.camp_lamps.all(func(lamp: PointLight2D) -> bool: return lamp.enabled), "camp_lamps_return")
	if capture:
		await _snapshot("night_witching_hud")


func _director_checks() -> void:
	clock.director_enabled = true
	player.position = level.plan.woods.center(Vector2i(10, 24))
	var roamer: CampCryptid
	var near: CampCryptid
	for enemy: CampCryptid in get_nodes_in_group("cryptids"):
		if not enemy.home.has_area():
			if roamer == null:
				roamer = enemy
			elif near == null:
				near = enemy
	var far_spot := NavigationServer2D.map_get_closest_point(level.get_world_2d().navigation_map, player.position + Vector2(0, 1000))
	roamer.position = far_spot
	near.position = player.position + Vector2(0, 250)
	for enemy in [roamer, near]:
		enemy.enabled = true
		enemy.state = CampKiller.State.PATROL
	clock.relief.clear()
	clock.dread = 30.0
	var sent := clock.direct()
	_check(sent == 1 and roamer.state == CampKiller.State.INVESTIGATE, "director_steers_one_distant_roamer")
	_check(near.state == CampKiller.State.PATROL, "director_never_uses_creature_within_400px")
	var miss := roamer.last_seen.distance_to(player.position)
	_check(miss >= 100.0 and miss <= 320.0 and CampMap.is_woods(roamer.last_seen), "director_sends_to_fuzzy_area_not_exact_spot_%d" % int(miss))
	roamer.state = CampKiller.State.PATROL
	clock.relief[player.get_instance_id()] = NightClock.RELIEF_SECONDS
	_check(clock.direct() == 0 and roamer.state == CampKiller.State.PATROL, "relief_window_after_chase_blocks_director")
	clock.relief.clear()
	player.position = Vector2(700, 520)
	_check(clock.direct() == 0, "director_ignores_survivors_in_camp")
	roamer.enabled = false
	near.enabled = false
	clock.director_enabled = false


func _dawn_checks() -> void:
	var straggler: CampPlayer = load("res://scenes/actors/player.tscn").instantiate()
	straggler.local_input = false
	straggler.position = level.plan.woods.center(Vector2i(10, 24))
	level.world_objects.add_child(straggler)
	player.position = Vector2(700, 520)
	await _frames(2)
	clock.skip_to(NightClock.DAWN)
	await _frames(2)
	_check(level.finished and level.won and player.status == CampPlayer.Status.ESCAPED, "dawn_rescues_survivor_in_camp")
	_check(straggler.status == CampPlayer.Status.LEFT_BEHIND, "dawn_leaves_woods_survivor_behind")
	_check(level.hud.result_panel.visible and level.hud.result_panel.get_child(0).get_node("Detail").text.contains("Dawn broke"), "dawn_result_explained")


func _part(kind: String) -> CampPickup:
	for pickup: CampPickup in level.pickups:
		if pickup.kind == kind and not pickup.has_meta("dropped_unit"):
			return pickup
	return null


func _count_near(at: Vector2) -> int:
	var total := 0
	for pickup: CampPickup in level.pickups:
		if pickup.available and pickup.position.distance_to(at) < 40:
			total += 1
	return total


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
