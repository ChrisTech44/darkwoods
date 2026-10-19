extends SceneTree
## Normal-route fixtures (never --all-escapes), bounded difficulty and visuals.
var checks := 0
var failures := 0
var level: Node2D

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": ok}))

func frames(count: int) -> void:
	for index in range(count): await physics_frame

func shot(label: String) -> void:
	await frames(4)
	await process_frame
	RenderingServer.force_draw(true)
	check(root.get_texture().get_image().save_png("res://artifacts/playtest_balance/" + label + ".png") == OK, "capture_" + label)

func _run() -> void:
	RoundPlan.force_all_escapes = false
	RoundPlan.force_modifiers = []
	var seeds := {}
	for value in range(1, 100):
		var plan := RoundPlan.new()
		plan.generate(value, "woods")
		seeds[plan.escape_options[1]] = value
		if seeds.size() == 4: break
	check(seeds.size() == 4, "normal_seeds_cover_four_secondary_routes")
	for route: String in seeds:
		root.get_node("Session").mode = "woods"
		root.get_node("Session").survivor = "christian"
		root.get_node("Session").next_seed = seeds[route]
		change_scene_to_file("res://scenes/world/forest_level.tscn")
		await frames(12)
		level = current_scene
		level.night_clock.set_physics_process(false)
		for enemy in get_nodes_in_group("killers"): enemy.enabled = false
		level.player.local_input = false
		level.select_route(1)
		check(level.plan.escape_options.size() == 2 and level.current_page() == route, "normal_route_" + route)
		check((level.escapes.gate_body != null) == (route == "gate"), "gate_collision_only_on_gate_night_" + route)
		for pickup in level.pickups:
			if pickup.kind in FieldEscapes.BOAT_PARTS:
				check(route == "boat", "no_inactive_boat_part")
			if pickup.kind in FieldEscapes.GATE_CODES:
				check(route == "gate", "no_inactive_gate_part")
		if route != "boat": continue
		var actor: CampPlayer = level.player
		actor.position = level.escapes.boat_point
		actor.facing = Vector2.UP
		actor.flashlight_on = true
		check(is_equal_approx(actor.flashlight_charge / actor.light_drain, 420.0), "full_light_lasts_420_seconds")
		var at := actor.position
		actor._physics_process(3.0)
		check(is_equal_approx(actor.flashlight_charge, 90.0 - 3.0 * 90.0 / 420.0), "three_seconds_uses_seven_minute_drain")
		actor.position = at
		actor.inventory.append("outboard_motor")
		for pickup in level.pickups:
			if pickup.kind == "outboard_motor": pickup.consume()
		check(level.escapes.prompt(actor).contains("INSTALL MOTOR"), "repair_prompt_names_carried_part")
		check(level.escapes.pack_text("boat").contains("YOU → DOCK REPAIR"), "plan_directs_carried_motor_to_dock")
		check(not ObjectiveState.on_ground(level, "outboard_motor"), "carried_part_is_not_ground_objective")
		var killer: CampKiller = level.killer
		level.night_clock.phase = 3
		killer.state = CampKiller.State.CHASE
		killer.traits.chase_time = 17.9
		killer.traits.physics(0.2)
		check(killer.state == CampKiller.State.PATROL and killer.recover_remaining >= 3.0, "long_chase_returns_to_stalking_with_head_start")
		level.plan.night_events.clear()
		level.night_clock.phase_elapsed = 100000.0
		level.night_clock.advance(0.0)
		check(level.night_clock.dread <= 80.0, "long_finale_pressure_plateaus")
		if "--capture" in OS.get_cmdline_user_args():
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/playtest_balance"))
			level.night_clock.active = false
			level.hud.broadcast.hide() # Isolate repair UI; normal lighting, frozen AI.
			level.message_time = 0.0
			level.player.notice_time = 0.0
			level.hud.notebook.close()
			await shot("boat_repair_motor")
			level.hud.notebook.open_view("plan")
			await shot("boat_plan_carried")
			level.hud.notebook.close()
		level.escapes.interact(actor)
		check(ObjectiveState.installed(level, "outboard_motor"), "fitted_part_is_complete")
		if "--capture" in OS.get_cmdline_user_args():
			await shot("boat_repair_installed")
			var witch: CampCryptid
			for enemy in get_nodes_in_group("cryptids"):
				if enemy.species == "witch": witch = enemy
			witch.position = actor.position + Vector2(55, 0)
			for kind: String in witch.brain.CURSES:
				witch.casting = true
				witch.cast_remaining = 0.4
				witch.brain.cast_kind = kind
				witch.queue_redraw()
				await shot("witch_" + kind)
	print(JSON.stringify({"event": "test_result", "suite": "playtest_balance", "checks": checks, "failures": failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)
