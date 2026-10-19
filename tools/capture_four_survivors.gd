extends SceneTree
## Actual graphical fixture: prototype art; staged poses, frozen AI/clock,
## seed42 normal lighting/sight. All routes forced only for objective diagnosis.
const OUT := "res://artifacts/four_survivors/"
var level: Node2D
var failures := 0
var previous_role := "christian"
func _initialize() -> void: run.call_deferred()
func frames(n: int = 5) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func shot(label: String) -> void:
	if level != null: level.player.queue_redraw()
	await frames()
	RenderingServer.force_draw(true)
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUT+label+("_inspection" if "--inspection" in OS.get_cmdline_user_args() else "")+".png")
	if error != OK: failures += 1
	print(JSON.stringify({"event":"capture","name":label,"error":error}))
func role(id: String) -> void:
	CreatureSamples.finish_cast(level.player)
	level.player.role = id
	SurvivorAbilities.setup(level.player)
	level.player.effects.clear()
	level.player.holder = null
	level.player.health = 100
	level.player.hurt_time = 0
	level.player.flash_time = 0
	level.player.invulnerability = 0
	level.player.sheet = load("res://assets/sprites/survivor_"+SurvivorRoster.art(id)+".png")
	level.player.ability_cooldown = 0
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	previous_role = root.get_node("Session").survivor
	root.get_node("Voice").mode = "off"
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await frames(8)
	current_scene.get_node("Menu/Play").pressed.emit()
	for i in range(4):
		current_scene._select_survivor(i)
		await shot("select_"+SurvivorRoster.IDS[i])
	RoundPlan.force_all_escapes = true
	RoundPlan.force_modifiers = []
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	root.get_node("Session").survivor = "christian"
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await frames(12)
	level = current_scene
	level.night_clock.active = false
	level.night_clock.set_physics_process(false)
	level.abilities.set_physics_process(false)
	for enemy in get_nodes_in_group("killers"):
		enemy.enabled = false
		enemy.set_physics_process(false)
	level.player.local_input = false
	level.player.set_physics_process(false)
	if "--inspection" in OS.get_cmdline_user_args():
		level.sight.enabled = false
		for child in level.get_children():
			if child.get_script() == load("res://scripts/ui/night_overlay.gd"):
				child.set_process(false)
				child.ambient.color = Color(0.7,0.7,0.7)
	var at := Vector2(300,400)
	assert(SurvivorKits.safe_point(level.player,at), "Capture pose must be traversable")
	level.player.position = at
	level.player.facing = Vector2.UP
	level.player.flashlight_on = true
	level.hud.broadcast.hide()
	level.message_time = 0
	level.player.notice_time = 0
	role("john")
	level.abilities.use(level.player)
	level.player.invulnerability = 0
	level.player.receive_hit(60)
	await shot("john_debt")
	SurvivorKits.settle(level.player)
	await shot("john_paid_debt")
	role("max")
	level.player.kit.cash = 24
	level.abilities.use(level.player)
	level.player.kit.stake_time = 1.4
	await shot("max_stake")
	level.abilities.release(level.player)
	level.player.invulnerability = 0
	level.player.receive_hit(10)
	await shot("max_cash_spill")
	role("alex")
	SurvivorKits.advance(level.player,5.0)
	level.abilities.use(level.player)
	level.player.position += Vector2(0,20)
	level.abilities.use(level.player)
	await shot("alex_channel")
	SurvivorKits.advance(level.player,2.1)
	await shot("alex_returned")
	role("christian")
	level.player.position = at
	level.player.facing = Vector2.UP
	for form in ["werewolf","briar_revenant","groundskeeper","mimic"]:
		CreatureSamples.finish_cast(level.player)
		level.player.kit.form = ""
		level.player.kit.sample = form
		level.player.ability_cooldown = 0
		level.night_clock.moon = true
		level.abilities.use(level.player)
		await shot("christian_"+form)
	level.player.kit.form = ""
	for sample in ["shutter_wraith","witch","ration_moth","bramble_seamstress","bog_hands","echo"]:
		CreatureSamples.finish_cast(level.player)
		level.player.kit.sample = sample
		level.player.kit.subtype = "frog"
		level.player.ability_cooldown = 0
		level.abilities.use(level.player)
		await shot("christian_"+sample+"_tell")
		if sample in ["ration_moth","witch"]:
			CreatureSamples.advance(level.player,1.1)
			await shot("christian_"+sample+"_effect")
	root.get_node("Session").select_survivor(previous_role)
	await root.get_node("AudioManager").prepare_shutdown()
	quit(1 if failures else 0)
