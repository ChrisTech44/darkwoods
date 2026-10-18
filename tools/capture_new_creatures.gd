extends SceneTree
## Graphical captures of the 18 October creatures. Staged: seed 42, the
## creature placed on a trail in front of the survivor (flashlight on, normal
## lighting), every other creature frozen, night clock stopped, state forced
## (inhale, count, riding/parked) to show each tell. Not a playthrough.
var level: Node2D
var player: CampPlayer
var trail := Vector2.ZERO
const OUT := "res://artifacts/new_creatures/"

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for index in range(count):
		await process_frame
		await physics_frame

func _shot(label: String) -> void:
	# Staged creatures are disabled, so they don't redraw on their own.
	for enemy in get_nodes_in_group("cryptids"):
		enemy.queue_redraw()
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + label + ".png")
	print(JSON.stringify({"capture": label}))

func _spawn(species: String, offset: Vector2) -> CampCryptid:
	var enemy: CampCryptid = preload("res://scenes/actors/cryptid.tscn").instantiate()
	enemy.species = species
	enemy.config = level.config
	enemy.position = trail + offset
	enemy.patrol.assign([trail + offset])
	level.world_objects.add_child(enemy)
	enemy.enabled = false
	return enemy

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	RoundPlan.force_modifiers = []
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await _frames(12)
	level = current_scene
	player = level.player
	player.local_input = false
	level.night_clock.set_physics_process(false)
	for enemy in get_nodes_in_group("killers"):
		enemy.enabled = false
		enemy.global_position += Vector2(5000, 0) if enemy is CampCryptid else Vector2.ZERO
	trail = level.plan.woods.center(Vector2i(18, 24))
	player.global_position = trail
	player.facing = Vector2.RIGHT
	player.flashlight_on = true
	# Let the opening Dusk title finish.
	await _frames(200)
	var row := [["groundskeeper", Vector2(60, 0)], ["cuckoo", Vector2(70, 0)], ["banshee", Vector2(70, 0)], ["slug", Vector2(60, 0)], ["surveyor", Vector2(60, 0)], ["hitchhiker", Vector2(50, 0)], ["tollkeeper", Vector2(60, 0)], ["echo", Vector2(60, 0)], ["fortune_teller", Vector2(55, 0)]]
	for pair in row:
		var enemy := _spawn(pair[0], pair[1])
		await _frames(4)
		var brain = enemy.brain
		enemy.queue_redraw()
		match pair[0]:
			"groundskeeper":
				brain.heading = Vector2.LEFT
				enemy.queue_redraw()
				await _shot("groundskeeper_riding_side")
				brain.heading = Vector2.DOWN
				enemy.queue_redraw()
				await _shot("groundskeeper_riding_front")
				brain._dismount()
				enemy.global_position += Vector2(30, -30)
				enemy.queue_redraw()
				await _shot("groundskeeper_on_foot_parked")
			"cuckoo":
				brain.calls = 2
				brain.bird = 0.4
				await _shot("cuckoo_counting")
			"banshee":
				brain.inhale = 0.6
				await _shot("banshee_inhale")
			"slug":
				for index in range(8):
					brain.puddles.append([trail + Vector2(20 + index * 10, 4 * sin(index)), 60.0])
				await _shot("slug_trail")
			"surveyor":
				await _shot("surveyor")
				player.add_effect("lost", 30.0)
				level.hud.notebook.open_view("map")
				await _shot("lost_map")
				level.hud.notebook.close()
				player.clear_effect("lost")
			"hitchhiker":
				await _shot("hitchhiker")
				brain._climb(player)
				enemy.enabled = true
				await _frames(4)
				await _shot("hitchhiker_riding")
				brain._hop_off(player)
				enemy.enabled = false
			"tollkeeper":
				await _shot("tollkeeper")
			"echo":
				await _shot("echo")
			"fortune_teller":
				player.add_effect("card", 2.0)
				player.effect_data["card"] = "THE TOWER"
				await _shot("fortune_teller_card")
		enemy.queue_free()
		await _frames(2)
	# Region entrance markers, approached normally with the flashlight on them.
	for site: ForestSite in level.camp_map.sites:
		if site.entrance == Vector2.INF:
			continue
		player.effects.clear()
		player.flashlight_charge = 90.0
		player.flashlight_on = true
		player.global_position = site.entrance + Vector2(-30, 36)
		player.facing = (site.entrance - player.global_position).normalized()
		# Let the place title for the new spot finish first.
		await _frames(170)
		player.flashlight_charge = 90.0
		await _shot("entrance_" + site.definition["kind"])
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0)
