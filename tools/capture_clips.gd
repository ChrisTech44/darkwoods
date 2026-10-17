extends SceneTree
## README clips: short scripted moments recorded as PNG frames (15 fps) into
## artifacts/clips/<name>/, then turned into GIFs by tools/build_clips.py.
## Real game, real HUD and sight mask; the night is brightened slightly so the
## action is readable. Run: godot --path . --fixed-fps 30 --audio-driver Dummy
##   --script res://tools/capture_clips.gd
var level: Node2D
var player: CampPlayer
const AMBIENT := Color(0.42, 0.44, 0.5)
## Per-clip override: fire and headlight clips read best at real night darkness.
var ambient := AMBIENT


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--clip="):
			only = argument.get_slice("=", 1)
	var clips := ["storm", "chase_flare", "flash_stun", "hide", "door", "snare", "van", "signal_fire"]
	for name in clips:
		if only.is_empty() or only == name:
			await call(name)
	RoundPlan.force_all_escapes = false
	RoundPlan.force_modifiers = null
	RoundPlan.force_headline = ""
	quit()


func _load(headline: String = "stalker", dark: bool = false) -> void:
	ambient = Color(0.14, 0.15, 0.2) if dark else AMBIENT
	RoundPlan.force_all_escapes = true
	RoundPlan.force_modifiers = []
	RoundPlan.force_headline = headline
	root.get_node("Session").survivor = "jock"
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	var previous := level
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await process_frame
	while current_scene == null or current_scene.name != "ForestLevel" or current_scene == previous:
		await process_frame
	level = current_scene
	player = level.player
	level.night_clock.director_enabled = false
	level.message_time = 0.0
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	for index in range(8):
		await process_frame


## Keep the brightened ambient each frame (the overlay recomputes it).
func _hold_light() -> void:
	if ambient != AMBIENT:
		return
	for child in level.get_children():
		if child.get_script() == load("res://scripts/ui/night_overlay.gd"):
			var lit: float = level.night_clock.lightning
			child.ambient.color = ambient.lerp(Color(0.85, 0.9, 1.0), lit * 3.0) if lit > 0.0 else ambient


func _record(name: String, frames: int, step: Callable) -> void:
	var folder := "res://artifacts/clips/%s" % name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for file in DirAccess.get_files_at(ProjectSettings.globalize_path(folder)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder + "/" + file))
	for index in range(frames):
		await step.call(index)
		for tick in range(2):
			_hold_light()
			await physics_frame
		RenderingServer.force_draw(true)
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/f_%04d.png" % [folder, index]))
	for action in ["move_left", "move_right", "move_up", "move_down", "sprint", "interact"]:
		Input.action_release(action)
	print("clip ", name, " ", frames)


func _trail() -> Vector2:
	# A straight east-west trail cell away from regions and roads.
	for cell: Vector2i in level.plan.woods.links:
		var links: Array = level.plan.woods.links[cell]
		var at: Vector2 = level.plan.woods.center(cell)
		if links.size() == 2 and (cell + Vector2i.LEFT) in links and (cell + Vector2i.RIGHT) in links and level.plan.woods.zone_at(at).is_empty() and not level.plan.woods.on_road(at) and at.distance_to(CampMap.CAMP_BOUNDS.get_center()) > 1200:
			return at
	return level.plan.woods.center(Vector2i(18, 24))


func _cryptid(species: String) -> CampCryptid:
	for enemy: CampCryptid in get_nodes_in_group("cryptids"):
		if enemy.species == species and not enemy.home.has_area():
			return enemy
	return get_nodes_in_group("cryptids")[0]


func storm() -> void:
	await _load()
	player.position = _trail() + Vector2(-150, 0)
	player.get_node("Camera2D").reset_smoothing()
	level.night_clock._start_event("storm")
	level.message_time = 0.0
	await _record("storm", 60, func(index: int) -> void:
		Input.action_press("move_right")
		if index in [8, 30, 48]:
			level.night_clock.lightning = 0.18)


func chase_flare() -> void:
	await _load()
	var at := _trail()
	player.position = at
	var wolf := _cryptid("werewolf")
	wolf.position = at + Vector2(-110, 0)
	wolf.enabled = true
	await _record("chase_flare", 64, func(index: int) -> void:
		if index < 26:
			Input.action_press("move_right")
			Input.action_press("sprint")
		elif index == 26:
			Input.action_release("move_right")
			Input.action_release("sprint")
			player.facing = Vector2.LEFT
			level.use_supply(player, "flare")
		elif index > 32:
			Input.action_press("move_right"))


func flash_stun() -> void:
	await _load()
	var at := _trail()
	player.position = at
	player.facing = Vector2.RIGHT
	var beast := _cryptid("switchback_hound")
	beast.position = at + Vector2(150, 0)
	beast.enabled = true
	await _record("flash_stun", 50, func(index: int) -> void:
		player.facing = Vector2.RIGHT
		if index == 0:
			beast.hear_stimulus(player.position, INF)
		if index > 0 and beast.position.distance_to(player.position) < 80 and beast.stun_remaining <= 0.0 and player.flash_cooldown <= 0.0:
			level.use_flash(player))


func hide() -> void:
	await _load()
	var props: ChaseProps = level.props
	var spot := -1
	for index in range(props.spots.size()):
		if not props.spots[index]["woods"]:
			spot = index
			break
	var target: Vector2 = props.spots[spot]["position"]
	player.position = target + Vector2(-40, 0)
	var stalker: CampKiller = level.killer
	stalker.position = target + Vector2(120, 30)
	await _record("hide", 70, func(index: int) -> void:
		if index < 12:
			Input.action_press("move_right")
		elif index == 12:
			Input.action_release("move_right")
			player.position = target + Vector2(-6, 0)
			props.hide_actor(player, spot)
		elif index == 16:
			stalker.enabled = true
			stalker.hear_stimulus(target + Vector2(-60, 0), INF))


func door() -> void:
	await _load()
	var props: ChaseProps = level.props
	var building: CampBuilding = level.camp_map.buildings[0]
	var index := props.doors.find(props.doors.filter(func(row: Dictionary) -> bool: return row["label"] == building.label)[0])
	player.position = building.door + Vector2(0, 50)
	var stalker: CampKiller = level.killer
	stalker.position = building.door + Vector2(0, 150)
	stalker.enabled = true
	await _record("door", 150, func(frame: int) -> void:
		if frame < 14:
			Input.action_press("move_up")
			Input.action_press("sprint")
		elif frame == 14:
			Input.action_release("sprint")
			props.toggle_door(player, index)
		elif frame < 19:
			Input.action_press("move_up")
		else:
			Input.action_release("move_up")
		if frame >= 16 and props.doors[index]["broken"] <= 0.0:
			# It heard the slam and throws itself at the door (just outside it).
			stalker.state = CampKiller.State.PATROL
			stalker.hear_stimulus(building.door + Vector2(0, 12), INF)
			# Navigation stops a few pixels short of the porch; close the gap so
			# the real door-breaking rule takes over (clip staging only).
			if stalker.global_position.distance_to(building.door) < 70:
				stalker.position = stalker.position.move_toward(building.door + Vector2(0, 8), 2.0))


func snare() -> void:
	await _load("groundskeeper")
	var at := _trail()
	level.plan.woods.visited[level.plan.woods.cell_at(at)] = true
	level.snares.try_place(at)
	player.position = at + Vector2(-90, 0)
	var keeper: CampKiller = level.killer
	keeper.position = at + Vector2(200, -10)
	await _record("snare", 64, func(index: int) -> void:
		if index == 30:
			keeper.enabled = true
		Input.action_press("move_right"))


func van() -> void:
	await _load("stalker", true)
	level.van.installed.assign(level.plan.required)
	player.position = level.van.interaction_point()
	player.facing = Vector2.UP
	var wolf := _cryptid("werewolf")
	wolf.position = level.van.global_position + Vector2(260, 120)
	# Most of the 2 s start hold happens before recording begins.
	Input.action_press("interact")
	for tick in range(45):
		await physics_frame
	await _record("van", 70, func(index: int) -> void:
		if not level.van.running:
			Input.action_press("interact")
		else:
			Input.action_release("interact")
			wolf.enabled = true)


func signal_fire() -> void:
	await _load("stalker", true)
	var fire: SignalFire = level.signal_fire
	fire.installed.assign(SignalFire.PARTS)
	player.position = fire.pyre + Vector2(0, 40)
	player.facing = Vector2.UP
	await _record("signal_fire", 56, func(index: int) -> void:
		if index == 6:
			level.try_interact(player)
		if index > 20:
			Input.action_press("move_down"))
