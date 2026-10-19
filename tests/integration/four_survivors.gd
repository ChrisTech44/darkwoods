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
	john.invulnerability = 0
	check(john.receive_hit(60) and john.health==100 and john.kit.debt==60 and john.wounded,"john_damage_deferred_effective_wound")
	check(not john.receive_hit(60) and john.kit.debt==60,"john_hit_grace_before_ledger")
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
	john.receive_hit(120)
	john.set_status(CampPlayer.Status.ESCAPED)
	check(john.status==CampPlayer.Status.DOWNED and john.kit.debt==0,"john_cannot_escape_lethal_debt")
	john.set_status(CampPlayer.Status.ALIVE)
	SurvivorKits.settle(john)
	check(john.health==35,"john_revive_has_no_stale_ledger")
	john.health = 100

func max_checks() -> void:
	var max_actor: CampPlayer = friends.max
	max_actor.kit.cash = 12
	var before: int = max_actor.supplies.values().reduce(func(a,b): return a+b,0)
	check(level.abilities.use(max_actor),"max_press_starts_stake")
	check(level.abilities.release(max_actor),"max_tap_commits_guaranteed_purchase")
	var after: int = max_actor.supplies.values().reduce(func(a,b): return a+b,0)
	check(max_actor.kit.cash==8 and after==before+1,"max_guaranteed_cost_and_one_supply")
	check(not level.abilities.release(max_actor) and max_actor.kit.cash==8,"max_release_not_replayed")
	SurvivorKits.earn(max_actor,"test:receipt",4)
	SurvivorKits.earn(max_actor,"test:receipt",4)
	check(max_actor.kit.cash==12,"max_receipt_awards_once")
	max_actor.invulnerability = 0
	max_actor.receive_hit(10)
	var cash: CampPickup
	for item: CampPickup in level.pickups:
		if item.available and item.kind=="cash" and item.cash_owner==max_actor.kit.owner: cash=item
	check(cash!=null and max_actor.kit.cash==8 and cash.cash_amount==4,"max_hit_spill_conserves_cash")
	var helper: CampPlayer = friends.john
	if cash!=null:
		helper.position = cash.position
		check(level.try_interact(helper) and not cash.available and max_actor.kit.cash==12,"friend_returns_cash_to_owner")
	max_actor.kit.cash = 0
	max_actor.ability_cooldown = 0
	check(not level.abilities.use(max_actor),"max_cannot_buy_without_cash")

func alex_checks() -> void:
	var alex: CampPlayer = friends.alex
	alex.position = Vector2(96,384)
	for role in ["christian","john","max"]: friends[role].position = Vector2(700,700)
	level.player.position = Vector2(700,700)
	SurvivorKits.advance(alex,4.1)
	check(alex.kit.isolated,"alex_qualifies_after_real_isolation")
	check(level.abilities.use(alex) and alex.kit.marker_life==75,"alex_places_marker")
	var origin := alex.position
	alex.position += Vector2(0,20)
	check(level.abilities.use(alex),"alex_begins_return")
	alex.invulnerability = 0
	alex.receive_hit(5)
	check(alex.kit.channel==0 and alex.kit.marker_life>0,"alex_damage_interrupt_keeps_lifetime")
	alex.ability_cooldown = 0
	level.abilities.use(alex)
	SurvivorKits.advance(alex,2.1)
	check(alex.position.distance_to(origin)<1 and alex.kit.marker_life==0 and alex.health==95,"alex_position_only_no_heal")
	alex.ability_cooldown = 0
	level.abilities.use(alex)
	alex.grab(friends.john,"TEST",0.2,0)
	check(not level.abilities.use(alex) and alex.kit.channel==0,"alex_grab_blocks_escape")
	alex.release()
	friends.john.position = alex.position+Vector2(20,0)
	SurvivorKits.advance(alex,0.1)
	check(not alex.kit.isolated,"alex_near_friend_loses_bonus")

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
	check(CreatureSamples.SOURCES.size()==30,"thirty_explicit_sample_sources")
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
		check(level.abilities.use(christian),"catalogue_cast_"+kind)
		check(christian.kit.sample.is_empty(),"catalogue_single_consumption_"+kind)
		if kind in CreatureSamples.FORMS:
			check(christian.kit.form==kind,"catalogue_distinct_form_"+kind)
			continue
		CreatureSamples.advance(christian,3.1)
		# Real Witch projectiles advance along their swept segment, not a point AoE.
		if kind=="witch": CreatureSamples.advance(christian,0.3)
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
