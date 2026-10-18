extends SceneTree
## Notebook, map markers, moon dial and phase broadcast logic (headless).
## Staged: seed 42, all escapes forced (diagnostic), enemies frozen.
var level: Node2D
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": name, "passed": ok}))

func _frames(count: int) -> void:
	for index in range(count):
		await process_frame
		await physics_frame

func _key(code: Key, shift: bool = false) -> void:
	var press := InputEventKey.new()
	press.physical_keycode = code
	press.keycode = code
	press.shift_pressed = shift
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	var release := press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)

func _run() -> void:
	RoundPlan.force_all_escapes = true
	RoundPlan.force_modifiers = ["blood_moon"]
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await _frames(12)
	level = current_scene
	level.player.local_input = false
	for enemy in get_nodes_in_group("killers"):
		enemy.enabled = false
	level.night_clock.set_physics_process(false)
	var book: CampNotebook = level.hud.notebook
	var chart: Control = level.hud.chart
	# Paging: Tab map → plan → guide → log → closed; Shift+Tab back; Esc closes first.
	await _key(KEY_TAB)
	_check(book.visible and book.view == "map", "tab_opens_map")
	await _key(KEY_TAB)
	await _key(KEY_TAB)
	await _key(KEY_TAB)
	_check(book.visible and book.view == "log", "tab_pages_to_log")
	await _key(KEY_TAB)
	_check(not book.visible, "tab_after_log_closes")
	await _key(KEY_TAB)
	await _key(KEY_TAB, true)
	_check(not book.visible, "shift_tab_from_map_closes")
	await _key(KEY_T)
	_check(book.visible and book.view == "plan" and level.objective_page == 0, "t_opens_plan_without_changing_route")
	await _key(KEY_T)
	_check(level.objective_page == 1 and chart.route_parts() == ["rescue_fuse"], "t_cycles_route_and_map_follows")
	await _key(KEY_ESCAPE)
	_check(not book.visible and not level.paused, "escape_closes_notebook_not_pause")
	level.select_route(0)
	# Live objective markers: installed parts drop off the map.
	var before: Array = chart.objective_items().map(func(item: Dictionary) -> String: return item["kind"])
	for pickup in level.pickups:
		if pickup.kind == "battery":
			pickup.consume()
	level.player.inventory.append("battery")
	level.player.position = level.van.interaction_point()
	level.van.deliver(level.player)
	var after: Array = chart.objective_items().map(func(item: Dictionary) -> String: return item["kind"])
	_check("battery" in before and "battery" not in after, "installed_part_leaves_map")
	# A dropped part shows where it lies, as dropped.
	level.spawn_dropped("key", Vector2(400, 400))
	_check(chart.objective_items().any(func(item: Dictionary) -> bool: return item["kind"] == "key" and item["dropped"] and item["position"] == Vector2(400, 400)), "dropped_part_marked_live")
	# Hidden woods caches stay hidden until explored or revealed.
	var hidden: Array = chart.objective_items().filter(func(item: Dictionary) -> bool: return CampMap.is_woods(item["position"]) and not item["dropped"])
	_check(hidden.all(func(item: Dictionary) -> bool: return level.plan.woods.visited.has(level.plan.woods.cell_at(item["position"])) or int(level.clues.get(item["kind"], 0)) >= 2), "unexplored_caches_stay_hidden")
	# Teammates appear (downed ones too).
	var mate: CampPlayer = preload("res://scenes/actors/player.tscn").instantiate()
	mate.position = level.player.position + Vector2(40, 0)
	mate.local_input = false
	mate.config = level.config
	level.world_objects.add_child(mate)
	await _frames(2)
	_check(chart.teammates().size() == 1, "teammate_on_map")
	mate.set_status(CampPlayer.Status.DOWNED)
	_check(chart.teammates().size() == 1 and chart.teammates()[0][0].status == CampPlayer.Status.DOWNED, "downed_teammate_on_map")
	mate.queue_free()
	await _frames(2)
	# Next step comes from the plan text.
	book.open_view("map")
	await _frames(2)
	_check(not book.next_step().is_empty() and book.side_label.text.contains("NEXT:"), "map_shows_next_step")
	# Moon dial: new before Nightfall, waxing, full while out.
	var clock: NightClock = level.night_clock
	_check(MoonDial.fullness(clock) == 0.0, "moon_new_before_nightfall")
	clock.phase = 1
	clock.moon_span = 100.0
	clock.moon_clock = 25.0
	_check(is_equal_approx(MoonDial.fullness(clock), 0.75), "moon_waxes_toward_next_rise")
	clock.set_moon(true)
	_check(MoonDial.fullness(clock) == 1.0 and clock.moon_span == clock.moon_clock, "moon_full_while_out")
	_check(level.plan.has_modifier("blood_moon"), "blood_moon_fixture")
	var snapshot := clock.snapshot()
	_check(snapshot.has("moon_clock") and snapshot.has("moon_span") and snapshot.has("radio"), "moon_and_radio_replicate")
	# Phase change on this peer: title + radio transcript with the radio text.
	clock.phase = 1
	clock._enter_phase(2)
	clock.phase = 2
	await _frames(3)
	var cast: NightBroadcast = level.hud.broadcast
	_check(cast.title_phase == 2 and cast.title_alpha() > 0.0, "phase_title_shown")
	_check(cast.radio_time >= 0.0 and cast.radio_text.contains(clock.radio_text), "radio_transcript_matches_radio")
	await _frames(4)
	_check(book.log_lines.any(func(line: String) -> bool: return line.contains("DEEP NIGHT")), "log_keeps_phase_announcement")
	print(JSON.stringify({"event": "test_result", "suite": "notebook", "checks": checks, "failures": failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)
