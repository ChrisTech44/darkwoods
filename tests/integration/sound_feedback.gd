extends SceneTree
## Accepted-cue routing for the 18 October sound pack. Counts only: no listening,
## mix or cross-machine claim. Enemies frozen; the soundscape is stepped manually.
var level: Node2D
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": name, "passed": ok}))

func _frames(count: int) -> void:
	for index in range(count):
		await process_frame
		await physics_frame

func _run() -> void:
	RoundPlan.force_headline = "stalker"
	RoundPlan.force_modifiers = []
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await _frames(12)
	level = current_scene
	var sound: CampSoundscape = level.soundscape
	var mixer: Node = root.get_node("AudioManager")
	level.player.local_input = false
	level.night_clock.active = false
	sound.set_physics_process(false)
	level.snares.set_physics_process(false)
	for enemy in get_nodes_in_group("killers"):
		enemy.enabled = false
	for cue in ["air_horn", "bear_trap", "bog_gurgle", "camera_shutter", "camera_charge", "dog_bark", "dog_whine", "frog_croak", "giggle", "helicopter", "scissors", "gasp", "grunt", "sneeze", "squeak", "lullaby", "train"]:
		_check(mixer.stream_for(cue) != null and not mixer.cues[cue].has("start_seconds"), "cue_loads_trimmed_" + cue)
	_check(mixer.stream_for("frog_croak").loop and mixer.stream_for("lullaby").loop and mixer.stream_for("helicopter").loop and not mixer.stream_for("sneeze").loop, "loop_flags")
	# Air horn: one audible blast.
	sound.played_counts.clear()
	level.player.supplies["air_horn"] = 1
	level.use_supply(level.player, "air_horn")
	_check(sound.played_counts.get("air_horn", 0) == 1, "air_horn_plays_once")
	# Bear trap: exactly one snap per activation (no direct + edge double).
	sound.played_counts.clear()
	var trap_at: Vector2 = level.plan.woods.center(Vector2i(18, 24))
	level.plan.woods.visited[level.plan.woods.cell_at(trap_at)] = true
	level.player.position = trap_at + Vector2(80, 0)
	level.snares.try_place(trap_at)
	sound._events()
	level.player.position = trap_at
	level.player.vault_time = 0.0
	level.snares.advance(0.01)
	sound._events()
	_check(sound.played_counts.get("bear_trap", 0) == 1 and sound.played_counts.get("metal_clang", 0) == 0, "bear_trap_single_snap")
	_check(sound.played_counts.get("grunt", 0) == 1, "trap_bite_grunt")
	level.player.snared = 0.0
	# Sneeze and grab edges come from replicated state, once each.
	sound.played_counts.clear()
	level.player.add_effect("achoo", 0.9)
	sound._events()
	sound._events()
	_check(sound.played_counts.get("sneeze", 0) == 1, "sneeze_once_per_achoo")
	level.player.add_effect("held", 2.0)
	sound._events()
	_check(sound.played_counts.get("gasp", 0) == 1, "held_gasp")
	level.player.clear_effect("held")
	# Client replay: each logged host event plays exactly once.
	sound.played_counts.clear()
	var log := [{"id": 900, "cue": "dog_bark", "at": level.player.global_position, "gain": 0.0, "pitch": 1.0, "length": 0.0, "time": 0}]
	sound.replay(log)
	sound.replay(log)
	_check(sound.played_counts.get("dog_bark", 0) == 1, "replay_exactly_once")
	# Follow loops: the frog croak attaches to a frog survivor and stops after.
	level.player.add_effect("frog", 1.0)
	sound._follow_loops()
	_check(sound.follow_loops.has(level.player.get_instance_id()), "frog_croak_loop_follows")
	level.player.clear_effect("frog")
	sound._follow_loops()
	_check(sound.follow_loops.is_empty(), "frog_croak_loop_stops")
	# Creature cues map to the new recordings.
	_check(CampSoundscape.CREATURE_CUES["switchback_hound"] == "dog_bark" and CampSoundscape.CREATURE_CUES["imps"] == "giggle" and CampSoundscape.CREATURE_CUES["teddy"] == "squeak" and CampSoundscape.CREATURE_CUES["bog_hands"] == "bog_gurgle" and CampSoundscape.CREATURE_CUES["last_car_conductor"] == "train", "creature_cue_mapping")
	# Radio/stingers are outside the positional voice list. Shutdown must also
	# release their native playback and reject the queued radio-talk callback.
	var tail := AudioStreamPlayer.new()
	tail.stream = mixer.stream_for("radio_talk")
	sound.add_child(tail)
	if mixer.output_enabled: tail.play()
	sound.radio_broadcast(1)
	sound.stinger("bells", -8.0, 1.0)
	sound.stop_round()
	var clean := true
	for child in sound.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			clean = clean and not child.playing and child.stream == null
	_check(clean, "shutdown_releases_all_positional_and_radio_streams")
	_check(not sound.radio_broadcast(2) and not sound.stinger("bells", -8.0, 1.0) and not sound.broadcast("bells", level.player.position), "stopped_round_rejects_new_audio_events")
	await create_timer(0.7).timeout
	var resumed := false
	for child in sound.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			resumed = resumed or child.stream != null or child.playing
	_check(not resumed, "delayed_radio_cannot_restart_after_shutdown")
	print(JSON.stringify({"event": "test_result", "suite": "sound_feedback", "checks": checks, "failures": failures}))
	await mixer.prepare_shutdown()
	quit(0 if failures == 0 else 1)
