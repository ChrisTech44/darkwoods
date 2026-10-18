extends SceneTree
## Critic's baseline: staged placements, normal lighting first, bright inspection second.
const OUT := "res://artifacts/world_review/"
var level: Node2D
var failures := 0
var measures: Array = []

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
	for building in level.camp_map.buildings:
		level.player.position = building.door + Vector2(0, 52)
		level.player.facing = Vector2.UP
		await _shot("building_" + building.kind + "_" + str(int(building.bounds.position.x)))
	for zone in level.plan.woods.zones:
		level.player.position = zone["position"] + Vector2(0, 65)
		level.player.facing = Vector2.UP
		await _shot("region_" + zone["kind"])
		var at: Vector2 = zone["bounds"].position + Vector2(8, zone["bounds"].size.y - 10)
		level.player.position = at + Vector2(65, 30)
		await _shot("label_" + zone["kind"])
		var width := ThemeDB.fallback_font.get_string_size(zone["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		measures.append({"region": zone["kind"], "label": zone["label"], "width_at_9px": width, "bounds": str(zone["bounds"])})
	var post: Dictionary = level.plan.woods.signposts[0]
	level.player.position = post["position"] + Vector2(0, 28)
	await _shot("signpost")
	# Stress the actual shared edge renderer with multiple known signals.
	level.player.position = level.plan.woods.center(Vector2i(18, 24))
	level.pins.append({"owner": -10, "slot": 1, "position": level.player.position + Vector2(0, -2500), "name": "TEAMMATE AT GENERATOR", "place": "CAMP"})
	level.help_pings.append({"position": level.player.position + Vector2(20, -2500), "remaining": 20.0, "name": "ALEXANDER"})
	await _shot("crowded_bearings")
	level.pins.clear()
	level.help_pings.clear()
	level.night_clock.force_phase(2)
	await _shot("deep_night_transition")
	# Explicit inspection lighting, not normal gameplay evidence.
	level.sight.enabled = false
	for child in level.get_children():
		if child.get_script() == load("res://scripts/ui/night_overlay.gd"):
			child.set_process(false)
			child.ambient.color = Color(0.65, 0.65, 0.65)
	for building in level.camp_map.buildings:
		if building.kind == "workshop":
			level.player.position = building.door + Vector2(0, 52)
			await _shot("inspection_workshop")
			level.player.position = building.door - Vector2(0, 40)
			await _shot("inspection_workshop_inside")
	for zone in level.plan.woods.zones:
		if zone["kind"] in ["mill", "logging", "boathouse", "ranger"]:
			var at: Vector2 = zone["bounds"].position + Vector2(8, zone["bounds"].size.y - 10)
			level.player.position = at + Vector2(65, 30)
			await _shot("inspection_label_" + zone["kind"])
	level.player.position = level.plan.woods.center(Vector2i(18, 24))
	level.killer.position = level.player.position + Vector2(50, 0)
	level.killer.faded = true
	await _shot("inspection_faded_killer")
	var file := FileAccess.open(OUT + "label_metrics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(measures, "\t"))
	file.close()
	file = null
	# Phase radio uses delayed voices/tweens; let the staged broadcast finish.
	await create_timer(8.0).timeout
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)

func _frames(count: int) -> void:
	for index in range(count):
		await process_frame
		await physics_frame

func _shot(label: String) -> void:
	await _frames(18)
	RenderingServer.force_draw(true)
	var result := root.get_texture().get_image().save_png(OUT + label + ".png")
	if result != OK:
		failures += 1
	print(JSON.stringify({"capture": label, "save_error": result}))
