extends SceneTree
## Separate production server and real clients. No RPC endpoint enters the game.
class Probe extends Node:
	var stage := ""
	var data := {}
	var reports := {}
	var relay_seen := {}
	@rpc("authority", "call_remote", "reliable", 0)
	func advance(value: String, payload: Dictionary = {}) -> void:
		stage = value
		data = payload
	@rpc("any_peer", "call_remote", "reliable", 0)
	func report(value: String, payload: Dictionary = {}) -> void:
		if value == stage: reports[multiplayer.get_remote_sender_id()] = payload

	@rpc("any_peer","call_remote","unreliable_ordered",3)
	func relay_probe() -> void:
		relay_seen[multiplayer.get_remote_sender_id()]=true

var probe: Probe
var net: Node
var side := OS.get_environment("LNAC_TEST_SIDE")
var port := int(OS.get_environment("LNAC_TEST_PORT"))
var humans := int(OS.get_environment("LNAC_TEST_PLAYERS"))
var index := int(OS.get_environment("LNAC_TEST_INDEX"))
var checks := 0
var failures := 0
var role: String = SurvivorRoster.IDS[index % 4]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(JSON.stringify({"event":"assertion", "name":label, "passed":ok}))

func until(predicate: Callable, seconds: float = 90.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < end: await process_frame
	var ok: bool = predicate.call()
	if not ok: print(JSON.stringify({"event":"dedicated_wait_failure", "phase":net.phase, "status":net.status_text, "loaded":net.loaded.keys(), "participants":net.participants.keys()}))
	check(ok, "wait_" + side + "_" + probe.stage)
	return ok

func stage(value: String, payload: Dictionary = {}) -> void:
	probe.stage = value
	probe.data = payload
	probe.reports.clear()
	print(JSON.stringify({"event":"test_stage_sending", "stage":value}))
	probe.advance.rpc(value, payload)
	print(JSON.stringify({"event":"test_stage_sent", "stage":value}))

func reports(count: int) -> bool:
	return await until(func(): return probe.reports.size() == count, 30)

func run() -> void:
	net = root.get_node("Net")
	if side == "client" and DisplayServer.get_name() == "headless":
		node_added.connect(func(node: Node):
			if node is Node2D and node.get_script() != null and node.get_script().resource_path == "res://scripts/world/forest_level.gd":
				node.hide()) # Headless replica fixture suppresses scenery drawing only.
	net.changed.connect(func(): print(JSON.stringify({"event":"probe_net_state", "side":side, "phase":net.phase, "status":net.status_text, "active":net.active})))
	probe = Probe.new()
	probe.name = "DedicatedTestProbe"
	root.add_child(probe)
	if side == "server": await server()
	else: await client()
	print(JSON.stringify({"event":"test_result", "suite":"dedicated_" + side, "checks":checks, "failures":failures, "players":humans}))
	for frame in range(8): await process_frame
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)

func server() -> void:
	if humans>1:
		if not await until(func(): return net.phase=="lobby" and net.roster.size()==humans): return
		# Deterministically reproduce join-order vs random-peer-ID disagreement.
		var order: Array=net.roster.keys()
		order.sort()
		order.reverse()
		var reversed_roster := {}
		for id: int in order: reversed_roster[id]=net.roster[id]
		net.roster=reversed_roster
		check(net.roster.keys()[0]!=net.roster.keys().min(),"fixture_join_order_differs_from_reference_peer_order")
	if not await until(func(): return net.phase == "playing"): return
	check(net.dedicated and not net.actors.has(1) and not net.roster.has(1), "server_has_no_survivor_or_slot")
	check(net.actors.size() == humans and get_nodes_in_group("survivors").size() == humans, "all_human_clients_have_exactly_one_actor")
	check(not root.get_node("Voice").available and not root.get_node("Voice").capturing and not root.get_node("Voice").is_processing(), "server_initializes_no_voice_codec_or_capture")
	check(not root.get_node("AudioManager").output_enabled and net.world.soundscape.loops.is_empty(), "server_has_no_audio_playback")
	check(net.world.player in net.actors.values() and net.world.hud.process_mode == Node.PROCESS_MODE_DISABLED, "server_focus_is_a_real_client_and_hud_disabled")
	var level: Node = net.world
	for enemy in get_nodes_in_group("killers"): enemy.enabled = false
	level.night_clock.director_enabled = false
	var ids: Array = net.actors.keys()
	ids.sort()
	if level.plan.expedition:
		var explorer: int = ids.back() # A different human from the server reference player.
		for actor: CampPlayer in net.actors.values(): actor.position = Vector2(120,400)
		net.actors[explorer].position = level.plan.woods.center(WoodsLayout.ENTRY) + Vector2.LEFT * 70
		stage("explore_ready",{"explorer":explorer,"entry":WoodsLayout.ENTRY,"next":WoodsLayout.ENTRY+Vector2i.LEFT})
		if not await reports(humans): return
		check(level.plan.woods.visited.has(WoodsLayout.ENTRY),"dedicated_discovers_non_reference_human_travel")
		stage("explore_walk",{"explorer":explorer,"entry":WoodsLayout.ENTRY,"next":WoodsLayout.ENTRY+Vector2i.LEFT})
		if not await reports(humans): return
		for id: int in ids: check(probe.reports[id].get("explored",false),"all_clients_receive_team_trail_progress_"+str(id))
		for actor: CampPlayer in net.actors.values(): actor.position = Vector2(120,400)
	var initial := {}
	for id: int in ids: initial[id] = net.actors[id].position
	stage("move")
	if not await reports(humans): return
	for id: int in ids:
		check(net.actors[id].position.distance_to(initial[id]) > 10.0, "server_accepts_movement_" + str(id))
		check(probe.reports[id].get("moved", false), "client_receives_own_motion_" + str(id))
	stage("relay")
	if not await reports(humans): return
	check(probe.relay_seen.size()==humans,"dedicated_receives_synthetic_voice_channel_packets")
	for row: Dictionary in probe.reports.values(): check(row.get("heard",0)==humans-1,"client_to_client_voice_channel_relay_preserves_peer_ids")
	await ability_checks(ids)
	var guest: int = ids[0]
	if level.plan.expedition:
		check(level.plan.escape_options == ["van", "boat"], "normal_boat_night_without_all_escape_override")
		var actor: CampPlayer = net.actors[guest]
		actor.inventory.assign(FieldEscapes.BOAT_PARTS)
		for pickup: CampPickup in level.pickups:
			if pickup.kind in FieldEscapes.BOAT_PARTS: pickup.consume()
		actor.position = level.escapes.boat_point
		stage("fit", {"operator":guest})
		if not await reports(humans): return
		check(level.escapes.boat_installed.size() == 3 and actor.inventory.is_empty(), "remote_installs_normal_night_boat_authoritatively")
		for id: int in ids: net.actors[id].position = level.escapes.boat_point
		stage("launch", {"operator":guest})
		if not await reports(humans): return
		check(level.escapes.boat_started, "remote_starts_launch")
		level.escapes.advance(26.0)
	else:
		var actor: CampPlayer = net.actors[guest]
		actor.inventory.assign(level.plan.required)
		actor.position = level.van.interaction_point()
		stage("van_fit", {"operator":guest})
		if not await reports(humans): return
		check(level.van.installed.size() == level.plan.required.size(), "remote_installs_van_authoritatively")
		for id: int in ids: net.actors[id].set_status(CampPlayer.Status.DOWNED)
		actor.set_status(CampPlayer.Status.ALIVE)
		actor.position = level.van.interaction_point()
		level.van.advance_start(actor, true, 3.0)
		level.van.board(actor)
		level.van.remaining = 0.0
		level._physics_process(0.02)
	if not await until(func(): return net.phase == "results"): return
	stage("result")
	if not await reports(humans): return
	check(level.won and net.actors.values().all(func(actor): return actor.status == CampPlayer.Status.ESCAPED), "all_connected_survivors_escape")
	for row: Dictionary in probe.reports.values(): check(row.get("won", false), "client_matches_server_result")
	var previous: WeakRef = weakref(level)
	if not await until(func(): return net.phase == "lobby"): return
	check(net.world == null and previous.get_ref() == null and get_nodes_in_group("survivors").is_empty(), "automatic_lobby_frees_world_and_actors")
	check(net.roster.values().all(func(row): return not row.ready), "automatic_lobby_clears_readiness")
	stage("ready_again")
	if not await until(func(): return net.round_id == 2 and net.phase == "playing"): return
	for enemy in get_nodes_in_group("killers"): enemy.enabled = false
	check(net.actors.size() == humans and not net.actors.has(1), "second_round_has_only_humans")
	check(net.actors.values().all(func(actor): return actor.inventory.is_empty() and actor.supplies.battery_pack == 1), "second_round_resets_inventory_and_role_once")
	if humans > 1:
		stage("leave_focus", {"peer":guest})
		if not await until(func(): return not net.actors.has(guest)): return
		check(net.active and net.world.player in net.actors.values(), "server_survives_first_client_departure")
	stage("leave_all")
	if not await until(func(): return net.roster.is_empty() and net.phase == "lobby"): return
	for frame in range(4): await process_frame
	check(net.active and net.world == null and get_nodes_in_group("survivors").is_empty(), "empty_server_cleans_up_and_keeps_listening")
	var transport: CampENetPeer=net.get_multiplayer().multiplayer_peer
	check(transport.is_server_relay_supported(),"server_retains_native_relay_capability")
	print(JSON.stringify({"event":"transport_diagnostics","closing_packets_dropped":transport.dropped_closing_packets,"relay":transport.is_server_relay_supported()}))

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(1.0).timeout
	for frame in range(4): await process_frame
	RenderingServer.force_draw(true)
	var folder := OS.get_environment("LNAC_TEST_CAPTURE_DIR")
	check(root.get_texture().get_image().save_png(folder + "/client_" + str(index) + "_" + label + ".png") == OK, "capture_" + label)

func client() -> void:
	change_scene_to_file("res://scenes/ui/network_lobby.tscn")
	while current_scene == null: await process_frame
	root.get_node("Voice").mode = "off" # In-memory only; never alter player preferences.
	var address := OS.get_environment("LNAC_TEST_HOST")
	if address.is_empty(): address = "127.0.0.1"
	check(net.join(address, port, "Server guest %d" % index, role) == OK, "client_connects")
	if not await until(func(): return net.phase == "lobby"): return
	net.choose(role, true)
	if not await until(func(): return net.phase == "playing"): return
	check(net.actors.size() == humans and not net.actors.has(1), "main_client_accepts_server_without_host_avatar")
	await capture("joined")
	var own: int = get_multiplayer().get_unique_id()
	check(net.actors[own].role==role,"client_keeps_requested_character")
	var handled := ""
	while net.active:
		await process_frame
		if probe.stage == handled: continue
		handled = probe.stage
		match handled:
			"relay":
				for repeat in range(8):
					probe.relay_probe.rpc()
					await create_timer(0.03).timeout
				await until(func(): return probe.relay_seen.size()==humans-1,10)
				probe.report.rpc_id(1,handled,{"heard":probe.relay_seen.size()})
			"explore_ready":
				await until(func(): return net.world.plan.woods.visited.has(probe.data.entry))
				probe.report.rpc_id(1,handled,{})
			"explore_walk":
				if own == probe.data.explorer:
					Input.action_press("move_left")
					await create_timer(0.85).timeout
					Input.action_release("move_left")
				await until(func(): return net.world.plan.woods.visited.has(probe.data.next))
				probe.report.rpc_id(1,handled,{"explored":net.world.plan.woods.visited.has(probe.data.entry) and net.world.plan.woods.visited.has(probe.data.next) and not net.world.plan.woods.visited.has(Vector2i.ZERO)})
			"sample_shot":
				var caster: CampPlayer=net.actors[probe.data.caster]
				var victim: CampPlayer=net.actors[probe.data.victim]
				await create_timer(0.4).timeout
				if own==probe.data.caster: net.action("ability")
				var travelled: bool=await until(func(): return caster.kit.get("cast",{}).get("projectile",false),10)
				await until(func(): return victim.has_effect("backwards"),10)
				probe.report.rpc_id(1,handled,{"flight":travelled,"hit":victim.has_effect("backwards"),"cue":net.world.soundscape.played_counts.get("witch_cackle",0)>0})
			"sample_song":
				await create_timer(0.4).timeout
				if own==probe.data.caster: net.action("ability")
				var key: String="sample_song:%d" % net.actors[probe.data.caster].get_instance_id()
				await until(func(): return net.world.soundscape.follow_loops.has(key),10)
				probe.report.rpc_id(1,handled,{"song":net.world.soundscape.follow_loops.has(key)})
			"sample_stop":
				var key: String="sample_song:%d" % net.actors[probe.data.caster].get_instance_id()
				await until(func(): return not net.world.soundscape.follow_loops.has(key),10)
				probe.report.rpc_id(1,handled,{"stopped":not net.world.soundscape.follow_loops.has(key)})
			"max_cancel":
				await create_timer(0.4).timeout
				if own==probe.data.owner:
					net.action("ability")
					await until(func(): return net.actors[own].kit.stake_time>=0,10)
					var escape := InputEventAction.new()
					escape.action="pause"
					escape.pressed=true
					net.handle_input(escape)
					await until(func(): return net.actors[own].kit.stake_time<0,10)
					net.handle_input(escape)
				await until(func(): return net.actors[probe.data.owner].kit.stake_time<0,10)
				probe.report.rpc_id(1,handled,{"cancelled":net.actors[probe.data.owner].kit.stake_time<0,"cash":net.actors[probe.data.owner].kit.cash})
			"move":
				var start: Vector2 = net.actors[own].position
				Input.action_press("move_down")
				await create_timer(0.65).timeout
				Input.action_release("move_down")
				await until(func(): return net.actors[own].position.distance_to(start) > 10.0, 10)
				probe.report.rpc_id(1, handled, {"moved":net.actors[own].position.distance_to(start) > 10.0})
			"fit", "launch", "van_fit":
				await create_timer(0.5).timeout
				if own == probe.data.operator: net.action("interact")
				var accepted := func() -> bool:
					if net.world == null: return false
					if handled == "fit": return net.world.escapes.boat_installed.size() == 3
					if handled == "launch": return net.world.escapes.boat_started
					return net.world.van.installed.size() == net.world.plan.required.size()
				await until(accepted, 10)
				if handled == "fit": await capture("boat_fitted")
				probe.report.rpc_id(1, handled, {"accepted":accepted.call()})
			"result":
				await until(func(): return net.phase == "results", 10)
				probe.report.rpc_id(1, handled, {"won":net.world.won})
			"ready_again": net.choose(role, true)
			"leave_focus":
				if own == probe.data.peer:
					net.leave()
					return
			"leave_all":
				if OS.get_environment("LNAC_TEST_SIMULTANEOUS") != "1":
					await create_timer(0.35 * index).timeout
				net.leave()
				return

func ability_checks(ids: Array) -> void:
	for id: int in ids: check(net.actors[id].role==net.participants[id].role,"dedicated_preserves_requested_role_"+str(id))
	var casters: Array=ids.filter(func(id): return net.actors[id].role=="christian")
	check(not casters.is_empty(),"dedicated_roster_contains_requested_christian")
	if casters.is_empty() or ids.size()<2: return
	var caster: CampPlayer=net.actors[casters[0]]
	var victim_id: int=ids.filter(func(id): return id!=casters[0])[0]
	var victim: CampPlayer=net.actors[victim_id]
	for id: int in ids: net.actors[id].position=Vector2(700,700)
	var origin := Vector2.ZERO
	for y in range(350,800,24):
		for x in range(120,1400,24):
			var point := Vector2(x,y)
			if SurvivorKits.safe_point(caster,point) and SurvivorKits.safe_point(victim,point+Vector2(85,0)) and net.world.clear_path(point,point+Vector2(85,0)):
				origin=point
				break
		if origin!=Vector2.ZERO: break
	check(origin!=Vector2.ZERO,"dedicated_spell_fixture_has_real_clear_collision_path")
	for i in range(ids.size()):
		if ids[i] not in [casters[0],victim_id]: net.actors[ids[i]].position=origin+Vector2(0,60+20*i)
	caster.position=origin
	caster.facing=Vector2.RIGHT
	victim.position=origin+Vector2(85,0)
	caster.kit.sample="witch"
	caster.kit.subtype="backwards"
	caster.ability_cooldown=0
	stage("sample_shot",{"caster":casters[0],"victim":victim_id})
	if not await reports(humans): return
	check(victim.has_effect("backwards"),"dedicated_projectile_applies_authoritative_curse")
	for row: Dictionary in probe.reports.values(): check(row.get("flight",false) and row.get("hit",false) and row.get("cue",false),"all_clients_render_shot_hit_and_audio")
	victim.clear_effect("backwards")
	CreatureSamples.finish_cast(caster)
	caster.kit.sample="boiler_saint"
	caster.add_effect("coffee",10)
	caster.ability_cooldown=0
	stage("sample_song",{"caster":casters[0]})
	if not await reports(humans): return
	for row: Dictionary in probe.reports.values(): check(row.get("song",false),"dedicated_copied_song_reaches_each_client")
	CreatureSamples.finish_cast(caster)
	stage("sample_stop",{"caster":casters[0]})
	if not await reports(humans): return
	for row: Dictionary in probe.reports.values(): check(row.get("stopped",false),"dedicated_copied_song_stops_on_each_client")
	for id: int in ids:
		net.actors[id].effects.clear()
		if net.actors[id].role=="max":
			net.actors[id].ability_cooldown=0
			stage("max_cancel",{"owner":id})
			if not await reports(humans): return
			check(net.actors[id].kit.stake_time<0 and net.actors[id].kit.cash==6,"dedicated_menu_cancels_stake_without_charge")
