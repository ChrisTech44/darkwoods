extends SceneTree
var checks := 0
var failures := 0
var level: Node2D
var capture := false
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	var previous_role: String = root.get_node("Session").survivor
	root.get_node("Session").survivor = "jock"
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await _frames(3)
	var menu := current_scene
	menu.get_node("Menu/Mode").select(0)
	menu.get_node("Menu/RandomNight").button_pressed = false
	menu.get_node("Menu/Seed").text = "42"
	menu.get_node("Menu/Play").pressed.emit()
	_check(menu.get_node("SurvivorSelection").visible and root.get_node("Session").next_seed == 42,"selection_before_generation_preserves_seed")
	menu.get_node("SurvivorSelection/Settings").pressed.emit()
	_check(menu.get_node("SettingsPanel").visible,"selection_settings_available")
	menu._hide_settings()
	_check(menu.get_node("SurvivorSelection").visible,"settings_returns_to_selection")
	for index in range(6):
		menu.get_node("SurvivorSelection/"+SurvivorRoster.IDS[index]).pressed.emit()
		_check(root.get_node("Session").survivor == SurvivorRoster.IDS[index],"card_select_"+SurvivorRoster.IDS[index])
	menu.get_node("SurvivorSelection/Random").pressed.emit()
	_check(root.get_node("Session").survivor in SurvivorRoster.IDS,"random_survivor_valid")
	menu._select_survivor(0)
	if capture:
		await _snapshot("survivor_selection")
	menu.get_node("SurvivorSelection/Back").pressed.emit()
	_check(menu.get_node("Menu").visible,"selection_back")
	menu.get_node("Menu/Play").pressed.emit()
	menu.get_node("SurvivorSelection/Start").pressed.emit()
	while current_scene == null or current_scene.name != "ForestLevel":
		await process_frame
	level = current_scene
	for enemy in get_nodes_in_group("killers"):
		enemy.enabled = false
	level.player.local_input = false
	await _frames(4)
	var base: CampConfig = load("res://assets/default_config.tres")
	for role in SurvivorRoster.IDS:
		for expedition in [false,true]:
			var actor: CampPlayer = load("res://scenes/actors/player.tscn").instantiate()
			actor.role = role
			actor.expedition = expedition
			actor.local_input = false
			actor.position = Vector2(100,400)
			level.world_objects.add_child(actor)
			actor.set_physics_process(false)
			_check(actor.config != base and actor.config.stamina_max == (5 if role=="jock" else 4),"private_stamina_%s_%s"%[role,expedition])
			_check(actor.config.start_hold_seconds == (1.5 if role=="mechanic" else 2.0),"ignition_stat_"+role)
			_check(actor.config.revive_seconds == (2.25 if role=="medic" else 3),"revive_stat_"+role)
			_check(is_equal_approx(actor.light_drain, (0.8 if role=="scout" else 1.0) / 3.0) and actor.sprint_hearing == (0.75 if role=="quiet" else 1.0),"sensing_modifiers_"+role)
			actor.position = level.plan.woods.center(Vector2i(18,24))
			actor._physics_process(1.0)
			_check(is_equal_approx(actor.flashlight_charge,90.0-(actor.light_drain if expedition else 0.0)),"actual_light_drain_%s_%s"%[role,expedition])
			var before := actor.supplies.duplicate()
			actor.apply_role()
			_check(actor.supplies==before,"role_apply_is_idempotent_"+role)
			_check(actor.supplies["flare"] == (3 if role in ["medic","quartermaster"] else 2),"starting_flares_"+role)
			_check(actor.supplies["battery_pack"] == (2 if role in ["mechanic","quartermaster"] else 1),"starting_cells_"+role)
			_check(actor.supplies["rations"] == (2 if role in ["scout","quartermaster"] else 1),"starting_food_"+role)
			_check(actor.supplies["medkit"] == (1 if role=="medic" else 0),"starting_medkit_"+role)
			actor.set_status(CampPlayer.Status.DOWNED)
			_check(actor.supplies.values().all(func(count): return count==0) and actor.belt.all(func(kind): return kind.is_empty()),"down_drops_all_supplies_"+role)
			actor.set_status(CampPlayer.Status.ALIVE)
			actor.apply_role()
			_check(actor.supplies.values().all(func(count): return count==0),"no_duplicate_bonus_on_revive_"+role)
			var van: CampVan = level.van
			actor.position = van.interaction_point()
			van.installed.assign(van.required_parts)
			van.running = false
			van.advance_start(actor,true,actor.config.start_hold_seconds-0.01)
			_check(not van.running,"ignition_not_early_"+role)
			van.advance_start(actor,true,0.02)
			_check(van.running,"ignition_effective_boundary_"+role)
			van.running = false
			van.advance_start(actor,false,0)
			actor.queue_free()
	await _frames(2)
	_check(base.stamina_max==4 and base.start_hold_seconds==2 and base.revive_seconds==3,"shared_baseline_unmodified")
	_check(SurvivorRoster.valid("forged")=="jock","invalid_role_fallback")
	var player: CampPlayer = level.player
	player.position = Vector2(100,400)
	player.pack("noise_tin")
	player.pack("salt_ward")
	player.pack("glow_moss")
	_check(not player.can_pack("medkit") and player.belt.size()==6,"six_slot_limit")
	player.inventory.append("fuel")
	_check("fuel" in player.inventory and not player.can_pack("medkit"),"parts_outside_belt")
	await _tap(KEY_KP_5)
	_check(player.selected_slot==4,"keypad_selects_fifth_slot")
	await _tap(KEY_4)
	_check(player.held_item()=="noise_tin","number_row_selects_item")
	await _tap(KEY_G)
	_check(player.held_item().is_empty() and player.supplies["noise_tin"]==0,"drop_stack_frees_slot")
	_check(level.try_interact(player) and player.supplies["noise_tin"]==1,"dropped_item_recovered_once")
	_check(not level.try_interact(player),"dropped_item_no_duplicate")
	var bounded_count: int=level.pickups.size()
	var recycling_ok := true
	for cycle in range(20):
		recycling_ok=level.drop_held(player) and level.try_interact(player) and recycling_ok
	_check(recycling_ok and level.pickups.size()==bounded_count,"twenty_drop_recovery_cycles_reuse_transient_units")
	_check(level.use_supply(player,"noise_tin"),"tin_lure_usable")
	var lure: NoiseLure
	for hazard in get_nodes_in_group("hazards"):
		if hazard is NoiseLure: lure=hazard
	lure._physics_process(1.6)
	_check(lure.pulses==1,"lure_delayed_first_pulse")
	lure._physics_process(4)
	lure._physics_process(0.1)
	await _frames(2)
	_check(not is_instance_valid(lure),"lure_expires")
	_check(level.use_supply(player,"salt_ward") and player.ward_remaining>0,"salt_ward_usable")
	player.receive_hit()
	_check(player.status==CampPlayer.Status.ALIVE,"ward_prevents_hit")
	player.flashlight_charge=10
	player.hex_remaining=3
	_check(level.use_supply(player,"glow_moss") and player.flashlight_charge==45 and player.hex_remaining==0,"moss_restores_light_clears_hex")
	_check(level.plan.woods.zones.size()==14 and level.plan.encounters.size()==RoundPlan.CRYPTID_COUNT,"fourteen_biomes_bounded_roster")
	for zone in level.plan.woods.zones:
		var bounds: Rect2 = zone["bounds"]
		var outside := {}
		for cell: Vector2i in level.plan.woods.links:
			if bounds.has_point(level.plan.woods.center(cell)):
				for next: Vector2i in level.plan.woods.links[cell]:
					if not bounds.has_point(level.plan.woods.center(next)): outside[next]=true
		_check(outside.size()>=2,"multiple_entrances_"+zone["kind"])
		for other in level.plan.woods.zones:
			if zone!=other:
				_check(not bounds.grow(32).intersects(other["bounds"].grow(32)),"nonoverlap_%s_%s"%[zone["kind"],other["kind"]])
	for enemy: CampCryptid in get_nodes_in_group("cryptids"):
		# The Mimic wears survivor sprites instead of a sheet of its own.
		_check(enemy.sheet!=null or enemy.species=="mimic","sprite_"+enemy.species)
		if enemy.home.has_area():
			enemy.enabled=true
			enemy.hear_stimulus(enemy.home.position-Vector2(50,50),10000)
			_check(enemy.state==CampKiller.State.PATROL,"guardian_ignores_outside_noise_"+enemy.species)
			_check(enemy.home.has_point(enemy.constrain_destination(Vector2(10000,10000))),"guardian_leash_"+enemy.species)
			player.position=enemy.home.position-Vector2(20,20)
			_check(not enemy.can_sense(player),"guardian_no_outside_target_"+enemy.species)
			enemy.enabled=false
	var listener: CampKiller = level.killer
	listener.config.hearing_radius=200
	listener.enabled=true
	listener.position=Vector2(280,400)
	player.position=Vector2(100,400)
	player.sprint_hearing=0.75
	listener.state=CampKiller.State.PATROL
	player.sprint_noise_emitted.emit(player.position)
	_check(listener.state==CampKiller.State.PATROL,"quiet_sprint_reach_reduced")
	player.sprinting=true
	player.noise_emitted.emit(player.position)
	_check(listener.state==CampKiller.State.INVESTIGATE,"quiet_does_not_reduce_interaction_noise_even_while_sprinting")
	listener.enabled=false
	player.sprinting=false
	player.sprint_hearing=1.0
	# The Ram's telegraphed charge locks its aim at the observed position.
	var test_enemy: CampCryptid = load("res://scenes/actors/cryptid.tscn").instantiate()
	test_enemy.species="stoneback_ram"
	test_enemy.enabled=false
	test_enemy.position=Vector2(100,440)
	level.world_objects.add_child(test_enemy)
	player.position=Vector2(100,400)
	test_enemy.visible_target=player
	test_enemy.brain.physics(0.1)
	_check(test_enemy.power_tell>1 and test_enemy.power_aim==player.position,"charge_warns_at_observed_position")
	var locked := test_enemy.power_aim
	player.position+=Vector2(40,0)
	test_enemy.brain.physics(0.5)
	_check(test_enemy.power_aim==locked,"charge_aim_does_not_home")
	test_enemy.queue_free()
	level.van.installed.clear()
	level.message_time=0
	if capture:
		await _tour()
	root.get_node("Session").select_survivor(previous_role)
	print(JSON.stringify({"event":"test_result","suite":"content_expansion","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures==0 else 1)
func _tour() -> void:
	level.player.hex_remaining=0
	level.player.ward_remaining=0
	for kind in ["noise_tin","salt_ward","glow_moss"]:
		level.player.pack(kind)
	level.player.selected_slot=3
	level.player.position=Vector2(100,400)
	await _snapshot("item_belt")
	# Inspection captures intentionally brighten terrain; production sight is captured separately.
	level.sight.enabled=false
	for child in level.get_children():
		if child.get_script()==load("res://scripts/ui/night_overlay.gd"):
			child.set_process(false)
			child.ambient.color=Color(0.85,0.85,0.85)
	for index in range(3,9):
		var zone: Dictionary=level.plan.woods.zones[index]
		level.player.position=zone["position"]+Vector2(0,55)
		level.player.get_node("Camera2D").zoom=Vector2(0.55,0.55)
		level.player.get_node("Camera2D").reset_smoothing()
		for enemy: CampCryptid in get_nodes_in_group("cryptids"):
			if enemy.home.has_area() and enemy.home.has_point(zone["position"]):
				enemy.position=zone["position"]+Vector2(50,15)
		await _frames(3)
		await _snapshot("biome_"+zone["kind"])
	# Remove local light overexposure for the brightened portrait inspection.
	for child in level.get_children():
		if child.get_script()==load("res://scripts/ui/night_overlay.gd"):
			child.flashlight.enabled=false
			child.nearby_glow.enabled=false
	level.player.hide()
	# Dedicated guide portraits: original in-engine creatures at native gameplay zoom.
	var camera: Camera2D = level.player.get_node("Camera2D")
	camera.zoom=Vector2.ONE
	camera.offset=Vector2(0,-32)
	level.player.position=level.plan.woods.center(Vector2i(4,4))+Vector2(0,28)
	level.player.facing=Vector2.UP
	for species: String in CampProfile.TIPS:
		if species in ["stalker","groundskeeper"]: continue
		var portrait: CampCryptid=load("res://scenes/actors/cryptid.tscn").instantiate()
		portrait.species=species
		portrait.enabled=false
		portrait.position=level.player.position+Vector2(0,-42)
		level.world_objects.add_child(portrait)
		# Pose the shape-shifters in their true form for the guide.
		if species=="werewolf": portrait.brain.wolf=true
		elif species=="mimic": portrait.brain.revealed=1.0
		elif species=="bog_hands": portrait.brain.sinking=2.0
		portrait.queue_redraw()
		camera.reset_smoothing()
		await _frames(5)
		await _snapshot("monster_"+species)
		portrait.queue_free()
		await _frames(1)
	camera.offset=Vector2.ZERO
	level.player.show()
func _frames(count: int) -> void:
	for i in range(count): await process_frame
func _tap(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await _frames(2)
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await _frames(2)
func _snapshot(label: String) -> void:
	await _frames(3)
	RenderingServer.force_draw(true)
	DirAccess.make_dir_recursive_absolute("res://artifacts/verification")
	_check(root.get_texture().get_image().save_png("res://artifacts/verification/%s.png"%label)==OK,"capture_"+label)
func _check(passed: bool, label: String) -> void:
	checks+=1
	if not passed: failures+=1
	print(JSON.stringify({"event":"assertion","name":label,"passed":passed}))
