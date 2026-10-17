extends SceneTree
## Playtest feedback round (17 October): health and per-creature damage with
## cooldowns, fewer creatures spread through the woods, camp closed to creatures
## until Deep Night, walkable-but-visible lake water, lobby name memory and
## voice that cuts through the woods.
var checks := 0
var failures := 0
var level: Node2D
var player: CampPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_encounter_checks()
	await _lobby_checks()
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
	level.night_clock.director_enabled = false
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	await _frames(4)
	await _health_checks()
	await _threat_checks()
	await _camp_checks()
	_water_checks()
	_voice_checks()
	root.get_node("Session").select_survivor(previous_role)
	print(JSON.stringify({"event":"test_result","suite":"design_feedback","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _encounter_checks() -> void:
	_check(RoundPlan.CRYPTID_COUNT <= 30, "fewer_creatures_than_before")
	for value in [42, 7, 2026, 6789]:
		var plan := RoundPlan.new()
		plan.generate(value, "woods")
		# Two region dwellers and six guardians come first; the rest roam.
		var roamers: Array[Vector2] = []
		for encounter in plan.encounters.slice(8):
			roamers.append(encounter["position"])
		var center := CampMap.CAMP_BOUNDS.get_center()
		var closest := INF
		var gap := INF
		var quadrants := {}
		for index in range(roamers.size()):
			closest = minf(closest, roamers[index].distance_to(center))
			var offset := roamers[index] - center
			var key := "%d%d" % [int(offset.x > 0), int(offset.y > 0)]
			quadrants[key] = quadrants.get(key, 0) + 1
			for other in range(index + 1, roamers.size()):
				gap = minf(gap, roamers[index].distance_to(roamers[other]))
		_check(plan.encounters.size() == RoundPlan.CRYPTID_COUNT and roamers.size() == RoundPlan.ROAMERS, "roamer_count_%d" % value)
		_check(closest >= RoundPlan.SAFE_RADIUS, "no_roamer_near_camp_%d" % value)
		_check(gap >= 600.0, "roamers_spread_apart_%d_min_%d" % [value, int(gap)])
		_check(quadrants.size() == 4 and quadrants.values().min() >= 2, "roamers_in_every_quarter_%d" % value)


func _lobby_checks() -> void:
	var lobby_script: GDScript = load("res://scripts/ui/network_lobby.gd")
	lobby_script.prefs_path = "user://lobby_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lobby_script.prefs_path))
	change_scene_to_file("res://scenes/ui/network_lobby.tscn")
	await _frames(3)
	var lobby: Control = current_scene
	lobby.fields["Name"].text = "Riley"
	lobby.fields["Address"].text = "10.0.0.7"
	lobby._save_prefs()
	change_scene_to_file("res://scenes/ui/network_lobby.tscn")
	await _frames(3)
	lobby = current_scene
	_check(lobby.fields["Name"].text == "Riley" and lobby.fields["Address"].text == "10.0.0.7", "lobby_remembers_name_and_address")
	_check(lobby.voice_meters != null, "lobby_shows_voice_meters")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lobby_script.prefs_path))
	lobby_script.prefs_path = lobby_script.PREFS


func _health_checks() -> void:
	player.position = level.plan.woods.center(Vector2i(18, 24))
	_check(is_equal_approx(player.health, CampPlayer.MAX_HEALTH) and not player.wounded, "starts_at_full_health")
	_check(player.receive_hit(15.0) and is_equal_approx(player.health, 85.0) and not player.wounded and player.status == CampPlayer.Status.ALIVE, "light_hit_takes_health_only")
	_check(not player.receive_hit(15.0) and is_equal_approx(player.health, 85.0), "grace_blocks_back_to_back_hits")
	player.invulnerability = 0.0
	player.receive_hit(40.0)
	_check(player.wounded and is_equal_approx(player.health, 45.0), "below_half_is_wounded")
	await _frames(2)
	_check(level.hud.health.value < 50.0, "hud_health_bar_tracks_health")
	player.supplies["medkit"] = 2
	_check(level.use_supply(player, "medkit") and is_equal_approx(player.health, 95.0) and not player.wounded, "medkit_heals_fifty")
	_check(level.use_supply(player, "medkit") and is_equal_approx(player.health, CampPlayer.MAX_HEALTH), "medkit_caps_at_full")
	player.supplies["medkit"] = 1
	_check(not level.use_supply(player, "medkit") and player.supplies["medkit"] == 1, "medkit_refused_at_full_health")
	player.invulnerability = 0.0
	player.receive_hit(60.0)
	player.invulnerability = 0.0
	player.receive_hit(60.0)
	_check(player.status == CampPlayer.Status.DOWNED and is_zero_approx(player.health), "zero_health_downs")
	player.set_status(CampPlayer.Status.ALIVE)
	_check(is_equal_approx(player.health, CampPlayer.REVIVE_HEALTH) and player.wounded, "revived_with_low_health")
	player.wounded = false
	player.invulnerability = 0.0


func _threat_checks() -> void:
	var table: Dictionary = CampKiller.THREATS
	var covered := true
	for encounter in level.plan.encounters:
		covered = covered and table.has(encounter["species"])
	_check(covered and table.has("stalker") and table.has("groundskeeper"), "every_creature_has_a_threat_row")
	_check(table["bigfoot"][0] > table["lantern_moth"][0] and table["bigfoot"][1] > table["lantern_moth"][1], "easy_to_evade_hits_harder_with_longer_cooldown")
	var max_light := 0.0
	for species: String in table:
		if table[species][1] <= 1.5:
			max_light = maxf(max_light, table[species][0])
	_check(max_light <= 20.0, "quick_attackers_hit_lightly")
	var beast: CampCryptid
	for enemy: CampCryptid in get_nodes_in_group("cryptids"):
		if enemy.species == "bigfoot":
			beast = enemy
	_check(beast != null and is_equal_approx(beast.hit_damage, table["bigfoot"][0]) and is_equal_approx(beast.hit_cooldown, table["bigfoot"][1]), "creature_uses_its_threat_row")
	player.position = level.plan.woods.center(Vector2i(18, 24))
	beast.position = player.position + Vector2(8, 0)
	_check(beast.land_hit(player, beast.hit_damage) and is_equal_approx(player.health, 100.0 - table["bigfoot"][0]), "hit_deals_creature_damage")
	_check(is_equal_approx(beast.attack_remaining, beast.hit_cooldown) and beast.recover_remaining > 0.0, "hit_starts_cooldown_and_recovery")
	beast.enabled = true
	var before := beast.position
	await _frames(20)
	_check(beast.position.distance_to(before) < 0.5 and player.status == CampPlayer.Status.ALIVE, "creature_pauses_after_a_hit")
	beast.enabled = false
	beast.position = before + Vector2(0, 4000)
	player.wounded = false
	player.invulnerability = 0.0


func _camp_checks() -> void:
	_check(CampKiller.camp_closed, "camp_closed_at_dusk")
	_check(not CampKiller.in_camp(level.killer.global_position) and level.killer.global_position.distance_to(CampMap.CAMP_BOUNDS.get_center()) >= RoundPlan.SAFE_RADIUS - 1.0, "stalker_starts_in_the_woods")
	var inside := Vector2(1500, 512)
	_check(not CampKiller.in_camp(CampKiller.outside_camp(inside)), "routes_are_pushed_out_of_camp")
	var watcher: CampCryptid = get_nodes_in_group("cryptids")[3]
	watcher.home = Rect2()
	watcher.position = Vector2(CampMap.CAMP_BOUNDS.end.x + 70.0, 512)
	watcher.state = CampKiller.State.PATROL
	player.position = inside
	_check(watcher.sense_visible_target() == null, "creatures_cannot_see_into_closed_camp")
	watcher.hear_stimulus(inside, INF)
	_check(watcher.state == CampKiller.State.PATROL, "creatures_ignore_noise_in_closed_camp")
	watcher.enabled = true
	watcher.last_seen = inside
	watcher.transition(CampKiller.State.INVESTIGATE)
	await _frames(90)
	_check(not CampKiller.in_camp(watcher.global_position), "creatures_never_walk_into_closed_camp")
	watcher.enabled = false
	level.night_clock.force_phase(2)
	_check(not CampKiller.camp_closed and level.killer.patrol == level.camp_tour(), "deep_night_opens_camp")
	watcher.enabled = true
	watcher.state = CampKiller.State.PATROL
	watcher.hear_stimulus(inside, INF)
	_check(watcher.state == CampKiller.State.INVESTIGATE, "creatures_hear_camp_after_deep_night")
	watcher.enabled = false


func _water_checks() -> void:
	var zone: Dictionary = level.plan.woods.zones.filter(func(item: Dictionary) -> bool: return item["kind"] == "boathouse")[0]
	var rects: Array[Rect2] = FieldEscapeArt.water_rects(zone["position"])
	var across := PhysicsRayQueryParameters2D.create(rects[0].position + Vector2(20, 20), rects[0].end - Vector2(20, 20), 1)
	_check(level.get_world_2d().direct_space_state.intersect_ray(across).is_empty(), "sight_and_voice_carry_across_water")
	var solid := PhysicsRayQueryParameters2D.create(rects[0].position + Vector2(20, 20), rects[0].end - Vector2(20, 20), CampPlayer.WATER_LAYER)
	solid.hit_from_inside = true
	_check(not level.get_world_2d().direct_space_state.intersect_ray(solid).is_empty() and player.collision_mask & CampPlayer.WATER_LAYER != 0, "water_still_blocks_walking")
	var lake: LakeWater
	for node in level.find_children("*", "Node2D", true, false):
		if node is LakeWater:
			lake = node
	_check(lake != null and lake.material is ShaderMaterial and lake.rects.size() == 3, "lake_draws_animated_water")


func _voice_checks() -> void:
	var voice_bus := AudioServer.get_bus_index("Voice")
	_check(voice_bus >= 0 and AudioServer.get_bus_effect_count(voice_bus) >= 1 and AudioServer.get_bus_effect(voice_bus, 0) is AudioEffectCompressor, "voice_bus_levels_quiet_speakers")
	var muffled := AudioServer.get_bus_index("VoiceMuffled")
	_check(muffled >= 0 and (AudioServer.get_bus_effect(muffled, 0) as AudioEffectLowPassFilter).cutoff_hz >= 2000.0, "walls_soften_voice_without_smothering_it")
	_check(VoiceChat.HEAR_RANGE >= 500.0 and VoiceChat.VOICE_ATTENUATION < 1.0, "voice_carries_further_and_fades_gently")
	var mixer: Node = root.get_node("AudioManager")
	var music := AudioServer.get_bus_index("Music")
	var base := AudioServer.get_bus_volume_db(music)
	mixer.set_duck({"Music": -10.0})
	_check(is_equal_approx(AudioServer.get_bus_volume_db(music), base - 10.0), "music_ducks_under_voice")
	mixer.set_duck({})
	_check(is_equal_approx(AudioServer.get_bus_volume_db(music), base), "ducking_releases")


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _check(condition: bool, name: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(JSON.stringify({"event":"assertion","name":name,"passed":condition}))
