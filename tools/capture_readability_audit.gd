extends SceneTree
## Diagnostic captures only: all escape pages enabled; enemies frozen.
## Keeps normal lighting/sight. Does not prove input playability or balance.
var level: Node2D
var failures := 0
const OUT := "res://artifacts/readability_audit/"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	RoundPlan.force_all_escapes = true
	RoundPlan.force_modifiers = []
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await _frames(12)
	level = current_scene
	level.player.local_input = false
	level.night_clock.active = false
	for enemy in get_nodes_in_group("killers"):
		enemy.enabled = false
	level.hud.inventory_label.show()
	level.hud.chart.show()
	await _shot("camp_van")
	# Reproduce a stale map marker after an actual pickup consume + delivery.
	for pickup in level.pickups:
		if pickup.kind == "battery":
			pickup.consume()
	level.player.inventory.append("battery")
	level.player.position = level.van.interaction_point()
	level.van.deliver(level.player)
	await _shot("battery_installed")
	level.player.position = level.plan.woods.center(Vector2i(18, 24))
	level.player.facing = Vector2.UP
	await _shot("woods_van")
	for index in range(1, level.plan.escape_options.size()):
		level.objective_page = index
		level.rescue.pack_selected = level.current_page() == "radio"
		level.hud.chart.hide()
		await _shot("page_" + level.current_page())
	level.hud.inventory_label.hide()
	level.hud.chart.hide()
	level.player.notice = "VAN ALARM! The STALKER tore out the SPARK PLUG and left it at the ABANDONED VILLAGE. It's pinned on your map."
	level.player.notice_time = 30.0
	await _shot("long_notice")
	level.hud.show_pause(true)
	await _shot("pause")
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await _frames(6)
	current_scene.get_node("Menu/Controls").pressed.emit()
	await _shot("field_guide")
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
