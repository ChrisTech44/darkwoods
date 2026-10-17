class_name VoiceChat
extends Node
## Opt-in proximity voice over the co-op session, using TwoVoIP (Opus) when the
## GDExtension is present. Off by default; push-to-talk (B) or open mic.
##
## Routing: in the lobby everyone hears everyone. In a round, living/downed/boarded
## survivors hear each other positionally (fading to silence at HEAR_RANGE and
## muffled behind walls). Escaped, dead and left-behind players share a ghost
## channel the living never hear, so spectators cannot pass information.
## Voice never reaches monster AI. Packets travel on their own unreliable ENet
## channel through the host relay, are size- and rate-limited, never recorded.

const SETTINGS_PATH := "user://voice_settings.cfg"
## Read by the engine at startup (project setting project_settings_override).
## The microphone is only initialised for players who turned voice on, because
## macOS asks for (and waits on) microphone permission when input starts.
const ENGINE_OVERRIDES := "user://engine_overrides.cfg"
## Loaded here at runtime, never by the editor: TwoVoIP's Linux and Windows
## libraries crash the Godot editor (and so the headless import) on load, so
## addons/twovoip carries a .gdignore and stays out of extension_list.cfg.
const EXTENSION := "res://addons/twovoip/twovoip.gdextension"
const MODES: Array[String] = ["off", "push", "open"]
const OPUS_RATE := 48000
const FRAME := 960
const BITRATE := 24000
const MAX_PACKET := 400
const PACKET_BUDGET := 75
const JITTER_PACKETS := 3
const STREAM_GAP := 0.35
const HEAR_RANGE := 560.0
## Gentle distance fade (1.0 = linear); speech stays clear across a clearing.
const VOICE_ATTENUATION := 0.6
## Walls and tree lines soften a voice rather than smother it.
const MUFFLE_CUTOFF := 2400.0
## While a teammate talks, music and ambience dip (dB) so speech cuts through.
const DUCK_MUSIC_DB := -10.0
const DUCK_AMBIENCE_DB := -8.0
const DUCK_EFFECTS_DB := -3.0
const OPEN_HANG := 0.6
const CHANNEL := 3

var available := false
## True when the audio driver started with microphone input this launch.
var mic_ready := false
var mode := "off"
var mic_gain := 1.0
var threshold := 0.04
var capturing := false
var talking := false
var mic_level := 0.0
var stream_id := 0
var sequence := 0
var sent_packets := 0
var received_packets := 0
var rejected_packets := 0
## Tests feed synthetic frames instead of the microphone.
var test_input := false
var test_talk := false
var injected := PackedVector2Array()
var _encoder: Object
var _pending := PackedVector2Array()
var _hang := 0.0
var _speakers: Dictionary = {}
var _budget: Dictionary = {}


func _ready() -> void:
	if not ClassDB.class_exists("TwovoipOpusEncoder") and FileAccess.file_exists(EXTENSION):
		GDExtensionManager.load_extension(EXTENSION)
	available =ClassDB.class_exists("TwovoipOpusEncoder") and ClassDB.class_exists("AudioStreamOpus")
	mic_ready = bool(ProjectSettings.get_setting("audio/driver/enable_input", false))
	if not InputMap.has_action("push_to_talk"):
		InputMap.add_action("push_to_talk")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_B
		InputMap.action_add_event("push_to_talk", key)
	if AudioServer.get_bus_index("VoiceMuffled") < 0:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, "VoiceMuffled")
		AudioServer.set_bus_send(index, "Voice")
		var lowpass := AudioEffectLowPassFilter.new()
		lowpass.cutoff_hz = MUFFLE_CUTOFF
		AudioServer.add_bus_effect(index, lowpass)
	# Level every voice: quiet microphones are lifted and loud ones held back,
	# so a soft-spoken teammate is as easy to hear as a loud one.
	var voice_bus := AudioServer.get_bus_index("Voice")
	if voice_bus >= 0 and AudioServer.get_bus_effect_count(voice_bus) == 0:
		var leveller := AudioEffectCompressor.new()
		leveller.threshold = -30.0
		leveller.ratio = 4.0
		leveller.gain = 12.0
		leveller.attack_us = 2000.0
		leveller.release_ms = 250.0
		AudioServer.add_bus_effect(voice_bus, leveller)
		var ceiling := AudioEffectLimiter.new()
		ceiling.ceiling_db = -1.5
		AudioServer.add_bus_effect(voice_bus, ceiling)
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		var stored: String = str(settings.get_value("voice", "mode", "off"))
		mode = stored if stored in MODES else "off"
		mic_gain = clampf(float(settings.get_value("voice", "mic_gain", 1.0)), 0.25, 4.0)
		threshold = clampf(float(settings.get_value("voice", "threshold", 0.04)), 0.005, 0.3)


func set_mode(value: String) -> void:
	if value not in MODES:
		return
	mode = value
	_save()
	var overrides := ConfigFile.new()
	overrides.load(ENGINE_OVERRIDES)
	overrides.set_value("audio", "driver/enable_input", value != "off")
	overrides.save(ENGINE_OVERRIDES)


func set_mic_gain(value: float) -> void:
	mic_gain = clampf(value, 0.25, 4.0)
	if _encoder != null:
		_encoder.set_gain(mic_gain)
	_save()


func set_threshold(value: float) -> void:
	threshold = clampf(value, 0.005, 0.3)
	_save()


func _save() -> void:
	var settings := ConfigFile.new()
	settings.set_value("voice", "mode", mode)
	settings.set_value("voice", "mic_gain", mic_gain)
	settings.set_value("voice", "threshold", threshold)
	settings.save(SETTINGS_PATH)


func status_text() -> String:
	if not available:
		return "VOICE UNAVAILABLE (TWOVOIP MISSING)"
	if mode == "off":
		return "VOICE OFF"
	if not mic_ready and not test_input:
		return "RESTART THE GAME TO TURN ON THE MIC"
	if not _session_live():
		return "VOICE READY · JOIN A CO-OP CAMP"
	if talking:
		return "TALKING"
	return "HOLD B TO TALK" if mode == "push" else "OPEN MIC"


## Peers heard right now (lobby meters and the HUD speaking indicator).
func speaking_ids() -> Array[int]:
	var ids: Array[int] = []
	var now := Time.get_ticks_msec() / 1000.0
	for peer: int in _speakers:
		var speaker: Dictionary = _speakers[peer]
		if now - speaker["last"] < 0.3 and _route(peer) != "none":
			ids.append(peer)
	return ids


func speaking_names() -> Array[String]:
	var names: Array[String] = []
	var net: Node = get_node("/root/Net")
	for peer in speaking_ids():
		names.append(str(net.participants.get(peer, net.roster.get(peer, {})).get("name", "Camper")))
	return names


func _session_live() -> bool:
	var net: Node = get_node("/root/Net")
	return net.active and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _process(delta: float) -> void:
	_set_capturing(available and mode != "off" and (mic_ready or test_input) and _session_live())
	if capturing:
		_capture(delta)
	_update_speakers()
	_duck(delta)


func _set_capturing(on: bool) -> void:
	if on == capturing:
		return
	capturing = on
	talking = false
	_pending.clear()
	if not test_input:
		AudioServer.set_input_device_active(on)
	if on:
		_encoder = ClassDB.instantiate("TwovoipOpusEncoder")
		var rate := AudioServer.get_input_mix_rate()
		var error: int = _encoder.initialize(rate if rate > 0 else 44100, OPUS_RATE, 1, 2, 1, FRAME)
		if error != OK:
			# RNNoise missing from this build: fall back to Speex denoising.
			_encoder = ClassDB.instantiate("TwovoipOpusEncoder")
			error = _encoder.initialize(rate if rate > 0 else 44100, OPUS_RATE, 1, 1, 1, FRAME)
		if error != OK or not _encoder.create_opus_encoder(BITRATE, 5, true):
			push_warning("Voice encoder unavailable: %s" % error_string(error))
			_encoder = null
			capturing = false
			return
		_encoder.set_gain(mic_gain)


func _capture(delta: float) -> void:
	if _encoder == null:
		return
	var need: int = _encoder.get_required_input_chunk_size()
	var incoming := PackedVector2Array()
	if test_input:
		incoming = injected
		injected = PackedVector2Array()
	else:
		incoming = AudioServer.get_input_frames(AudioServer.get_input_frames_available())
	_pending.append_array(incoming)
	var wants := _wants_to_talk(delta)
	while _pending.size() >= need:
		var consumed: int = _encoder.process_chunk(_pending.slice(0, need))
		if consumed <= 0:
			break
		_pending = _pending.slice(consumed)
		mic_level = _encoder.get_peak()
		if mode == "open" and mic_level >= threshold:
			_hang = OPEN_HANG
		var send := wants if mode == "push" or test_talk else _hang > 0.0
		if send and not talking:
			talking = true
			stream_id = (stream_id + 1) % 65536
			sequence = 0
			_encoder.reset_opus_encoder()
		elif not send:
			talking = false
		if talking:
			var packet: PackedByteArray = _encoder.encode_chunk()
			if not packet.is_empty() and packet.size() <= MAX_PACKET:
				_voice_packet.rpc(stream_id, sequence, packet)
				sequence += 1
				sent_packets += 1
	# Never let a stalled microphone queue grow without bound.
	if _pending.size() > need * 8:
		_pending = _pending.slice(_pending.size() - need * 2)


func _wants_to_talk(delta: float) -> bool:
	_hang = maxf(0.0, _hang - delta)
	if test_talk:
		return true
	if mode != "push":
		return false
	var net: Node = get_node("/root/Net")
	return Input.is_action_pressed("push_to_talk") and not net.menu_open and get_window().has_focus()


@rpc("any_peer", "call_remote", "unreliable_ordered", CHANNEL)
func _voice_packet(stream: int, seq: int, packet: PackedByteArray) -> void:
	accept_packet(multiplayer.get_remote_sender_id(), stream, seq, packet)


## Validate and play one packet from `peer` (public for tests).
func accept_packet(peer: int, stream: int, seq: int, packet: PackedByteArray) -> bool:
	if not available or packet.is_empty() or packet.size() > MAX_PACKET or not _within_budget(peer):
		rejected_packets += 1
		return false
	received_packets += 1
	var speaker := _speaker(peer)
	var now := Time.get_ticks_msec() / 1000.0
	if speaker["stream"] != stream or now - speaker["last"] > STREAM_GAP:
		speaker["stream"] = stream
		speaker["next"] = seq
		speaker["buffer"] = []
		speaker["primed"] = false
		speaker["released"] = false
	speaker["last"] = now
	if seq < speaker["next"]:
		return false
	var playback: Object = speaker["playback"]
	if speaker["primed"] and seq > speaker["next"] and playback != null:
		# One lost packet: rebuild it from this packet's forward error correction.
		speaker["decoded"] += maxi(0, playback.push_opus_packet(packet, 0, 1))
	speaker["next"] = seq + 1
	speaker["buffer"].append(packet)
	if not speaker["primed"] and speaker["buffer"].size() < JITTER_PACKETS:
		return true
	speaker["primed"] = true
	var player: AudioStreamPlayer2D = speaker["player"]
	if not player.playing or playback == null:
		player.play()
		playback = player.get_stream_playback()
		speaker["playback"] = playback
	for queued: PackedByteArray in speaker["buffer"]:
		speaker["decoded"] += maxi(0, playback.push_opus_packet(queued, 0, 0))
	speaker["buffer"] = []
	# TwoVoIP playback starts paused at an end mark; clear it once audio is
	# queued or the decoded voice is never mixed (silent but "received").
	if not speaker.get("released", false):
		playback.mark_end_opus_stream(true)
		speaker["released"] = true
	return true


## Loudest sample the mixer has recently output for `peer` (0 when paused/silent).
func output_peak(peer: int) -> float:
	if not _speakers.has(peer) or _speakers[peer]["playback"] == null:
		return 0.0
	return _speakers[peer]["playback"].get_chunk_max()


func decoded_frames(peer: int) -> int:
	return _speakers[peer]["decoded"] if _speakers.has(peer) else 0


func _within_budget(peer: int) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var window: Array = _budget.get(peer, [now, 0])
	if now - window[0] >= 1.0:
		window = [now, 0]
	window[1] += 1
	_budget[peer] = window
	return window[1] <= PACKET_BUDGET


func _speaker(peer: int) -> Dictionary:
	if not _speakers.has(peer):
		var player := AudioStreamPlayer2D.new()
		player.name = "Voice%d" % peer
		var stream: AudioStream = ClassDB.instantiate("AudioStreamOpus")
		stream.set("opus_sample_rate", float(OPUS_RATE))
		stream.set("opus_channels", 1)
		stream.set("buffer_length", 1.0)
		player.stream = stream
		player.bus = "Voice"
		player.max_distance = HEAR_RANGE
		player.attenuation = VOICE_ATTENUATION
		# Teammates are panned only gently: a voice off to one side stays in both ears.
		player.panning_strength = 0.4
		add_child(player)
		_speakers[peer] = {"player": player, "playback": null, "stream": -1, "next": 0, "buffer": [], "primed": false, "last": -10.0, "decoded": 0}
	return _speakers[peer]


## "proximity", "global" or "none" for how the local player hears `peer`.
func _route(peer: int) -> String:
	var net: Node = get_node("/root/Net")
	if net.world == null or not is_instance_valid(net.world):
		return "global"
	var speaker: Variant = net.actors.get(peer)
	var listener: Variant = net.actors.get(multiplayer.get_unique_id())
	if not is_instance_valid(speaker) or not is_instance_valid(listener):
		return "none"
	return route_between(listener, speaker)


static func is_ghost(status: int) -> bool:
	return status in [CampPlayer.Status.ESCAPED, CampPlayer.Status.DEAD, CampPlayer.Status.LEFT_BEHIND]


## Routing rule shared with tests: the living never hear ghosts.
static func route_between(listener: CampPlayer, speaker: CampPlayer) -> String:
	return route_for(listener.status, listener.global_position, speaker.status, speaker.global_position)


static func route_for(listener_status: int, listener_at: Vector2, speaker_status: int, speaker_at: Vector2) -> String:
	if is_ghost(speaker_status):
		return "global" if is_ghost(listener_status) else "none"
	if is_ghost(listener_status):
		return "proximity"
	return "proximity" if listener_at.distance_to(speaker_at) <= HEAR_RANGE else "none"


func _update_speakers() -> void:
	var net: Node = get_node("/root/Net")
	# Actors are freed when a round ends: never hold a freed instance in a typed var.
	var found: Variant = net.actors.get(multiplayer.get_unique_id()) if _session_live() else null
	var listener: CampPlayer = found if is_instance_valid(found) else null
	for peer: int in _speakers.keys():
		var speaker: Dictionary = _speakers[peer]
		var player: AudioStreamPlayer2D = speaker["player"]
		if not _session_live() or not (net.participants.has(peer) or net.roster.has(peer)):
			player.stop()
			player.queue_free()
			_speakers.erase(peer)
			continue
		var route := _route(peer)
		var other: Variant = net.actors.get(peer)
		var actor: CampPlayer = other if is_instance_valid(other) else null
		var camera := get_viewport().get_camera_2d()
		var here: Vector2 = camera.get_screen_center_position() if camera != null else get_viewport().get_visible_rect().get_center()
		player.volume_db = -80.0 if route == "none" else 0.0
		player.global_position = actor.global_position if route == "proximity" and actor != null and is_instance_valid(actor) else here
		player.bus = "VoiceMuffled" if route == "proximity" and listener != null and actor != null and _occluded(listener, actor) else "Voice"


## Smoothly dip music, ambience and (slightly) effects while anyone is heard.
var ducked := 0.0
func _duck(delta: float) -> void:
	var target := 1.0 if not speaking_ids().is_empty() else 0.0
	var next := move_toward(ducked, target, delta * (6.0 if target > ducked else 1.5))
	if is_equal_approx(next, ducked):
		return
	ducked = next
	var mixer: Node = get_node_or_null("/root/AudioManager")
	if mixer != null and mixer.has_method("set_duck"):
		mixer.set_duck({"Music": DUCK_MUSIC_DB * ducked, "Ambience": DUCK_AMBIENCE_DB * ducked, "Effects": DUCK_EFFECTS_DB * ducked})


func _occluded(listener: CampPlayer, speaker: CampPlayer) -> bool:
	var query := PhysicsRayQueryParameters2D.create(listener.global_position, speaker.global_position, 1)
	return not listener.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
