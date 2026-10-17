extends "res://tests/integration/offline_playthrough.gd"
## Active expedition using ordinary input. The bot uses navigation as a route guide.

var supply_cooldown: int = 0
var walked: float = 0.0


func _run() -> void:
	root.get_node("Session").mode = "woods"
	root.get_node("Session").survivor = "quartermaster"
	root.get_node("Session").next_seed = 42
	capture = "--capture" in OS.get_cmdline_user_args()
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await _frames(3)
	level = current_scene
	player = level.player
	# Route/mechanics regression: reveal staged parts now and keep the director out;
	# night pacing has its own suite (night_phases.gd).
	level.night_clock.director_enabled = false
	level.night_clock.reveal_all()
	print(JSON.stringify({"event": "expedition_start", "seed": level.plan.seed_value, "weather": level.plan.weather, "encounters": level.plan.encounters, "required": level.plan.required}))
	# Camp preparations first, then choose the nearest remaining cache by path length.
	var targets: Array[CampPickup] = []
	for kind in ["battery_pack", "battery", "flare", "boltcutters", "key"]:
		for pickup: CampPickup in level.pickups:
			if pickup.kind == kind and not CampMap.is_woods(pickup.position):
				targets.append(pickup)
	for target in targets:
		if not await _collect(target):
			_finish()
			return
	var remaining: Array[CampPickup] = []
	for pickup: CampPickup in level.pickups:
		if pickup.locked:
			remaining.append(pickup)
	while not remaining.is_empty():
		var closest: CampPickup
		var shortest := INF
		for pickup in remaining:
			var path := NavigationServer2D.map_get_path(level.get_world_2d().navigation_map, player.global_position, pickup.position, true)
			var distance := 0.0
			for index in range(1, path.size()):
				distance += path[index - 1].distance_to(path[index])
			if distance < shortest:
				closest = pickup
				shortest = distance
		if not await _collect(closest):
			_finish()
			return
		for site: ForestSite in level.camp_map.sites:
			if site.definition["kind"] in ["village", "graveyard"] and site.definition["bounds"].has_point(closest.position):
				for action in site.actions:
					if action["kind"] in ["supplies", "crypt"] and not action["used"]:
						if not await _navigate_to(action["position"]):
							_finish()
							return
						await _tap(KEY_E)
						_check(action["used"], "input_searches_" + action["kind"])
		remaining.erase(closest)
	_check(level.plan.required.all(func(kind: String) -> bool: return kind in player.inventory), "five_parts_collected_via_input")
	if not await _navigate_to(level.van.interaction_point()):
		_finish()
		return
	await _tap(KEY_E)
	_check(level.van.installed.size() == 5, "five_parts_installed_via_input")
	await _hold(KEY_E, 130)
	await _frames(ceili(level.config.extraction_seconds * 60) + 10)
	_check(level.finished and level.won and player.status == CampPlayer.Status.ESCAPED, "woods_input_only_escape_with_all_enemies_active")
	if capture:
		await _snapshot("woods_playthrough_win")
	print(JSON.stringify({"event": "expedition_distance", "pixels": walked, "visited_clearings": level.plan.woods.visited.size(), "flares_left": player.supplies["flare"]}))
	_finish()


func _collect(pickup: CampPickup) -> bool:
	if not await _navigate_to(pickup.position):
		return false
	await _tap(KEY_E)
	_check(not pickup.available, "input_collect_" + pickup.kind)
	return not pickup.available


func _leg(points: Array) -> bool:
	for destination: Vector2 in points:
		var reached := false
		# Roads make long straight path segments; budget 1.6x the walking time (min 15s).
		var budget := maxi(900, ceili(player.position.distance_to(destination) / player.config.walk_speed * 60.0 * 1.6))
		for index in range(budget):
			var offset := destination - player.position
			if offset.length() < 2:
				reached = true
				break
			if player.status != CampPlayer.Status.ALIVE:
				break
			for action in ["move_left", "move_right", "move_up", "move_down", "sprint"]:
				Input.action_release(action)
			var chasing := false
			var nearby_moth := false
			var danger := INF
			for enemy: CampKiller in get_nodes_in_group("killers"):
				var distance := player.position.distance_to(enemy.position)
				if enemy is CampCryptid and enemy.species == "lantern_moth" and distance < 230:
					nearby_moth = true
				if enemy.state == CampKiller.State.CHASE and distance < 180:
					chasing = true
				if distance < 90 and enemy.has_line_of_sight(player.position):
					chasing = true
				if enemy.fears_flare() and (enemy.state == CampKiller.State.CHASE or distance < 48 and enemy.has_line_of_sight(player.position)) and enemy.nearby_flare() == Vector2.INF:
					danger = minf(danger, distance)
			if nearby_moth == player.flashlight_on and (nearby_moth or player.flashlight_charge > 0):
				await _tap(KEY_F)
			supply_cooldown = maxi(0, supply_cooldown - 1)
			if danger < 48 and supply_cooldown == 0 and player.supplies["flare"] > 0:
				await _tap(KEY_Q)
				print(JSON.stringify({"event": "expedition_flare", "position": player.position, "danger_distance": danger}))
				supply_cooldown = 30
			# Out of flares: face the threat and flash-stun it, as a player would.
			if danger < 60 and player.supplies["flare"] == 0 and player.flash_cooldown <= 0.0 and player.flashlight_charge >= CampPlayer.FLASH_COST:
				for enemy: CampKiller in get_nodes_in_group("killers"):
					if player.position.distance_to(enemy.position) <= danger + 0.5:
						player.facing = player.position.direction_to(enemy.position)
				await _tap(KEY_SPACE)
				print(JSON.stringify({"event": "expedition_flash", "position": player.position, "danger_distance": danger}))
			# Use carried rare counterplay through normal belt keys when flares run out.
			if danger<65 and player.supplies["flare"]==0 and player.ward_remaining<=0 and player.supplies.get("salt_ward",0)>0:
				await _belt_use("salt_ward")
			if player.hex_remaining>0 and player.supplies.get("glow_moss",0)>0:
				await _belt_use("glow_moss")
			if player.flashlight_charge < 10 and player.supplies["battery_pack"] > 0:
				await _tap(KEY_R)
			if chasing:
				Input.action_press("sprint")
				if player.stamina < 0.5 and player.supplies["rations"] > 0:
					await _tap(KEY_C)
			# Opportunistic supplies require the same E/proximity/raycast rules as a player.
			for pickup: CampPickup in level.pickups:
				if pickup.available and player.supplies.has(pickup.kind) and player.position.distance_to(pickup.position) < 23 and level.clear_path(player.position, pickup.position):
					await _tap(KEY_E)
			if absf(offset.x) > 1:
				Input.action_press("move_right" if offset.x > 0 else "move_left", absf(offset.x) / maxf(absf(offset.x), absf(offset.y)))
			if absf(offset.y) > 1:
				Input.action_press("move_down" if offset.y > 0 else "move_up", absf(offset.y) / maxf(absf(offset.x), absf(offset.y)))
			var before := player.position
			await physics_frame
			walked += before.distance_to(player.position)
		for action in ["move_left", "move_right", "move_up", "move_down", "sprint"]:
			Input.action_release(action)
		await _frames(1)
		if not reached:
			print(JSON.stringify({"event": "expedition_blocked", "destination": destination, "position": player.position, "status": player.status, "stamina": player.stamina, "supplies":player.supplies, "hidden": player.hidden_spot, "velocity": player.velocity, "controls": player.controls_enabled, "paused": level.paused}))
			for enemy: CampKiller in get_nodes_in_group("killers"):
				print(JSON.stringify({"event": "enemy_at_failure", "position": enemy.position, "state": enemy.state, "flare": enemy.nearby_flare()}))
		_check(reached, "woods_walk_to_%d_%d" % [destination.x, destination.y])
		if not reached:
			return false
	return true


func _finish() -> void:
	print(JSON.stringify({"event": "test_result", "suite": "woods_playthrough", "checks": checks, "failures": failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _belt_use(kind: String) -> void:
	var slot := player.belt.find(kind)
	if slot<0: return
	await _tap([KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6][slot])
	await _tap(KEY_V)
