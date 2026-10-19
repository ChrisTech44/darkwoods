extends SceneTree
## Separate production server and real clients. No RPC endpoint enters the game.
class Probe extends Node:
	var stage := ""
	var data := {}
	var reports := {}
	@rpc("authority", "call_remote", "reliable", 0)
	func advance(value: String, payload: Dictionary = {}) -> void:
		stage = value
		data = payload
	@rpc("any_peer", "call_remote", "reliable", 0)
	func report(value: String, payload: Dictionary = {}) -> void:
		if value == stage: reports[multiplayer.get_remote_sender_id()] = payload

var probe: Probe
var net: Node
var side := OS.get_environment("LNAC_TEST_SIDE")
var port := int(OS.get_environment("LNAC_TEST_PORT"))
var humans := int(OS.get_environment("LNAC_TEST_PLAYERS"))
var index := int(OS.get_environment("LNAC_TEST_INDEX"))
var checks := 0
var failures := 0

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
	var initial := {}
	for id: int in ids: initial[id] = net.actors[id].position
	stage("move")
	if not await reports(humans): return
	for id: int in ids:
		check(net.actors[id].position.distance_to(initial[id]) > 10.0, "server_accepts_movement_" + str(id))
		check(probe.reports[id].get("moved", false), "client_receives_own_motion_" + str(id))
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
	check(net.actors.values().all(func(actor): return actor.inventory.is_empty() and actor.supplies.battery_pack == 2), "second_round_resets_inventory_and_role_once")
	if humans > 1:
		stage("leave_focus", {"peer":guest})
		if not await until(func(): return not net.actors.has(guest)): return
		check(net.active and net.world.player in net.actors.values(), "server_survives_first_client_departure")
	stage("leave_all")
	if not await until(func(): return net.roster.is_empty() and net.phase == "lobby"): return
	for frame in range(4): await process_frame
	check(net.active and net.world == null and get_nodes_in_group("survivors").is_empty(), "empty_server_cleans_up_and_keeps_listening")

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
	check(net.join("127.0.0.1", port, "Server guest %d" % index, "mechanic") == OK, "client_connects")
	if not await until(func(): return net.phase == "lobby"): return
	net.choose("mechanic", true)
	if not await until(func(): return net.phase == "playing"): return
	check(net.actors.size() == humans and not net.actors.has(1), "main_client_accepts_server_without_host_avatar")
	await capture("joined")
	var own: int = get_multiplayer().get_unique_id()
	var handled := ""
	while net.active:
		await process_frame
		if probe.stage == handled: continue
		handled = probe.stage
		match handled:
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
			"ready_again": net.choose("mechanic", true)
			"leave_focus":
				if own == probe.data.peer:
					net.leave()
					return
			"leave_all":
				if OS.get_environment("LNAC_TEST_SIMULTANEOUS") != "1":
					await create_timer(0.35 * index).timeout
				net.leave()
				return
