extends SceneTree
## Monster revamp (docs/monster_revamp.md): every creature's verb, the stalker's
## own traits and the new items, each exercised in a controlled scene on a
## straight woods trail with everything else switched off.
var checks := 0
var failures := 0
var level: Node2D
var player: CampPlayer
var trail := Vector2.ZERO
var along := Vector2.RIGHT


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var previous_role: String = root.get_node("Session").survivor
	root.get_node("Session").survivor = "jock"
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	RoundPlan.force_modifiers = []
	RoundPlan.force_headline = "stalker"
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	while current_scene == null or current_scene.name != "ForestLevel":
		await process_frame
	level = current_scene
	player = level.player
	player.local_input = false
	level.night_clock.director_enabled = false
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	_find_trail()
	for attempt in range(300):
		if NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, trail, trail + along * 120, true).size() > 1:
			break
		await physics_frame
	_roster_checks()
	await _vampire()
	await _werewolf()
	await _bigfoot()
	await _witch()
	await _moth()
	await _puffball()
	await _scarecrow()
	await _hound()
	await _jackal()
	await _peeper()
	await _paparazzo()
	await _conductor()
	await _ram()
	await _snuffer()
	await _seamstress()
	await _lullaby()
	await _mimic()
	await _owl()
	await _bog_hands()
	await _imps()
	await _teddy()
	await _stalker()
	await _items()
	root.get_node("Session").select_survivor(previous_role)
	RoundPlan.force_modifiers = null
	RoundPlan.force_headline = ""
	print(JSON.stringify({"event":"test_result","suite":"monster_revamp","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


## A straight east-west trail cell far from camp, regions and roads.
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
	player.knock = Vector2.ZERO
	player.hidden_spot = -1
	player.snared = 0.0
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


func _roster_checks() -> void:
	var seen: Dictionary = {}
	for encounter in level.plan.encounters:
		seen[encounter["species"]] = true
	_check(level.plan.encounters.size() == RoundPlan.CRYPTID_COUNT, "roster_size")
	var missing: Array = []
	for species: String in CampProfile.TIPS:
		if species in ["stalker", "groundskeeper", "vampire", "witch"]:
			continue
		if not seen.has(species):
			missing.append(species)
		if CreatureBrain.for_species(species) == null:
			missing.append("brain:" + species)
	_check(missing.is_empty(), "every_creature_spawns_with_a_brain %s" % str(missing))
	_check(level.plan.encounters.filter(func(row: Dictionary) -> bool: return row["species"] == "switchback_hound").size() == 1, "buster_is_unique")
	_check(level.plan.encounters.filter(func(row: Dictionary) -> bool: return row["species"] == "relay_jackal").size() == 2, "jackals_come_as_a_pair")
	var names: Dictionary = {}
	for species: String in CampProfile.NAMES:
		names[CampProfile.NAMES[species]] = true
	_check(names.size() == CampProfile.NAMES.size() and CampProfile.NAMES.size() == CampProfile.TIPS.size(), "every_creature_named_uniquely")


func _vampire() -> void:
	_reset()
	player.facing = Vector2.LEFT
	var vampire := _spawn("vampire", along * 110)
	await _frames(20)
	_check(player.has_effect("hypnotized"), "vampire_gaze_hypnotizes")
	player.facing = along
	await _frames(4)
	var lit_free: bool = not player.has_effect("hypnotized") or player.effects.get("hypnotized", 0.0) <= 0.25
	_check(lit_free, "beam_on_vampire_breaks_the_pull")
	vampire.brain.contact(player)
	_check(player.has_effect("held") and vampire.held == player, "vampire_bite_latches")
	await _frames(30)
	_check(player.health < 99.0 and player.health > 80.0, "latched_vampire_drains_health")
	for press in range(8):
		level.try_interact(player)
	_check(not player.has_effect("held") and vampire.held == null, "eight_presses_break_the_bite")
	_reset()
	player.add_effect("garlic", 60.0)
	vampire.recover_remaining = 0.0
	vampire.global_position = trail + along * 60
	var before := vampire.global_position.distance_to(player.global_position)
	await _frames(40)
	_check(vampire.global_position.distance_to(player.global_position) > before and not player.has_effect("hypnotized"), "garlic_drives_the_vampire_off")
	await _despawn(vampire)


func _werewolf() -> void:
	_reset()
	level.night_clock.moon = false
	var wolf := _spawn("werewolf", along * 40)
	await _frames(5)
	_check(not wolf.brain.wolf and not wolf.can_sense(player), "werewolf_is_a_harmless_hiker_without_moon")
	level.night_clock.set_moon(true)
	await _frames(3)
	_check(wolf.brain.wolf and wolf.door_force > 10.0, "moon_turns_hiker_into_rampaging_wolf")
	wolf.brain.contact(player)
	_check(is_equal_approx(player.health, 100.0 - 35.0) and player.knock.length() > 300.0, "pounce_hits_and_knocks_flying")
	_reset()
	player.supplies["wolfsbane"] = 1
	player.belt[3] = "wolfsbane"
	player.facing = player.global_position.direction_to(wolf.global_position)
	_check(level.use_supply(player, "wolfsbane") and not wolf.brain.wolf, "wolfsbane_turns_it_back")
	level.night_clock.set_moon(false)
	await _despawn(wolf)


func _bigfoot() -> void:
	_reset()
	player.flashlight_on = false
	var foot := _spawn("bigfoot", along * 30)
	await _frames(3)
	_check(player.knock.length() > 300.0 and is_equal_approx(player.health, 90.0), "startled_bigfoot_yeets_you")
	_reset(-along * 140)
	foot.global_position = trail
	foot.brain.cooldown = 8.0
	foot.brain.fleeing = 0.0
	player.facing = along
	var pickups_before: int = level.pickups.filter(func(p: CampPickup) -> bool: return p.available and p.kind == "bigfoot_fur").size()
	await _frames(3)
	var furs: Array = level.pickups.filter(func(p: CampPickup) -> bool: return p.available and p.kind == "bigfoot_fur")
	_check(furs.size() == pickups_before + 1 and foot.brain.fleeing > 0.0, "lit_from_afar_it_bolts_and_drops_fur")
	player.global_position = furs.back().global_position
	# Anything Bigfoot made you drop lies here too; keep pressing E.
	for press in range(4):
		if level.furs == 0:
			level.try_interact(player)
	_check(level.furs == 1 and level.compute_score(true)["lines"].any(func(line: String) -> bool: return line.begins_with("BIGFOOT FUR")), "fur_scores")
	await _despawn(foot)


func _witch() -> void:
	_reset()
	var witch := _spawn("witch", along * 150)
	witch.enabled = false
	player.inventory.append("fuel")
	witch.brain.curse(player, "frog")
	_check(player.has_effect("frog") and "fuel" not in player.inventory and not level.use_supply(player, "flare"), "frog_curse_drops_parts_and_blocks_items")
	_reset()
	witch.brain.curse(player, "backwards")
	var start := player.global_position
	player.apply_intent(Vector2.RIGHT, false, 0.2)
	_check(player.global_position.x < start.x, "backwards_curse_inverts_controls")
	_reset()
	witch.brain.curse(player, "swap")
	_check(player.global_position.distance_to(trail) > 50.0, "swap_curse_moves_you_when_alone")
	_reset()
	witch.brain.curse(player, "float")
	_check(player.has_effect("float") and player.effect_data.has("drift"), "float_curse_drifts")
	_reset()
	player.ward_remaining = 3.0
	witch.brain.curse(player, "frog")
	_check(not player.has_effect("frog") and witch.brain.frogged > 0.0, "salt_ward_turns_the_witch_into_a_frog")
	player.ward_remaining = 0.0
	await _despawn(witch)


func _moth() -> void:
	_reset()
	var moth := _spawn("lantern_moth", along * 20)
	moth.brain.contact(player)
	_check(player.has_effect("face_moth"), "moth_lands_on_your_face")
	var charge := player.flashlight_charge
	await _frames(30)
	_check(player.flashlight_charge < charge - 1.0, "face_moth_drinks_your_light")
	player.flash_cooldown = 0.0
	level.use_flash(player)
	_check(not player.has_effect("face_moth"), "flash_swats_the_moth")
	_reset()
	player.add_effect("bug_spray", 45.0)
	_check(not moth.can_sense(player), "bug_spray_hides_you_from_moths")
	await _despawn(moth)


func _puffball() -> void:
	_reset(along * -10)
	var puff := _spawn("ration_moth", along * 40)
	player.velocity = along * 30.0
	puff.brain._burst()
	_check(player.has_effect("helium") and player.has_effect("sneezy"), "spores_give_helium_voice_and_sneezes")
	_reset(along * -10)
	player.velocity = Vector2.ZERO
	puff.brain._burst()
	_check(not player.has_effect("helium"), "standing_still_holds_your_breath")
	_reset()
	player.add_effect("sneezy", 20.0)
	player.set_meta("sneeze_clock", 0.01)
	await _frames(3)
	_check(player.has_effect("achoo"), "sneezes_happen")
	await _despawn(puff)


func _scarecrow() -> void:
	_reset()
	var crow := _spawn("briar_revenant", along * 120)
	player.facing = along
	var at := crow.global_position
	await _frames(20)
	_check(crow.global_position.distance_to(at) < 1.0, "scarecrow_frozen_while_watched")
	player.facing = -along
	player.flashlight_on = false
	await _frames(20)
	_check(crow.global_position.distance_to(at) > 10.0, "scarecrow_moves_when_unwatched")
	_check(not crow.stun(1.5), "flash_cannot_freeze_the_scarecrow")
	await _despawn(crow)


func _hound() -> void:
	_reset()
	var dog := _spawn("switchback_hound", along * 120)
	var stalker: CampKiller = level.killer
	stalker.enabled = true
	stalker.state = CampKiller.State.PATROL
	await _frames(4)
	_check(dog.brain.barking > 0.0 and stalker.state == CampKiller.State.INVESTIGATE and stalker.last_seen.distance_to(player.global_position) < 2.0, "buster_barks_the_stalker_over")
	stalker.enabled = false
	stalker.transition(CampKiller.State.PATROL)
	dog.global_position = trail + along * 60
	player.supplies["rations"] = 1
	player.stamina = 1.0
	_check(level.use_supply(player, "rations") and dog.brain.friendly > 0.0 and not dog.can_sense(player), "rations_make_buster_a_friend")
	await _despawn(dog)


func _jackal() -> void:
	_reset()
	var jackal := _spawn("relay_jackal", along * 40)
	player.supplies["flare"] = 2
	player.belt = ["flare", "", "", "", "", ""]
	jackal.brain.contact(player)
	_check(player.supplies["flare"] == 1 and jackal.brain.loot == "flare", "jackal_snatches_from_the_belt")
	_check(level.pins.any(func(pin: Dictionary) -> bool: return pin["name"] == "DEN"), "den_is_pinned")
	jackal.stun_immunity = 0.0
	jackal.stun(1.5)
	_check(jackal.brain.loot.is_empty() and level.pickups.any(func(p: CampPickup) -> bool: return p.available and p.kind == "flare" and p.global_position.distance_to(jackal.global_position) < 4.0), "flash_makes_the_jackal_drop_it")
	jackal.brain.loot = "battery_pack"
	jackal.brain._stash()
	_check(level.pickups.any(func(p: CampPickup) -> bool: return p.available and p.kind == "battery_pack" and p.global_position.distance_to(jackal.brain.den) < 20.0), "loot_ends_up_at_the_den")
	await _despawn(jackal)


func _peeper() -> void:
	_reset()
	var peeper := _spawn("lens_eater", along * 120)
	player.facing = along
	await _frames(3)
	_check(player.has_effect("held") and peeper.held == player, "looking_at_the_peeper_locks_you")
	var start := player.global_position
	player.apply_intent(-along, true, 0.2)
	_check(player.global_position.distance_to(start) < 0.5, "locked_in_the_stare_you_cannot_move")
	await _frames(60)
	_check(player.health < 98.0, "the_stare_hurts")
	peeper.brain.stare = 6.95
	await _frames(3)
	_check(not player.has_effect("held"), "it_blinks_eventually")
	await _despawn(peeper)


func _paparazzo() -> void:
	_reset()
	var snapper := _spawn("shutter_wraith", along * 100)
	var stalker: CampKiller = level.killer
	stalker.enabled = true
	stalker.state = CampKiller.State.PATROL
	player.facing = along
	snapper.brain.cooldown = 0.0
	await _frames(int(60 * 1.2))
	_check(player.has_effect("whiteout") and player.has_effect("marked"), "flash_photo_blinds_and_marks")
	_check(stalker.state == CampKiller.State.INVESTIGATE, "the_photo_goes_to_the_stalker")
	stalker.enabled = false
	stalker.transition(CampKiller.State.PATROL)
	await _despawn(snapper)


func _conductor() -> void:
	_reset()
	var conductor := _spawn("last_car_conductor", along * 20)
	conductor.brain.contact(player)
	var yard: Vector2 = conductor.brain._rail_yard(level)
	_check(player.global_position.distance_to(yard) < 200.0, "no_ticket_sends_you_to_the_rail_yard")
	_reset()
	player.supplies["train_ticket"] = 1
	conductor.brain.contact(player)
	_check(player.global_position.distance_to(Vector2(150, 420)) < 120.0 and player.supplies["train_ticket"] == 0, "ticket_buys_a_free_ride_to_camp")
	await _despawn(conductor)


func _ram() -> void:
	_reset()
	var ram := _spawn("stoneback_ram", along * 70)
	ram.home = Rect2()
	ram.power_aim = player.global_position
	ram.power_tell = 0.01
	await _frames(40)
	_check(is_equal_approx(player.health, 70.0) and (player.knock.length() > 0.0 or player.global_position.distance_to(trail) > 20.0), "ram_charge_bowls_you_over")
	await _despawn(ram)


func _snuffer() -> void:
	_reset()
	var snuffer := _spawn("candle_grazer", along * 80)
	await _frames(2)
	_check(not player.flashlight_on, "snuffer_cuts_your_light")
	_reset()
	player.add_effect("glowing", 60.0)
	await _frames(2)
	_check(player.flashlight_on, "glow_moss_cannot_be_snuffed")
	await _despawn(snuffer)


func _seamstress() -> void:
	_reset()
	var stitcher := _spawn("bramble_seamstress", along * 100)
	stitcher.brain._stitch(player)
	_check(player.has_effect("tethered"), "thread_stitches_you_down")
	var anchor: Vector2 = player.effect_data["tether_to"]
	player.global_position = anchor + along * 200
	await _frames(60)
	_check(player.global_position.distance_to(anchor) < 150.0, "the_thread_drags_you_back")
	player.supplies["scissors"] = 1
	player.belt[4] = "scissors"
	_check(level.use_supply(player, "scissors") and not player.has_effect("tethered"), "scissors_cut_the_thread")
	await _despawn(stitcher)


func _lullaby() -> void:
	_reset()
	var saint := _spawn("boiler_saint", along * 80)
	await _frames(int(60 * 2.3))
	_check(player.has_effect("drowsy") and player.has_effect("asleep"), "standing_in_the_hymn_puts_you_to_sleep")
	_reset()
	player.add_effect("coffee", 90.0)
	await _frames(int(60 * 2.3))
	_check(not player.has_effect("asleep"), "coffee_keeps_you_awake")
	await _despawn(saint)


func _mimic() -> void:
	_reset()
	var mimic := _spawn("mimic", along * 150)
	await _frames(2)
	_check(mimic.brain.revealed <= 0.0 and mimic.brain.role in SurvivorRoster.IDS, "mimic_wears_a_survivor")
	mimic.global_position = trail + along * 30
	await _frames(3)
	_check(mimic.brain.revealed > 0.0 and is_equal_approx(player.health, 75.0) and player.has_effect("tripped"), "up_close_it_reveals_and_strikes")
	await _despawn(mimic)


func _owl() -> void:
	_reset()
	var owl := _spawn("owl", along * 40)
	owl.brain.cooldown = 0.0
	for frame in range(60 * 4):
		await physics_frame
		if player.has_effect("held"):
			break
	_check(player.has_effect("held") and owl.held == player, "lone_survivor_snatched_by_the_owl")
	var grabbed_at := player.global_position
	for frame in range(60 * 12):
		await physics_frame
		if not player.has_effect("held"):
			break
	_check(not player.has_effect("held") and player.global_position.distance_to(grabbed_at) > 300.0 and is_equal_approx(player.health, 90.0), "carried_off_and_dropped_far_away")
	await _despawn(owl)


func _bog_hands() -> void:
	_reset(along * 60)
	var hands := _spawn("bog_hands", along * 60)
	await _frames(2)
	_check(player.has_effect("held") and hands.held == player, "stepping_in_the_puddle_gets_you_grabbed")
	for press in range(12):
		level.try_interact(player)
	_check(not player.has_effect("held") and hands.brain.rest > 0.0, "mashing_e_pulls_you_out")
	hands.brain.rest = 0.0
	hands.recover_remaining = 0.0
	_reset(along * 60)
	await _frames(int(60 * 6.3))
	_check(player.status == CampPlayer.Status.DOWNED, "too_slow_and_youre_dragged_under")
	await _despawn(hands)


func _imps() -> void:
	_reset()
	var imps := _spawn("imps", along * 30)
	player.supplies["battery_pack"] = 1
	player.belt = ["battery_pack", "", "", "", "", ""]
	player.selected_slot = 0
	imps.brain.cooldown = 0.0
	imps.brain.contact(player)
	_check(player.has_effect("tripped") and imps.brain.loot == "battery_pack" and player.supplies["battery_pack"] == 0, "imps_trip_you_and_take_it")
	imps.brain._hide()
	_check(level.pickups.any(func(p: CampPickup) -> bool: return p.available and p.kind == "battery_pack"), "they_hide_it_nearby")
	imps.brain.loot = "flare"
	imps.stun_immunity = 0.0
	imps.stun(1.5)
	_check(imps.brain.poofed > 0.0 and imps.brain.loot.is_empty(), "flash_poofs_the_imps")
	await _despawn(imps)


func _teddy() -> void:
	_reset()
	var bear := _spawn("teddy", along * 80)
	await _frames(2)
	_check(bear.brain.beloved == player, "teddy_falls_in_love_at_first_sight")
	bear.global_position = trail + along * 8
	await _frames(3)
	_check(player.has_effect("held") and bear.held == player, "bear_hug")
	await _frames(60)
	_check(player.health < 97.0, "the_hug_squeezes")
	for press in range(15):
		level.try_interact(player)
	_check(not player.has_effect("held") and bear.brain.content > 0.0, "fifteen_wriggles_and_its_content")
	await _despawn(bear)


func _stalker() -> void:
	_reset()
	var stalker: CampKiller = level.killer
	_check(stalker.traits != null and stalker.has_node("CampSong") and CampSong.tune().data.size() > 10000, "stalker_has_traits_and_a_whistled_song")
	player.health = 40.0
	stalker.global_position = trail + along * 10
	stalker.enabled = true
	_check(stalker.traits.strike(player) and stalker.held == player and stalker.carrying, "wounded_survivor_is_carried_not_hit")
	var hook: Vector2 = level.hook_point()
	stalker.global_position = hook + Vector2(4, 0)
	await _frames(3)
	_check(player.status == CampPlayer.Status.DOWNED and player.global_position.distance_to(hook) < 30.0 and level.pins.any(func(pin: Dictionary) -> bool: return pin["name"] == "HOOK"), "carried_to_the_hook_and_pinned")
	_reset()
	player.health = 40.0
	stalker.global_position = trail + along * 10
	stalker.traits.strike(player)
	player.supplies["air_horn"] = 1
	_check(not level.use_supply(player, "air_horn"), "cannot_honk_while_carried")
	player.release()
	_check(stalker.held == null, "wriggling_free_drops_you")
	_reset()
	player.supplies["air_horn"] = 1
	player.belt[5] = "air_horn"
	stalker.stun_immunity = 0.0
	stalker.stun_remaining = 0.0
	_check(level.use_supply(player, "air_horn") and stalker.stun_remaining > 4.0, "air_horn_stuns_him")
	stalker.stun_remaining = 0.0
	await _grip_checks(stalker)
	stalker.frenzy = 0.0
	stalker.traits.rage = 0
	for slip in range(3):
		stalker.traits.humiliated()
	_check(stalker.frenzy > 0.0 and stalker.door_force > 1.0 or stalker.frenzy > 0.0, "three_humiliations_send_him_into_a_frenzy")
	stalker.frenzy = 0.0
	# Shadowing: caught in your beam, he melts away.
	level.night_clock.force_phase(1)
	stalker.state = CampKiller.State.PATROL
	stalker.traits.favourite = player
	stalker.recover_remaining = 0.0
	stalker.enabled = true
	stalker.global_position = trail + along * 120
	player.facing = along
	await _frames(3)
	_check(stalker.faded, "beam_on_his_shadow_makes_him_melt_away")
	stalker.traits.melt = 0.0
	stalker.faded = false
	stalker.enabled = false
	# Memory: a reused hiding spot is checked and you're dragged out.
	stalker.traits.remember_spot(0)
	stalker.traits.remember_spot(0)
	_check(stalker.traits.used_spots[0] == 2, "he_remembers_hiding_spots")
	level.add_card(trail, "I SEE YOU")
	_check(level.cards.back()["text"] == "I SEE YOU", "calling_cards_are_kept")
	_check(level.snares.kind() == "bear_trap", "stalker_nights_set_bear_traps")
	_reset()
	level.snares.snares.append({"position": (trail + along * 2).round(), "armed": true})
	level.snares.advance(0.016)
	_check(player.snared > 0.0 and is_equal_approx(player.health, 85.0), "bear_trap_bites")


## The stalker's grip: struggle drains, each grab needs more presses, he jolts
## you, tearing free costs you, and teammates still free you at once.
func _grip_checks(stalker: CampKiller) -> void:
	_reset()
	player.health = 40.0
	stalker.global_position = trail + along * 10
	stalker.enabled = true
	stalker.stun_immunity = 0.0
	var times: int = player.grab_counts.get(stalker.headline.to_upper(), 0)
	stalker.traits.strike(player)
	_check(is_equal_approx(player.struggle_step, 1.0 / (14.0 + 8.0 * times)), "each_grab_needs_more_presses")
	player.struggle = 0.5
	stalker.traits.shake_clock = 10.0
	await _frames(60)
	_check(player.struggle < 0.42 and player.has_effect("held"), "struggle_drains_while_you_dont_press")
	player.struggle = 0.9
	stalker.traits.shake_clock = 0.05
	await _frames(6)
	_check(player.struggle < 0.7 and player.has_effect("jolted"), "he_jolts_you_and_knocks_progress_back")
	player.supplies["flare"] = 2
	player.belt[0] = "flare"
	player.selected_slot = 0
	player.struggle = 0.999
	level.try_interact(player)
	_check(not player.has_effect("held") and player.has_effect("tripped") and player.supplies["flare"] == 0, "tearing_free_drops_you_and_what_you_held")
	await _frames(70)
	_reset()
	player.health = 40.0
	stalker.recover_remaining = 0.0
	stalker.global_position = trail + along * 10
	stalker.traits.strike(player)
	stalker.stun_immunity = 0.0
	_check(stalker.stun(1.5) and not player.has_effect("held") and not player.has_effect("tripped"), "a_teammates_flash_frees_you_cleanly")
	stalker.stun_remaining = 0.0


func _items() -> void:
	_reset()
	for kind: String in level.CREATURE_ITEMS:
		_check(level.plan.loot.any(func(item: Dictionary) -> bool: return item["kind"] == kind), "item_%s_is_placed_tonight" % kind)
	# Every creature item can be walked to, and none sits within reach of
	# another pickup (one E press must never grab the neighbour instead).
	var map: RID = level.get_world_2d().navigation_map
	for pickup: CampPickup in level.pickups:
		if pickup.kind not in level.CREATURE_ITEMS or not pickup.available:
			continue
		var path := NavigationServer2D.map_get_path(map, Vector2(96, 384), pickup.position, true)
		# Same standard as every other pickup: it lies on the navmesh.
		var reach: bool = path.size() > 1 and path[-1].distance_to(pickup.position) < 4.0
		_check(reach, "item_reachable_%s_%d" % [pickup.kind, pickup.get_index()])
		var crowded: bool = level.pickups.any(func(other: CampPickup) -> bool: return other != pickup and other.available and other.position.distance_to(pickup.position) < 30.0)
		_check(not crowded, "item_not_crowding_%s_%d" % [pickup.kind, pickup.get_index()])
	player.supplies["coffee"] = 1
	player.add_effect("drowsy", 5.0)
	_check(level.use_supply(player, "coffee") and player.has_effect("coffee") and not player.has_effect("drowsy"), "coffee_wakes_you")
	player.supplies["garlic"] = 1
	_check(level.use_supply(player, "garlic") and player.has_effect("garlic"), "garlic_works")
	player.supplies["bug_spray"] = 1
	_check(level.use_supply(player, "bug_spray") and player.has_effect("bug_spray"), "bug_spray_works")


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _check(condition: bool, name: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(JSON.stringify({"event":"assertion","name":name,"passed":condition}))
