extends SceneTree
## README showcase captures for the 17 October features (not a test). Inspection
## lighting: ambient raised and the sight mask off; normal nights are dark.
## Run: godot --path . --audio-driver Dummy --script res://tools/capture_showcase.gd
var level: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/showcase"))
	RoundPlan.force_all_escapes = true
	RoundPlan.force_modifiers = ["blood_moon"]
	RoundPlan.force_headline = "groundskeeper"
	root.get_node("Session").survivor = "alex"
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	while current_scene == null or current_scene.name != "ForestLevel":
		await process_frame
	level = current_scene
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	level.night_clock.director_enabled = false
	await _frames(6)
	level.sight.enabled = false
	for child in level.get_children():
		if child.get_script() == load("res://scripts/ui/night_overlay.gd"):
			child.set_process(false)
			child.ambient.color = Color(0.62, 0.64, 0.7)
	var player: CampPlayer = level.player
	player.local_input = false
	# Groundskeeper beside a snare on a walked trail.
	var trail: Vector2 = level.plan.woods.center(Vector2i(18, 24))
	level.plan.woods.visited[level.plan.woods.cell_at(trail)] = true
	level.snares.try_place(trail + Vector2(28, -6))
	level.killer.position = trail + Vector2(-34, -10)
	level.killer.facing = Vector2.RIGHT
	level.killer.velocity = Vector2.ZERO
	# Frame him and the snare below the HUD's top lines.
	player.position = trail + Vector2(30, 22)
	player.facing = Vector2.UP
	await _shot("groundskeeper_snare")
	level.killer.position = Vector2(600, 520)
	# Scout mark on a creature in sight.
	var cryptid: CampCryptid = get_nodes_in_group("cryptids")[0]
	cryptid.position = trail + Vector2(0, -70)
	player.position = trail + Vector2(0, 20)
	player.facing = Vector2.UP
	level.abilities.use(player)
	await _shot("scout_mark")
	cryptid.position = level.plan.woods.center(Vector2i(4, 4))
	level.abilities.marks.clear()
	# Gift crate and lost camper.
	level.events.start("gift")
	player.position = level.events.gift_at + Vector2(-30, 30)
	await _shot("stalkers_gift")
	level.events.start("camper")
	player.position = level.events.camper_at + Vector2(24, 20)
	level.events.advance(0.1)
	await _shot("lost_camper")
	# Signal fire blazing.
	var fire: SignalFire = level.signal_fire
	fire.installed.assign(SignalFire.PARTS)
	fire.started = true
	fire.remaining = 31.0
	player.position = fire.pyre + Vector2(30, 60)
	await _frames(20)
	await _shot("signal_fire")
	fire.started = false
	# Van finale.
	level.van.installed.assign(level.plan.required)
	level.van.running = true
	level.van.remaining = 14.0
	player.position = level.van.global_position + Vector2(30, 40)
	await _shot("van_finale")
	# Results with score and awards.
	level.abilities.stat(player)["revives"] = 1
	level.abilities.stat(player)["flares"] = 4
	level.escape_route = "SIGNAL FIRE"
	level.finish_round(true, "SIGNAL FIRE evacuation: 2 survivor(s) recovered. You: escaped.")
	await _shot("results_score")
	# Camp Journal on the menu.
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	while current_scene == null or current_scene.name != "MainMenu":
		await process_frame
	await _frames(4)
	current_scene._show_journal()
	await _frames(4)
	await _shot("camp_journal")
	RoundPlan.force_all_escapes = false
	RoundPlan.force_modifiers = null
	RoundPlan.force_headline = ""
	quit()


func _shot(label: String) -> void:
	await _frames(8)
	RenderingServer.force_draw(true)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/showcase/%s.png" % label))
	print("captured ", label)


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame
