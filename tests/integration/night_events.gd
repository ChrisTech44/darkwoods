extends SceneTree
## Story events (The Hunt Begins, The Stalker's Gift, Lost Camper), director
## build-ups (distant call + flashlight flicker) and the audio revamp: louder,
## farther creature calls, killer voices and the distant chorus.
var checks := 0
var failures := 0
var level: Node2D
var player: CampPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var previous_role: String = root.get_node("Session").survivor
	root.get_node("Session").survivor = "jock"
	RoundPlan.force_modifiers = []
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
	_hunt_checks()
	_gift_checks()
	await _camper_checks()
	_buildup_checks()
	_audio_checks()
	RoundPlan.force_modifiers = null
	root.get_node("Session").select_survivor(previous_role)
	print(JSON.stringify({"event": "test_result", "suite": "night_events", "checks": checks, "failures": failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _roamer() -> CampCryptid:
	for enemy: CampCryptid in get_nodes_in_group("cryptids"):
		if not enemy.home.has_area():
			return enemy
	return null


func _hunt_checks() -> void:
	var events: NightEvents = level.events
	var noise := CampMap.CAMP_BOUNDS.get_center() + Vector2(900, 0)
	level.loud_noise(noise, 10)
	_check(events.last_loud == noise, "loud_noise_in_inner_ring_remembered")
	level.loud_noise(CampMap.CAMP_BOUNDS.get_center() + Vector2(3000, 0), 10)
	_check(events.last_loud == noise, "far_noise_outside_ring_ignored")
	var roamer := _roamer()
	roamer.enabled = true
	roamer.state = CampKiller.State.PATROL
	roamer.position = level.plan.woods.center(Vector2i(4, 4))
	level.night_clock._start_event("hunt")
	_check(events.hunt_remaining == NightEvents.HUNT_SECONDS, "hunt_starts_for_a_minute")
	events.advance(0.1)
	_check(roamer.state == CampKiller.State.INVESTIGATE and roamer.last_seen == noise, "hunt_sends_roamers_to_last_loud_noise")
	_check(level.soundscape.played_counts.get("hunting_horn", 0) == 1, "hunt_horn_plays")
	roamer.enabled = false
	roamer.state = CampKiller.State.PATROL
	events.hunt_remaining = 0.0


func _gift_checks() -> void:
	var events: NightEvents = level.events
	level.night_clock._start_event("gift")
	_check(events.gift_at != Vector2.INF and level.pins.any(func(pin: Dictionary) -> bool: return pin["name"] == "GIFT"), "gift_crate_placed_and_pinned")
	var stalker: CampKiller = level.killer
	stalker.enabled = true
	stalker.state = CampKiller.State.PATROL
	player.position = events.gift_at
	player.supplies["medkit"] = 0
	var flares: int = player.supplies["flare"]
	_check(level.context_prompt().contains("GIFT CRATE"), "gift_prompt")
	_check(level.try_interact(player) and events.gift_open and player.supplies["flare"] >= flares + 2 and player.supplies["medkit"] == 1, "gift_gives_supplies")
	_check(stalker.state == CampKiller.State.INVESTIGATE and stalker.last_seen == events.gift_at, "gift_bell_calls_the_killer")
	_check(not level.pins.any(func(pin: Dictionary) -> bool: return pin["name"] == "GIFT"), "gift_pin_cleared")
	stalker.enabled = false
	stalker.state = CampKiller.State.PATROL


func _camper_checks() -> void:
	var events: NightEvents = level.events
	level.night_clock._start_event("camper")
	_check(is_instance_valid(events.camper_body) and level.pins.any(func(pin: Dictionary) -> bool: return pin["name"] == "CAMPER"), "lost_camper_placed_and_pinned")
	var start: Vector2 = events.camper_at
	# Put the camper near camp to keep the escort short; the rules are the same.
	events.camper_body.position = CampMap.CAMP_BOUNDS.position + Vector2(-60, 300)
	player.position = events.camper_body.position + Vector2(20, 0)
	await physics_frame
	events.advance(0.1)
	_check(events.camper_leader == player.get_instance_id(), "camper_follows_first_survivor_to_reach_them")
	var stalker: CampKiller = level.killer
	stalker.enabled = true
	stalker.state = CampKiller.State.CHASE
	stalker.position = events.camper_body.position + Vector2(40, 0)
	events.advance(0.1)
	_check(events.camper_panic > 0.0, "camper_panics_when_chased")
	stalker.enabled = false
	stalker.state = CampKiller.State.PATROL
	stalker.position = Vector2(600, 520)
	events.camper_panic = 0.0
	player.position = CampMap.CAMP_BOUNDS.position + Vector2(40, 300)
	var medkits: int = player.supplies.get("medkit", 0)
	for step in range(240):
		events.advance(1.0 / 30.0)
		await physics_frame
		if events.camper_saved:
			break
	_check(events.camper_saved and player.supplies.get("medkit", 0) == medkits + 1, "camper_reaches_camp_and_gives_medkit")
	_check(start != Vector2.INF, "camper_spawned_in_a_region")
	var card: Dictionary = level.compute_score(true)
	_check(card["lines"].has("LOST CAMPER +250"), "rescued_camper_scores")


func _buildup_checks() -> void:
	var clock: NightClock = level.night_clock
	var roamer := _roamer()
	roamer.enabled = true
	roamer.state = CampKiller.State.PATROL
	player.position = level.plan.woods.center(Vector2i(10, 24))
	roamer.position = NavigationServer2D.map_get_closest_point(level.get_world_2d().navigation_map, player.position + Vector2(0, 1000))
	clock.relief.clear()
	var calls: int = level.soundscape.played_counts.get("distant_call", 0)
	_check(clock.direct() >= 1 and player.flicker > 0.0, "director_peak_flickers_the_light")
	_check(level.soundscape.played_counts.get("distant_call", 0) == calls + 1, "director_peak_has_a_distant_call")
	roamer.enabled = false


func _audio_checks() -> void:
	var sound: CampSoundscape = level.soundscape
	_check(CampSoundscape.MONSTER_RANGE >= 500.0 and CampSoundscape.ENEMY_STEP_RANGE >= 200.0, "creature_calls_and_steps_carry_farther")
	for voice in sound.voices:
		voice.queue_free()
	sound.voices.clear()
	var stalker: CampKiller = level.killer
	stalker.enabled = true
	stalker.state = CampKiller.State.CHASE
	stalker.position = player.position + Vector2(300, 0)
	sound.killer_call_clock = 0.0
	var screams: int = sound.played_counts.get("screech_3", 0) + sound.played_counts.get("screech_2", 0)
	sound._killer_voice(stalker, 0.1)
	_check(sound.played_counts.get("screech_3", 0) + sound.played_counts.get("screech_2", 0) == screams + 1, "headline_killer_screams_in_a_chase")
	stalker.enabled = false
	stalker.state = CampKiller.State.PATROL
	var chorus: int = sound.played_counts.get("distant_call", 0)
	var far := _roamer()
	far.enabled = true
	far.position = player.position + Vector2(1200, 0)
	sound.chorus_clock = 0.0
	sound._chorus(0.1)
	far.enabled = false
	_check(sound.played_counts.get("distant_call", 0) == chorus + 1, "distant_chorus_from_far_creatures")
	var roamer := _roamer()
	roamer.position = player.position + Vector2(450, 0)
	var cue: String = CampSoundscape.CREATURE_CUES[roamer.species]
	var before: int = sound.played_counts.get(cue, 0)
	for voice in sound.voices:
		voice.queue_free()
	sound.voices.clear()
	sound.call_timers[roamer.get_instance_id()] = 0.0
	sound._creature_call(roamer)
	_check(sound.played_counts.get(cue, 0) == before + 1, "creature_call_heard_at_450px")


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame


func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": passed}))
