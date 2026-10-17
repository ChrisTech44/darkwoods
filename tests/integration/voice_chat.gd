extends SceneTree
## Proximity voice without a network: Opus encode/decode through VoiceChat's real
## packet path, routing rules, packet limits, push-to-talk binding and settings.
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var voice: Node = root.get_node("Voice")
	_check(voice.available and ClassDB.class_exists("TwovoipOpusEncoder"), "twovoip_extension_loaded")
	_check(InputMap.has_action("push_to_talk") and InputMap.action_get_events("push_to_talk").any(func(event: InputEvent) -> bool: return event is InputEventKey and event.physical_keycode == KEY_B), "push_to_talk_bound_to_b")
	var saved_mode: String = voice.mode
	_check(saved_mode in ["off", "push", "open"], "voice_mode_valid_default_%s" % saved_mode)
	await _codec_checks(voice)
	_routing_checks()
	_limit_checks(voice)
	voice.set_mode("push")
	var stored := ConfigFile.new()
	_check(stored.load(voice.SETTINGS_PATH) == OK and stored.get_value("voice", "mode") == "push", "voice_mode_persists")
	var engine := ConfigFile.new()
	_check(engine.load(voice.ENGINE_OVERRIDES) == OK and engine.get_value("audio", "driver/enable_input") == true, "voice_on_requests_mic_next_launch")
	_check(not bool(ProjectSettings.get_setting("audio/driver/enable_input", false)) or voice.mic_ready, "mic_not_opened_by_default_project")
	voice.set_mode("off")
	engine.load(voice.ENGINE_OVERRIDES)
	_check(engine.get_value("audio", "driver/enable_input") == false, "voice_off_releases_mic_next_launch")
	voice.set_mode(saved_mode)
	_check(voice.status_text() != "" and not voice.capturing, "no_capture_outside_session")
	print(JSON.stringify({"event": "test_result", "suite": "voice_chat", "checks": checks, "failures": failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


## Sine "speech" through a real Opus encoder, decoded by VoiceChat's speaker path.
func _codec_checks(voice: Node) -> void:
	var encoder: Object = ClassDB.instantiate("TwovoipOpusEncoder")
	var rate := 44100
	_check(encoder.initialize(rate, voice.OPUS_RATE, 1, 0, 0, voice.FRAME) == OK and encoder.create_opus_encoder(voice.BITRATE, 5, true), "encoder_initializes_mono_48k")
	var need: int = encoder.get_required_input_chunk_size()
	var packets: Array[PackedByteArray] = []
	var phase := 0.0
	for chunk in range(25):
		var frames := PackedVector2Array()
		frames.resize(need)
		for index in range(need):
			var value := sin(phase) * 0.5
			phase += TAU * 440.0 / rate
			frames[index] = Vector2(value, value)
		if encoder.process_chunk(frames) > 0:
			packets.append(encoder.encode_chunk())
	var sizes := packets.map(func(packet: PackedByteArray) -> int: return packet.size())
	_check(packets.size() >= 20 and sizes.max() <= voice.MAX_PACKET and sizes.min() > 0, "opus_packets_small_%d_to_%d_bytes" % [sizes.min(), sizes.max()])
	var accepted := 0
	for index in range(packets.size()):
		if voice.accept_packet(77, 5, index, packets[index]):
			accepted += 1
	_check(accepted == packets.size(), "speaker_accepts_ordered_stream")
	var decoded: int = voice.decoded_frames(77)
	_check(decoded >= (packets.size() - voice.JITTER_PACKETS) * voice.FRAME, "decoded_%d_frames_of_speech" % decoded)
	_check(not voice.accept_packet(77, 5, 3, packets[3]), "late_packet_dropped")
	_check(voice.accept_packet(77, 5, packets.size() + 1, packets[0]) and voice.decoded_frames(77) > decoded, "single_loss_recovered_with_fec")


func _routing_checks() -> void:
	var alive := CampPlayer.Status.ALIVE
	var near := Vector2(200, 0)
	var far := Vector2(VoiceChat.HEAR_RANGE + 50, 0)
	_check(VoiceChat.route_for(alive, Vector2.ZERO, alive, near) == "proximity", "living_hear_nearby_living")
	_check(VoiceChat.route_for(alive, Vector2.ZERO, alive, far) == "none", "living_out_of_range_silent")
	_check(VoiceChat.route_for(alive, Vector2.ZERO, CampPlayer.Status.DOWNED, near) == "proximity", "downed_still_heard_nearby")
	_check(VoiceChat.route_for(alive, Vector2.ZERO, CampPlayer.Status.BOARDED, near) == "proximity", "boarded_heard_nearby")
	_check(VoiceChat.route_for(alive, Vector2.ZERO, CampPlayer.Status.ESCAPED, near) == "none", "living_never_hear_ghosts")
	_check(VoiceChat.route_for(CampPlayer.Status.LEFT_BEHIND, Vector2.ZERO, CampPlayer.Status.DEAD, far * 9) == "global", "ghosts_share_channel")
	_check(VoiceChat.route_for(CampPlayer.Status.ESCAPED, Vector2.ZERO, alive, near) == "proximity", "ghost_listens_to_living_by_position")


func _limit_checks(voice: Node) -> void:
	var big := PackedByteArray()
	big.resize(voice.MAX_PACKET + 1)
	_check(not voice.accept_packet(91, 1, 0, big), "oversized_packet_rejected")
	_check(not voice.accept_packet(91, 1, 1, PackedByteArray()), "empty_packet_rejected")
	var tiny := PackedByteArray([8, 1, 2, 3])
	var rejected_before: int = voice.rejected_packets
	for index in range(voice.PACKET_BUDGET + 20):
		voice.accept_packet(92, 1, index, tiny)
	_check(voice.rejected_packets - rejected_before >= 20, "per_peer_packet_budget_enforced")


func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": passed}))
