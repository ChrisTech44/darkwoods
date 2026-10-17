extends SceneTree
## No-device rules plus real MP3 decode/mix through AudioEffectCapture.

var checks := 0
var failures := 0
var mixer: Node
var level: Node2D
var capture := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	mixer = root.get_node("AudioManager")
	capture = "--capture" in OS.get_cmdline_user_args()
	# Every supplied MP3 is registered, and every registered cue loads.
	var files := Array(DirAccess.get_files_at("res://assets/audio")).filter(func(name: String) -> bool: return name.ends_with(".mp3"))
	var paths: Array = mixer.cues.values().map(func(cue: Dictionary) -> String: return cue["path"].get_file())
	_check(mixer.cues.size() == 50 and files.all(func(name: String) -> bool: return name in paths), "all_fifty_supplied_files_registered")
	_check(mixer.cues.keys().all(func(cue: String) -> bool: return mixer.stream_for(cue) != null), "every_cue_stream_loads")
	for bus in mixer.BUSES:
		_check(AudioServer.get_bus_index(bus) >= 0, "bus_" + bus)
	for cue in mixer.cues:
		var stream: AudioStream = mixer.stream_for(cue)
		_check(stream != null and stream.get_length() > 0.4 and stream.loop == mixer.cues[cue]["loop"], "real_import_and_loop_flag_" + cue)
	_check(AudioServer.get_bus_send(AudioServer.get_bus_index("Campfire")) == "Ambience", "fire_compression_respects_ambience_control")
	_check(mixer.stream_for("missing") == null, "unknown_cues_fail_safely")
	var previous: Dictionary = mixer.volumes.duplicate()
	mixer.set_volume("Master", 0.0, false)
	_check(AudioServer.is_bus_mute(0), "zero_volume_mutes")
	mixer.set_volume("Effects", 0.35)
	var settings := ConfigFile.new()
	_check(settings.load(mixer.settings_path) == OK and is_equal_approx(settings.get_value("volume", "Effects"), 0.35), "preferences_saved_to_isolated_test_file")
	for bus in previous:
		mixer.set_volume(bus, previous[bus], false)
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await _frames(4)
	level = current_scene
	for enemy in get_nodes_in_group("killers"):
		enemy.enabled = false
	var sound: CampSoundscape = level.soundscape
	await _frames(90)
	# Music now follows the night's dread: quiet at Dusk, swelling toward the Witching Hour.
	var music_target := clampf(0.45 + level.night_clock.dread * 0.0055, 0.0, 1.0)
	_check(sound.gains["woods"] > 0.9 and absf(sound.gains["music"] - music_target) < 0.06 and music_target < 0.6, "round_ambience_and_dread_scaled_music_fade_in")
	level.player.position = Vector2(300, 448)
	await _frames(2)
	var steps_before: int = sound.played_counts.get("footstep", 0)
	Input.action_press("move_right")
	await _frames(50)
	Input.action_release("move_right")
	_check(sound.played_counts.get("footstep", 0) > steps_before, "walking_emits_distance_based_steps")
	Input.action_press("move_right")
	Input.action_press("sprint")
	await _frames(12)
	_check(sound.last_step_cue == "running_grass" and sound.gains["running_grass"] > 0.5, "sprint_uses_grass_loop")
	Input.action_release("move_right")
	Input.action_release("sprint")
	await _frames(15)
	_check(sound.gains["running_grass"] == 0, "standing_stops_footsteps")
	level.player.position = level.camp_map.buildings[0].door - Vector2(0, 32)
	await _frames(2)
	Input.action_press("move_down")
	await _frames(8)
	_check(sound.last_step_cue == "walking_indoor" and sound.gains["walking_indoor"] > 0, "building_floor_uses_indoor_steps")
	Input.action_release("move_down")
	level.player.position = level.plan.woods.zones[1]["position"]
	await _frames(90)
	_check(sound.gains["swamp"] > 0.9 and sound.gains["woods"] < 0.3, "bog_crossfades_ambience")
	level.player.position = Vector2(300, 448)
	level.killer.set_physics_process(false)
	level.killer.enabled = true
	level.killer.visible_target = level.player
	level.killer.transition(CampKiller.State.CHASE)
	await _frames(90)
	_check(sound.threat_gain > 0.95 and sound.gains["heartbeat"] > 0.9, "spotted_player_fades_in_heartbeat")
	level.killer.visible_target = null
	level.killer.transition(CampKiller.State.SEARCH)
	await _frames(240)
	_check(sound.threat_gain == 0 and sound.gains["heartbeat"] < 0.01, "lost_target_fades_out_heartbeat")
	for species in CampSoundscape.CREATURE_CUES:
		# Long calls hold their voices; free the bounded pool so each species is tested alone.
		for voice in sound.voices:
			voice.queue_free()
		sound.voices.clear()
		var enemy := CampCryptid.new()
		enemy.species = species
		enemy.position = level.player.position + Vector2(30, 0)
		var cue: String = CampSoundscape.CREATURE_CUES[species]
		var count: int = sound.played_counts.get(cue, 0)
		sound._enemy_state(CampKiller.State.CHASE, enemy)
		sound._spell_started(enemy)
		_check(sound.played_counts.get(cue, 0) == count + 1, "species_cue_once_with_cooldown_" + species)
		enemy.free()
	level.paused = true
	await _frames(2)
	_check((not mixer.output_enabled or sound.loops["woods"].stream_paused) and not sound.play_cue("footstep", level.player.position), "pause_suspends_and_rejects_cues")
	level.hud.show_pause(true)
	if capture:
		await _snapshot("audio_pause_mixer")
	level.hud.show_pause(false)
	level.paused = false
	await _frames(2)
	_check(not sound.loops["woods"].stream_paused, "resume_restores_loops")
	mixer.set_volume("Effects", 0.0, false)
	level._on_noise(level.killer.position + Vector2(20, 0))
	_check(level.killer.state == CampKiller.State.INVESTIGATE, "muting_does_not_change_ai_hearing")
	mixer.set_volume("Effects", previous["Effects"], false)
	var output_before: bool = mixer.output_enabled
	mixer.output_enabled = false
	_check(sound.play_cue("footstep", level.player.position), "missing_output_does_not_block_events")
	mixer.output_enabled = output_before
	for index in range(40):
		sound.play_cue("footstep", level.player.position)
	_check(sound.voices.size() <= CampSoundscape.MAX_VOICES, "positional_voice_pool_bounded")
	level.finish_round(false, "Audio regression fixture")
	_check(sound.voices.is_empty() and sound.loops.values().all(func(node: Node) -> bool: return not node.playing), "result_stops_every_emitter")
	var old_sound: WeakRef = weakref(sound)
	level.retry_round()
	while current_scene == null or current_scene.name != "ForestLevel" or current_scene == level:
		await process_frame
	await _frames(3)
	_check(old_sound.get_ref() == null and current_scene.soundscape != null, "retry_frees_round_audio_and_recreates_once")
	current_scene.return_to_menu()
	await _frames(3)
	_check(current_scene.name == "MainMenu" and get_nodes_in_group("survivors").is_empty(), "menu_has_no_round_audio_or_capture")
	if capture:
		await mixer.prepare_shutdown()
		await _decode_mix()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mixer.settings_path))
	print(JSON.stringify({"event": "test_result", "suite": "audio_polish", "checks": checks, "failures": failures, "audio_driver": AudioServer.get_driver_name(), "display": DisplayServer.get_name(), "output_enabled": mixer.output_enabled}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)

func _decode_mix() -> void:
	AudioServer.add_bus(1)
	var bus := 1
	AudioServer.set_bus_name(bus, "AudioTest")
	AudioServer.set_bus_volume_db(bus, -30)
	var tap := AudioEffectCapture.new()
	tap.buffer_length = 0.3
	AudioServer.add_bus_effect(bus, tap)
	for cue in mixer.cues:
		var send_bus: String = "Ambience" if mixer.cues[cue]["bus"] == "Campfire" else mixer.cues[cue]["bus"]
		var send_index := AudioServer.get_bus_index(send_bus)
		var previous_send := AudioServer.get_bus_send(send_index)
		AudioServer.set_bus_send(send_index, "AudioTest")
		var source := AudioStreamPlayer.new()
		source.stream = mixer.stream_for(cue).duplicate()
		source.stream.loop = false
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
			source.stream.loop = true
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

func _snapshot(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(true)
	_check(root.get_texture().get_image().save_png("res://artifacts/verification/%s.png" % label) == OK, "capture_" + label)

func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func _check(passed: bool, label: String) -> void:
	checks += 1
	failures += 0 if passed else 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": passed}))
