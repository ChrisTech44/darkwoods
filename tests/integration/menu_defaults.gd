extends SceneTree
## User flow: music/knobs before Play, random camps in both modes, explicit replay.
var checks := 0
var failures := 0
var capture := false
var mixer: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	mixer = root.get_node("AudioManager")
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await _frames(4)
	var menu: Control = current_scene
	_check(menu.get_node("Menu/RandomNight").button_pressed and not menu.get_node("Menu/Seed").editable, "random_night_default_seed_disabled")
	_check(not menu.get_node("SettingsPanel").visible, "knobs_hidden_behind_settings")
	menu.get_node("Menu/Settings").pressed.emit()
	_check(menu.get_node("SettingsPanel").visible, "settings_opens")
	_check(menu.get_node("SettingsPanel/Content/AudioControls").get_child_count() == 4, "four_pre_game_mix_controls_visible")
	var music: AudioStreamPlayer = menu.get_node("MenuAudio/music")
	_check(music.stream != null and music.bus == "Music" and (not mixer.output_enabled or music.playing), "menu_music_plays_on_music_bus")
	var audio_ref: WeakRef = weakref(menu.get_node("MenuAudio"))
	var saved_path: String = mixer.settings_path
	var saved_volumes: Dictionary = mixer.volumes.duplicate()
	mixer.settings_path = "user://menu_controls_test.cfg"
	var music_slider: HSlider = menu.get_node("SettingsPanel/Content/AudioControls").get_child(3).get_node("Music")
	music_slider.value = 0
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "menu_music_knob_mutes_immediately")
	music_slider.value = 30
	var settings := ConfigFile.new()
	_check(settings.load(mixer.settings_path) == OK and is_equal_approx(settings.get_value("volume", "Music"), 0.3), "menu_knob_saves_before_play")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mixer.settings_path))
	mixer.settings_path = saved_path
	for bus in saved_volumes:
		mixer.set_volume(bus, saved_volumes[bus], false)
	music_slider.set_value_no_signal(float(saved_volumes["Music"]) * 100.0)
	if capture:
		await _snapshot("menu_settings")
	menu._hide_settings()
	if capture:
		await _snapshot("menu_defaults")
	for mode_index in [1, 0]:
		menu = current_scene
		menu.get_node("Menu/Mode").select(mode_index)
		menu.get_node("Menu/Seed").text = "42" # Even stale programmatic text is ignored in random mode.
		menu.get_node("Menu/Play").pressed.emit()
		menu.get_node("SurvivorSelection/Start").pressed.emit()
		await _world()
		var level: Node2D = current_scene
		var first_seed: int = level.plan.seed_value
		var first_camp: String = level.plan.camp.signature()
		_check(first_seed != 42 and audio_ref.get_ref() == null, "random_play_ignores_seed_and_frees_menu_audio_%d" % mode_index)
		level.retry_round()
		await _world()
		level = current_scene
		_check(level.plan.seed_value == first_seed and level.plan.camp.signature() == first_camp, "explicit_retry_repeats_camp_%d" % mode_index)
		level.restart_round()
		await _frames(4)
		menu = current_scene
		menu.get_node("Menu/Play").pressed.emit()
		menu.get_node("SurvivorSelection/Start").pressed.emit()
		await _world()
		level = current_scene
		_check(level.plan.seed_value != first_seed and level.plan.camp.signature() != first_camp, "another_night_randomizes_camp_%d" % mode_index)
		level.return_to_menu()
		await _frames(4)
		menu = current_scene
		_check(menu.get_node("Menu/RandomNight").button_pressed and menu.get_node("MenuAudio").get_child_count() == 2, "menu_return_resets_random_and_restores_music_%d" % mode_index)
		menu.get_node("Menu/RandomNight").button_pressed = false
		_check(menu.get_node("Menu/Seed").editable, "fixed_seed_opt_in_%d" % mode_index)
		menu.get_node("Menu/Seed").text = "2026"
		menu.get_node("Menu/Play").pressed.emit()
		menu.get_node("SurvivorSelection/Start").pressed.emit()
		await _world()
		level = current_scene
		_check(level.plan.seed_value == 2026, "explicit_seed_respected_%d" % mode_index)
		level.return_to_menu()
		await _frames(4)
		menu = current_scene
		audio_ref = weakref(menu.get_node("MenuAudio"))
	current_scene.queue_free()
	await _frames(4)
	print(JSON.stringify({"event": "test_result", "suite": "menu_defaults", "checks": checks, "failures": failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)

func _world() -> void:
	await process_frame
	while current_scene == null or current_scene.name != "ForestLevel":
		await process_frame
	for enemy in get_nodes_in_group("killers"):
		enemy.enabled = false
	await _frames(3)

func _frames(count: int) -> void:
	for index in range(count):
		await process_frame

func _snapshot(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(true)
	_check(root.get_texture().get_image().save_png("res://artifacts/verification/%s.png" % label) == OK, "capture_" + label)

func _check(passed: bool, label: String) -> void:
	checks += 1
	failures += 0 if passed else 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": passed}))
