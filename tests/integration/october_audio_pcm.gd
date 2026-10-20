extends SceneTree
## Native MP3 decode and bus capture; no microphone or human listening claim.
var mixer: Node
var checks:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(JSON.stringify({"event":"assertion","name":label,"passed":ok}))
func run() -> void:
	root.get_node("Voice").mode="off"
	mixer=root.get_node("AudioManager")
	await mixer.prepare_shutdown()
	await decode()
	print(JSON.stringify({"event":"test_result","suite":"october_audio_pcm","checks":checks,"failures":failures}))
	quit(1 if failures else 0)
func decode() -> void:
	AudioServer.add_bus(1)
	var bus := 1
	AudioServer.set_bus_name(bus, "AudioTest")
	AudioServer.set_bus_volume_db(bus, -30)
	var tap := AudioEffectCapture.new()
	tap.buffer_length = 0.3
	AudioServer.add_bus_effect(bus, tap)
	for cue in preload("res://tests/integration/october_audio.gd").CUES:
		var send_bus: String = "Ambience" if mixer.cues[cue]["bus"] == "Campfire" else mixer.cues[cue]["bus"]
		var send_index := AudioServer.get_bus_index(send_bus)
		var previous_send := AudioServer.get_bus_send(send_index)
		AudioServer.set_bus_send(send_index, "AudioTest")
		var source := AudioStreamPlayer.new()
		source.stream = mixer.stream_for(cue).duplicate()
		if source.stream is AudioStreamMP3: source.stream.loop = false
		else: source.stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
		source.bus = mixer.cues[cue]["bus"]
		source.volume_db = mixer.cues[cue]["gain_db"]
		root.add_child(source)
		tap.clear_buffer()
		source.play(float(mixer.cues[cue].get("start_seconds", 0.0)))
		var end := Time.get_ticks_msec() + 750
		var frames := 0
		var peak := 0.0
		while Time.get_ticks_msec() < end:
			await process_frame
			var samples := tap.get_buffer(tap.get_frames_available())
			frames += samples.size()
			for sample in samples:
				peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		_check(frames > 0 and peak > 0.0000001 and peak < 0.95, "decoded_nonzero_gain_staged_pcm_" + cue)
		print(JSON.stringify({"event": "audio_pcm", "cue": cue, "frames": frames, "peak": peak}))
		if mixer.cues[cue]["loop"]:
			if source.stream is AudioStreamMP3: source.stream.loop = true
			else: source.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			source.seek(source.stream.get_length() - 0.08)
			await _audio_wait(350)
			_check(source.playing and source.get_playback_position() < 0.9, "native_loop_wraps_" + cue)
		source.stop()
		source.queue_free()
		await _audio_wait(160)
		tap.clear_buffer()
		AudioServer.set_bus_send(send_index, previous_send)
	AudioServer.remove_bus(bus)

func _audio_wait(milliseconds: int) -> void:
	var deadline := Time.get_ticks_msec() + milliseconds
	while Time.get_ticks_msec() < deadline:
		await process_frame
