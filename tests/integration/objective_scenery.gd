extends SceneTree
## Normal two-route nights; --capture uses actual rendering, normal light/sight,
## frozen AI/clock and staged poses. Voice stays off. No forced escape fixture.
const OUT := "res://artifacts/objective_scenery/"
var checks := 0
var failures := 0
var capture := false
var level: Node2D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(JSON.stringify({"event":"assertion", "name":label, "passed":ok}))

func frames(count: int = 6) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	root.get_node("Voice").mode = "off"
	RoundPlan.force_all_escapes = false
	RoundPlan.force_modifiers = []
	var seeds := {"boat":13}
	for value in range(1, 100):
		var plan := RoundPlan.new()
		plan.generate(value, "woods")
		if not seeds.has(plan.escape_options[1]): seeds[plan.escape_options[1]] = value
		if seeds.size() == 4: break
	check(seeds.size() == 4, "four_normal_secondary_routes")
	if capture: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for route: String in seeds:
		root.get_node("Session").mode = "woods"
		root.get_node("Session").next_seed = seeds[route]
		change_scene_to_file("res://scenes/world/forest_level.tscn")
		await frames(12)
		level = current_scene
		level.player.local_input = false
		level.night_clock.active = false
		level.night_clock.set_physics_process(false)
		for enemy in get_nodes_in_group("killers"): enemy.enabled = false
		check(level.plan.escape_options == ["van", route], route + "_normal_routes")
		check(level.rescue.get_child_count() > 0 and level.escapes.art != null, route + "_permanent_structure_layers")
		check((level.escapes.gate_body != null) == (route == "gate"), route + "_gate_collision_unchanged")
		check((level.signal_fire.glow != null) == (route == "signal"), route + "_pyre_light_only_when_active")
		var actor: CampPlayer = level.player
		actor.flashlight_on = true
		actor.set_physics_process(false)
		if route not in ["radio", "gate"]:
			actor.position = level.rescue.power_point
			actor.inventory.append("rescue_fuse")
			check(level.rescue.prompt(actor).is_empty() and not level.rescue.interact(actor) and "rescue_fuse" in actor.inventory and not level.rescue.powered, route + "_inactive_power_rejects_interaction")
			check(level.rescue.lamps.is_empty(), route + "_no_inactive_power_lights")
		if route != "radio":
			actor.position = level.rescue.relay_point
			check(level.rescue.prompt(actor).is_empty() and not level.rescue.interact(actor), route + "_inactive_relay_rejects_interaction")
		if route != "boat":
			actor.position = level.escapes.boat_point
			check(level.escapes.prompt(actor).is_empty() and not level.escapes.interact(actor), route + "_inactive_boat_rejects_interaction")
		if route != "gate":
			actor.position = level.escapes.gate_point
			check(level.escapes.prompt(actor).is_empty() and not level.escapes.interact(actor), route + "_inactive_gate_rejects_interaction")
		if route != "signal":
			actor.position = level.signal_fire.pyre
			check(level.signal_fire.prompt(actor).is_empty() and not level.signal_fire.interact(actor), route + "_inactive_pyre_rejects_interaction")
		if not capture: continue
		# No ambient/sight changes. Both approaches reproduce the original diagnosis.
		await shot(route + "_power_front", 9, Vector2(0, 70), Vector2.UP, "f5_breaker")
		await shot(route + "_power_north", 9, Vector2(0, -125), Vector2.DOWN, "f5_breaker")
		await shot(route + "_relay", 10, Vector2(0, 100), Vector2.UP, "f5_relay")
		await shot(route + "_logging", 11, Vector2(0, -45), Vector2.DOWN, "f5_logging")
		await shot(route + "_lakeshore", 12, Vector2(0, 130), Vector2.UP, "f5_boathouse")
		await shot(route + "_hull", 12, Vector2(0, -105), Vector2.UP, "")
		await shot(route + "_ranger", 13, Vector2(0, 560), Vector2.UP, "f5_ranger_booth")
		await shot(route + "_pyre", 7, Vector2(0, -100), Vector2.UP, "pyre")
		# A silhouette must disappear when its front anchor leaves sight.
		actor.position = CampMap.CAMP_BOUNDS.get_center()
		await frames()
		var standing: StandingProps = level.get_node("StandingProps")
		var canvas_id: int = level.rescue.get_child(0).get_instance_id()
		check(not standing.props.values().any(func(entry: Dictionary) -> bool: return entry["canvas"] == canvas_id and entry["sprite"].visible), route + "_machinery_hidden_after_leaving")
	print(JSON.stringify({"event":"test_result", "suite":"objective_scenery", "checks":checks, "failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(1 if failures else 0)

func shot(label: String, zone: int, offset: Vector2, facing: Vector2, prop: String) -> void:
	level.player.position = level.plan.woods.zones[zone]["position"] + offset
	level.player.facing = facing
	# Frame tall props above the HUD; camera offset only, no world/light changes.
	var camera: Camera2D = level.player.get_node("Camera2D")
	camera.offset = Vector2.ZERO
	camera.position = Vector2(60 if zone in [12, 13] else 0, -35 if facing == Vector2.UP else (80 if zone == 9 else 0))
	camera.force_update_scroll()
	level.player.flashlight_charge = 90
	await frames(4)
	await process_frame
	# Synchronous draw also works when macOS suppresses background window draws.
	RenderingServer.force_draw(true)
	check(root.get_texture().get_image().save_png(OUT + label + ".png") == OK, "capture_" + label)
	if not prop.is_empty():
		var standing: StandingProps = level.get_node("StandingProps")
		check(standing.props.values().any(func(entry: Dictionary) -> bool: return entry["sprite"].visible and entry["sprite"].get_meta("prop", "") == prop and entry["sprite"].position.distance_to(level.player.position) < 400), label + "_visible_" + prop)
