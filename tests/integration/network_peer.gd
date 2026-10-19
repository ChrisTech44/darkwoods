extends SceneTree
## Real ENet processes. Host-only placements isolate contested authority/lifecycle checks.
var light_dark: Image
var checks := 0
var failures := 0
var net: Node
var harness: Harness
var side := "host"
var selected_mode := "camp"
var port := 27941
var peers := 2
var index := 1
var capture := false
var deadline := 0

class Harness extends Node:
	var stage := ""
	var data := {}
	var reports := {}
	@rpc("authority","call_local","reliable",0)
	func advance(value: String, payload: Dictionary = {}) -> void:
		stage=value
		data=payload
		if multiplayer.is_server():
			reports.clear()
			print(JSON.stringify({"event":"network_stage","stage":value}))
	@rpc("any_peer","call_remote","reliable",0)
	func report(value: String, payload: Dictionary) -> void:
		if multiplayer.is_server() and value==stage: reports[multiplayer.get_remote_sender_id()]=payload

func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		match args[i]:
			"--side": side=args[i+1]
			"--mode": selected_mode=args[i+1]
			"--port": port=int(args[i+1])
			"--peers": peers=int(args[i+1])
			"--index": index=int(args[i+1])
			"--capture": capture=true
	net=root.get_node("Net")
	harness=Harness.new()
	harness.name="NetworkTestHarness"
	root.add_child(harness)
	change_scene_to_file("res://scenes/ui/network_lobby.tscn")
	while current_scene==null: await process_frame
	if side=="host": await _host()
	elif side=="late": await _late()
	else: await _client()
	_finish()
func _host() -> void:
	current_scene.fields["Name"].text="Test Host"
	current_scene.fields["Port"].text=str(port)
	current_scene.fields["Role"].select(SurvivorRoster.IDS.find("john"))
	current_scene.fields["Mode"].select(1 if selected_mode=="woods" else 0)
	current_scene.fields["Seed"].text="42"
	current_scene.fields["Host"].pressed.emit()
	_check(net.active and net.phase=="lobby","host_button_binds_udp")
	if not await _until(func(): return net.roster.size()==peers,15): return
	net.choose("john",true)
	if not await _until(func(): return net.can_start(),10): return
	_check(net.roster.size()==peers,"real_peers_join_ready_lobby")
	net.configure_lobby("camp" if selected_mode=="woods" else "woods",42)
	_check(net.roster.values().all(func(entry): return not entry["ready"]),"changing_rules_clears_ready")
	net.configure_lobby(selected_mode,42)
	harness.advance.rpc("ready_check")
	net.choose("john",true)
	if not await _reports(peers-1): return
	if not await _until(func(): return net.can_start(),5): return
	if capture:
		current_scene.last_refresh=0
		current_scene._process(0.1)
		await process_frame
		RenderingServer.force_draw(true)
		root.get_texture().get_image().save_png("res://artifacts/network/lobby_%s_%d.png"%[selected_mode,peers])
	_check(net.start_round(selected_mode,42),"host_starts_locked_seed")
	if not await _until(func(): return net.phase=="playing",90): return
	var level: Node2D=net.world
	for enemy: CampKiller in get_nodes_in_group("killers"): enemy.enabled=false
	_check(net.actors.size()==peers and get_nodes_in_group("survivors").size()==peers,"one_actor_per_peer")
	_check(level.plan.seed_value==42 and level.plan.expedition==(selected_mode=="woods"),"shared_seed_mode")
	_check(get_nodes_in_group("killers").size()==(RoundPlan.CRYPTID_COUNT+1 if selected_mode=="woods" else 1),"current_monster_roster")
	var ids: Array=net.actors.keys()
	ids.sort()
	var guest: int=ids[1]
	harness.advance.rpc("movement",{"guest":guest})
	Input.action_press("move_right")
	await _until(func(): return net.actors[1].position.x>135,5)
	Input.action_release("move_right")
	if not await _reports(peers-1): return
	await _until(func(): return net.actors[guest].position.y>410,5)
	if net.actors[guest].position.y<=410: print(JSON.stringify({"event":"movement_probe","host":str(net.actors[1].position),"guest":str(net.actors[guest].position),"inputs":str(net.inputs)}))
	_check(net.actors[1].position.x>130 and net.actors[guest].position.y>410,"host_validates_both_players_movement")
	for report: Dictionary in harness.reports.values():
		_check(report.get("host_moved",false) and report.get("own_moved",false),"client_sees_remote_and_local_movement")
	if capture:
		await process_frame
		RenderingServer.force_draw(true)
		root.get_texture().get_image().save_png("res://artifacts/network/host_%s_%d.png"%[selected_mode,peers])
	if selected_mode == "woods":
		var entry := WoodsLayout.ENTRY
		var next := entry + Vector2i.LEFT
		for actor: CampPlayer in net.actors.values(): actor.position = Vector2(120,400)
		net.actors[guest].position = level.plan.woods.center(entry) + Vector2.LEFT * 70
		harness.advance.rpc("explore_ready",{"entry":entry,"next":next,"guest":guest})
		if not await _reports(peers-1): return
		_check(level.plan.woods.visited.has(entry) and not level.plan.woods.visited.has(next),"guest_position_discovers_only_occupied_trail_cell")
		harness.advance.rpc("explore_walk",{"entry":entry,"next":next,"guest":guest})
		if not await _reports(peers-1): return
		_check(level.plan.woods.visited.has(next),"guest_walk_extends_authoritative_team_map")
		for report: Dictionary in harness.reports.values():
			_check(report.get("explored",false),"client_map_receives_guest_trail_progress")
			_check(report.get("hidden",false),"unvisited_trails_stay_hidden_on_client")
		for actor: CampPlayer in net.actors.values(): actor.position = Vector2(140,430)
	# Empty interaction feedback belongs to the acting peer, never the shared banner.
	for actor: CampPlayer in net.actors.values(): actor.notice_time=0
	var shared_before: String=level.message
	harness.advance.rpc("empty_interaction",{"guest":guest})
	if not await _reports(peers-1): return
	_check(net.actors[guest].notice.contains("Nothing to use") and level.player.notice_time==0 and level.message==shared_before,"empty_interaction_does_not_broadcast")
	for report: Dictionary in harness.reports.values(): _check(report.get("private",false),"client_interaction_feedback_is_private")
	# Map pins are host-accepted intents, replicated once to every peer.
	harness.advance.rpc("map_pin",{"guest":guest})
	if not await _reports(peers-1): return
	_check(level.pins.size()==1 and level.pins[0]["owner"]==guest,"guest_pin_accepted_by_host")
	for report: Dictionary in harness.reports.values(): _check(report.get("pin",false),"guest_pin_replicated_to_clients")
	# F6 ability: a guest's X is a host-validated intent; its charge replicates.
	var rigger: CampPlayer=net.actors[guest]
	var rig_spot: Vector2=rigger.position
	rigger.kit["sample"]="werewolf"
	level.night_clock.set_moon(true)
	harness.advance.rpc("ability",{"guest":guest})
	if not await _reports(peers-1): return
	_check(rigger.kit.get("form","")=="werewolf" and rigger.kit.get("sample","").is_empty(),"guest_ability_accepted_by_host")
	for report: Dictionary in harness.reports.values(): _check(report.get("ability",false),"guest_ability_state_replicated")
	rigger.kit["form"]=""
	rigger.kit["form_time"]=0.0
	rigger.position=rig_spot
	# F7 snares are host state; every client renders the same traps.
	level.snares.snares.append({"position": Vector2(2000, 2000), "armed": true})
	harness.advance.rpc("snare",{})
	if not await _reports(peers-1): return
	for report: Dictionary in harness.reports.values(): _check(report.get("snare",false),"host_snare_replicated_to_clients")
	level.snares.snares.clear()
	# A guest's flash is a host-validated intent; the stun replicates to every peer.
	var flasher: CampPlayer=net.actors[guest]
	flasher.facing=Vector2.RIGHT
	flasher.ward_remaining=4.0
	flasher.flashlight_charge=90.0
	flasher.flash_cooldown=0.0
	var dazzled: CampKiller=level.killer
	var dazzled_was: bool=dazzled.enabled
	dazzled.position=flasher.position+Vector2(60,0)
	dazzled.stun_remaining=0.0
	dazzled.stun_immunity=0.0
	dazzled.enabled=true
	harness.advance.rpc("flash",{"guest":guest})
	if not await _reports(peers-1): return
	_check(dazzled.stun_immunity>0.0 and flasher.flash_cooldown>0.0,"guest_flash_stuns_on_host")
	for report: Dictionary in harness.reports.values(): _check(report.get("stun",false),"flash_stun_replicated_to_clients")
	dazzled.stun_remaining=0.0
	dazzled.stun_immunity=0.0
	dazzled.enabled=dazzled_was
	flasher.ward_remaining=0.0
	# Hiding is a host-validated interact; door state and collision replicate to clients.
	var hider: CampPlayer=net.actors[guest]
	var spot_index := -1
	for index in range(level.props.spots.size()):
		var free: bool=level.pickups.all(func(pickup: CampPickup) -> bool: return not pickup.available or pickup.position.distance_to(level.props.spots[index]["position"])>40)
		if not level.props.spots[index]["woods"] and free:
			spot_index=index
			break
	hider.position=level.props.spots[spot_index]["position"]+Vector2(0,6)
	var slammed: Dictionary=level.props.doors[0]
	level.props.toggle_door(level.player,0)
	# A shortcut gate opened on the host replicates (state and client collision).
	var shortcut: Dictionary=level.plan.woods.gates[0]
	var host_spot: Vector2=level.player.position
	level.player.position=shortcut["position"]+shortcut["toward_zone"]*22.0
	level.props.open_gate(level.player,0)
	level.player.position=host_spot
	harness.advance.rpc("hide_door",{"guest":guest,"door":slammed["rect"]})
	if not await _reports(peers-1): return
	_check(hider.hidden_spot==spot_index and not slammed["open"],"guest_hides_and_host_door_closed")
	for report: Dictionary in harness.reports.values(): _check(report.get("hidden",false) and report.get("door",false),"hiding_and_door_replicated_with_collision")
	level.props.leave(hider)
	level.props.toggle_door(level.player,0)
	if selected_mode=="woods":
		# The host owns the night clock; clients see the phase and the radio-revealed fuel cache.
		level.night_clock.force_phase(1)
		level.read_note(level.plan.required[3])
		harness.advance.rpc("night_phase",{"note":level.plan.required[3]})
		if not await _reports(peers-1): return
		for report: Dictionary in harness.reports.values(): _check(report.get("night",false),"nightfall_and_fuel_reveal_replicated")
	for actor: CampPlayer in net.actors.values():
		actor.flashlight_on=false
		actor.position=Vector2(140,430)
	level.player.position=Vector2(120,400)
	level.player.facing=Vector2.DOWN
	harness.advance.rpc("light_off")
	if not await _reports(peers-1): return
	level.player.flashlight_on=true
	harness.advance.rpc("light_on")
	if not await _reports(peers-1): return
	for report: Dictionary in harness.reports.values():
		_check(report.get("beam",false),"remote_flashlight_node_enabled")
		if capture: _check(report.get("pixels",false),"remote_flashlight_illuminates_client_pixels")
	# Deliberately omit snapshot pieces. Clients must keep old state and recover on the next complete sequence.
	net.snapshot_clock=1000
	net.snapshot_sequence+=1
	var gap: int=net.snapshot_sequence
	var incomplete: PackedByteArray=var_to_bytes(WorldSync.capture(net)).compress(FileAccess.COMPRESSION_DEFLATE)
	level.player.position += Vector2(32, 0)
	harness.advance.rpc("packet_gap",{"sequence":gap, "position":level.player.position})
	# This channel is intentionally lossy: retry the same incomplete piece until observed.
	var gap_deadline := Time.get_ticks_msec()+4000
	while harness.reports.size()<peers-1 and Time.get_ticks_msec()<gap_deadline:
		net._snapshot_piece.rpc(net.round_id,gap,0,2,incomplete.slice(0,mini(900,incomplete.size()/2)))
		await create_timer(0.1).timeout
	if not await _reports(peers-1): return
	for report: Dictionary in harness.reports.values():
		_check(report.get("partial_rejected",false),"partial_snapshot_never_applied")
		_check(report.get("motion_live",false),"player_motion_continues_without_complete_world_snapshot")
	net.snapshot_clock=0
	harness.advance.rpc("packet_recovery",{"sequence":gap})
	if not await _reports(peers-1): return
	for report: Dictionary in harness.reports.values(): _check(report.get("recovered",false),"snapshot_recovers_after_missing_piece")
	# Hold BOTH authority streams while inputs continue over real ENet for two seconds.
	net.motion_clock = 1000
	net.snapshot_clock = 1000
	harness.advance.rpc("prediction_gap")
	if not await _reports(peers-1): return
	for report: Dictionary in harness.reports.values():
		_check(report.get("stopped",false),"prediction_stops_during_real_authority_stream_gap")
		_check(report.get("bounded",false),"pending_inputs_bounded_during_real_stream_gap")
	net.motion_clock = 0
	net.snapshot_clock = 0
	harness.advance.rpc("prediction_recovery")
	if not await _reports(peers-1): return
	for report: Dictionary in harness.reports.values():
		_check(report.get("recovered",false),"prediction_recovers_to_authority_after_two_second_gap")
		_check(report.get("smooth",false),"ordinary_travel_during_gap_does_not_teleport_on_recovery")
		_check(report.get("independent",false),"legacy_world_target_cannot_drag_predicted_owner")
	_check(net.largest_snapshot_payload<=1000,"snapshot_pieces_fit_network_budget")
	# Authority fixture: move actors together on the host, never accept positions from clients.
	var pickup: CampPickup=level.pickups[0]
	for actor: CampPlayer in net.actors.values(): actor.position=pickup.position+Vector2(0,10)
	harness.advance.rpc("pickup",{"kind":pickup.kind})
	await create_timer(0.12).timeout
	net.action("interact")
	if not await _reports(peers-1): return
	var awarded := 0
	for actor: CampPlayer in net.actors.values(): awarded+=actor.inventory.count(pickup.kind)
	_check(awarded==1 and not pickup.available,"contested_pickup_awards_once")
	for report: Dictionary in harness.reports.values(): _check(report.get("unavailable",false),"pickup_state_shared")
	# Forged actions/roles and nonfinite direction cross actual client RPC boundaries.
	harness.advance.rpc("forgery")
	if not await _reports(peers-1): return
	_check(net.actors[guest].role=="christian" and net.roster[guest]["role"]=="christian","round_role_lock_rejects_forgery")
	_check(not "forged" in net.actors[guest].inventory,"client_cannot_grant_items")
	# A down releases every objective and supply once, offset from the prone sprite.
	var before_death: int=level.pickups.size()
	var body: CampPlayer=net.actors[guest]
	var carried_before: int=body.inventory.size()+1
	for kind in body.supplies: carried_before+=body.supplies[kind]
	body.inventory.append("fuse")
	body.set_status(CampPlayer.Status.DOWNED)
	body.set_status(CampPlayer.Status.DOWNED)
	_check(level.pickups.size()==before_death+carried_before and body.inventory.is_empty(),"down_releases_all_gear_once")
	_check(level.pickups.slice(before_death).all(func(item): return item.position.distance_to(body.position)>=30),"down_loot_clear_of_body")
	body.receive_hit()
	body._physics_process(120)
	_check(body.status==CampPlayer.Status.DOWNED,"down_survives_repeat_hits_and_time")
	body.set_status(CampPlayer.Status.ALIVE)

	_check(net.actors[guest].position.is_finite(),"nonfinite_input_rejected")
	# Injury and a real timed teammate rescue on the authoritative host.
	var injured: CampPlayer=net.actors[guest]
	injured.invulnerability=0
	injured.receive_hit()
	level.player.position=injured.position+Vector2(12,0)
	harness.advance.rpc("down",{"guest":guest})
	if not await _reports(peers-1): return
	for report: Dictionary in harness.reports.values(): _check(report.get("downed",false),"downed_state_shared")
	level.player.supplies["medkit"]=0
	level.advance_revive(level.player,injured,true,level.player.config.revive_seconds+0.01)
	_check(injured.status==CampPlayer.Status.DOWNED and level.revive_progress>0,"kitless_revive_slower_than_kit_time")
	level.advance_revive(level.player,injured,false,0.1)
	_check(level.revive_progress==0,"released_revive_resets")
	level.player.pack("medkit")
	Input.action_press("interact")
	await create_timer(3.4).timeout
	Input.action_release("interact")
	_check(injured.status==CampPlayer.Status.ALIVE and level.player.supplies["medkit"]==0,"timed_host_revive_consumes_one_kit")
	_check(injured.supplies["battery_pack"]==0,"revive_does_not_refresh_role_supplies")
	for slot in range(ids.size()):
		net.actors[ids[slot]].position=Vector2(120+slot*16,400)
		net.actors[ids[slot]].pack("flare")
	harness.advance.rpc("drop")
	if not await _reports(peers-1): return
	_check(level.pickups.size()>level.plan.loot.size(),"dropped_items_replicate_as_host_objects")
	harness.advance.rpc("flare_dark")
	if not await _reports(peers-1): return
	harness.advance.rpc("flare")
	if not await _reports(peers-1): return
	_check(not get_nodes_in_group("flares").is_empty(),"accepted_flare_spawned_on_host")
	for report: Dictionary in harness.reports.values():
		_check(report.get("flare",false),"accepted_flare_visible_on_clients")
		_check(report.get("lamp",false),"replica_flare_has_active_light")
		if capture: _check(report.get("pixels",false),"replica_flare_illuminates_client_pixels")
	if selected_mode=="woods":
		var bolt := HexBolt.new()
		bolt.position=Vector2(300,400)
		level.world_objects.add_child(bolt)
		bolt.set_physics_process(false)
		var patch := LandmarkHazard.new()
		patch.position=Vector2(330,400)
		level.world_objects.add_child(patch)
		patch.set_physics_process(false)
		harness.advance.rpc("hazards")
		if not await _reports(peers-1): return
		for report: Dictionary in harness.reports.values(): _check(report.get("hazards",false),"woods_projectile_patch_replicated_without_client_physics")
	await _active_ai_round(level,ids,guest)
	# Assemble the objective with host fixture inventory; interaction still uses production validation.
	level.player.inventory.assign(level.plan.required)
	level.player.position=level.van.interaction_point()
	for item: CampPickup in level.pickups:
		if item.kind in level.plan.required: item.consume()
	net.action("interact")
	_check(level.van.installed.size()==level.plan.required.size(),"all_parts_installed_authoritatively")
	level.player.position=level.van.position+Vector2(-22,2)
	for id: int in ids:
		net.actors[id].position=level.van.interaction_point() if id==guest else level.van.position+Vector2(-22,2)
	harness.advance.rpc("ignite",{"guest":guest})
	if not await _until(func(): return level.van.running,5): return
	_check(level.van.start_actor==injured and injured.status==CampPlayer.Status.BOARDED,"remote_mechanic_ignites_and_boards")
	# Leave one teammate down away from the van: departure must rescue them too.
	level.player.position=Vector2(180,420)
	level.player.invulnerability=0
	level.player.wounded=true
	level.player.receive_hit()
	harness.advance.rpc("board")
	if not await _reports(peers-1): return
	_check(level.van.passengers.size()==peers-1,"living_survivors_board_while_teammate_downed")
	# Expedition departures are a 20 s hold-out (Quick Camp: 8 s).
	if not await _until(func(): return level.finished,25): return
	_check(level.won and net.actors.values().all(func(actor): return actor.status==CampPlayer.Status.ESCAPED),"van_escape_also_rescues_downed_teammate")
	harness.advance.rpc("result")
	if not await _reports(peers-1): return
	for report: Dictionary in harness.reports.values(): _check(report.get("escaped",false),"client_escape_result_matches")
	var old_world: WeakRef = weakref(level)
	net.return_lobby(true)
	if not await _until(func(): return current_scene!=null and current_scene.name=="NetworkLobby",5): return
	harness.advance.rpc("lobby")
	if not await _reports(peers-1): return
	_check(old_world.get_ref()==null and get_nodes_in_group("survivors").is_empty() and get_nodes_in_group("hazards").is_empty(),"restart_frees_old_world_and_entities")
	for report: Dictionary in harness.reports.values(): _check(report.get("clean",false),"clients_return_to_same_clean_lobby")
	net.choose("john",true)
	harness.advance.rpc("ready_again")
	if not await _until(func(): return net.can_start(),5): return
	_check(net.start_round(selected_mode,net.seed_value),"synchronized_same_seed_restart")
	if not await _until(func(): return net.phase=="playing",90): return
	for enemy: CampKiller in get_nodes_in_group("killers"): enemy.enabled=false
	_check(net.round_id==2 and net.world.plan.seed_value==42 and net.actors[guest].supplies["flare"]==2,"fresh_round_resets_state_and_applies_bonus_once")
	if peers>2:
		var departing: int=ids.back()
		net.actors[departing].inventory.append("battery")
		var dropped_count := 1
		for kind in net.actors[departing].supplies: dropped_count+=int(net.actors[departing].supplies[kind])
		var initial_items: int=net.world.pickups.size()
		harness.advance.rpc("guest_leave",{"departing":departing})
		if not await _until(func(): return not net.actors.has(departing),5): return
		_check(net.world.pickups.size()==initial_items+dropped_count and net.roster.size()==peers-1,"disconnect_drops_objective_and_removes_actor")
	if selected_mode == "woods":
		await _radio_round(net.world, guest)
		await _field_round(guest, "boat")
		await _field_round(guest, "gate")
	harness.advance.rpc("host_loss")
	await create_timer(0.3).timeout
	net.leave("Host closed test camp.")
	await create_timer(0.5).timeout
	_check(not net.active and get_nodes_in_group("survivors").is_empty(),"host_leave_cleans_up")

func _client() -> void:
	current_scene.fields["Address"].text="127.0.0.1" # Never inherit a player's saved remote host.
	current_scene.fields["Name"].text="Guest %d"%index
	current_scene.fields["Port"].text=str(port)
	current_scene.fields["Role"].select(SurvivorRoster.IDS.find("christian"))
	current_scene.fields["Join"].pressed.emit()
	_check(net.active,"join_button_starts_connection")
	if not await _until(func(): return net.phase=="lobby",15): return
	net.choose("christian",true)
	if not await _until(func(): return harness.stage=="ready_check",10): return
	_check(net.mode==selected_mode and net.seed_value==42 and not net.roster[get_multiplayer().get_unique_id()]["ready"],"client_receives_changed_rules_and_unready")
	net.choose("christian",true)
	harness.report.rpc_id(1,"ready_check",{})
	if not await _until(func(): return net.phase=="playing",90): return
	_check(net.actors.size()==peers and get_nodes_in_group("survivors").size()==peers,"client_receives_exact_roster")
	_check(net.world.plan.seed_value==42 and not net.world.player.is_physics_processing(),"client_is_replica_with_shared_seed")
	var handled := ""
	while net.active:
		await process_frame
		if harness.stage==handled: continue
		handled=harness.stage
		var mine: int=get_multiplayer().get_unique_id()
		if handled.begins_with("field_take_"):
			await create_timer(0.45).timeout
			if mine==harness.data["guest"]: net.action("interact")
			await _until(func(): return harness.data["kind"] in net.actors[harness.data["guest"]].inventory,5)
			harness.report.rpc_id(1,handled,{"taken":harness.data["kind"] in net.actors[harness.data["guest"]].inventory})
			continue
		match handled:
			"explore_ready":
				await _until(func(): return net.world.plan.woods.visited.has(harness.data.entry),5)
				net.world.hud.notebook.open_view("map")
				if capture:
					await create_timer(0.15).timeout
					RenderingServer.force_draw(true)
					root.get_texture().get_image().save_png("res://artifacts/network/exploration_before_%d.png" % index)
				harness.report.rpc_id(1,handled,{})
			"explore_walk":
				if mine == harness.data.guest:
					Input.action_press("move_left")
					await create_timer(0.85).timeout
					Input.action_release("move_left")
				await _until(func(): return net.world.plan.woods.visited.has(harness.data.next),5)
				var explored: bool = net.world.hud.chart.plan.woods.visited.has(harness.data.entry) and net.world.hud.chart.plan.woods.visited.has(harness.data.next)
				var hidden: bool = not net.world.plan.woods.visited.has(Vector2i.ZERO)
				if capture:
					await create_timer(0.15).timeout
					RenderingServer.force_draw(true)
					root.get_texture().get_image().save_png("res://artifacts/network/exploration_after_%d.png" % index)
				net.world.hud.notebook.close()
				harness.report.rpc_id(1,handled,{"explored":explored,"hidden":hidden})
			"ready_boat", "ready_gate": net.choose("christian",true)
			"field_boat_fit", "field_boat_start", "field_gate_fit", "field_gate_power", "field_circuit":
				await create_timer(0.45).timeout
				if mine==harness.data["guest"]: net.action("interact")
				var accepted:=func() -> bool:
					match handled:
						"field_boat_fit": return net.world.escapes.boat_installed.size()==3
						"field_boat_start": return net.world.escapes.boat_started
						"field_gate_fit": return net.world.escapes.gate_installed.size()==3
						"field_gate_power": return net.world.escapes.gate_powered
						_: return net.world.rescue.powered
				await _until(accepted,5)
				harness.report.rpc_id(1,handled,{"accepted":accepted.call()})
			"field_gate_hold":
				await create_timer(0.45).timeout
				if mine==harness.data["guest"]: Input.action_press("interact")
				await _until(func(): return net.world.escapes.gate_open,7)
				Input.action_release("interact")
				await physics_frame
				await physics_frame
				harness.report.rpc_id(1,handled,{"open":net.world.escapes.gate_open and net.world.escapes.gate_body.get_child(0).disabled})
			"field_assist":
				await _until(func(): return net.actors[harness.data["guest"]].motor_assisted,5)
				harness.report.rpc_id(1,handled,{"assisted":net.actors[harness.data["guest"]].motor_assisted and net.actors[1].assisting_motor})
			"field_lake":
				await _until(func(): return net.world.escapes.lake_tell>0,5)
				harness.report.rpc_id(1,handled,{"tell":net.world.escapes.lake_tell>0,"wave":net.world.escapes.lake_wave})
			"field_bridge":
				await _until(func(): return net.world.escapes.bridge_started,5)
				harness.report.rpc_id(1,handled,{"bridge":net.world.escapes.bridge_started})
			"field_result_boat", "field_result_gate":
				await _until(func(): return net.world.finished,5)
				harness.report.rpc_id(1,handled,{"won":net.world.won,"escaped":net.world.player.status==CampPlayer.Status.ESCAPED,"route":net.world.escape_route})
			"movement":
				Input.action_press("move_down")
				await _until(func(): return net.world.player.position.y>440,5)
				Input.action_release("move_down")
				await _until(func(): return net.actors[1].position.x>125 and net.world.player.position.y>410,5)
				if capture:
					await process_frame
					RenderingServer.force_draw(true)
					root.get_texture().get_image().save_png("res://artifacts/network/client_%s_%d_%d.png"%[selected_mode,peers,index])
				harness.report.rpc_id(1,handled,{"host_moved":net.actors[1].position.x>125,"own_moved":net.world.player.position.y>410})
			"empty_interaction":
				if get_multiplayer().get_unique_id()==harness.data["guest"]: net.action("interact")
				await _until(func(): return net.actors[harness.data["guest"]].notice.contains("Nothing to use"),5)
				var personal_actor: CampPlayer=net.world.player
				harness.report.rpc_id(1,handled,{"private":personal_actor.notice.contains("Nothing to use") if get_multiplayer().get_unique_id()==harness.data["guest"] else personal_actor.notice_time==0})
			"hide_door":
				if mine==harness.data["guest"]:
					await create_timer(0.4).timeout
					net.action("interact")
				await _until(func(): return net.actors[harness.data["guest"]].hidden_spot>=0 and not net.world.props.doors[0]["open"],5)
				for frame in range(3): await physics_frame
				var door_rect: Rect2=harness.data["door"]
				var blocked: bool=not net.world.clear_path(door_rect.get_center()+Vector2(0,20),door_rect.get_center()-Vector2(0,30))
				var gate_ok: bool=net.world.plan.woods.gates[0]["open"] and net.world.props.gate_links[0].enabled
				harness.report.rpc_id(1,handled,{"hidden":net.actors[harness.data["guest"]].hidden_spot>=0,"door":not net.world.props.doors[0]["open"] and blocked and gate_ok})
			"flash":
				if mine==harness.data["guest"]: net.action("flash")
				var stunned := func() -> bool:
					for enemy: CampKiller in get_nodes_in_group("killers"):
						if enemy.stun_remaining>0.0: return true
					return false
				await _until(stunned,5)
				harness.report.rpc_id(1,handled,{"stun":stunned.call() and net.actors[harness.data["guest"]].flash_cooldown>0.0})
			"night_phase":
				var fuel: CampPickup
				for pickup: CampPickup in net.world.pickups:
					if pickup.kind=="fuel": fuel=pickup
				await _until(func(): return net.world.night_clock.phase==1 and fuel.available,5)
				for frame in range(3): await process_frame
				var night_ok: bool=net.world.night_clock.phase==1 and fuel.available and fuel.visible and net.world.hud.title.text.contains("NIGHTFALL") and net.world.clues.get(harness.data["note"],0)==1
				if not night_ok: print(JSON.stringify({"event":"night_replica","phase":net.world.night_clock.phase,"elapsed":net.world.night_clock.elapsed,"fuel":fuel.available,"visible":fuel.visible,"title":net.world.hud.title.text}))
				harness.report.rpc_id(1,handled,{"night":night_ok})
			"snare":
				await _until(func(): return net.world.snares.snares.size()==1,5)
				harness.report.rpc_id(1,handled,{"snare":net.world.snares.snares.size()==1 and net.world.snares.snares[0]["armed"]})
			"ability":
				if mine==harness.data["guest"]: net.action("ability")
				await _until(func(): return net.actors[harness.data["guest"]].kit.get("form","")=="werewolf",5)
				harness.report.rpc_id(1,handled,{"ability":net.actors[harness.data["guest"]].kit.get("form","")=="werewolf"})
			"map_pin":
				if mine==harness.data["guest"]: net.action("pin")
				await _until(func(): return net.world.pins.size()==1,5)
				harness.report.rpc_id(1,handled,{"pin":net.world.pins.size()==1 and net.world.pins[0]["owner"]==harness.data["guest"]})
			"active_ai_0", "active_ai_1", "active_ai_2", "active_ai_3":
				await _until(func(): return net.actors[harness.data["down"]].status==CampPlayer.Status.DOWNED,5)
				var enemies := get_nodes_in_group("killers")
				var initial := []
				for enemy_index in harness.data["enemies"]: initial.append(enemies[enemy_index].stride)
				await create_timer(0.5).timeout
				var moving := true
				for i in range(initial.size()):
					var enemy: CampKiller=enemies[harness.data["enemies"][i]]
					moving=moving and enemy.enabled and enemy.stride>initial[i]+1
				harness.report.rpc_id(1,handled,{"moving":moving,"playing":not net.world.finished})
			"light_off":
				await _until(func(): return not net.actors[1].flashlight_on,5)
				await create_timer(0.15).timeout
				if capture: light_dark=await _light_image()
				harness.report.rpc_id(1,handled,{})
			"light_on":
				await _until(func(): return net.actors[1].flashlight_on,5)
				await create_timer(0.15).timeout
				var beam: bool=net.actors[1].get_children().any(func(node): return node is PointLight2D and node.texture==CampLights.texture(true) and node.enabled)
				var pixels := false
				if capture:
					var bright := await _light_image()
					pixels=_brighter(bright,light_dark)
					bright.save_png("res://artifacts/network/shared_flashlight_%s_%d_%d.png"%[selected_mode,peers,index])
				harness.report.rpc_id(1,handled,{"beam":beam,"pixels":pixels})
			"flare_dark":
				await create_timer(0.15).timeout
				if capture: light_dark=await _light_image()
				harness.report.rpc_id(1,handled,{})
			"packet_gap":
				var first_motion: int = net.last_motion_sequence
				await _until(func(): return net.assembling_sequence>=harness.data["sequence"],5)
				var live := func() -> bool: return net.last_motion_sequence > first_motion + 2 and net.actors[1].position.distance_to(harness.data["position"]) < 3.0
				await _until(live, 5)
				harness.report.rpc_id(1,handled,{"partial_rejected":net.last_snapshot<harness.data["sequence"], "motion_live":live.call()})
			"packet_recovery":
				await _until(func(): return net.last_snapshot>harness.data["sequence"],5)
				harness.report.rpc_id(1,handled,{"recovered":net.last_snapshot>harness.data["sequence"]})
			"prediction_gap":
				Input.action_press("move_right")
				await create_timer(1.7).timeout
				var stopped_at: Vector2 = net.actors[mine].position
				net.motion_targets[net.actors[mine]] = stopped_at # Force world-before-motion arrival ordering.
				await create_timer(0.35).timeout
				Input.action_release("move_right")
				harness.report.rpc_id(1,handled,{"stopped":net.actors[mine].position.distance_to(stopped_at)<2.0,"bounded":net.prediction.history.size()<=16})
			"prediction_recovery":
				var observed := {"position":net.actors[mine].position,"largest":0.0}
				var watch := func():
					var at: Vector2 = net.actors[mine].position
					observed.largest = maxf(observed.largest,at.distance_to(observed.position))
					observed.position = at
				process_frame.connect(watch)
				await create_timer(2.0).timeout
				process_frame.disconnect(watch)
				harness.report.rpc_id(1,handled,{"recovered":net.prediction.actor.position.distance_to(net.prediction.simulated)<3.0,"smooth":observed.largest<12.0,"independent":not net.motion_targets.has(net.actors[mine])})
			"pickup":
				await create_timer(0.1).timeout
				net.action("interact")
				await _until(func(): return not net.world.pickups[0].available,5)
				harness.report.rpc_id(1,handled,{"unavailable":not net.world.pickups[0].available})
			"forgery":
				net._choice.rpc_id(1,"forged",true)
				net._action.rpc_id(1,net.round_id,"give_item",0)
				net._input_packet.rpc_id(1,net.round_id,999999,Vector2(INF,0),false,false)
				await create_timer(0.2).timeout
				harness.report.rpc_id(1,handled,{})
			"down":
				await _until(func(): return net.actors[harness.data["guest"]].status==CampPlayer.Status.DOWNED,5)
				if capture:
					await create_timer(0.1).timeout
					var image := await _light_image()
					image.save_png("res://artifacts/network/downed_gear_%s_%d_%d.png"%[selected_mode,peers,index])
				harness.report.rpc_id(1,handled,{"downed":net.actors[harness.data["guest"]].status==CampPlayer.Status.DOWNED})
			"drop":
				net.action("select",0)
				net.action("drop")
				await create_timer(0.25).timeout
				net.action("interact")
				await create_timer(0.25).timeout
				harness.report.rpc_id(1,handled,{})
			"flare":
				net.action("flare")
				await _until(func(): return not get_nodes_in_group("flares").is_empty(),5)
				await create_timer(0.15).timeout
				var lamp := get_nodes_in_group("flares").any(func(node): return node.get_children().any(func(child): return child is PointLight2D and child.enabled))
				var pixels := false
				if capture:
					var bright := await _light_image()
					pixels=_brighter(bright,light_dark)
					bright.save_png("res://artifacts/network/shared_flare_%s_%d_%d.png"%[selected_mode,peers,index])
				harness.report.rpc_id(1,handled,{"flare":not get_nodes_in_group("flares").is_empty(),"lamp":lamp,"pixels":pixels})
			"hazards":
				await _until(func(): return get_nodes_in_group("hazards").size()>=2,5)
				harness.report.rpc_id(1,handled,{"hazards":get_nodes_in_group("hazards").size()>=2 and get_nodes_in_group("hazards").all(func(node): return not node.is_physics_processing())})
			"radio_take", "radio_power", "radio_signal_0", "radio_signal_1", "radio_signal_2", "radio_begin":
				await create_timer(0.45).timeout
				if mine == harness.data["guest"]: net.action("interact")
				var accepted := func() -> bool:
					if net.world == null: return false
					match handled:
						"radio_take": return "rescue_fuse" in net.actors[harness.data["guest"]].inventory
						"radio_power": return net.world.rescue.powered
						"radio_begin": return net.world.rescue.started
						_: return net.world.rescue.signals[int(handled.right(1))]
				await _until(accepted, 5)
				harness.report.rpc_id(1, handled, {"accepted":accepted.call()})
			"radio_transmit":
				await create_timer(0.45).timeout
				if mine == harness.data["guest"]: Input.action_press("interact")
				await _until(func(): return net.world.rescue.transmitted, 9)
				Input.action_release("interact")
				harness.report.rpc_id(1, handled, {"sent":net.world.rescue.transmitted, "waiting":not net.world.rescue.started})
			"radio_lamps":
				await create_timer(0.4).timeout
				var lit: bool = net.world.rescue.lamps.slice(0,3).all(func(lamp): return lamp.enabled)
				harness.report.rpc_id(1, handled, {"lit":lit, "signals":net.world.rescue.signals.count(true)})
			"radio_result":
				await _until(func(): return net.world.finished, 5)
				harness.report.rpc_id(1, handled, {"won":net.world.won, "escaped":net.world.player.status == CampPlayer.Status.ESCAPED, "route":net.world.escape_route})
			"ignite":
				if mine==harness.data["guest"]: Input.action_press("interact")
			"board":
				Input.action_release("interact")
				net.action("interact")
				await create_timer(0.3).timeout
				harness.report.rpc_id(1,handled,{})
			"result":
				await _until(func(): return net.world.finished,5)
				harness.report.rpc_id(1,handled,{"escaped":net.world.finished and net.world.won and net.world.player.status==CampPlayer.Status.ESCAPED})
			"lobby":
				await create_timer(0.2).timeout
				harness.report.rpc_id(1,handled,{"clean":net.phase=="lobby" and get_nodes_in_group("survivors").is_empty() and net.roster.values().all(func(row): return not row["ready"])})
			"ready_again": net.choose("christian",true)
			"guest_leave":
				if mine==harness.data["departing"]:
					net.leave()
					await create_timer(0.2).timeout
					_check(get_nodes_in_group("survivors").is_empty(),"guest_leave_cleans_up")
					return
			"host_loss":
				if not await _until(func(): return not net.active,15): return
				await create_timer(0.2).timeout
				_check(net.status_text.contains("Host") and get_nodes_in_group("survivors").is_empty(),"host_loss_returns_client_to_clean_menu")
				return
func _late() -> void:
	net.join("127.0.0.1",port,"Late Guest","john")
	if not await _until(func(): return not net.active,15): return
	_check(net.status_text.contains("already running") or net.status_text.contains("failed") or net.status_text.contains("timed out"),"late_join_refused")
func _reports(count: int) -> bool:
	return await _until(func(): return harness.reports.size()>=count,30)
func _until(predicate: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<until: await process_frame
	var ok: bool=predicate.call()
	if not ok:
		print(JSON.stringify({"event":"network_wait_failure","phase":net.phase,"status":net.status_text,"loaded":net.loaded.size(),"participants":net.participants.size()}))
	_check(ok,"wait_%s_%s"%[side,harness.stage])
	return ok
func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(JSON.stringify({"event":"assertion","name":label,"passed":ok}))
func _finish() -> void:
	if current_scene!=null: current_scene.queue_free()
	harness.queue_free()
	for frame in range(5): await process_frame
	print(JSON.stringify({"event":"test_result","suite":"network_%s_%s_%d"%[side,selected_mode,peers],"checks":checks,"failures":failures,"snapshot_bytes":net.latest_snapshot_bytes,"largest_snapshot_payload":net.largest_snapshot_payload}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures==0 else 1)


func _light_image() -> Image:
	await process_frame
	RenderingServer.force_draw(true)
	return root.get_texture().get_image()


func _brighter(bright: Image, dark: Image) -> bool:
	var gain := 0.0
	# Compare terrain, excluding HUD, survivor sprites and the flare's own sparks.
	var sources: Array=get_nodes_in_group("survivors")
	sources.append_array(get_nodes_in_group("flares"))
	var centers: Array[Vector2]=[]
	for source: Node2D in sources: centers.append(root.get_canvas_transform()*source.global_position)
	for y in range(40,mini(145,bright.get_height())):
		for x in range(bright.get_width()):
			var point := Vector2(x,y)
			if centers.any(func(center): return center.distance_to(point)<30): continue
			var a := bright.get_pixel(x,y)
			var b := dark.get_pixel(x,y)
			gain+=maxf(0,(a.r+a.g+a.b)-(b.r+b.g+b.b))
	return gain>20


func _active_ai_round(level: Node2D, ids: Array, guest: int) -> void:
	var enemies := get_nodes_in_group("killers")
	var probes: Array[CampKiller]=[level.killer]
	for enemy: CampKiller in enemies:
		# A roaming creature with ordinary senses that keeps walking (the Mimic
		# ambles toward people; guardians stay in their regions).
		if enemy is CampCryptid and enemy.species == "mimic" and not enemy.home.has_area():
			probes.append(enemy)
			break
	# Camp sensing is a second-half matter (creatures stay out until Deep Night).
	level.open_camp()
	var indices := []
	for enemy in probes: indices.append(enemies.find(enemy))
	# Real senses must choose a living teammate over a closer downed body.
	for id in ids:
		net.actors[id].position=Vector2(96+12*ids.find(id),384)
		net.actors[id].ward_remaining=60
	level.player.position=Vector2(360,520)
	net.actors[guest].position=Vector2(400,520)
	level.player.set_status(CampPlayer.Status.DOWNED)
	for enemy in probes:
		enemy.position=Vector2(360,520)
		_check(enemy.sense_visible_target()==net.actors[guest],"active_enemy_prefers_living_teammate_over_body")
	# With no kit, E must collect nearby gear rather than silently starting a revive.
	net.actors[guest].position=level.player.position+Vector2(16,0)
	level.spawn_dropped("medkit",net.actors[guest].position)
	for attempt in range(10):
		if net.actors[guest].supplies["medkit"]>0: break
		level.try_interact(net.actors[guest])
	_check(net.actors[guest].supplies["medkit"]==1,"no_kit_interaction_recovers_gear_beside_downed_teammate")
	level.advance_revive(net.actors[guest],level.player,true,net.actors[guest].config.revive_seconds+0.01)
	_check(level.player.status==CampPlayer.Status.ALIVE,"recovered_kit_revives_teammate")
	for id in ids: net.actors[id].position=Vector2(96+12*ids.find(id),384)
	for i in range(probes.size()):
		var enemy := probes[i]
		enemy.position=Vector2(360,520+i*20)
		enemy.patrol.assign([Vector2(600,520+i*20),Vector2(360,520+i*20)])
		enemy.patrol_index=0
		enemy.visible_target=null
		enemy.transition(CampKiller.State.PATROL)
		if enemy is CampCryptid: enemy.home=Rect2()
	for enemy: CampKiller in enemies: enemy.enabled=true
	for turn in range(4):
		var target: CampPlayer=net.actors[1 if turn%2==0 else guest]
		var rescuer: CampPlayer=net.actors[guest if turn%2==0 else 1]
		target.set_status(CampPlayer.Status.DOWNED)
		var before := []
		for enemy in probes: before.append(enemy.stride)
		harness.advance.rpc("active_ai_%d"%turn,{"down":1 if turn%2==0 else guest,"enemies":indices})
		if not await _reports(peers-1): return
		for i in range(probes.size()): _check(probes[i].stride>before[i]+3 and probes[i].enabled,"enemy_keeps_walking_during_down_%d"%turn)
		for report: Dictionary in harness.reports.values(): _check(report.get("moving",false) and report.get("playing",false),"clients_see_active_enemies_without_false_defeat_%d"%turn)
		_check(not level.finished,"alternating_down_does_not_end_round_%d"%turn)
		rescuer.pack("medkit")
		level.advance_revive(rescuer,target,true,rescuer.config.revive_seconds+0.01)
		_check(target.status==CampPlayer.Status.ALIVE and rescuer.supplies["medkit"]==0,"alternating_revive_completes_%d"%turn)
	for enemy: CampKiller in enemies: enemy.enabled=false
	for actor: CampPlayer in net.actors.values(): actor.ward_remaining=0


func _radio_round(level: Node2D, guest: int) -> void:
	level.night_clock.director_enabled = false
	var rescue: RadioRescue = level.rescue
	var operator: CampPlayer = net.actors[guest]
	var fuse: CampPickup
	for pickup: CampPickup in level.pickups:
		if pickup.kind == "rescue_fuse": fuse = pickup
	operator.position = fuse.position
	harness.advance.rpc("radio_take", {"guest":guest})
	if not await _reports(net.actors.size()-1): return
	_check("rescue_fuse" in operator.inventory and not fuse.available, "remote_collects_radio_fuse_authoritatively")
	operator.position = rescue.power_point
	harness.advance.rpc("radio_power", {"guest":guest})
	if not await _reports(net.actors.size()-1):
		print(JSON.stringify({"event":"radio_power_fixture", "position":str(operator.position), "inventory":operator.inventory, "effects":operator.effects, "prompt":rescue.prompt(operator), "notice":operator.notice, "powered":rescue.powered}))
		return
	_check(rescue.powered and "rescue_fuse" not in operator.inventory, "remote_restores_substation")
	level.night_clock.skip_to(2400)
	operator.position = rescue.relay_point
	harness.advance.rpc("radio_transmit", {"guest":guest})
	if not await _reports(net.actors.size()-1): return
	_check(rescue.transmitted and rescue.starter == operator and not rescue.started, "remote_holds_radio_without_starting_finale_early")
	for report: Dictionary in harness.reports.values(): _check(report.get("sent",false) and report.get("waiting",false), "client_receives_radio_transmission")
	operator.pack("flare",3)
	for index in range(3):
		operator.position = rescue.landing + RadioRescue.SOCKET_OFFSETS[index]
		harness.advance.rpc("radio_signal_%d" % index, {"guest":guest})
		if not await _reports(net.actors.size()-1): return
		_check(rescue.signals[index], "remote_lights_signal_%d" % index)
	for actor: CampPlayer in net.actors.values(): actor.position = rescue.landing
	harness.advance.rpc("radio_lamps")
	if not await _reports(net.actors.size()-1): return
	for report: Dictionary in harness.reports.values(): _check(report.get("lit",false) and report.get("signals",0)==3, "all_client_signal_lights_enabled")
	harness.advance.rpc("radio_begin", {"guest":guest})
	if not await _reports(net.actors.size()-1): return
	_check(rescue.started and rescue.remaining > 35, "remote_begins_full_host_owned_holdout")
	level.player.position = Vector2(96,384)
	level.player.set_status(CampPlayer.Status.DOWNED)
	# Accelerate only the countdown tail; actual remote inputs drove every step.
	rescue.advance(41)
	_check(level.finished and level.won and net.actors.values().all(func(actor): return actor.status == CampPlayer.Status.ESCAPED), "radio_escape_rescues_connected_downed_host")
	harness.advance.rpc("radio_result")
	if not await _reports(net.actors.size()-1): return
	for report: Dictionary in harness.reports.values(): _check(report.get("won",false) and report.get("escaped",false) and report.get("route", "") == "RADIO RESCUE", "client_radio_result_matches_authority")


func _field_round(guest: int, route: String) -> void:
	net.return_lobby(true)
	if not await _until(func(): return current_scene!=null and current_scene.name=="NetworkLobby",5): return
	harness.advance.rpc("ready_"+route)
	net.choose("john",true)
	if not await _until(func(): return net.can_start(),8): return
	_check(net.start_round("woods",42),"fresh_"+route+"_round_starts")
	if not await _until(func(): return net.phase=="playing",90): return
	var level: Node2D=net.world
	var field: FieldEscapes=level.escapes
	var operator: CampPlayer=net.actors[guest]
	for enemy: CampKiller in get_nodes_in_group("killers"): enemy.enabled=false
	level.night_clock.director_enabled=false
	var parts: Array[String]=FieldEscapes.BOAT_PARTS.duplicate() if route=="boat" else FieldEscapes.GATE_CODES.duplicate()
	if route=="gate": parts.append("rescue_fuse")
	for kind in parts:
		for pickup: CampPickup in level.pickups:
			if pickup.kind==kind and pickup.available: operator.position=pickup.position
		harness.advance.rpc("field_take_"+kind,{"guest":guest,"kind":kind})
		if not await _reports(net.actors.size()-1): return
		_check(kind in operator.inventory,"remote_takes_"+kind)
	if route=="boat":
		operator.position=Vector2(620,520)
		level.player.position=Vector2(600,520)
		Input.action_press("interact")
		harness.advance.rpc("field_assist",{"guest":guest})
		if not await _reports(net.actors.size()-1): return
		Input.action_release("interact")
		_check(operator.motor_assisted,"heavy_assistance_authoritative")
		for report: Dictionary in harness.reports.values(): _check(report.get("assisted",false),"client_sees_heavy_assistance")
		operator.position=field.boat_point
		harness.advance.rpc("field_boat_fit",{"guest":guest})
		if not await _reports(net.actors.size()-1): return
		_check(field.boat_installed.size()==3 and not field.boat_started,"remote_installs_boat_parts")
		level.night_clock.skip_to(2400)
		harness.advance.rpc("field_boat_start",{"guest":guest})
		if not await _reports(net.actors.size()-1): return
		_check(field.boat_started and field.boat_remaining>23,"remote_starts_full_boat_countdown")
		field.advance(5.1)
		harness.advance.rpc("field_lake")
		if not await _reports(net.actors.size()-1): return
		for report: Dictionary in harness.reports.values(): _check(report.get("tell",false) and report.get("wave",0)==1,"client_receives_telegraphed_lake_attack")
	else:
		operator.position=level.rescue.power_point
		harness.advance.rpc("field_circuit",{"guest":guest})
		if not await _reports(net.actors.size()-1): return
		operator.position=field.breaker_point
		harness.advance.rpc("field_gate_power",{"guest":guest})
		if not await _reports(net.actors.size()-1): return
		operator.position=field.gate_point
		harness.advance.rpc("field_gate_fit",{"guest":guest})
		if not await _reports(net.actors.size()-1): return
		_check(field.gate_powered and field.gate_installed.size()==3,"remote_powers_gate_and_installs_codes")
		level.night_clock.skip_to(2400)
		harness.advance.rpc("field_gate_hold",{"guest":guest})
		if not await _reports(net.actors.size()-1): return
		_check(field.gate_open,"remote_gate_hold_opens_arm")
		for report: Dictionary in harness.reports.values(): _check(report.get("open",false),"client_opens_physical_gate_arm")
		operator.position=field.bridge
		harness.advance.rpc("field_bridge")
		if not await _reports(net.actors.size()-1): return
		_check(field.bridge_started,"remote_reaches_bridge")
	for id: int in net.actors:
		if id!=guest:
			net.actors[id].position=Vector2(96,384)
			net.actors[id].set_status(CampPlayer.Status.DOWNED)
	operator.position=field.boat_point if route=="boat" else field.bridge
	field.advance(26 if route=="boat" else 9)
	_check(level.finished and level.won and net.actors.values().all(func(actor): return actor.status==CampPlayer.Status.ESCAPED),route+"_recovers_all_connected_downed_teammates")
	harness.advance.rpc("field_result_"+route)
	if not await _reports(net.actors.size()-1): return
	for report: Dictionary in harness.reports.values(): _check(report.get("won",false) and report.get("escaped",false) and report.get("route","")==("BOAT" if route=="boat" else "RANGER GATE"),"client_"+route+"_result_matches")
