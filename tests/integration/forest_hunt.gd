extends "res://tests/integration/woods_replay.gd"
## Isolated native-physics fixtures for new sites, senses, search, spells and lifecycle.


func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await _wait_world()
	player.local_input = false
	await _site_checks()
	await _ai_checks()
	await _spell_checks()
	if capture:
		await _site_tour()
	level.return_to_menu()
	await _frames(3)
	_check(get_nodes_in_group("hazards").is_empty() and get_nodes_in_group("cryptids").is_empty(), "new_hazards_and_creatures_freed_on_menu_return")
	print(JSON.stringify({"event":"test_result","suite":"forest_hunt","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _site_checks() -> void:
	_check(level.camp_map.forest_buildings.size() == 2, "village_has_two_enterable_furnished_huts")
	for building: CampBuilding in level.camp_map.forest_buildings:
		var path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, player.position, building.door - Vector2(0,32), true)
		_check(path.size() > 1 and path[-1].distance_to(building.door - Vector2(0,32)) < 4, "village_interior_reachable_" + building.label)
	for enemy: CampKiller in get_nodes_in_group("cryptids"):
		var spread := 0.0
		for point: Vector2 in enemy.patrol:
			spread = maxf(spread, enemy.patrol[0].distance_to(point))
		_check(enemy.patrol.size() >= 8 and spread >= 320, "expanded_roaming_route_" + enemy.species)
	for site: ForestSite in level.camp_map.sites:
		var action: Dictionary = site.actions[-1]
		_check(not site.interact(player), "remote_site_interaction_rejected_" + site.definition["kind"])
		player.position = action["position"]
		await _frames(2)
		var before: Dictionary = player.supplies.duplicate()
		player.flashlight_charge = 10
		_check(site.interact(player) and action["used"], "finite_site_action_" + action["kind"])
		if action["kind"] == "supplies":
			_check(player.supplies["flare"] == before["flare"] + 2 and player.supplies["battery_pack"] == before["battery_pack"] + 1, "well_awards_supplies_once")
		elif action["kind"] == "crypt":
			_check(player.supplies["flare"] == before["flare"] + 2, "crypt_awards_two_flares")
		elif action["kind"] == "relic":
			var total_before := 0
			var total_after := 0
			for kind in ["noise_tin","salt_ward","glow_moss"]:
				total_before += before[kind]
				total_after += player.supplies[kind]
			_check(total_after == total_before + 1, "landmark_awards_one_rare_tool")
		else:
			_check(player.flashlight_charge > 89 and player.hex_remaining > 1.8, "cauldron_trades_hex_for_full_charge")
		var after: Dictionary = player.supplies.duplicate()
		_check(not site.interact(player) and player.supplies == after, "used_site_cannot_duplicate_rewards_" + action["kind"])
	var village: ForestSite = level.camp_map.sites[0]
	var bell: Dictionary = village.actions[0]
	player.position = bell["position"]
	village.cooldown = 0
	var enemy: CampKiller = level.killer
	enemy.position = player.position + Vector2(450, 0)
	enemy.enabled = true
	enemy.state = CampKiller.State.PATROL
	await _frames(2)
	_check(village.interact(player) and enemy.state == CampKiller.State.INVESTIGATE and enemy.last_seen == bell["position"], "bell_creates_audible_distraction_at_bell_not_hidden_player")
	_check(not village.interact(player), "bell_cooldown_prevents_spam")
	enemy.enabled = false


func _ai_checks() -> void:
	var center: Vector2 = level.plan.woods.zones[1]["position"]
	player.position = center
	player.flashlight_on = true
	player.facing = Vector2.UP
	var vampire: CampCryptid = load("res://scenes/actors/cryptid.tscn").instantiate()
	vampire.species = "vampire"
	vampire.position = center - Vector2(0,100)
	vampire.enabled = false
	level.world_objects.add_child(vampire)
	await _frames(2)
	vampire.enabled = true
	await _frames(2)
	_check(vampire.config.killer_chase_speed == 52 and vampire.pursuit_goal(player).distance_to(player.position) > 40, "vampire_slows_and_flanks_flashlight")
	player.flashlight_on = false
	await _frames(2)
	_check(vampire.config.killer_chase_speed == 90, "vampire_accelerates_outside_beam")
	vampire.enabled = false
	var saved := center
	vampire.last_seen = saved
	vampire.transition(CampKiller.State.SEARCH)
	_check(vampire.search_points.size() == 5, "search_sweeps_multiple_reachable_points")
	player.position = Vector2(96,384)
	vampire.enabled = true
	await _frames(8)
	_check(vampire.last_seen == saved, "search_does_not_track_hidden_player_position")
	vampire.queue_free()
	var revenant: CampCryptid = load("res://scenes/actors/cryptid.tscn").instantiate()
	revenant.species = "briar_revenant"
	revenant.position = center
	revenant.enabled = false
	level.world_objects.add_child(revenant)
	player.position = center + Vector2(80,0)
	await _frames(2)
	_check(revenant.sense_visible_target() == null, "revenant_ignores_still_distant_survivor")
	player.velocity = Vector2(70,0)
	_check(revenant.sense_visible_target() == player, "revenant_detects_movement_in_clear_sight")
	player.velocity = Vector2.ZERO
	player.position = Vector2(96,384)
	revenant.patrol.assign(level.plan.woods.roaming_route(level.plan.woods.cell_at(center)))
	revenant.position = revenant.patrol[0]
	var before := revenant.position
	revenant.enabled = true
	await _frames(240)
	_check(revenant.position.distance_to(before) > 90, "roaming_enemy_actually_traverses_trails")
	revenant.queue_free()
	await _frames(1)


func _spell_checks() -> void:
	var center: Vector2 = level.plan.woods.zones[1]["position"]
	player.position = center
	player.hex_remaining = 0
	player.flashlight_on = true
	player.flashlight_charge = 90
	var witch: CampCryptid = load("res://scenes/actors/cryptid.tscn").instantiate()
	witch.species = "witch"
	witch.position = center - Vector2(0,110)
	witch.cast_cooldown = 0
	level.world_objects.add_child(witch)
	await _frames(20)
	_check(witch.casting and get_nodes_in_group("hazards").is_empty(), "witch_winds_up_before_firing")
	if capture:
		player.get_node("Camera2D").offset = Vector2(0,-75)
		player.get_node("Camera2D").zoom = Vector2(0.75,0.75)
		await _snapshot("hunt_witch_windup")
	await _frames(35)
	_check(get_nodes_in_group("hazards").size() == 1, "witch_fires_one_projectile_after_telegraph")
	if capture:
		await _snapshot("hunt_hex_bolt")
	var bolt: HexBolt = get_first_node_in_group("hazards")
	await _key(KEY_ESCAPE)
	var at := bolt.position
	var life := bolt.remaining
	var casting_time := witch.cast_cooldown
	await _frames(45)
	_check(level.paused and bolt.position == at and bolt.remaining == life and witch.cast_cooldown == casting_time, "pause_freezes_projectiles_and_cast_cooldowns")
	await _key(KEY_ESCAPE)
	for enemy: CampKiller in get_nodes_in_group("killers"):
		if enemy != witch:
			enemy.enabled = false
	await _frames(75)
	_check(player.hex_remaining > 0 and player.status == CampPlayer.Status.ALIVE, "projectile_applies_temporary_hex_without_instant_down")
	witch.enabled = false
	player.hex_remaining = 0
	# A native wall between a new bolt and the player must absorb it.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = center - Vector2(35,0)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8,80)
	shape.shape = rectangle
	wall.add_child(shape)
	level.add_child(wall)
	await _frames(2)
	bolt = HexBolt.new()
	bolt.position = center - Vector2(100,0)
	level.world_objects.add_child(bolt)
	await _frames(70)
	_check(not is_instance_valid(bolt) and player.hex_remaining == 0, "wall_absorbs_swept_projectile")
	wall.position = center - Vector2(0,55)
	rectangle.size = Vector2(80,8)
	witch.cast_cooldown = 0
	witch.enabled = true
	await _frames(60)
	_check(get_nodes_in_group("hazards").is_empty() and not witch.casting, "witch_cannot_cast_through_occluding_wall")
	witch.enabled = false
	wall.queue_free()
	await _frames(2)
	bolt = HexBolt.new()
	bolt.position = center - Vector2(100,0)
	level.world_objects.add_child(bolt)
	player.position = center + Vector2(0,50)
	await _frames(90)
	_check(player.hex_remaining == 0 and is_instance_valid(bolt), "sidestep_dodges_non_homing_bolt")
	bolt.queue_free()
	witch.queue_free()
	player.get_node("Camera2D").offset = Vector2.ZERO
	player.get_node("Camera2D").zoom = Vector2.ONE
	await _frames(1)


func _site_tour() -> void:
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	for hazard in get_nodes_in_group("hazards"):
		hazard.queue_free()
	level.message_time = 0
	player.hex_remaining = 0
	player.flashlight_charge = 90
	player.flashlight_on = true
	player.get_node("Camera2D").zoom = Vector2(0.75,0.75)
	for site: ForestSite in level.camp_map.sites:
		player.position = site.definition["position"] + Vector2(0,40)
		player.facing = Vector2.UP
		player.get_node("Camera2D").offset = Vector2(0,-24)
		await _frames(20)
		await _snapshot("hunt_" + site.definition["kind"])
	player.get_node("Camera2D").offset = Vector2.ZERO
	player.get_node("Camera2D").zoom = Vector2.ONE
