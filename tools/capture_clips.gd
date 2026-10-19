extends SceneTree
## README clips: short scripted moments recorded as PNG frames (15 fps) into
## artifacts/clips/<name>/, then turned into GIFs by tools/build_clips.py.
## Real game, real HUD and creature brains; the night is brightened slightly so
## the action is readable. Run: godot --path . --fixed-fps 30 --audio-driver Dummy
##   --script res://tools/capture_clips.gd [-- --clip=<name>]
var level: Node2D
var player: CampPlayer
const AMBIENT := Color(0.42, 0.44, 0.5)
## Per-clip override: fire and headlight clips read best at real night darkness.
var ambient := AMBIENT
const CLIPS := ["storm", "stalker_stalking", "stalker_grab", "mimic", "imps", "owl", "witch_frog", "bigfoot_yeet", "werewolf_moon", "bear_hug", "moth_face", "door", "van",
	"groundskeeper_mower", "cuckoo", "banshee", "slug", "surveyor", "hitchhiker", "tollkeeper", "echo", "fortune_teller"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--clip="):
			only = argument.get_slice("=", 1)
	for name: String in CLIPS:
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
	root.get_node("Session").survivor = "john"
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	var previous := level
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await process_frame
	while current_scene == null or current_scene.name != "ForestLevel" or current_scene == previous:
		await process_frame
	level = current_scene
	player = level.player
	player.local_input = true
	level.night_clock.director_enabled = false
	level.message_time = 0.0
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	for index in range(8):
		await process_frame
	# Clips start mid-night: no opening Dusk title or place title over the action.
	level.hud.broadcast.shown_phase = level.night_clock.phase
	level.hud.broadcast.title_time = -1.0
	level.hud.broadcast.place = "SKIP"
	level.hud.broadcast.place_time = -1.0


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
		# Physics runs at 60 steps/s: four per 15 fps frame is real time.
		for tick in range(4):
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


## A creature for the clip at `offset` from `at`.
func _spawn(species: String, at: Vector2, offset: Vector2) -> CampCryptid:
	var enemy: CampCryptid = preload("res://scenes/actors/cryptid.tscn").instantiate()
	enemy.species = species
	enemy.config = level.config
	enemy.position = at + offset
	enemy.patrol.assign([at + offset, at + offset + Vector2(30, 0)])
	level.world_objects.add_child(enemy)
	enemy.facing = Vector2.LEFT
	return enemy


func _start(at: Vector2, facing := Vector2.RIGHT) -> void:
	player.position = at
	player.facing = facing
	player.flashlight_on = true
	player.get_node("Camera2D").reset_smoothing()
	level.message_time = 0.0


func storm() -> void:
	await _load()
	_start(_trail() + Vector2(-150, 0))
	level.night_clock._start_event("storm")
	level.message_time = 0.0
	await _record("storm", 90, func(index: int) -> void:
		Input.action_press("move_right")
		if index in [8, 34, 60, 80]:
			level.night_clock.lightning = 0.18)


## The stalker catches a wounded survivor, carries them off (jolting them on
## his shoulder), and they tear free, losing what they held.
func stalker_grab() -> void:
	await _load()
	var at := _trail()
	_start(at)
	player.health = 40.0
	player.supplies["flare"] = 2
	player.selected_slot = 0
	var stalker: CampKiller = level.killer
	# Night 42 is foggy (sight ~108 px): he starts inside it.
	stalker.position = at + Vector2(85, 0)
	stalker.tier = 2
	stalker.enabled = true
	await _record("stalker_grab", 112, func(index: int) -> void:
		# Mash E from about four seconds in, as fast as a player would.
		if index >= 62 and index % 2 == 0 and player.has_effect("held"):
			level.try_interact(player)
		if index >= 62 and not player.has_effect("held") and not player.has_effect("tripped"):
			Input.action_press("move_left")
			Input.action_press("sprint"))


## Nightfall: the stalker shadows a survivor just outside their light and
## scrawls on the ground behind them. They turn around: the beam finds the
## message, and him for an instant, before he melts back into the dark.
## A long straight east-west trail: seven cells in a row.
func _long_trail() -> Vector2:
	var woods: WoodsLayout = level.plan.woods
	for cell: Vector2i in woods.links:
		var straight := true
		for step in range(-3, 4):
			var here := cell + Vector2i(step, 0)
			var links: Array = woods.links.get(here, [])
			if not (here + Vector2i.LEFT in links and here + Vector2i.RIGHT in links) or not woods.zone_at(woods.center(here)).is_empty():
				straight = false
				break
		if straight and woods.center(cell).distance_to(CampMap.CAMP_BOUNDS.get_center()) > 1300:
			return woods.center(cell)
	return _trail()


func stalker_stalking() -> void:
	await _load()
	var at := _long_trail()
	_start(at + Vector2(-60, 0))
	level.night_clock.force_phase(1)
	level.message_time = 0.0
	var stalker: CampKiller = level.killer
	stalker.position = player.position + Vector2(-260, 0)
	stalker.traits.favourite = player
	stalker.traits.shadow_clock = 0.0
	stalker.traits.lunge_at = 999.0
	stalker.traits.next_card = "I SEE YOU"
	stalker.traits.card_clock = 3.2
	stalker.state = CampKiller.State.PATROL
	stalker.enabled = true
	await _record("stalker_stalking", 108, func(index: int) -> void:
		player.notice_time = 0.0 if index < 60 else player.notice_time
		if index < 26:
			Input.action_press("move_right")
		else:
			Input.action_release("move_right")
			# Turn around slowly: the beam sweeps back across the trail.
			var turn := clampf((index - 62) / 12.0, 0.0, 1.0)
			player.facing = Vector2.RIGHT.rotated(PI * turn * (1.0 if turn < 1.0 else 1.0)).normalized())


## A "teammate" waves and calls out, walks up... and shows its teeth.
func mimic() -> void:
	await _load()
	var at := _trail()
	_start(at)
	var mimic := _spawn("mimic", at, Vector2(170, 0))
	mimic.brain.masked = true
	mimic.brain.role = "john"
	mimic.brain.mask_name = "SAM"
	mimic.brain.call_clock = 0.4
	mimic.enabled = true
	await _record("mimic", 104, func(index: int) -> void:
		if mimic.brain.revealed > 0.0 and not player.has_effect("tripped"):
			Input.action_press("move_left")
			Input.action_press("sprint"))


## The imps trip you, grab what you were holding and run off to hide it.
func imps() -> void:
	await _load()
	var at := _trail()
	_start(at + Vector2(-60, 0))
	player.pack("battery_pack")
	player.selected_slot = player.belt.find("battery_pack")
	var imps := _spawn("imps", at, Vector2(90, 0))
	imps.brain.cooldown = 0.0
	imps.enabled = true
	await _record("imps", 84, func(index: int) -> void:
		if index < 10:
			Input.action_press("move_right")
		else:
			Input.action_release("move_right"))


## A survivor alone on the trail: the owl's shadow grows, it snatches them
## and carries them far away.
func owl() -> void:
	await _load()
	var at := _trail()
	_start(at)
	var owl := _spawn("owl", at, Vector2(-50, -30))
	owl.brain.cooldown = 0.0
	owl.enabled = true
	await _record("owl", 168, func(index: int) -> void:
		if index < 12:
			Input.action_press("move_right")
		else:
			Input.action_release("move_right"))


## The witch's bolt turns a survivor into a frog.
func witch_frog() -> void:
	await _load()
	var at := _trail()
	_start(at)
	var witch := _spawn("witch", at, Vector2(170, -6))
	witch.brain.forced = "frog"
	witch.brain.cast_cooldown = 0.0
	witch.enabled = true
	await _record("witch_frog", 80, func(index: int) -> void:
		if player.has_effect("frog"):
			witch.enabled = false
			Input.action_press("move_left"))


## Sneak up on Bigfoot in the dark and get thrown across the clearing.
func bigfoot_yeet() -> void:
	await _load()
	var at := _trail()
	_start(at + Vector2(-70, 0))
	player.flashlight_on = false
	var foot := _spawn("bigfoot", at, Vector2(60, 0))
	foot.enabled = true
	await _record("bigfoot_yeet", 56, func(index: int) -> void:
		if player.knock.length() < 30.0 and player.health >= 100.0:
			Input.action_press("move_right")
		else:
			Input.action_release("move_right"))


## A friendly hiker... until the moon comes out. A flare drives it off.
func werewolf_moon() -> void:
	await _load()
	var at := _trail()
	_start(at)
	level.night_clock.moon = false
	var wolf := _spawn("werewolf", at, Vector2(120, 0))
	wolf.enabled = true
	await _record("werewolf_moon", 96, func(index: int) -> void:
		if index == 16:
			level.night_clock.set_moon(true)
		if index == 58:
			player.facing = Vector2.RIGHT
			level.use_supply(player, "flare")
		if index > 60:
			Input.action_press("move_left"))


## Bear Hug plods after you, hugs you, and you wriggle free.
func bear_hug() -> void:
	await _load()
	var at := _trail()
	_start(at + Vector2(40, 0), Vector2.LEFT)
	var bear := _spawn("teddy", at, Vector2(120, 0))
	bear.enabled = true
	var hugged := [false]
	await _record("bear_hug", 110, func(index: int) -> void:
		# Back away a little, then get caught, wriggle free and leave.
		if index < 8:
			Input.action_press("move_left")
		elif not hugged[0]:
			Input.action_release("move_left")
		if player.has_effect("held"):
			if not hugged[0]:
				hugged[0] = index
			elif index > hugged[0] + 8 and index % 2 == 0:
				level.try_interact(player)
		elif hugged[0]:
			Input.action_press("move_left"))


## A moth lands on your face; a flash swats it off.
func moth_face() -> void:
	await _load()
	var at := _trail()
	_start(at)
	var moth := _spawn("lantern_moth", at, Vector2(150, -10))
	moth.enabled = true
	var swatted := [false]
	await _record("moth_face", 64, func(index: int) -> void:
		if player.has_effect("face_moth") and player.effects["face_moth"] < 7.6 and not swatted[0]:
			swatted[0] = true
			player.flash_cooldown = 0.0
			level.use_flash(player))


func door() -> void:
	await _load()
	# Doors are a second-half fight: camp opens to creatures at Deep Night.
	level.open_camp()
	var props: ChaseProps = level.props
	var building: CampBuilding = level.camp_map.buildings[0]
	var index := props.doors.find(props.doors.filter(func(row: Dictionary) -> bool: return row["label"] == building.label)[0])
	_start(building.door + Vector2(0, 50), Vector2.UP)
	player.local_input = false
	var stalker: CampKiller = level.killer
	stalker.position = building.door + Vector2(0, 150)
	stalker.enabled = true
	await _record("door", 150, func(frame: int) -> void:
		player.local_input = true
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


func van() -> void:
	await _load("stalker", true)
	level.van.installed.assign(level.plan.required)
	_start(level.van.interaction_point(), Vector2.UP)
	# Most of the 2 s start hold happens before recording begins.
	Input.action_press("interact")
	for tick in range(45):
		await physics_frame
	await _record("van", 70, func(index: int) -> void:
		if not level.van.running:
			Input.action_press("interact")
		else:
			Input.action_release("interact"))


## The Groundskeeper's mower comes down the trail in its headlight and runs
## the survivor over.
func groundskeeper_mower() -> void:
	await _load()
	var at := _trail()
	_start(at)
	var keeper := _spawn("groundskeeper", at, Vector2(230, 0))
	keeper.brain.heading = Vector2.LEFT
	keeper.patrol.assign([at + Vector2(-300, 0), at + Vector2(230, 0)])
	keeper.enabled = true
	await _record("groundskeeper_mower", 75, func(index: int) -> void:
		if player.knock.length() > 30.0 or player.health < 100.0:
			Input.action_release("move_right"))


## Three CUCKOOs while you're in its sight, and you're back where you were.
func cuckoo() -> void:
	await _load()
	var at := _trail()
	_start(at + Vector2(-120, 0))
	var bird := _spawn("cuckoo", at, Vector2(110, 0))
	bird.brain.cooldown = 1.0
	bird.enabled = true
	await _record("cuckoo", 90, func(index: int) -> void:
		if not player.has_effect("rewound") and index < 70:
			Input.action_press("move_right")
		else:
			Input.action_release("move_right"))


## The Banshee draws breath, then screams: deafened.
func banshee() -> void:
	await _load()
	var at := _trail()
	_start(at)
	var ghost := _spawn("banshee", at, Vector2(150, 0))
	ghost.brain.cooldown = 0.0
	ghost.enabled = true
	await _record("banshee", 80, func(index: int) -> void:
		if player.has_effect("deaf") and index > 50:
			Input.action_press("move_left"))


## Step in the slug's trail and skate.
func slug() -> void:
	await _load()
	var at := _trail()
	_start(at + Vector2(-110, 0))
	var slug := _spawn("slug", at, Vector2(120, 0))
	for index in range(14):
		slug.brain.puddles.append([at + Vector2(-60 + index * 9, randf_range(-3, 3)), 60.0])
	slug.enabled = true
	await _record("slug", 80, func(index: int) -> void:
		if index < 30:
			Input.action_press("move_right")
		elif index < 55:
			Input.action_release("move_right")
			Input.action_press("move_left")
		else:
			Input.action_release("move_left"))


## The Surveyor's touch: LOST. The map is scribble.
func surveyor() -> void:
	await _load()
	var at := _trail()
	_start(at)
	var man := _spawn("surveyor", at, Vector2(110, 0))
	player.flashlight_on = false
	man.enabled = true
	await _record("surveyor", 90, func(index: int) -> void:
		if player.has_effect("lost") and not level.hud.notebook.visible and index > 10:
			man.enabled = false
			level.hud.notebook.open_view("map"))


## The Hitchhiker climbs on and switches your light off.
func hitchhiker() -> void:
	await _load()
	var at := _trail()
	_start(at)
	var child := _spawn("hitchhiker", at, Vector2(90, 0))
	child.enabled = true
	await _record("hitchhiker", 90, func(index: int) -> void:
		if player.has_effect("piggyback"):
			child.brain.prank_clock = minf(child.brain.prank_clock, 2.0)
			Input.action_press("move_left"))


## Walk past the Tollkeeper unpaid: shoved back. Pay, and through you go.
func tollkeeper() -> void:
	await _load()
	var at := _trail()
	_start(at + Vector2(-60, 0))
	player.pack("flare")
	var troll := _spawn("tollkeeper", at, Vector2(0, 0))
	troll.enabled = true
	var paid := [false]
	await _record("tollkeeper", 96, func(index: int) -> void:
		if index == 40 and not paid[0]:
			paid[0] = true
			Input.action_release("move_right")
			player.global_position = troll.global_position + Vector2(-30, 0)
			level.try_interact(player)
		elif index < 36 or index > 48:
			Input.action_press("move_right")
		else:
			Input.action_release("move_right"))


## The Echo whistles the camp song (notes rise); step close with the light
## on it and it bursts into smoke.
func echo() -> void:
	await _load()
	var at := _trail()
	_start(at + Vector2(-90, 0), Vector2.RIGHT)
	var shade := _spawn("echo", at, Vector2(60, 0))
	shade.patrol.assign([at + Vector2(60, 0)])
	shade.brain.whistle_clock = 0.3
	shade.enabled = true
	await _record("echo", 72, func(index: int) -> void:
		if index > 38 and index < 52:
			Input.action_press("move_right")
		else:
			Input.action_release("move_right"))


## The Fortune Teller reaches you and turns a card.
func fortune_teller() -> void:
	await _load()
	var at := _trail()
	_start(at)
	var seer := _spawn("fortune_teller", at, Vector2(70, 0))
	seer.brain.cooldown = 0.0
	seer.enabled = true
	await _record("fortune_teller", 86, func(index: int) -> void:
		pass)
