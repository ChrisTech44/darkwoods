extends SceneTree
## F5c: one rumoured secondary escape per night beside the van, only tonight's
## escape parts spawn, the Signal Fire chain and 45 s hold-out, and the van's
## 20 s expedition departure that draws the woods in.
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
	await _load(42, true)
	await _fire_checks()
	await _load(42, true)
	await _van_checks()
	await _disabled_checks()
	RoundPlan.force_all_escapes = false
	root.get_node("Session").select_survivor(previous_role)
	print(JSON.stringify({"event": "test_result", "suite": "signal_fire", "checks": checks, "failures": failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _load(seed_value: int, all_escapes: bool) -> void:
	RoundPlan.force_all_escapes = all_escapes
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
	RoundPlan.force_all_escapes = false
	var seen := {}
	var parts_ok := true
	var spread_ok := true
	for seed_value in range(1, 41):
		var plan := RoundPlan.new()
		plan.generate(seed_value, "woods")
		var kinds := plan.loot.map(func(item: Dictionary) -> String: return item["kind"])
		var second: String = plan.escape_options[1]
		seen[second] = true
		parts_ok = parts_ok and plan.escape_options.size() == 2 and plan.escape_options[0] == "van"
		parts_ok = parts_ok and (("outboard_motor" in kinds) == (second == "boat")) and (("gate_code_1" in kinds) == (second == "gate")) and (("flare_gun" in kinds) == (second == "signal"))
		parts_ok = parts_ok and (("rescue_fuse" in kinds) == (second in ["radio", "gate"]))
		if second == "signal":
			var regions: Array = plan.signal_regions.values()
			spread_ok = spread_ok and regions.size() == 3 and regions[0] != regions[1] and regions[1] != regions[2] and regions[0] != regions[2]
	_check(seen.size() == 4, "all_four_secondary_escapes_rotate_across_seeds")
	_check(parts_ok, "only_tonights_escape_parts_spawn")
	_check(spread_ok, "signal_parts_in_three_different_regions")
	var again := RoundPlan.new()
	again.generate(7, "woods")
	var once := RoundPlan.new()
	once.generate(7, "woods")
	_check(again.escape_options == once.escape_options, "escape_choice_reproducible_per_seed")
	var camp := RoundPlan.new()
	camp.generate(7, "camp")
	_check(camp.escape_options == ["van"], "quick_camp_stays_van_only")


func _fire_checks() -> void:
	var fire: SignalFire = level.signal_fire
	_check(fire.active and level.plan.escape_options.size() == 5, "all_escapes_fixture_enables_signal_fire")
	var map := level.get_world_2d().navigation_map
	var path := NavigationServer2D.map_get_path(map, Vector2(96, 384), fire.pyre, true)
	_check(path.size() > 1 and path[-1].distance_to(fire.pyre) < 8, "pyre_reachable_from_camp")
	for kind in SignalFire.PARTS:
		var pickup := _pickup(kind)
		var route := NavigationServer2D.map_get_path(map, Vector2(96, 384), pickup.position, true)
		_check(route.size() > 1 and route[-1].distance_to(pickup.position) < 8, "%s_reachable" % kind)
		player.position = pickup.position
		_check(level.try_interact(player) and kind in player.inventory and player.belt.find(kind) < 0, "%s_taken_without_belt_slot" % kind)
	player.position = fire.pyre + Vector2(0, 30)
	_check(level.context_prompt().contains("KEROSENE"), "pyre_prompt")
	_check(level.try_interact(player) and fire.installed.size() == 3, "pyre_takes_all_three_parts")
	level.night_clock.advance(0.1)
	_check(level.night_clock.phase == 3, "ready_pyre_brings_witching_hour")
	var stalker: CampKiller = level.killer
	stalker.enabled = true
	stalker.state = CampKiller.State.PATROL
	_check(level.try_interact(player) and fire.started and fire.remaining == SignalFire.HOLD_SECONDS, "lighting_starts_45s_holdout")
	_check(stalker.state == CampKiller.State.INVESTIGATE and stalker.last_seen.distance_to(fire.pyre) < 1.0, "blaze_draws_the_stalker_to_the_pyre")
	stalker.enabled = false
	await _frames(2)
	_check(level.hud.title.text.contains("SIGNAL FIRE"), "heading_shows_signal_fire_countdown")
	# Tall props are depth-sorted world sprites: behind them they turn see-through.
	var standing: StandingProps = level.get_node("StandingProps")
	var pyre_sprite: Sprite2D
	for entry: Dictionary in standing.props.values():
		if entry["sprite"].get_meta("prop", "") == "pyre_lit":
			pyre_sprite = entry["sprite"]
	_check(pyre_sprite != null and pyre_sprite.get_parent() == level.world_objects and level.world_objects.y_sort_enabled, "pyre_is_a_depth_sorted_world_sprite")
	var before_y: Vector2 = player.position
	player.position = fire.pyre + Vector2(0, -12)
	for step in range(40):
		await process_frame
	_check(pyre_sprite != null and pyre_sprite.self_modulate.a < 0.6, "pyre_turns_see_through_when_survivor_behind")
	player.position = before_y
	fire.remaining = SignalFire.HOLD_SECONDS
	for step in range(int(SignalFire.HOLD_SECONDS * 10) - 5):
		fire.advance(0.1)
	_check(not level.finished, "holdout_not_finished_early")
	for step in range(10):
		fire.advance(0.1)
	_check(level.finished and level.won and level.escape_route == "SIGNAL FIRE" and player.status == CampPlayer.Status.ESCAPED, "standing_by_pyre_escapes")


func _van_checks() -> void:
	_check(is_equal_approx(level.config.extraction_seconds, 20.0) and is_equal_approx(level.van.config.extraction_seconds, 20.0), "expedition_van_departure_20s")
	level.van.installed.assign(level.plan.required)
	var stalker: CampKiller = level.killer
	stalker.enabled = true
	stalker.state = CampKiller.State.PATROL
	player.position = level.van.interaction_point()
	for step in range(int(player.config.start_hold_seconds * 10) + 2):
		if level.van.running:
			break
		level.van.advance_start(player, true, 0.1)
	_check(level.van.running and is_equal_approx(level.van.remaining, 20.0), "van_starts_20s_holdout")
	level._van_started()
	_check(stalker.state == CampKiller.State.INVESTIGATE and stalker.last_seen.distance_to(level.van.global_position) < 1.0, "engine_start_calls_the_stalker")
	stalker.state = CampKiller.State.PATROL
	stalker.position = level.van.global_position + Vector2(600, 0)
	level.van_rev_clock = 0.05
	level._physics_process(0.1)
	_check(stalker.state == CampKiller.State.INVESTIGATE, "engine_revs_keep_drawing_creatures")
	stalker.enabled = false


func _disabled_checks() -> void:
	var chosen := 0
	for seed_value in range(1, 60):
		var plan := RoundPlan.new()
		RoundPlan.force_all_escapes = false
		plan.generate(seed_value, "woods")
		if plan.escape_options[1] == "signal":
			chosen = seed_value
			break
	await _load(chosen, false)
	_check(level.signal_fire.active and not level.escapes.boat_enabled and not level.escapes.gate_enabled and not level.rescue.relay_enabled, "only_rumoured_escape_active")
	player.position = level.plan.woods.zones[12]["position"] + Vector2(0, -95)
	await _frames(2)
	_check(level.escapes.prompt(player).is_empty() and not level.context_prompt().contains("BOAT"), "absent_escape_has_no_prompts")
	_check(level.message.contains("Rumour") and level.message.contains("SIGNAL FIRE"), "dusk_message_names_the_rumour")
	level.objective_page = 1
	await _frames(2)
	_check(level.current_page() == "signal" and level.hud.inventory_label.text.contains("QUARRY"), "t_page_shows_signal_fire_plan")


func _pickup(kind: String) -> CampPickup:
	for pickup: CampPickup in level.pickups:
		if pickup.kind == kind:
			return pickup
	return null


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame


func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": passed}))
