extends SceneTree
## The 18 October creatures: Groundskeeper (mower), Cuckoo, Banshee, Slug,
## Surveyor, Hitchhiker, Tollkeeper, Echo and Fortune Teller. Each verb is
## exercised on a quiet woods trail (seed 42, other creatures frozen).
var level: Node2D
var player: CampPlayer
var trail := Vector2.ZERO
var along := Vector2.RIGHT
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": name, "passed": ok}))


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame
		await physics_frame


func _run() -> void:
	var previous_role: String = root.get_node("Session").survivor
	root.get_node("Session").survivor = "jock"
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	RoundPlan.force_modifiers = []
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	while current_scene == null or current_scene.name != "ForestLevel":
		await process_frame
	level = current_scene
	player = level.player
	player.local_input = false
	level.night_clock.director_enabled = false
	level.night_clock.set_physics_process(false)
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	_find_trail()
	for attempt in range(300):
		if NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, trail, trail + along * 120, true).size() > 1:
			break
		await physics_frame
	_check(level.killer.headline == "stalker", "stalker_headlines")
	# One roaming kind rests each night, so look across a few seeds.
	var spawned := {}
	for seed_value in [42, 43, 44]:
		var plan := RoundPlan.new()
		plan.generate(seed_value, "woods")
		for row in plan.encounters:
			spawned[row["species"]] = true
	_check(["groundskeeper", "cuckoo", "banshee", "slug", "surveyor", "hitchhiker", "tollkeeper", "echo", "fortune_teller"].all(func(species: String) -> bool: return spawned.has(species) and CreatureBrain.for_species(species) != null and ResourceLoader.exists("res://assets/sprites/%s.png" % species)), "new_creatures_spawn_with_brains_and_art")
	await _groundskeeper()
	await _cuckoo()
	await _banshee()
	await _slug()
	await _surveyor()
	await _hitchhiker()
	await _tollkeeper()
	await _echo()
	await _fortune_teller()
	root.get_node("Session").select_survivor(previous_role)
	RoundPlan.force_modifiers = null
	print(JSON.stringify({"event": "test_result", "suite": "new_creatures", "checks": checks, "failures": failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _find_trail() -> void:
	var woods: WoodsLayout = level.plan.woods
	for cell: Vector2i in woods.links:
		var links: Array = woods.links[cell]
		var at: Vector2 = woods.center(cell)
		if links.size() == 2 and (cell + Vector2i.LEFT) in links and (cell + Vector2i.RIGHT) in links and (cell + Vector2i(2, 0)) in woods.links.get(cell + Vector2i.RIGHT, []) and woods.zone_at(at).is_empty() and not woods.on_road(at) and at.distance_to(CampMap.CAMP_BOUNDS.get_center()) > 1500:
			trail = at
			return
	trail = woods.center(Vector2i(18, 24))


func _reset(offset := Vector2.ZERO) -> void:
	if player.has_effect("held"):
		player.release()
	player.status = CampPlayer.Status.ALIVE
	player.health = CampPlayer.MAX_HEALTH
	player.effects.clear()
	player.effect_data.clear()
	player.invulnerability = 0.0
	player.ward_remaining = 0.0
	player.knock = Vector2.ZERO
	player.hidden_spot = -1
	player.flashlight_on = true
	player.flashlight_charge = 90.0
	player.facing = Vector2.RIGHT
	player.global_position = trail + offset
	player.velocity = Vector2.ZERO


func _spawn(species: String, offset: Vector2) -> CampCryptid:
	var enemy: CampCryptid = preload("res://scenes/actors/cryptid.tscn").instantiate()
	enemy.species = species
	enemy.config = level.config
	enemy.position = trail + offset
	enemy.patrol.assign([trail + offset, trail + offset + along * 40])
	level.world_objects.add_child(enemy)
	enemy.enabled = true
	return enemy


func _despawn(enemy: CampKiller) -> void:
	enemy.release_held()
	enemy.enabled = false
	enemy.queue_free()
	await _frames(2)


func _step(enemy: CampCryptid, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		enemy.brain.physics(1.0 / 60.0)
		t += 1.0 / 60.0


func _groundskeeper() -> void:
	_reset()
	var keeper := _spawn("groundskeeper", Vector2(-60, 0))
	await _frames(2)
	var brain = keeper.brain
	_check(brain.riding and keeper.has_node("PointLight2D") or brain.headlight != null, "groundskeeper_rides_with_a_headlight")
	brain.heading = Vector2.RIGHT
	_check(brain.senses(player) == 1, "headlight_sees_ahead")
	brain.heading = Vector2.LEFT
	player.global_position = trail + Vector2(60, 0)
	_check(brain.senses(player) == 0, "blind_behind_the_mower")
	# Run over: driving at speed into a survivor in front.
	brain.heading = Vector2.RIGHT
	brain.speed = 110.0
	player.global_position = keeper.global_position + Vector2(10, 0)
	var health := player.health
	brain._run_over()
	_check(player.health < health and player.knock.length() > 100.0, "mower_runs_you_over")
	_reset()
	# Lose him: he parks and walks with the rake.
	brain._dismount()
	_check(not brain.riding and brain.mower_at.distance_to(keeper.global_position) < 1.0, "parks_and_walks")
	# Sabotage: hold E at the parked mower.
	keeper.global_position = trail + Vector2(-300, 0)
	player.global_position = brain.mower_at + Vector2(0, 12)
	_check(brain.prompt(player).begins_with("HOLD E"), "spark_plug_prompt_at_parked_mower")
	Input.action_press("interact")
	_step(keeper, 3.2)
	Input.action_release("interact")
	_check(brain.dead > 60.0 and "mower" in level.feats, "spark_plug_pulled_kills_the_mower")
	_check(brain.prompt(player).is_empty(), "dead_mower_offers_no_prompt")
	await _despawn(keeper)


func _cuckoo() -> void:
	_reset()
	var cuckoo := _spawn("cuckoo", Vector2(90, 0))
	await _frames(2)
	var brain = cuckoo.brain
	brain.cooldown = 0.0
	# Walk the survivor along for 8 s of history, then let it count to three.
	for index in range(40):
		player.global_position = trail + Vector2(index * 1.0, 0)
		brain._record(0.3)
	var start: Vector2 = brain.history[player.get_instance_id()][0]
	_step(cuckoo, 3.4)
	_check(player.global_position.distance_to(start) < 20.0 and player.has_effect("rewound"), "third_cuckoo_rewinds_you")
	_reset()
	brain.cooldown = 0.0
	brain.history.clear()
	_step(cuckoo, 1.2)
	player.hidden_spot = 0
	_step(cuckoo, 0.5)
	_check(brain.victim == null, "breaking_sight_stops_the_count")
	await _despawn(cuckoo)


func _banshee() -> void:
	_reset()
	var banshee := _spawn("banshee", Vector2(80, 0))
	await _frames(2)
	banshee.brain.cooldown = 0.0
	_step(banshee, 0.1)
	_check(banshee.brain.inhale > 0.0, "banshee_draws_breath")
	_step(banshee, 1.8)
	_check(player.has_effect("deaf"), "scream_deafens")
	level.soundscape._physics_process(1.0 / 60.0)
	_check(root.get_node("AudioManager").muffled, "deafness_muffles_local_audio")
	player.clear_effect("deaf")
	level.soundscape._physics_process(1.0 / 60.0)
	_check(not root.get_node("AudioManager").muffled, "hearing_returns")
	await _despawn(banshee)


func _slug() -> void:
	_reset(Vector2(200, 0))
	var slug := _spawn("slug", Vector2.ZERO)
	await _frames(2)
	slug.brain.puddles.append([trail + Vector2(40, 0), 60.0])
	player.global_position = trail + Vector2(40, 0)
	_step(slug, 0.05)
	_check(player.has_effect("slimed"), "slime_makes_you_skate")
	player.apply_intent(Vector2.RIGHT, false, 1.0 / 60.0)
	var first := player.velocity.length()
	_check(first < player.config.walk_speed * 0.5, "skating_starts_slowly")
	player.ward_remaining = 3.0
	player.global_position = slug.global_position + Vector2(20, 0)
	_step(slug, 0.05)
	_check(slug.brain.shrivel > 0.0 and slug.brain.puddles.is_empty(), "salt_shrivels_slug_and_dissolves_slime")
	await _despawn(slug)


func _surveyor() -> void:
	_reset()
	var surveyor := _spawn("surveyor", Vector2(14, 0))
	await _frames(2)
	surveyor.brain.contact(player)
	_check(player.has_effect("lost"), "surveyor_touch_leaves_you_lost")
	await _frames(2)
	_check(level.hud.location_label.text.begins_with("LOST"), "lost_hides_location")
	var friend: CampPlayer = level.PLAYER_SCENE.instantiate()
	friend.role = "medic"
	friend.local_input = false
	friend.position = player.global_position + Vector2(20, 0)
	level.world_objects.add_child(friend)
	await _frames(2)
	surveyor.global_position = trail + Vector2(400, 0)
	_step(surveyor, 3.2)
	_check(not player.has_effect("lost"), "teammate_beside_you_restores_bearings")
	friend.queue_free()
	await _despawn(surveyor)


func _hitchhiker() -> void:
	_reset()
	var rider := _spawn("hitchhiker", Vector2(12, 0))
	await _frames(2)
	rider.brain.contact(player)
	_step(rider, 0.1)
	_check(player.has_effect("piggyback"), "hitchhiker_climbs_on")
	player.apply_intent(Vector2.RIGHT, true, 1.0 / 60.0)
	_check(not player.sprinting and player.velocity.length() < player.config.walk_speed, "rider_slows_and_stops_sprint")
	var friend: CampPlayer = level.PLAYER_SCENE.instantiate()
	friend.role = "medic"
	friend.local_input = false
	friend.position = player.global_position + Vector2(8, 0)
	level.world_objects.add_child(friend)
	await _frames(2)
	rider.brain.tag_lock = 0.0
	_step(rider, 0.1)
	_check(rider.brain.rider_of == friend and not player.has_effect("piggyback"), "tag_passes_the_hitchhiker")
	rider.brain._hop_off(friend)
	friend.queue_free()
	await _despawn(rider)


func _tollkeeper() -> void:
	_reset(Vector2(-60, 0))
	var troll := _spawn("tollkeeper", Vector2.ZERO)
	await _frames(2)
	player.global_position = troll.global_position + Vector2(-16, 0)
	var health := player.health
	_step(troll, 0.05)
	_check(player.health < health and player.knock.length() > 100.0, "unpaid_survivor_shoved_back")
	_reset()
	player.global_position = troll.global_position + Vector2(-30, 0)
	player.supplies["flare"] = 2
	player.tidy_belt()
	_check(troll.brain.prompt(player).begins_with("E · PAY THE TOLL"), "toll_prompt")
	level.try_interact(player)
	_check(player.supplies["flare"] == 1 and troll.brain.paid.has(player.get_instance_id()), "toll_paid_with_a_supply")
	player.global_position = troll.global_position + Vector2(10, 0)
	health = player.health
	_step(troll, 0.05)
	_check(player.health == health, "paid_survivor_passes")
	await _despawn(troll)


func _echo() -> void:
	_reset(Vector2(-200, 0))
	var echo := _spawn("echo", Vector2.ZERO)
	await _frames(2)
	echo.brain.whistle_clock = 0.0
	_step(echo, 0.05)
	_check(echo.brain.whistles == 1, "echo_whistles_the_camp_song")
	var before := echo.global_position
	player.global_position = echo.global_position + Vector2(-60, 0)
	player.facing = Vector2.RIGHT
	player.flashlight_on = true
	_step(echo, 0.05)
	_check(echo.global_position.distance_to(before) > 500.0, "light_bursts_the_echo")
	await _despawn(echo)


func _fortune_teller() -> void:
	_reset()
	var teller := _spawn("fortune_teller", Vector2(12, 0))
	await _frames(2)
	teller.brain.cooldown = 0.0
	teller.brain.contact(player)
	_step(teller, 1.8)
	var card: String = teller.brain.last_card
	_check(card in teller.brain.CARDS and player.has_effect("card") and str(player.effect_data.get("card", "")) == card, "fortune_teller_deals_a_card")
	_check(teller.global_position.distance_to(player.global_position) > 500.0, "she_vanishes_after_the_reading")
	await _despawn(teller)
