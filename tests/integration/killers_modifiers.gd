extends SceneTree
## F7: headline killer rotation (stalker / Groundskeeper snares), stalker escalation
## tiers (Dusk inner-ring limit, Deep Night sabotage, Witching Hour power cut and
## faster door breaking) and the six night modifiers.
var checks := 0
var failures := 0
var level: Node2D
var player: CampPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_plan_checks()
	var previous_role: String = root.get_node("Session").survivor
	root.get_node("Session").survivor = "jock"
	await _load(42, "groundskeeper", [])
	await _snare_checks()
	await _tier_checks()
	await _load(42, "stalker", ["dead_batteries", "silent_night", "blood_moon"])
	_modifier_checks()
	await _load(42, "stalker", ["lone_wolf"])
	_lone_wolf_checks()
	RoundPlan.force_headline = ""
	RoundPlan.force_modifiers = null
	root.get_node("Session").select_survivor(previous_role)
	print(JSON.stringify({"event": "test_result", "suite": "killers_modifiers", "checks": checks, "failures": failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _load(seed_value: int, headline: String, modifiers: Array) -> void:
	RoundPlan.force_headline = headline
	RoundPlan.force_modifiers = modifiers
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = seed_value
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await process_frame
	while current_scene == null or current_scene.name != "ForestLevel" or current_scene == level:
		await process_frame
	level = current_scene
	player = level.player
	player.local_input = false
	level.night_clock.director_enabled = false
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	await _frames(4)


func _plan_checks() -> void:
	RoundPlan.force_headline = ""
	RoundPlan.force_modifiers = null
	var headlines := {}
	var seen := {}
	var counts_ok := true
	var fog_ok := true
	for seed_value in range(1, 61):
		var plan := RoundPlan.new()
		plan.generate(seed_value, "woods")
		headlines[plan.headline] = true
		counts_ok = counts_ok and plan.modifiers.size() <= 2 and (plan.modifiers.size() < 2 or plan.modifiers[0] != plan.modifiers[1])
		for id in plan.modifiers:
			seen[id] = true
		if plan.has_modifier("fog_bank"):
			fog_ok = fog_ok and plan.weather == "fog"
	_check(headlines.size() == 2, "both_headline_killers_rotate")
	_check(seen.size() == RoundPlan.MODIFIERS.size(), "all_six_modifiers_appear")
	_check(counts_ok, "zero_to_two_distinct_modifiers")
	_check(fog_ok, "fog_bank_forces_fog")
	var base := _plan_with(9, [])
	var rich := _plan_with(9, ["generous_woods"])
	_check(rich.loot.size() > base.loot.size() + 30, "generous_woods_adds_supplies")
	var moon := _plan_with(9, ["blood_moon"])
	var wolves := func(plan: RoundPlan) -> int: return plan.encounters.filter(func(item: Dictionary) -> bool: return item["species"] == "werewolf").size()
	_check(moon.encounters.size() == base.encounters.size() and wolves.call(moon) >= wolves.call(base) + 4, "blood_moon_more_werewolves_same_total")
	var camp := RoundPlan.new()
	camp.generate(9, "camp")
	_check(camp.modifiers.is_empty(), "quick_camp_has_no_modifiers")


func _plan_with(seed_value: int, modifiers: Array) -> RoundPlan:
	RoundPlan.force_modifiers = modifiers
	var plan := RoundPlan.new()
	plan.generate(seed_value, "woods")
	RoundPlan.force_modifiers = null
	return plan


func _snare_checks() -> void:
	var snares: Snares = level.snares
	_check(level.killer.headline == "groundskeeper" and snares.active(), "groundskeeper_headline_active")
	_check(level.message.contains("GROUNDSKEEPER"), "dusk_message_names_the_killer")
	var trail: Vector2 = level.plan.woods.center(Vector2i(18, 24))
	player.position = trail + Vector2(200, 0)
	_check(not snares.try_place(trail), "no_snare_on_unwalked_trail")
	level.plan.woods.visited[level.plan.woods.cell_at(trail)] = true
	_check(snares.try_place(trail) and snares.snares.size() == 1, "snare_on_walked_trail")
	_check(not snares.try_place(trail + Vector2(40, 0)), "snares_keep_their_spacing")
	var stalker: CampKiller = level.killer
	stalker.enabled = true
	stalker.state = CampKiller.State.PATROL
	stalker.position = trail + Vector2(0, 150)
	player.position = trail
	snares.advance(0.1)
	_check(player.snared > 3.5 and not snares.snares[0]["armed"], "stepping_on_snare_holds_survivor")
	_check(stalker.state == CampKiller.State.INVESTIGATE, "snare_rattle_calls_the_groundskeeper")
	stalker.enabled = false
	player.apply_intent(Vector2.RIGHT, true, 1.0 / 60.0)
	_check(player.velocity == Vector2.ZERO, "snared_survivor_cannot_move")
	var friend: CampPlayer = level.PLAYER_SCENE.instantiate()
	friend.role = "medic"
	friend.local_input = false
	friend.position = trail + Vector2(12, 0)
	level.world_objects.add_child(friend)
	await _frames(2)
	_check(snares.prompt(friend).contains("FREE TEAMMATE") and level.try_interact(friend) and player.snared == 0.0, "teammate_frees_snared_survivor")
	friend.queue_free()
	level.plan.woods.visited[level.plan.woods.cell_at(trail + Vector2(0, 200))] = true
	snares.try_place(trail + Vector2(0, 200))
	player.position = trail + Vector2(0, 186)
	_check(snares.prompt(player).contains("DISARM") and level.try_interact(player) and not snares.snares.back()["armed"], "survivor_disarms_snare_quietly")
	player.snared = 4.0
	snares.advance(4.1)
	_check(player.snared == 0.0, "snare_gives_way_after_four_seconds")


func _tier_checks() -> void:
	var stalker: CampKiller = level.killer
	var far: Vector2 = level.plan.woods.center(Vector2i(4, 4))
	player.position = far
	stalker.position = far + Vector2(30, 0)
	stalker.enabled = true
	stalker.tier = 1
	await physics_frame
	await physics_frame
	_check(stalker.state != CampKiller.State.CHASE, "dusk_killer_never_chases_beyond_inner_ring")
	stalker.tier = 2
	await physics_frame
	await physics_frame
	_check(stalker.state == CampKiller.State.CHASE, "nightfall_killer_chases_anywhere")
	stalker.enabled = false
	stalker.state = CampKiller.State.PATROL
	player.invulnerability = 0.0
	player.wounded = false
	player.set_status(CampPlayer.Status.ALIVE)
	player.position = far
	var clock: NightClock = level.night_clock
	var search_before: float = stalker.config.search_seconds
	clock.force_phase(2)
	_check(stalker.tier == 3 and is_equal_approx(stalker.config.search_seconds, search_before * 1.5) and clock.sabotage_armed, "deep_night_tier_three")
	level.van.installed.assign(["battery", "key"])
	stalker.enabled = true
	stalker.position = level.van.interaction_point()
	clock.advance(0.1)
	_check(clock.sabotage_done and level.van.installed == ["battery"] and level.message.contains("VAN ALARM"), "unguarded_van_sabotaged_once")
	var dropped: Array = level.pickups.filter(func(pickup: CampPickup) -> bool: return pickup.kind == "key" and pickup.available and pickup.has_meta("dropped_unit"))
	_check(dropped.size() == 1 and level.pins.any(func(pin: Dictionary) -> bool: return pin["name"] == "STOLEN" and pin["position"].distance_to(dropped[0].position) < 2.0), "stolen_part_dropped_and_pinned")
	level.van.installed.append("key")
	clock.advance(0.1)
	_check(level.van.installed.size() == 2, "sabotage_happens_only_once")
	clock.force_phase(3)
	stalker.position = clock.generator_point()
	clock.blackout = false
	clock.advance(0.1)
	_check(clock.blackout and clock.power_cut_done, "witching_hour_cuts_unguarded_power")
	clock.blackout = false
	clock.advance(0.1)
	_check(not clock.blackout, "power_cut_only_once")
	stalker.enabled = false
	var props: ChaseProps = level.props
	var building: CampBuilding = level.camp_map.buildings[0]
	var door: Dictionary = props.doors[props.doors.find(props.doors.filter(func(row: Dictionary) -> bool: return row["label"] == building.label)[0])]
	door["open"] = false
	door["progress"] = 0.0
	stalker.enabled = true
	stalker.position = building.door + Vector2(0, 8)
	props.advance(1.0)
	_check(is_equal_approx(door["progress"], 1.5), "witching_hour_breaks_doors_faster")
	stalker.enabled = false


func _modifier_checks() -> void:
	_check(level.plan.modifiers == ["dead_batteries", "silent_night", "blood_moon"] and level.message.contains("DEAD BATTERIES"), "modifiers_announced")
	player.flashlight_charge = 0.0
	player.supplies["battery_pack"] = 1
	level.use_supply(player, "battery_pack")
	_check(is_equal_approx(player.flashlight_charge, 40.0), "dead_batteries_hold_40")
	var base: CampConfig = preload("res://assets/default_config.tres")
	var expected_hearing: float = 220.0 * (0.7 if level.plan.weather == "rain" else 1.0) * 1.15
	_check(is_equal_approx(level.killer.config.hearing_radius, expected_hearing), "silent_night_sharpens_hearing_%d" % int(level.killer.config.hearing_radius))
	_check(is_equal_approx(level.killer.config.killer_chase_speed, base.killer_chase_speed * 1.08), "blood_moon_faster_killer")


func _lone_wolf_checks() -> void:
	var doors: Array = level.camp_map.buildings.map(func(building: CampBuilding) -> Vector2: return building.door + Vector2(0, 14))
	_check(doors.has(player.position), "lone_wolf_starts_at_a_cabin_door")


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame


func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": passed}))
