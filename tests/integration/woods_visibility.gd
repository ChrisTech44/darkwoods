extends SceneTree
var checks := 0
var failures := 0
var capture := false
var level: Node2D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	while current_scene==null or current_scene.name!="ForestLevel": await process_frame
	await _frames(3)
	level = current_scene
	for enemy in get_nodes_in_group("killers"):
		enemy.enabled = false
	for cell: Vector2i in level.plan.woods.links:
		var next := cell + Vector2i.RIGHT
		if not level.plan.woods.valid(next) or next in level.plan.woods.links[cell]:
			continue
		var from: Vector2 = level.plan.woods.center(cell)
		var to: Vector2 = level.plan.woods.center(next)
		if level.clear_path(from, to):
			continue
		level.player.position = from
		level.player.set_physics_process(false)
		var monster: CampCryptid = level.get_tree().get_nodes_in_group("cryptids")[0]
		monster.position = to
		await _frames(3)
		_check(level.sight.can_see(from + Vector2(24, 0)), "current_path_visible")
		_check(not level.sight.can_see(to) and not monster.visible, "tree_border_hides_entire_monster")
		_check(not level.soundscape.play_cue("werewolf_howl", from + Vector2(200, 0)), "distant_monster_does_not_start_call")
		_check(level.soundscape.play_cue("werewolf_howl", from + Vector2(60, 0)), "nearby_call_allowed")
		if capture:
			# Isolate world pixels: UI markers and weather haze are drawn above the sight mask.
			for layer in level.get_children():
				if layer is CanvasLayer: layer.hide()
			for node in level.get_children():
				if node.get_script() == load("res://scripts/ui/night_overlay.gd"):
					node.set_process(false)
					node.ambient.color = Color.WHITE
			level.player.get_node("Camera2D").offset = Vector2(40, 0)
			level.player.get_node("Camera2D").force_update_scroll()
			for settled in range(3): await process_frame
			await _frames(3)
			var hidden := await _image()
			var probe := Vector2i(level.player.get_global_transform_with_canvas().origin + Vector2(176, 24))
			level.sight.enabled = false
			await _frames(3)
			var shown := await _image()
			print(JSON.stringify({"event":"sight_pixels","hidden":hidden.get_pixelv(probe).get_luminance(),"shown":shown.get_pixelv(probe).get_luminance(),"probe":probe}))
			_check(hidden.get_pixelv(probe).get_luminance() < 0.001 and shown.get_pixelv(probe).get_luminance() > 0.02, "opaque_sight_mask_even_in_full_ambient_light")
			hidden.save_png("res://artifacts/verification/sight_blocked.png")
			shown.save_png("res://artifacts/verification/sight_control.png")
			var mixer: Node = root.get_node("AudioManager")
			if mixer.output_enabled:
				monster.position = from + Vector2(60, 0)
				level.soundscape.play_cue("witch_cackle", monster.position, 0, 1, monster)
				var voice: AudioStreamPlayer2D = level.soundscape.voices[-1]
				_check(voice.max_distance == 160 and voice.attenuation == 2, "monster_native_proximity_falloff")
				monster.position += Vector2(20, 0)
				await _frames(2)
				_check(voice.global_position == monster.global_position, "playing_call_follows_moving_monster")
		break
	print(JSON.stringify({"event": "test_result", "suite": "woods_visibility", "checks": checks, "failures": failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)

func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func _image() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _check(passed: bool, label: String) -> void:
	checks += 1
	failures += 0 if passed else 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": passed}))
