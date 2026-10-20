extends SceneTree
## Authority/state transitions for the replacement roster. Frozen AI, diagnostic
## all-route fixture. --capture opens a real renderer; voice is always off.
var checks := 0
var failures := 0
var level: Node2D
var friends: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(JSON.stringify({"event":"assertion","name":label,"passed":ok}))
func frames(n: int = 4) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func survivor(role: String, at: Vector2) -> CampPlayer:
	var actor: CampPlayer = load("res://scenes/actors/player.tscn").instantiate()
	actor.role = role
	actor.expedition = true
	actor.local_input = false
	actor.position = at
	level.world_objects.add_child(actor)
	actor.set_physics_process(false)
	return actor
func run() -> void:
	root.get_node("Voice").mode = "off"
	RoundPlan.force_all_escapes = true
	RoundPlan.force_modifiers = []
	root.get_node("Session").mode = "woods"
	root.get_node("Session").survivor = "christian"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await frames(12)
	level = current_scene
	level.night_clock.active = false
	level.night_clock.set_physics_process(false)
	level.abilities.set_physics_process(false)
	level.player.local_input = false
	level.player.set_physics_process(false)
	for enemy in get_nodes_in_group("killers"):
		enemy.enabled = false
		enemy.set_physics_process(false)
	check(SurvivorRoster.IDS == ["christian","john","max","alex"],"four_new_ids")
	check(SurvivorRoster.valid("jock") == "christian","retired_ids_do_not_survive_validation")
	for i in range(4):
		var role: String = SurvivorRoster.IDS[i]
		friends[role] = survivor(role, Vector2(80+i*30,400))
		var actor: CampPlayer = friends[role]
		check(actor.config.stamina_max == 4 and actor.config.start_hold_seconds == 2 and actor.config.revive_seconds == 3,"common_baseline_"+role)
		check(actor.supplies["flare"]==2 and actor.supplies["battery_pack"]==1 and actor.supplies["rations"]==1,"no_old_starting_bonus_"+role)
	await john_checks()
	await max_checks()
	await alex_checks()
	await sample_checks()
	await catalogue_checks()
	await sharing_checks()
	watching_checks()
	rule_checks()
	cancellation_checks()
	disconnect_cleanup_checks()
	print(JSON.stringify({"event":"test_result","suite":"four_survivors","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(1 if failures else 0)

func john_checks() -> void:
	var john: CampPlayer = friends.john
	john.stamina = 0
	SurvivorKits.progress(john,"test:one")
	check(john.stamina == 4 and not john.exhausted,"john_new_preparation_refill")
	john.stamina = 0
	SurvivorKits.progress(john,"test:one")
	check(john.stamina == 0,"john_no_repeat_completion_farm")
	check(level.abilities.use(john),"john_push_through_starts")
	check(john.ability_cooldown==60,"john_cooldown_is_one_minute_from_activation")
	john.invulnerability = 0
	check(john.receive_hit(120) and john.health==100 and john.kit.debt==60 and john.wounded,"john_damage_deferred_effective_wound")
	check(not john.receive_hit(120) and john.kit.debt==60,"john_hit_grace_before_ledger")
	john.supplies.medkit = 1
	check(not level.use_supply(john,"medkit") and john.supplies.medkit == 1,"john_no_heal_debt_consumption")
	john.heal(50)
	check(john.kit.debt == 60,"john_heal_cannot_erase_debt")
	SurvivorKits.settle(john)
	check(john.health == 40 and john.kit.debt == 0 and john.ability_active==0,"john_settlement_once")
	SurvivorKits.settle(john)
	check(john.health == 40,"john_no_double_settlement")
	john.health = 100
	john.ability_cooldown = 0
	level.abilities.use(john)
	john.invulnerability = 0
	john.receive_hit(240)
	john.set_status(CampPlayer.Status.ESCAPED)
	check(john.status==CampPlayer.Status.DOWNED and john.kit.debt==0,"john_cannot_escape_lethal_debt")
	john.set_status(CampPlayer.Status.ALIVE)
	SurvivorKits.settle(john)
	check(john.health==35,"john_revive_has_no_stale_ledger")
	john.health = 100
	john.ability_active = 6
	john.receive_drain(20)
	check(john.health == 100 and john.kit.debt == 10 and john.ability_active == 6,"john_continuous_drain_halved_and_deferred")
	SurvivorKits.settle(john)
	check(john.health == 90,"john_reduced_drain_settles_once")
	john.receive_drain(20)
	check(john.health == 70,"john_outside_window_drain_full_strength")
	john.health = 100
	john.ability_active = 6
	john.grab(friends.christian,"TEST",0.1)
	check(john.ability_active == 0,"john_grab_ends_window_even_without_prior_debt")
	john.receive_drain(10)
	check(john.health == 90,"john_post_grab_drain_is_full_strength")
	john.release()
	john.health = 100

func max_checks() -> void:
	var max_actor: CampPlayer=friends.max
	check(max_actor.kit.cash==0,"max_has_no_cash_economy")
	check(level.abilities.use(max_actor),"max_spin_starts")
	check(not level.abilities.use(max_actor) and not level.abilities.release(max_actor),"max_no_repeat_or_release_roll")
	max_actor.kit.wheel_pick=4
	max_actor.health=50
	FortuneWheel.advance(max_actor,2)
	check(max_actor.health==100 and max_actor.notice=="SECOND WIND","max_result_is_authoritative_name_only")
	check(max_actor.ability_cooldown==120,"max_cooldown_starts_on_commit")
	check(SamplePresentation.detail(max_actor).is_empty(),"max_no_large_help_panel")

# Select each real RNG branch without replacing the host completion code.
func return_seed(ticket: int) -> int:
	for candidate in range(100):
		seed(candidate)
		if randi_range(0,2)==ticket: return candidate
	return -1

func alex_checks() -> void:
	var alex: CampPlayer = friends.alex
	alex.position = Vector2(96,384)
	for role in ["christian","john","max"]: friends[role].position = Vector2(700,700)
	level.player.position = Vector2(700,700)
	SurvivorKits.advance(alex,4.1)
	check(alex.kit.isolated,"alex_qualifies_after_real_isolation")
	check(level.abilities.use(alex) and alex.kit.marker_life==60,"alex_places_marker")
	var origin := alex.position
	alex.position += Vector2(0,20)
	check(level.abilities.use(alex),"alex_begins_return")
	alex.invulnerability = 0
	alex.receive_hit(5)
	check(alex.kit.channel==0 and alex.kit.marker_life>0,"alex_damage_interrupt_keeps_lifetime")
	alex.ability_cooldown = 0
	level.abilities.use(alex)
	SurvivorKits.advance(alex,6.9)
	check(alex.kit.channel>0 and alex.position.distance_to(origin)>1,"alex_cannot_return_before_seven_seconds")
	seed(return_seed(1))
	SurvivorKits.advance(alex,0.11)
	check(alex.position.distance_to(origin)<1 and alex.kit.marker_life==0 and alex.health==95,"alex_position_only_no_heal")
	# Both ordinary tickets return to the marker; one ticket misfires to the map.
	for ticket in [2,0]:
		alex.ability_cooldown = 0
		check(level.abilities.use(alex),"alex_places_marker_for_ticket_%d" % ticket)
		alex.position = origin+Vector2(0,20)
		check(level.abilities.use(alex),"alex_channels_ticket_%d" % ticket)
		var inventory_before := alex.inventory.duplicate()
		var charge_before := alex.flashlight_charge
		seed(return_seed(ticket))
		SurvivorKits.advance(alex,7.01)
		check(alex.kit.marker_life==0 and alex.kit.channel==0 and alex.ability_cooldown==120,"alex_completion_consumes_marker_and_cooldown_ticket_%d" % ticket)
		check(alex.health==95 and alex.inventory==inventory_before and alex.flashlight_charge==charge_before,"alex_completion_preserves_state_ticket_%d" % ticket)
		if ticket==0:
			check(alex.position.distance_to(origin)>300 and SurvivorKits.safe_point(alex,alex.position,1|CampPlayer.BARRIER_LAYER|CampPlayer.WATER_LAYER),"alex_misfire_lands_valid_elsewhere_on_map")
		else:
			check(alex.position.distance_to(origin)<1,"alex_second_normal_ticket_returns_to_marker")
		alex.position = origin
	check(not level.abilities.use(alex),"alex_cannot_replace_marker_during_two_minute_cooldown")
	level.abilities.advance(119.9)
	check(not level.abilities.use(alex),"alex_cannot_replace_marker_before_two_minutes")
	level.abilities.advance(0.11)
	check(alex.ability_cooldown==0,"alex_marker_cooldown_expires_after_two_minutes")
	alex.ability_cooldown = 0
	level.abilities.use(alex)
	var threat: CampKiller = level.killer
	var saved_position := threat.global_position
	threat.enabled = true
	threat.global_position = alex.global_position + Vector2(CampSoundscape.NEAR_RANGE,0)
	check(not level.abilities.use(alex) and alex.kit.channel==0,"alex_heartbeat_boundary_blocks_start")
	check(alex.kit.marker_life>0 and alex.ability_cooldown==0,"alex_blocked_start_preserves_marker_and_cooldown")
	check("MONSTER NEAR" in SurvivorKits.status(alex),"alex_status_explains_monster_block")
	threat.global_position.x += 1
	check(level.abilities.use(alex) and alex.kit.channel==7,"alex_outside_heartbeat_starts_full_seven")
	SurvivorKits.advance(alex,3)
	threat.global_position.x -= 1
	var life_before: float = alex.kit.marker_life
	SurvivorKits.advance(alex,0.1)
	check(alex.kit.channel==0 and is_equal_approx(alex.kit.marker_life,life_before-0.1),"alex_monster_entry_cancels_without_refreshing_marker")
	check(alex.ability_cooldown==2,"alex_monster_interrupt_uses_existing_retry_guard")
	threat.global_position.x += 1
	alex.ability_cooldown = 0
	check(level.abilities.use(alex) and alex.kit.channel==7,"alex_restart_discards_previous_progress")
	alex.position.x += 2
	SurvivorKits.advance(alex,7.1)
	check(alex.kit.channel==0 and alex.kit.marker_life>0,"alex_moving_into_heartbeat_cancels_even_completion_tick")
	threat.enabled = false
	alex.ability_cooldown = 0
	check(level.abilities.use(alex),"alex_disabled_enemy_does_not_block")
	SurvivorKits.cancel_return(alex)
	threat.global_position = saved_position
	alex.ability_cooldown = 0
	alex.grab(friends.john,"TEST",0.2,0)
	check(not level.abilities.use(alex) and alex.kit.channel==0,"alex_grab_blocks_escape")
	alex.release()
	friends.john.position = alex.position+Vector2(20,0)
	SurvivorKits.advance(alex,0.1)
	check(not alex.kit.isolated,"alex_near_friend_loses_bonus")
	SurvivorKits.cleanup(alex)
	alex.ability_cooldown = 0
	check(level.abilities.use(alex) and alex.kit.marker_life==60,"alex_fresh_marker_lasts_one_minute")
	SurvivorKits.advance(alex,59.9)
	check(alex.kit.marker_life>0,"alex_marker_remains_before_one_minute")
	SurvivorKits.advance(alex,0.11)
	check(alex.kit.marker_life==0 and alex.ability_cooldown==0,"alex_unused_marker_expires_without_teleport_cooldown")

func sample_checks() -> void:
	var christian: CampPlayer = friends.christian
	var at: Vector2 = level.plan.woods.zones[7]["position"]
	christian.position = at
	christian.facing = Vector2.RIGHT
	level.player.position = Vector2(96,384)
	for role in ["john","max","alex"]: friends[role].position = Vector2(96,384)
	var enemy: CampCryptid = load("res://scenes/actors/cryptid.tscn").instantiate()
	enemy.species = "vampire"
	enemy.position = at+Vector2(50,0)
	level.world_objects.add_child(enemy)
	enemy.set_physics_process(false)
	await frames()
	check(CreatureSamples.SOURCES.size()==RoundPlan.CRYPTID_COUNT-1,"thirty_explicit_sample_sources")
	CreatureSamples.encounter(christian,enemy)
	check(christian.kit.sample.is_empty(),"sample_not_immediate_before_survival")
	CreatureSamples.advance(christian,3.1)
	check(christian.kit.sample=="vampire","sample_from_source_event_after_survival")
	christian.kit.sample = "werewolf"
	level.night_clock.moon = false
	check(not level.abilities.use(christian) and christian.kit.sample=="werewolf","wolf_requires_moon_keeps_sample")
	level.night_clock.moon = true
	check(level.abilities.use(christian) and christian.kit.form=="werewolf","wolf_transforms_in_actual_moon")
	check(not CreatureSamples.can_interact(christian),"wolf_cannot_install_or_use_supplies")
	christian.ability_cooldown = 0
	check(level.abilities.use(christian) and christian.kit.dash>0,"wolf_pounce_secondary_action")
	level.night_clock.moon = false
	CreatureSamples.advance(christian,0.1)
	check(christian.kit.form.is_empty(),"wolf_cloud_ends_form")
	christian.kit.sample = "shutter_wraith"
	christian.ability_cooldown = 0
	var friend: CampPlayer = friends.john
	friend.position = at+Vector2(40,0)
	friend.facing = Vector2.LEFT
	enemy.position = at+Vector2(70,0)
	enemy.facing = Vector2.LEFT
	check(level.abilities.use(christian),"camera_warning_starts")
	CreatureSamples.advance(christian,1.1)
	check(friend.has_effect("whiteout") and christian.has_effect("whiteout") and enemy.sample_state.get("timers",{}).has("whiteout"),"camera_friendly_self_and_ai_blindness")
	check(friend.has_effect("marked"),"camera_photograph_consequence")
	friend.clear_effect("whiteout")
	friend.facing = Vector2.RIGHT
	CreatureSamples.fire(christian,{"kind":"shutter_wraith"})
	check(not friend.has_effect("whiteout"),"camera_turn_away_counter")
	CreatureSamples.apply(enemy,"frog",3)
	check(CreatureSamples.tick_enemy(enemy,0.1),"frog_ai_actually_stops")
	CreatureSamples.tick_enemy(enemy,4)
	check(not enemy.sample_state.get("timers",{}).has("frog"),"frog_adapter_expires")
	if "--capture" in OS.get_cmdline_user_args():
		christian.kit.sample = "werewolf"
		christian.kit.cast = {}
		christian.ability_cooldown = 0
		level.night_clock.moon = true
		level.abilities.use(christian)
		level.player.position = at+Vector2(0,70)
		level.player.facing = Vector2.UP
		level.player.flashlight_on = true
		await shot("wolf")
		christian.kit.form = ""
		christian.kit.sample = "shutter_wraith"
		christian.ability_cooldown = 0
		level.abilities.use(christian)
		await shot("camera_warning")
	enemy.queue_free()

func sharing_checks() -> void:
	var john: CampPlayer = friends.john
	var alex: CampPlayer = friends.alex
	john.position = Vector2(96,384)
	alex.position = john.position+Vector2(15,0)
	for other: CampPlayer in get_nodes_in_group("survivors"):
		if other not in [john,alex]: other.position = Vector2(700,700)
	john.pack("flare",3)
	john.supplies.flare = 3
	john.selected_slot = john.belt.find("flare")
	var before: int = alex.supplies.flare
	check(level.abilities.give(john) and john.supplies.flare==2 and alex.supplies.flare==before+1,"shared_handoff_preserved")
	var net := root.get_node("Net")
	net.world = level
	net.actors = {1:john,2:alex}
	var snapshot := WorldSync.capture(net).duplicate(true)
	john.kit.debt = 7.0
	WorldSync.apply(net,snapshot)
	check(john.kit.debt == snapshot.players[1].kit.debt,"kit_snapshot_restores_without_outcomes")
	check(LocalPrediction.valid(LocalPrediction.capture(alex)),"kit_movement_payload_valid")
	net.world = null
	net.actors.clear()

func shot(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/four_survivors"))
	await frames(6)
	RenderingServer.force_draw(true)
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/four_survivors/"+label+".png")==OK,"capture_"+label)

func catalogue_checks() -> void:
	var christian: CampPlayer = friends.christian
	var origin: Vector2 = level.plan.woods.zones[7]["position"]
	var bodies: Array[CampCryptid] = []
	for i in range(2):
		var body: CampCryptid = load("res://scenes/actors/cryptid.tscn").instantiate()
		body.species = "vampire"
		body.position = origin+Vector2(30+40*i,0)
		level.world_objects.add_child(body)
		body.set_physics_process(false)
		bodies.append(body)
	await frames()
	for kind: String in CreatureSamples.SOURCES:
		CreatureSamples.finish_cast(christian)
		christian.effects.clear()
		christian.holder = null
		christian.kit.form = ""
		christian.kit.sample = kind
		christian.kit.subtype = "frog"
		christian.ability_cooldown = 0
		christian.position = origin
		christian.facing = Vector2.RIGHT
		christian.flash_time = 0
		level.night_clock.moon = true
		for i in range(2):
			bodies[i].position = origin+Vector2(30+40*i,0)
			bodies[i].velocity = Vector2(10,0)
			bodies[i].facing = Vector2.LEFT
			bodies[i].sample_state.clear()
			CreatureSamples.history[bodies[i].get_instance_id()] = [bodies[i].position-Vector2(15,0)]
		for role in ["john","max","alex"]:
			friends[role].position = Vector2(96,384)
		if kind=="vulture":
			friends.john.position=origin+Vector2(0,40)
			friends.john.status=CampPlayer.Status.DOWNED
		if kind=="shade":
			christian.flashlight_on=false
			for encounter: Dictionary in level.plan.encounters:
				if not ShadowLight.lit(level,encounter.position):
					christian.position=encounter.position
					break
		check(level.abilities.use(christian),"catalogue_cast_"+kind)
		check(christian.kit.sample.is_empty(),"catalogue_single_consumption_"+kind)
		if kind in CreatureSamples.FORMS:
			check(christian.kit.form==kind,"catalogue_distinct_form_"+kind)
			continue
		CreatureSamples.advance(christian,3.1)
		friends.john.status=CampPlayer.Status.ALIVE
		# Real Witch projectiles advance along their swept segment, not a point AoE.
		if kind in SamplePresentation.SHOTS:
			check(not bodies[0].sample_state.get("timers",{}).has("face_moth"),"shot_has_real_travel_before_impact_"+kind)
			CreatureSamples.advance(christian,0.3)
		match kind:
			"witch": check(bodies[0].sample_state.get("timers",{}).has("frog"),"catalogue_witch_projectile_hits_ai")
			"shutter_wraith": check(bodies[0].sample_state.get("timers",{}).has("whiteout"),"catalogue_camera_sensing_adapter")
			"ration_moth": check(bodies[0].sample_state.get("timers",{}).has("sneezy"),"catalogue_spore_ai_sneeze")
			"bramble_seamstress": check(bodies[0].sample_state.get("timers",{}).has("tethered"),"catalogue_ai_thread")
			"vampire": check(bodies[0].sample_state.get("timers",{}).has("hypnotized"),"catalogue_gaze_pull_adapter")
			"bigfoot": check(bodies[0].position.x>origin.x+30,"catalogue_collision_checked_throw")
			"lantern_moth": check(bodies[0].sample_state.get("timers",{}).has("face_moth"),"catalogue_ai_moth_obscures_sensing")
			"cuckoo": check(bodies[0].position.x<origin.x+30,"catalogue_target_history_rewind")
			"banshee": check(bodies[0].sample_state.get("timers",{}).has("deaf"),"catalogue_ai_deafness")
			"surveyor": check(bodies[0].sample_state.get("timers",{}).has("lost"),"catalogue_search_disorientation")
			"hitchhiker": check(bodies[0].sample_state.get("timers",{}).has("piggyback"),"catalogue_spectral_passenger")
			"owl","teddy","lens_eater": check(not christian.kit.get("cast",{}).is_empty(),"catalogue_finite_committed_hold_"+kind)
			"last_car_conductor": check(christian.position.distance_to(origin)>100,"catalogue_fixed_stop_transport")
			"candle_grazer","boiler_saint","bog_hands","tollkeeper","echo","slug": check(christian.kit.get("cast",{}).get("life",0)>0,"catalogue_finite_area_"+kind)
	CreatureSamples.finish_cast(christian)
	christian.kit.form = ""
	for body in bodies: body.queue_free()

func watching_checks() -> void:
	var christian: CampPlayer = friends.christian
	var observer: CampPlayer = friends.john
	for other: CampPlayer in get_nodes_in_group("survivors"): other.position = Vector2(700,700)
	christian.position = Vector2(120,400)
	christian.kit.form = "briar_revenant"
	observer.position = Vector2(240,400)
	observer.facing = Vector2.LEFT
	observer.status = CampPlayer.Status.ALIVE
	observer.hidden_spot = -1
	observer.flashlight_on = false
	check(level.clear_path(observer.position,christian.position),"scarecrow_observer_fixture_clear_path")
	check(not CreatureSamples.motion(christian)[3],"scarecrow_far_unlit_friend_does_not_watch")
	observer.flashlight_on = true
	check(CreatureSamples.motion(christian)[3],"scarecrow_beam_counts_as_watching")
	observer.status = CampPlayer.Status.DOWNED
	check(not CreatureSamples.motion(christian)[3],"scarecrow_downed_observer_does_not_watch")
	observer.status = CampPlayer.Status.ALIVE
	observer.flashlight_on = false
	observer.position = Vector2(170,400)
	check(CreatureSamples.motion(christian)[3],"scarecrow_close_facing_without_light_watches")
	observer.facing = Vector2.RIGHT
	check(not CreatureSamples.motion(christian)[3],"scarecrow_turn_away_frees_form")

func cancellation_checks() -> void:
	var max_actor: CampPlayer=friends.max
	max_actor.role="max"
	max_actor.status=CampPlayer.Status.ALIVE
	max_actor.effects.clear()
	SurvivorAbilities.setup(max_actor)
	max_actor.kit.cash=24
	check(level.abilities.use(max_actor),"pending_buy_starts_before_menu")
	SurvivorKits.advance(max_actor,1.4)
	SurvivorKits.cancel_stake(max_actor)
	check(not level.abilities.release(max_actor) and max_actor.kit.cash==24 and max_actor.kit.wheel_time==0,"cancelled_spin_keeps_cooldown_after_menu")
	var christian: CampPlayer=friends.christian
	var target: CampPlayer=friends.john
	christian.position=Vector2(900,520)
	target.position=Vector2(980,520)
	christian.facing=Vector2.RIGHT
	christian.effects.clear()
	christian.holder=null
	target.effects.clear()
	target.holder=null
	target.status=CampPlayer.Status.ALIVE
	SurvivorAbilities.setup(christian)
	christian.kit.sample="teddy"
	check(level.abilities.use(christian),"committed_hug_starts")
	CreatureSamples.advance(christian,0.81)
	christian.ability_cooldown=0
	check(christian.has_effect("tripped") and target.holder==christian,"committed_hug_really_locks_both_bodies")
	check(level.abilities.use(christian) and christian.kit.cast.is_empty() and target.holder==null,"own_commitment_does_not_block_x_cancel")

func rule_checks() -> void:
	var christian: CampPlayer = friends.christian
	var alex: CampPlayer = friends.alex
	var john: CampPlayer = friends.john
	var max_actor: CampPlayer = friends.max
	for actor: CampPlayer in get_nodes_in_group("survivors"):
		actor.status = CampPlayer.Status.ALIVE
		actor.effects.clear()
		actor.holder = null
		SurvivorAbilities.setup(actor)
	christian.peer_name = "Christian"
	john.peer_name = "John in this round"
	christian.kit.sample = "mimic"
	check(CreatureSamples.use(christian),"mimic_uses_present_player")
	var original_name: String = christian.peer_name
	var borrowed_name: String = christian.kit.mask_name
	check(christian.display_name()==borrowed_name and borrowed_name!="Christian" and christian.peer_name==original_name,"mimic_borrows_display_identity_not_network_identity")
	var source: CampPlayer = instance_from_id(christian.kit.mask_source)
	source.remove_from_group("survivors")
	CreatureSamples.advance(christian,0.1)
	check(christian.kit.form.is_empty() and christian.display_name()==original_name,"mimic_ends_when_source_leaves")
	source.add_to_group("survivors")
	for other: CampPlayer in get_nodes_in_group("survivors"):
		if other != christian: other.remove_from_group("survivors")
	christian.kit.sample="mimic"
	christian.ability_cooldown=0
	check(not CreatureSamples.use(christian) and christian.kit.sample=="mimic","solo_mimic_keeps_sample_without_inventing_player")
	for actor: CampPlayer in friends.values():
		if not actor.is_in_group("survivors"): actor.add_to_group("survivors")
	level.abilities.enabled=false
	for actor: CampPlayer in friends.values():
		SurvivorAbilities.setup(actor)
		check(not level.abilities.use(actor),"disabled_active_"+actor.role)
	john.stamina=0
	SurvivorKits.progress(john,"disabled:step")
	check(john.stamina==0,"disabled_john_progress_passive")
	SurvivorKits.earn(max_actor,"disabled:cash",4)
	check(max_actor.kit.cash==0,"disabled_max_earning_and_starting_cash")
	alex.position=Vector2(800,800)
	SurvivorKits.advance(alex,5)
	check(not alex.kit.isolated,"disabled_alex_isolation")
	christian.kit.sample="witch"
	check(not CreatureSamples.use(christian),"direct_sample_cannot_bypass_disabled_rule")
	check(SurvivorKits.status(christian)=="CAMPER ABILITIES OFF","disabled_rule_visible")
	level.abilities.enabled=true
	check(is_equal_approx(christian.config.flashlight_capacity/christian.light_drain,840),"ordinary_flashlight_lasts_fourteen_minutes")
	alex.kit.isolated=true
	check(is_equal_approx(alex.config.flashlight_capacity/alex.passive_light_rate(),1120),"isolated_alex_light_estimate_matches_drain")

func disconnect_cleanup_checks() -> void:
	var actor: CampPlayer = friends.alex
	var net: Node = root.get_node("Net")
	net.world = level
	# Set each typed player reference, including windups and passive targets.
	var assigned := 0
	for enemy: CampKiller in get_nodes_in_group("killers"):
		if not enemy is CampCryptid or enemy.brain == null: continue
		for property: Dictionary in enemy.brain.get_property_list():
			if property.get("class_name", "") == "CampPlayer":
				enemy.brain.set(property.name, actor)
				assigned += 1
	level.killer.traits.favourite = actor
	actor.kit.cast = {"kind":"vampire"}
	friends.christian.grab(actor,"COPIED HOLD",0.1)
	level.props.vaults[actor.get_instance_id()] = {"actor":weakref(actor),"from":Vector2(96,384),"to":Vector2(96,420)}
	actor.vault_time = 0.1
	actor.collision_mask &= ~CampPlayer.BARRIER_LAYER
	net._clear_links(actor)
	check(assigned >= 10,"disconnect_fixture_covers_direct_brain_targets")
	for enemy: CampKiller in get_nodes_in_group("killers"):
		if not enemy is CampCryptid or enemy.brain == null: continue
		for property: Dictionary in enemy.brain.get_property_list():
			if property.get("class_name", "") == "CampPlayer":
				check(enemy.brain.get(property.name) != actor,"disconnect_clears_"+enemy.species+"_"+property.name)
	check(level.killer.traits.favourite == null and not friends.christian.has_effect("held") and actor.kit.cast.is_empty(),"disconnect_releases_favourite_and_copied_hold")
	check(not level.props.vaults.has(actor.get_instance_id()) and actor.vault_time == 0 and actor.collision_mask & CampPlayer.BARRIER_LAYER and actor.position == Vector2(96,384),"disconnect_cancels_vault_on_safe_starting_side")
	net.world = null
