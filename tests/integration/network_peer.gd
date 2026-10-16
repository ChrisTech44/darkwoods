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
	current_scene.fields["Role"].select(3)
	current_scene.fields["Mode"].select(1 if selected_mode=="woods" else 0)
	current_scene.fields["Seed"].text="42"
	current_scene.fields["Host"].pressed.emit()
	_check(net.active and net.phase=="lobby","host_button_binds_udp")
	if not await _until(func(): return net.roster.size()==peers,15): return
	net.choose("medic",true)
	if not await _until(func(): return net.can_start(),10): return
	_check(net.roster.size()==peers,"real_peers_join_ready_lobby")
	net.configure_lobby("camp" if selected_mode=="woods" else "woods",42)
	_check(net.roster.values().all(func(entry): return not entry["ready"]),"changing_rules_clears_ready")
	net.configure_lobby(selected_mode,42)
	harness.advance.rpc("ready_check")
	net.choose("medic",true)
	if not await _reports(peers-1): return
	if not await _until(func(): return net.can_start(),5): return
	if capture:
		current_scene.last_refresh=0
		current_scene._process(0.1)
		await process_frame
		RenderingServer.force_draw(true)
		root.get_texture().get_image().save_png("res://artifacts/network/lobby_%s_%d.png"%[selected_mode,peers])
	_check(net.start_round(selected_mode,42),"host_starts_locked_seed")
	if not await _until(func(): return net.phase=="playing",15): return
	var level: Node2D=net.world
	for enemy: CampKiller in get_nodes_in_group("killers"): enemy.enabled=false
	_check(net.actors.size()==peers and get_nodes_in_group("survivors").size()==peers,"one_actor_per_peer")
	_check(level.plan.seed_value==42 and level.plan.expedition==(selected_mode=="woods"),"shared_seed_mode")
	_check(get_nodes_in_group("killers").size()==(49 if selected_mode=="woods" else 1),"current_monster_roster")
	var ids: Array=net.actors.keys()
	ids.sort()
	var guest: int=ids[1]
	harness.advance.rpc("movement",{"guest":guest})
	Input.action_press("move_right")
	await _until(func(): return net.actors[1].position.x>135,5)
	Input.action_release("move_right")
	if not await _reports(peers-1): return
	_check(net.actors[1].position.x>130 and net.actors[guest].position.y>410,"host_validates_both_players_movement")
	for report: Dictionary in harness.reports.values():
		_check(report.get("host_moved",false) and report.get("own_moved",false),"client_sees_remote_and_local_movement")
	if capture:
		await process_frame
		RenderingServer.force_draw(true)
		root.get_texture().get_image().save_png("res://artifacts/network/host_%s_%d.png"%[selected_mode,peers])
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
	if selected_mode=="woods":
		# The host owns the night clock; clients see the phase and the radio-revealed fuel cache.
		level.night_clock.skip_to(NightClock.PHASE_STARTS[1])
		harness.advance.rpc("night_phase")
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
	harness.advance.rpc("packet_gap",{"sequence":gap})
	# This channel is intentionally lossy: retry the same incomplete piece until observed.
	var gap_deadline := Time.get_ticks_msec()+4000
	while harness.reports.size()<peers-1 and Time.get_ticks_msec()<gap_deadline:
		net._snapshot_piece.rpc(net.round_id,gap,0,2,incomplete.slice(0,mini(900,incomplete.size()/2)))
		await create_timer(0.1).timeout
	if not await _reports(peers-1): return
	for report: Dictionary in harness.reports.values(): _check(report.get("partial_rejected",false),"partial_snapshot_never_applied")
	net.snapshot_clock=0
	harness.advance.rpc("packet_recovery",{"sequence":gap})
	if not await _reports(peers-1): return
	for report: Dictionary in harness.reports.values(): _check(report.get("recovered",false),"snapshot_recovers_after_missing_piece")
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
	_check(net.actors[guest].role=="mechanic" and net.roster[guest]["role"]=="mechanic","round_role_lock_rejects_forgery")
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
	await create_timer(2.6).timeout
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
	if not await _until(func(): return level.finished,12): return
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
	net.choose("medic",true)
	harness.advance.rpc("ready_again")
	if not await _until(func(): return net.can_start(),5): return
	_check(net.start_round(selected_mode,net.seed_value),"synchronized_same_seed_restart")
	if not await _until(func(): return net.phase=="playing",15): return
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
	harness.advance.rpc("host_loss")
	await create_timer(0.3).timeout
	net.leave("Host closed test camp.")
	await create_timer(0.5).timeout
	_check(not net.active and get_nodes_in_group("survivors").is_empty(),"host_leave_cleans_up")

func _client() -> void:
	current_scene.fields["Name"].text="Guest %d"%index
	current_scene.fields["Port"].text=str(port)
	current_scene.fields["Role"].select(1)
	current_scene.fields["Join"].pressed.emit()
	_check(net.active,"join_button_starts_connection")
	if not await _until(func(): return net.phase=="lobby",15): return
	net.choose("mechanic",true)
	if not await _until(func(): return harness.stage=="ready_check",10): return
	_check(net.mode==selected_mode and net.seed_value==42 and not net.roster[get_multiplayer().get_unique_id()]["ready"],"client_receives_changed_rules_and_unready")
	net.choose("mechanic",true)
	harness.report.rpc_id(1,"ready_check",{})
	if not await _until(func(): return net.phase=="playing",20): return
	_check(net.actors.size()==peers and get_nodes_in_group("survivors").size()==peers,"client_receives_exact_roster")
	_check(net.world.plan.seed_value==42 and not net.world.player.is_physics_processing(),"client_is_replica_with_shared_seed")
	var handled := ""
	while net.active:
		await process_frame
		if harness.stage==handled: continue
		handled=harness.stage
		var mine: int=get_multiplayer().get_unique_id()
		match handled:
			"movement":
				Input.action_press("move_down")
				await _until(func(): return net.world.player.position.y>415,5)
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
				var night_ok: bool=net.world.night_clock.phase==1 and net.world.night_clock.elapsed>=600 and fuel.available and fuel.visible and net.world.hud.title.text.contains("NIGHTFALL")
				if not night_ok: print(JSON.stringify({"event":"night_replica","phase":net.world.night_clock.phase,"elapsed":net.world.night_clock.elapsed,"fuel":fuel.available,"visible":fuel.visible,"title":net.world.hud.title.text}))
				harness.report.rpc_id(1,handled,{"night":night_ok})
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
				await _until(func(): return net.assembling_sequence>=harness.data["sequence"],5)
				harness.report.rpc_id(1,handled,{"partial_rejected":net.last_snapshot<harness.data["sequence"]})
			"packet_recovery":
				await _until(func(): return net.last_snapshot>harness.data["sequence"],5)
				harness.report.rpc_id(1,handled,{"recovered":net.last_snapshot>harness.data["sequence"]})
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
			"ready_again": net.choose("mechanic",true)
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
	net.join("127.0.0.1",port,"Late Guest","jock")
	if not await _until(func(): return not net.active,15): return
	_check(net.status_text.contains("already running") or net.status_text.contains("failed") or net.status_text.contains("timed out"),"late_join_refused")
func _reports(count: int) -> bool:
	return await _until(func(): return harness.reports.size()>=count,10)
func _until(predicate: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<until: await process_frame
	var ok: bool=predicate.call()
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
		if enemy is CampCryptid and enemy.species=="relay_jackal":
			probes.append(enemy)
			break
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
