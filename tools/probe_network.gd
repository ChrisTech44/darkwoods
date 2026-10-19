extends SceneTree
## Real ENet movement/timing probe. Uses an isolated server and no microphones.
## Host on headless-server using -- --dedicated-server --port <spare port>.
## Client: LNAC_PROBE_HOST=<host> LNAC_PROBE_PORT=<port> godot ... --script <this>.
var net: Node
var server := "--dedicated-server" in OS.get_cmdline_user_args()
var frame_times: Array[float] = []
var physics_times: Array[float] = []
var net_times: Array[float] = []
var snapshot_gaps: Array[float] = []
var snapshot_sizes: Array[float] = []
var motion_gaps: Array[float] = []
var motion_sizes: Array[float] = []
var last_motion := 0
var last_motion_arrival := 0
var responses: Array[float] = []
var rtts: Array[float] = []
var last_frame := 0
var last_physics := 0
var last_snapshot := 0
var last_arrival := 0
var snapshots := 0
var skipped_snapshots := 0
var largest_step := 0.0
var previous := Vector2.ZERO
var tracked := false
var measuring := false
var waiting_response := false
var response_start := 0
var response_origin := Vector2.ZERO
var response_direction := Vector2.ZERO
var response_timeouts := 0
var last_rtt := 0
var loss_scaled := 0.0

func _initialize() -> void:
	if not server and DisplayServer.get_name() == "headless":
		node_added.connect(func(node: Node):
			if node is Node2D and node.get_script() != null and node.get_script().resource_path == "res://scripts/world/forest_level.gd": node.hide())
	run.call_deferred()

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"count":0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in values: total += value
	return {"count":values.size(), "mean":total/values.size(), "p50":sorted[int((sorted.size()-1)*0.5)], "p95":sorted[int((sorted.size()-1)*0.95)], "p99":sorted[int((sorted.size()-1)*0.99)], "max":sorted.back()}

func sample_frame() -> void:
	var now := Time.get_ticks_usec()
	if not measuring:
		last_frame = now
		return
	if last_frame: frame_times.append((now-last_frame)/1000.0)
	last_frame = now
	if server: return
	if net.last_snapshot != last_snapshot:
		if last_snapshot:
			snapshot_gaps.append((now-last_arrival)/1000.0)
			skipped_snapshots += maxi(0, net.last_snapshot-last_snapshot-1)
		last_snapshot = net.last_snapshot
		last_arrival = now
		snapshots += 1
		snapshot_sizes.append(float(net.latest_snapshot_bytes))
	if "last_motion_sequence" in net and net.last_motion_sequence != last_motion:
		if last_motion: motion_gaps.append((now-last_motion_arrival)/1000.0)
		last_motion = net.last_motion_sequence
		last_motion_arrival = now
		motion_sizes.append(float(net.latest_motion_bytes))
	var own: int = get_multiplayer().get_unique_id()
	if net.actors.has(own):
		var at: Vector2 = net.actors[own].position
		if tracked: largest_step = maxf(largest_step, at.distance_to(previous))
		previous = at
		tracked = true
		if waiting_response and (at-response_origin).dot(response_direction) > 2.0:
			responses.append((now-response_start)/1000.0)
			waiting_response = false
	if now-last_rtt >= 1000000 and net.active:
		last_rtt = now
		var peer: ENetPacketPeer = get_multiplayer().multiplayer_peer.get_peer(1)
		rtts.append(peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
		loss_scaled = peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)

func sample_physics() -> void:
	var now := Time.get_ticks_usec()
	if measuring and last_physics: physics_times.append((now-last_physics)/1000.0)
	last_physics = now
	if server:
		# Wrap the existing Net tick once per physics frame, retaining its logic.
		var started := Time.get_ticks_usec()
		net._physics_process(1.0/Engine.physics_ticks_per_second)
		if measuring: net_times.append((Time.get_ticks_usec()-started)/1000.0)

func run() -> void:
	net = root.get_node("Net")
	root.get_node("Voice").mode = "off"
	if server: net.set_physics_process(false)
	process_frame.connect(sample_frame)
	physics_frame.connect(sample_physics)
	if not server:
		change_scene_to_file("res://scenes/ui/network_lobby.tscn")
		while current_scene == null: await process_frame
		var error: Error = net.join(OS.get_environment("LNAC_PROBE_HOST"), int(OS.get_environment("LNAC_PROBE_PORT")), "Movement probe", "christian")
		if error != OK:
			print(JSON.stringify({"event":"probe_error", "error":error}))
			quit(1)
			return
	var timeout := Time.get_ticks_msec()+110000
	var ready := false
	while net.phase != "playing" and Time.get_ticks_msec() < timeout:
		if not server and net.phase == "lobby" and not ready:
			ready = true
			net.choose("christian", true)
		if not server and not net.active: break
		await process_frame
	if net.phase != "playing":
		print(JSON.stringify({"event":"probe_error", "phase":net.phase, "status":net.status_text}))
		quit(1)
		return
	await create_timer(2.0).timeout
	measuring = true
	last_physics = 0
	last_frame = 0
	print(JSON.stringify({"event":"probe_measuring", "side":"server" if server else "client", "ai_frozen":false, "headless_replica_hidden":not server and DisplayServer.get_name()=="headless"}))
	if server:
		await create_timer(38.0).timeout
	else:
		for cycle in range(24):
			var action := "move_down" if cycle%2 == 0 else "move_up"
			var own: int = get_multiplayer().get_unique_id()
			if net.phase != "playing" or not net.actors.has(own): break
			waiting_response = true
			response_start = Time.get_ticks_usec()
			response_origin = net.actors[own].position
			response_direction = Vector2.DOWN if cycle%2 == 0 else Vector2.UP
			Input.action_press(action)
			await create_timer(0.45).timeout
			Input.action_release(action)
			await create_timer(0.55).timeout
			if waiting_response: response_timeouts += 1
			waiting_response = false
	measuring = false
	if not server and DisplayServer.get_name() != "headless" and not OS.get_environment("LNAC_PROBE_CAPTURE").is_empty():
		for frame in range(4): await process_frame
		RenderingServer.force_draw(true)
		var result := root.get_texture().get_image().save_png(OS.get_environment("LNAC_PROBE_CAPTURE"))
		print(JSON.stringify({"event":"probe_capture", "error":result}))
	var summary := {"event":"network_probe_result", "side":"server" if server else "client", "frame_interval_ms":stats(frame_times), "physics_interval_ms":stats(physics_times), "network_tick_ms":stats(net_times), "snapshot_gap_ms":stats(snapshot_gaps), "snapshot_bytes":stats(snapshot_sizes), "motion_gap_ms":stats(motion_gaps), "motion_bytes":stats(motion_sizes), "movement_response_ms":stats(responses), "movement_response_timeouts":response_timeouts, "rtt_ms":stats(rtts), "enet_packet_loss_scaled":loss_scaled, "enet_packet_loss_scale":ENetPacketPeer.PACKET_LOSS_SCALE, "snapshots":snapshots, "skipped_snapshot_sequences":skipped_snapshots, "largest_render_step_pixels":largest_step}
	if not server and "prediction" in net:
		summary["prediction"] = {"corrections":net.prediction.corrections, "largest_correction_pixels":net.prediction.largest_correction, "history_size":net.prediction.history.size()}
	print(JSON.stringify(summary))
	if server:
		get_multiplayer().multiplayer_peer.close()
		net.active = false
	else:
		var leave_delay := OS.get_environment("LNAC_PROBE_LEAVE_DELAY").to_float()
		if leave_delay > 0.0: await create_timer(leave_delay).timeout
		if net.active: net.leave()
		for frame in range(8): await process_frame
	await root.get_node("AudioManager").prepare_shutdown()
	quit()
