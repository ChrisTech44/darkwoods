extends SceneTree
## Graphical captures of the Tab notebook, moon dial, phase title and radio
## transcript. Staged: seed 42, all escapes forced (diagnostic), enemies frozen,
## night progression driven by hand, normal lighting. Not a playthrough.
var level: Node2D
var failures := 0
const OUT := "res://artifacts/notebook/"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	RoundPlan.force_all_escapes = "--all-escapes" in OS.get_cmdline_user_args()
	RoundPlan.force_modifiers = ["blood_moon"] if "--blood-moon" in OS.get_cmdline_user_args() else []
	var tag := "blood_" if "--blood-moon" in OS.get_cmdline_user_args() else ""
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await _frames(12)
	level = current_scene
	level.player.local_input = false
	for enemy in get_nodes_in_group("killers"):
		enemy.enabled = false
	var clock: NightClock = level.night_clock
	clock.set_physics_process(false)
	var book: CampNotebook = level.hud.notebook
	await _frames(30)
	await _shot(tag + "dusk_title")
	book.open_view("map")
	await _shot(tag + "map_camp")
	for pickup in level.pickups:
		if pickup.kind == "battery":
			pickup.consume()
	level.player.inventory.append("battery")
	level.player.position = level.van.interaction_point()
	level.van.deliver(level.player)
	await _shot(tag + "map_camp_battery_installed")
	level.player.position = level.plan.woods.center(Vector2i(18, 24))
	level.player.facing = Vector2.UP
	for x in range(14, 21):
		level.plan.woods.visited[Vector2i(x, 24)] = true
	await _shot(tag + "map_woods_local")
	book.secondary()
	await _shot(tag + "map_woods_overview")
	book.secondary()
	for index in range(level.plan.escape_options.size()):
		level.select_route(index)
		book.open_view("plan")
		await _shot(tag + "plan_" + level.current_page())
	level.select_route(0)
	book.open_view("guide")
	for index in range(FieldGuide.TOPICS.size()):
		book.topic = index
		await _shot(tag + "guide_" + FieldGuide.TOPICS[index].to_lower().replace(" ", "_"))
	book.close()
	# Night progression by hand: Nightfall brings the title and the radio.
	clock.advance(0.0)
	clock.phase = 1
	clock.phase_elapsed = 0.0
	clock._enter_phase(1)
	clock.moon_clock = clock.moon_span * 0.55
	await _frames(20)
	await _shot(tag + "nightfall_title_radio")
	await _frames(70)
	await _shot(tag + "radio_crawl")
	await _frames(120)
	await _shot(tag + "moon_waxing")
	clock.set_moon(true)
	await _frames(20)
	await _shot(tag + "moon_full")
	book.open_view("log")
	await _shot(tag + "log")
	book.close()
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await _frames(6)
	current_scene.get_node("Menu/Controls").pressed.emit()
	await _shot(tag + "title_guide")
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)

func _frames(count: int) -> void:
	for index in range(count):
		await process_frame
		await physics_frame

func _shot(label: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUT + label + ".png")
	if result != OK:
		failures += 1
	print(JSON.stringify({"capture": label, "save_error": result}))
