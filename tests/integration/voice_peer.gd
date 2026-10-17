extends SceneTree
## Two real processes over ENet: each side streams synthetic speech (a 440 Hz tone
## through the real Opus encoder) via VoiceChat; the other side must decode it.
## No microphone is opened; capture uses VoiceChat.test_input.
var checks := 0
var failures := 0
var side := "host"
var port := 28311


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size() - 1):
		if args[index] == "--side":
			side = args[index + 1]
		elif args[index] == "--port":
			port = int(args[index + 1])
	var net: Node = root.get_node("Net")
	var voice: Node = root.get_node("Voice")
	voice.test_input = true
	voice.mode = "push"
	var error: Error = net.host(port, "VoiceHost", "jock") if side == "host" else net.join("127.0.0.1", port, "VoiceGuest", "medic")
	_check(error == OK, side + "_session_started")
	var joined := Time.get_ticks_msec()
	while net.roster.size() < 2 and Time.get_ticks_msec() - joined < 15000:
		await process_frame
	_check(net.roster.size() == 2, side + "_both_peers_registered")
	var other := 0
	for peer: int in net.roster:
		if peer != root.multiplayer.get_unique_id():
			other = peer
	# Speak for ~1.5 s: inject 20 ms of tone per frame while "holding" talk.
	voice.test_talk = true
	var phase := 0.0
	var rate := 44100
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 1500:
		var frames := PackedVector2Array()
		frames.resize(882)
		for index in range(frames.size()):
			var value := sin(phase) * 0.4
			phase += TAU * 440.0 / rate
			frames[index] = Vector2(value, value)
		voice.injected.append_array(frames)
		await create_timer(0.02).timeout
	voice.test_talk = false
	_check(voice.sent_packets >= 40, side + "_sent_%d_voice_packets" % voice.sent_packets)
	# Allow the peer's stream to arrive and decode.
	started = Time.get_ticks_msec()
	while voice.decoded_frames(other) < 30 * voice.FRAME and Time.get_ticks_msec() - started < 4000:
		await process_frame
	var decoded: int = voice.decoded_frames(other)
	_check(voice.received_packets >= 30 and decoded >= 30 * voice.FRAME, side + "_decoded_%d_frames_from_peer" % decoded)
	_check(voice.rejected_packets == 0, side + "_no_rejected_packets")
	print(JSON.stringify({"event": "voice_stats", "side": side, "sent": voice.sent_packets, "received": voice.received_packets, "decoded": decoded}))
	await create_timer(1.0).timeout
	await _round_checks(net, voice, other)
	# Let the other side finish before leaving.
	await create_timer(1.5).timeout
	print(JSON.stringify({"event": "test_result", "suite": "voice_peer_" + side, "checks": checks, "failures": failures}))
	net.leave("Voice test done.")
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


## In a real Quick Camp round: positional voice, range cut-off and ghost routing.
func _round_checks(net: Node, voice: Node, other: int) -> void:
	net.choose("jock" if side == "host" else "medic", true)
	var waited := Time.get_ticks_msec()
	if side == "host":
		while not net.can_start() and Time.get_ticks_msec() - waited < 10000:
			await process_frame
		_check(net.start_round("camp", 42), "host_starts_round_with_voice_session")
	waited = Time.get_ticks_msec()
	while (net.world == null or net.waiting) and Time.get_ticks_msec() - waited < 30000:
		await process_frame
	_check(net.world != null and not net.waiting, side + "_round_running")
	if side == "client":
		_check(voice.capturing, "client_mic_stays_live_in_round")
		await _talk(voice, 4.0)
		return
	var guest: CampPlayer = net.actors[other]
	var me: CampPlayer = net.actors[root.multiplayer.get_unique_id()]
	await create_timer(0.8).timeout
	var player: AudioStreamPlayer2D = voice.get_node("Voice%d" % other)
	_check(voice._route(other) == "proximity" and player.volume_db == 0.0 and player.global_position.distance_to(guest.global_position) < 1.0, "nearby_teammate_heard_from_their_position")
	guest.position = me.position + Vector2(VoiceChat.HEAR_RANGE + 200, 0)
	await create_timer(0.3).timeout
	_check(voice._route(other) == "none" and player.volume_db <= -79.0, "distant_teammate_silent")
	guest.position = me.position + Vector2(40, 0)
	guest.set_status(CampPlayer.Status.ESCAPED)
	await create_timer(0.3).timeout
	_check(voice._route(other) == "none", "living_cannot_hear_escaped_ghost")
	me.set_status(CampPlayer.Status.ESCAPED)
	await create_timer(0.3).timeout
	_check(voice._route(other) == "global" and player.volume_db == 0.0, "ghosts_hear_each_other")
	_check(voice.decoded_frames(other) > 70000, "round_voice_keeps_decoding_%d" % voice.decoded_frames(other))


func _talk(voice: Node, seconds: float) -> void:
	voice.test_talk = true
	var phase := 0.0
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < seconds * 1000:
		var frames := PackedVector2Array()
		frames.resize(882)
		for index in range(frames.size()):
			var value := sin(phase) * 0.4
			phase += TAU * 440.0 / 44100
			frames[index] = Vector2(value, value)
		voice.injected.append_array(frames)
		await create_timer(0.02).timeout
	voice.test_talk = false


func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": passed}))
