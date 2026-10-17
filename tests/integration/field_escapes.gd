extends "res://tests/integration/radio_rescue.gd"
var field: FieldEscapes

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	var deterministic := true
	for seed_value in [1,2,42,109]:
		var plan := RoundPlan.new()
		plan.generate(seed_value,"woods")
		var again := RoundPlan.new()
		again.generate(seed_value,"woods")
		deterministic = deterministic and plan.loot==again.loot and plan.gate_regions==again.gate_regions
		for kind in FieldEscapes.BOAT_PARTS+FieldEscapes.GATE_CODES:
			deterministic = deterministic and plan.loot.filter(func(item): return item["kind"]==kind).size()==1 and kind not in plan.required
	_check(deterministic,"four_seeds_unique_separate_escape_items_and_rotating_codes")
	await _load_round()
	await _boat_checks()
	await _load_round()
	await _gate_checks()
	print(JSON.stringify({"event":"test_result","suite":"field_escapes","checks":checks,"failures":failures}))
	current_scene.queue_free()
	await _frames(4)
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures==0 else 1)

func _load_round() -> void:
	root.get_node("Session").mode="woods"
	root.get_node("Session").next_seed=42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	while current_scene==null or current_scene.name!="ForestLevel": await process_frame
	level=current_scene
	player=level.player
	player.local_input=false
	rescue=level.rescue
	field=level.escapes
	level.night_clock.director_enabled=false
	for enemy: CampKiller in get_nodes_in_group("killers"): enemy.enabled=false
	await _frames(12)

func _take(kind: String) -> void:
	var pickup: CampPickup
	for item: CampPickup in level.pickups:
		if item.kind==kind and item.available: pickup=item
	_check(pickup!=null,"unique_available_"+kind)
	if pickup==null: return
	var path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map,Vector2(96,384),pickup.position,true)
	_check(path.size()>1 and path[-1].distance_to(pickup.position)<4,"native_route_to_"+kind)
	player.position=pickup.position
	for attempt in range(5):
		if kind in player.inventory: break
		level.try_interact(player)
	_check(kind in player.inventory and not pickup.available,"production_pickup_"+kind)

func _boat_checks() -> void:
	var belt := player.belt.duplicate()
	for kind in FieldEscapes.BOAT_PARTS: await _take(kind)
	_check(player.belt==belt,"boat_parts_use_no_belt_slots")
	player.position=Vector2(600,520)
	player.apply_intent(Vector2.RIGHT,true,1.0/60)
	_check(not player.sprinting and is_equal_approx(player.velocity.length(),player.config.walk_speed*0.75),"heavy_motor_blocks_sprint_and_uses_75_percent_walk")
	_check(level.drop_held(player) and "outboard_motor" not in player.inventory,"G_drops_motor_before_selected_supply")
	player.apply_intent(Vector2.RIGHT,true,1.0/60)
	_check(player.sprinting,"dropping_motor_restores_sprint")
	await _take("outboard_motor")
	var carrier: CampPlayer=load("res://scenes/actors/player.tscn").instantiate()
	carrier.local_input=false
	level.world_objects.add_child(carrier)
	carrier.position=Vector2(620,520)
	carrier.inventory.append("outboard_motor")
	player.inventory.erase("outboard_motor")
	player.position=Vector2(600,520)
	Input.action_press("interact")
	field._assistance()
	carrier.apply_intent(Vector2.RIGHT,true,1.0/60)
	_check(carrier.motor_assisted and player.assisting_motor and not carrier.sprinting and is_equal_approx(carrier.velocity.length(),carrier.config.walk_speed),"adjacent_held_helper_restores_full_walk_without_sprint")
	Input.action_release("interact")
	field._assistance()
	_check(not carrier.motor_assisted and not player.assisting_motor,"releasing_helper_resets_assistance")
	carrier.inventory.clear()
	carrier.queue_free()
	player.inventory.append("outboard_motor")
	await _frames(2)
	var goal: Vector2=field.boat_point
	var path:=NavigationServer2D.map_get_path(level.get_world_2d().navigation_map,Vector2(96,384),goal,true)
	_check(path.size()>1 and path[-1].distance_to(goal)<4,"native_boat_dock_reachable")
	player.position=goal
	_check(field.interact(player) and field.boat_installed.size()==3,"all_three_parts_install_authoritatively")
	level.night_clock.advance(0.1)
	_check(level.night_clock.progress()==1.0 and level.night_clock.phase==3,"ready_boat_brings_witching_hour")
	player.position=goal
	_check(field.interact(player) and field.boat_started,"ready_player_starts_25_second_launch")
	if capture:
		await _snapshot("boat",goal,Vector2(0,-35),0.8)
		await _snapshot("boathouse",level.plan.woods.zones[12]["position"]+Vector2(0,100),Vector2(90,-24),0.75)
		await _snapshot("logging",level.plan.woods.zones[11]["position"],Vector2(0,-35),0.8)
		level.objective_page=2
		level.hud.inventory_label.show()
		await _snapshot("boat_plan",goal,Vector2.ZERO,1)
		level.hud.inventory_label.hide()
	field.advance(5.01)
	_check(field.lake_tell>1.9 and not player.wounded,"lake_attack_has_two_second_visible_tell")
	if capture:
		await _snapshot("lake_thing",goal+Vector2(0,20),Vector2(0,-32),1.0)
	player.position=field.lake_target
	field._lake(1)
	_check(not player.wounded,"lake_never_hits_before_tell_finishes")
	field._lake(1.1)
	_check(player.wounded,"standing_in_finished_tell_wounds_survivor")
	player.invulnerability=0
	field.boat_remaining=12
	field._lake(0.01)
	player.position=field.lake_target+Vector2(-48,0)
	field._lake(2.1)
	_check(player.status==CampPlayer.Status.ALIVE,"sidestep_dodges_next_lake_strike")
	field.boat_remaining=4
	field._lake(0.01)
	player.position=goal
	player.pack("flare")
	player.facing=Vector2.DOWN
	level.use_supply(player,"flare")
	field._lake(0.1)
	_check(field.lake_tell==0,"nearby_flare_interrupts_lake_attack")
	var state: Dictionary=field.snapshot()
	field.boat_installed.clear()
	field.restore(state)
	_check(field.boat_installed.size()==3 and field.boat_started,"snapshot_restores_boat_and_hazard")
	var downed: CampPlayer=load("res://scenes/actors/player.tscn").instantiate()
	downed.local_input=false
	level.world_objects.add_child(downed)
	downed.position=Vector2(96,384)
	downed.set_status(CampPlayer.Status.DOWNED)
	field.boat_remaining=1
	player.position=goal
	field.advance(0.5)
	_check(not level.finished,"boat_countdown_cannot_finish_early")
	field.advance(0.6)
	_check(level.finished and level.won and level.escape_route=="BOAT" and player.status==CampPlayer.Status.ESCAPED and downed.status==CampPlayer.Status.ESCAPED,"boat_extracts_dock_and_rescues_downed_teammate")

func _gate_checks() -> void:
	_check(field.boat_installed.is_empty() and not field.gate_open and not field.boat_started,"fresh_round_clears_both_escapes")
	player.position=field.bridge
	field.advance(0.1)
	_check(not field.bridge_started,"walking_around_closed_gate_cannot_trigger_evacuation")
	var used := {}
	for kind in FieldEscapes.GATE_CODES:
		used[level.plan.gate_regions[kind]]=true
		await _take(kind)
	_check(used.size()==3,"gate_fragments_span_three_regions")
	player.position=field.breaker_point
	_check(not field.interact(player) and not field.gate_powered,"floodlights_require_rescue_circuit")
	await _take("rescue_fuse")
	player.position=rescue.power_point
	_check(rescue.interact(player),"shared_fuse_restores_north_substation")
	player.position=field.breaker_point
	_check(field.interact(player) and field.gate_powered,"gate_breaker_powers_floodlights")
	player.position=field.gate_point
	_check(field.interact(player) and field.gate_installed.size()==3,"code_fragments_install_once")
	player.position=field.gate_point
	field.advance_gate(player,2)
	_check(not field.gate_open and field.gate_progress>0,"gate_hold_starts_without_clock_floor")
	field.advance_gate(null,0.1)
	_check(field.gate_progress==0,"gate_release_resets_hold")
	if capture:
		await _snapshot("ranger_gate_closed",field.gate_point,Vector2(0,-32),0.8)
	Input.action_press("interact")
	await _frames(245)
	Input.action_release("interact")
	await _frames(2)
	_check(field.gate_open and field.gate_body.get_child(0).disabled,"real_gate_hold_opens_physical_arm")
	var gate_line: Vector2=field.gate_point+Vector2(0,-28)
	var query:=PhysicsRayQueryParameters2D.create(gate_line+Vector2(0,20),gate_line-Vector2(0,20),CampPlayer.BARRIER_LAYER)
	_check(level.get_world_2d().direct_space_state.intersect_ray(query).is_empty(),"opened_arm_allows_road_crossing")
	var route:=NavigationServer2D.map_get_path(level.get_world_2d().navigation_map,field.gate_point,field.bridge,true)
	_check(route.size()>1 and route[-1].distance_to(field.bridge)<4,"native_bridge_run_is_reachable")
	# Alarm changes a sensed goal, never the stalker's transform or player memory.
	var before: Vector2=level.killer.position
	level.killer.enabled=true
	level.killer.hear_stimulus(field.gate_point,6000)
	_check(level.killer.position==before and level.killer.last_seen.distance_to(field.gate_point)<1,"gate_alarm_investigates_real_location_without_teleport")
	level.killer.enabled=false
	if capture:
		await _snapshot("ranger_gate",field.gate_point,Vector2(0,-32),0.8)
		level.objective_page=3
		level.hud.inventory_label.show()
		await _snapshot("gate_plan",field.gate_point,Vector2.ZERO,1)
		level.hud.inventory_label.hide()
		await _snapshot("bridge",field.bridge,Vector2(0,-16),0.9)
		await _atlas()
	player.position=field.bridge
	field.advance(0.1)
	_check(field.bridge_started and field.bridge_remaining>7,"first_arrival_starts_eight_second_team_window")
	field.advance(8)
	_check(level.finished and level.won and level.escape_route=="RANGER GATE" and player.status==CampPlayer.Status.ESCAPED,"bridge_run_completes_ranger_escape")
