extends SceneTree
## Distance/visibility gating and real navigation against a walking survivor.
var checks := 0
var failures := 0
var level: Node2D
var player: CampPlayer
var killer: CampKiller
var traits: StalkerTraits
var start := Vector2.ZERO

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	RoundPlan.force_headline = "stalker"
	RoundPlan.force_modifiers = []
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	for index in range(12):
		await physics_frame
	level = current_scene
	player = level.player
	killer = level.killer
	traits = killer.traits
	player.local_input = false
	level.night_clock.active = false
	level.night_clock.director_enabled = false
	level.night_clock.force_phase(1)
	for enemy in get_nodes_in_group("killers"):
		enemy.enabled = false
	start = level.plan.woods.center(Vector2i(22, 17))
	for attempt in range(240):
		if NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, start - Vector2(350, 0), start + Vector2(700, 0), true).size() > 1:
			break
		await physics_frame
	_reset(350.0)
	_check(killer.has_line_of_sight(player.position), "fixture_has_clear_road_sight")
	traits.shadow_clock = 44.0
	traits.lunge_at = 45.0
	_check(traits.physics(10.0), "distant_target_gets_approach_movement")
	_check(is_equal_approx(traits.shadow_clock, 44.0) and killer.state == CampKiller.State.PATROL, "distant_approach_cannot_spend_lunge_timer")
	_check(killer.velocity.length() > player.config.walk_speed and killer.velocity.length() < player.config.sprint_speed, "approach_outpaces_walking_but_not_sprinting")
	_reset(200.0)
	traits.physics(0.5)
	_check(is_equal_approx(traits.shadow_clock, 0.5), "nearby_visible_target_advances_stalking")
	traits.shadow_clock = 44.5
	traits.lunge_at = 45.0
	traits.physics(0.5)
	_check(killer.state == CampKiller.State.CHASE, "nearby_stalking_eventually_lunges")
	_reset(200.0)
	killer.state = CampKiller.State.CHASE
	_check(not traits.physics(1.0) and traits.shadow_clock == 0.0, "ordinary_chase_is_not_overridden_by_stalking")
	_reset(200.0)
	level.night_clock.phase = 0
	_check(not traits.physics(1.0) and traits.shadow_clock == 0.0, "dusk_keeps_normal_detection")
	level.night_clock.phase = 1
	_blocked_sight()
	# Real player movement and killer navigation, not a speed-only assertion.
	_reset(350.0)
	for frame in range(600):
		await physics_frame
		player.apply_intent(Vector2.RIGHT, false, 1.0 / 60.0)
		traits.physics(1.0 / 60.0)
	var gap := killer.position.distance_to(player.position)
	_check(player.position.x > start.x + 650.0, "survivor_actually_walked_the_road")
	_check(gap < StalkerTraits.SHADOW_RANGE and traits.shadow_clock > 0.0, "killer_closes_walking_gap_and_begins_stalking")
	for frame in range(600):
		await physics_frame
		player.apply_intent(Vector2.RIGHT, false, 1.0 / 60.0)
		traits.physics(1.0 / 60.0)
	var following_gap := killer.position.distance_to(player.position)
	_check(following_gap < StalkerTraits.SHADOW_DISTANCE + 40.0 and killer.state == CampKiller.State.PATROL, "nearby_stalking_keeps_up_with_a_walking_survivor")
	if "--capture" in OS.get_cmdline_user_args():
		await _shot("nearby_shadow")
	_reset(120.0)
	player.flashlight_on = true
	player.facing = Vector2.LEFT
	traits.physics(0.1)
	_check(traits.melt > 0.0, "beam_still_interrupts_nearby_shadowing")
	traits.physics(0.1)
	if "--capture" in OS.get_cmdline_user_args():
		await _shot("beam_fade")
	_reset(220.0)
	traits.card_clock = 0.0
	var before: int = level.cards.size()
	traits._cards(level, 0.1)
	_check(level.cards.size() == before + 1, "calling_card_range_remains_230_despite_closer_shadow_distance")
	# Exercise the final velocity after exaggerated phase/modifier/frenzy stacking.
	_reset(80.0)
	killer.enabled = true
	killer.state = CampKiller.State.CHASE
	killer.config.killer_chase_speed = 200.0
	killer.frenzy = 12.0
	for frame in range(12): await physics_frame
	_check(is_equal_approx(killer.velocity.length(), 90.0), "stacked_chase_speed_is_actually_capped")
	_check(player.config.sprint_speed * CampPlayer.WOUNDED_SPRINT > killer.velocity.length(), "wounded_sprint_can_gain_a_gap")
	killer.enabled = false
	print(JSON.stringify({"event": "test_result", "suite": "stalker_distance", "checks": checks, "failures": failures, "walking_gap": gap, "following_gap": following_gap}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)

func _reset(distance: float) -> void:
	player.position = start
	player.facing = Vector2.RIGHT
	player.flashlight_on = false
	player.velocity = Vector2.ZERO
	killer.position = start - Vector2(distance, 0)
	killer.velocity = Vector2.ZERO
	killer.state = CampKiller.State.PATROL
	killer.path_clock = 0.0
	traits.favourite = player
	traits.melt = 0.0
	killer.faded = false
	traits.shadow_clock = 0.0
	traits.lunge_at = 45.0

func _blocked_sight() -> void:
	var found := false
	for wall: Rect2 in level.plan.woods.walls:
		if wall.size.x > 180.0:
			continue
		var a := wall.get_center() - Vector2(wall.size.x * 0.5 + 20.0, 0)
		var b := wall.get_center() + Vector2(wall.size.x * 0.5 + 20.0, 0)
		if not CampMap.is_woods(a) or not CampMap.is_woods(b) or not level.plan.woods.walkable(a) or not level.plan.woods.walkable(b):
			continue
		_reset(200.0)
		player.position = a
		killer.position = b
		if killer.has_line_of_sight(a):
			continue
		found = true
		traits.shadow_clock = 44.0
		traits.physics(5.0)
		_check(traits.shadow_clock == 44.0 and killer.state == CampKiller.State.PATROL, "nearby_but_occluded_target_does_not_spend_lunge_timer")
		break
	_check(found, "occlusion_fixture_found")

func _shot(label: String) -> void:
	killer.queue_redraw()
	for frame in range(4):
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/stalker_distance"))
	RenderingServer.force_draw(true)
	_check(root.get_texture().get_image().save_png("res://artifacts/stalker_distance/" + label + ".png") == OK, "capture_" + label)

func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": passed}))
