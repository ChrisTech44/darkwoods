extends SceneTree
## Real ENet processes. Host-only placements isolate contested authority/lifecycle checks.
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
	# A corpse must release carried objective objects exactly once.
	var before_death: int=level.pickups.size()
	var body: CampPlayer=net.actors[guest]
	var carried_before: int=body.inventory.size()+1
	body.inventory.append("fuse")
	body.set_status(CampPlayer.Status.DEAD)
	body.set_status(CampPlayer.Status.DEAD)
	_check(level.pickups.size()==before_death+carried_before and body.inventory.is_empty(),"death_releases_objectives_once")
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
	Input.action_press("interact")
	await create_timer(1.5).timeout
	Input.action_release("interact")
	_check(injured.status==CampPlayer.Status.ALIVE and level.player.supplies["medkit"]==0,"timed_host_revive_consumes_one_kit")
	_check(injured.supplies["battery_pack"]==2,"revive_does_not_refresh_role_supplies")
	for slot in range(ids.size()): net.actors[ids[slot]].position=Vector2(120+slot*16,400)
	harness.advance.rpc("drop")
	if not await _reports(peers-1): return
	_check(level.pickups.size()>level.plan.loot.size(),"dropped_items_replicate_as_host_objects")
	harness.advance.rpc("flare")
	if not await _reports(peers-1): return
	_check(not get_nodes_in_group("flares").is_empty(),"accepted_flare_spawned_on_host")
	for report: Dictionary in harness.reports.values(): _check(report.get("flare",false),"accepted_flare_visible_on_clients")
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
	harness.advance.rpc("board")
	net.action("interact")
	if not await _reports(peers-1): return
	_check(level.van.passengers.size()==peers,"all_survivors_board_shared_van")
	if not await _until(func(): return level.finished,12): return
	_check(level.won and net.actors.values().all(func(actor): return actor.status==CampPlayer.Status.ESCAPED),"shared_escape_results")
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
		var initial_items: int=net.world.pickups.size()
		harness.advance.rpc("guest_leave",{"departing":departing})
		if not await _until(func(): return not net.actors.has(departing),5): return
		_check(net.world.pickups.size()==initial_items+1 and net.roster.size()==peers-1,"disconnect_drops_objective_and_removes_actor")
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
				harness.report.rpc_id(1,handled,{"flare":not get_nodes_in_group("flares").is_empty()})
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
