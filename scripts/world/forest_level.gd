extends Node2D
## Offline authority for the M1 round. Scene replacement owns cleanup.

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
var config: CampConfig = preload("res://assets/default_config.tres")
var camp_map: CampMap
var player: CampPlayer
var hud: CanvasLayer
var paused: bool = false
var pickups: Array[CampPickup] = []
var van: CampVan
var finished: bool = false
var won: bool = false
var message: String = "Search camp buildings. Tab shows where to find the supplies."
var message_time: float = 6.0
var killer: CampKiller
var revive_target: CampPlayer
var revive_progress: float = 0.0
var world_objects: Node2D
var plan := RoundPlan.new()
var soundscape: CampSoundscape
var sight: WoodsVisibility


func _ready() -> void:
	var session: Node = get_node("/root/Session")
	plan.generate(session.begin_run(), session.mode)
	if plan.expedition:
		message = "Find cutters in Maintenance. Search woods caches for 3 of 5 van parts."
	world_objects = Node2D.new()
	world_objects.name = "WorldObjects"
	world_objects.y_sort_enabled = true
	add_child(world_objects)
	camp_map = CampMap.new()
	camp_map.z_index = -1
	camp_map.objects = world_objects
	camp_map.woods = plan.woods
	camp_map.seed_value = plan.seed_value
	camp_map.layout = plan.camp
	add_child(camp_map)
	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(96, 384)
	player.config = config
	player.expedition = plan.expedition
	world_objects.add_child(player)
	camp_map.focus = player
	player.get_node("Camera2D").enabled = true
	player.get_node("Camera2D").limit_right = int(CampMap.WORLD_SIZE.x)
	player.get_node("Camera2D").limit_bottom = int(CampMap.WORLD_SIZE.y)
	player.noise_emitted.connect(_on_noise)
	killer = preload("res://scenes/actors/killer.tscn").instantiate()
	killer.config = config
	killer.position = Vector2(1400, 480)
	killer.patrol = [Vector2(1400, 520), Vector2(960, 520), Vector2(960, 840), Vector2(600, 520), Vector2(360, 520), Vector2(360, 216), Vector2(960, 216)]
	if plan.expedition:
		killer.position = Vector2(600, 520)
		killer.patrol.assign([Vector2(360,216), Vector2(360,520), Vector2(960,520), Vector2(1400,520), Vector2(960,216), Vector2(960,840), Vector2(600,520)])
		killer.patrol_index = 0
		if plan.seed_value % 2 == 1:
			killer.patrol.reverse()
			killer.patrol.push_front(Vector2(360,216))
	world_objects.add_child(killer)
	_spawn_cryptids()
	_apply_weather()
	var night := preload("res://scripts/ui/night_overlay.gd").new()
	night.player = player
	night.weather = plan.weather
	add_child(night)
	var weather := preload("res://scripts/ui/weather.gd").new()
	weather.level = self
	var weather_layer := CanvasLayer.new()
	weather_layer.layer = 2
	add_child(weather_layer)
	weather_layer.add_child(weather)
	van = preload("res://scenes/world/escape_van.tscn").instantiate()
	van.config = config
	van.required_parts.assign(plan.required)
	van.position = Vector2(96, 300)
	world_objects.add_child(van)
	for item in plan.loot:
		var pickup: CampPickup = preload("res://scenes/items/pickup.tscn").instantiate()
		pickup.kind = item["kind"]
		pickup.position = item["position"]
		pickup.locked = item["locked"]
		pickups.append(pickup)
		add_child(pickup)
	hud = preload("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	hud.chart.camp_map = camp_map
	hud.chart.player = player
	hud.chart.van = van
	hud.chart.plan = plan
	hud.menu_requested.connect(return_to_menu)
	hud.restart_requested.connect(restart_round)
	hud.retry_requested.connect(retry_round)
	sight = WoodsVisibility.new()
	sight.player = player
	add_child(sight)
	soundscape = CampSoundscape.new()
	soundscape.level = self
	add_child(soundscape)
	print(JSON.stringify({"event": "round_ready", "milestone": "M1"}))


func _process(_delta: float) -> void:
	var heading := "VAN %d/%d · %s" % [van.installed.size(), plan.required.size(), plan.weather.to_upper() + " NIGHT" if plan.expedition else "SEARCH CAMP"]
	if van.installed.size() == plan.required.size():
		heading = "VAN REPAIRED  ·  HOLD E AT THE REAR TO START"
	if van.running:
		heading = "DEPARTING IN %.1fs  ·  %d ABOARD" % [van.remaining, van.passengers.size()]
	if finished:
		heading = "ROUND COMPLETE  ·  ESCAPED" if won else "ROUND COMPLETE  ·  NO ESCAPE"
	elif player.status == CampPlayer.Status.DOWNED:
		heading = "DOWNED  ·  BLEEDING OUT IN %.1fs" % player.bleedout
	var detail := context_prompt()
	if revive_progress > 0.0:
		detail = "HOLD E · REVIVE  %d%%" % int(revive_progress / (1.2 if player.supplies["medkit"] > 0 else config.revive_seconds) * 100)
	hud.threat_label.text = ""
	if not finished and killer.global_position.distance_to(player.global_position) < 155.0:
		hud.threat_label.text = "SPOTTED · RUN!" if killer.state == CampKiller.State.CHASE else "FOOTSTEPS NEARBY · KEEP QUIET"
	if message_time > 0.0:
		detail = message + "\n" + detail
	hud.set_status(heading, detail, player.stamina / config.stamina_max)
	hud.inventory_label.text = "NIGHT %d / %s\nQ FLARE %d · R BATTERY %d · C FOOD %d\n" % [plan.seed_value, plan.weather.to_upper(), player.supplies["flare"], player.supplies["battery_pack"], player.supplies["rations"]]
	hud.inventory_label.text += plan.pack_description(van.installed)
	hud.inventory_label.text += "\nCUTTERS: " + ("YES" if "boltcutters" in player.inventory else "MAINTENANCE") + " / TAB CLOSE"
	hud.location_label.text = camp_map.location_label(player.global_position)
	hud.supplies_label.text = "LIGHT %ds / FLARES %d" % [int(player.flashlight_charge), player.supplies["flare"]] if plan.expedition else "QUICK CAMP"
	for enemy: CampKiller in get_tree().get_nodes_in_group("cryptids"):
		if player.global_position.distance_to(enemy.global_position) < 180 and sight.can_see(enemy.global_position):
			hud.threat_label.text = enemy.species.replace("_", " ").to_upper() + " NEARBY"
	if player.hex_remaining > 0:
		hud.threat_label.text = "HEXED %.1fs / SLOWED!" % player.hex_remaining



func _physics_process(delta: float) -> void:
	if paused or finished:
		return
	if plan.woods.valid(plan.woods.cell_at(player.global_position)):
		plan.woods.visited[plan.woods.cell_at(player.global_position)] = true
	message_time = maxf(0.0, message_time - delta)
	var target := nearby_downed(player)
	advance_revive(player, target, Input.is_action_pressed("interact"), delta)
	var was_running := van.running
	van.advance_start(player, Input.is_action_pressed("interact") and clear_path(player.global_position, van.interaction_point()), delta)
	if van.running and not was_running:
		van.board(player)
		announce("Engine started. Driver boarded automatically. Others: E to enter.")
	var living := false
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status in [CampPlayer.Status.ALIVE, CampPlayer.Status.DOWNED, CampPlayer.Status.BOARDED]:
			living = true
	if not living:
		finish_round(false, "No survivor made it out. You were caught in the woods.")
		return
	if van.running and van.remaining <= 0.0:
		var escaped := 0
		for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
			if actor.status == CampPlayer.Status.BOARDED and actor in van.passengers:
				actor.set_status(CampPlayer.Status.ESCAPED)
				escaped += 1
			elif actor.status in [CampPlayer.Status.ALIVE, CampPlayer.Status.DOWNED]:
				actor.set_status(CampPlayer.Status.LEFT_BEHIND)
		var detail := "The van departed without a living survivor."
		if escaped > 0:
			detail = "%d survivor(s) escaped. You: %s." % [escaped, CampPlayer.Status.keys()[player.status].to_lower().replace("_", " ")]
		finish_round(escaped > 0, detail)


func try_interact(actor: CampPlayer) -> bool:
	if paused or finished or actor.status != CampPlayer.Status.ALIVE or not actor.is_in_group("survivors"):
		return false
	if van.can_board(actor):
		var entered := van.board(actor)
		if entered:
			announce("You're aboard. Stay seated until departure.")
		return entered
	if nearby_downed(actor) != null:
		return true
	for pickup in pickups:
		if pickup.available and actor.global_position.distance_to(pickup.global_position) <= config.interact_radius and clear_path(actor.global_position, pickup.global_position):
			if pickup.locked and "boltcutters" not in actor.inventory:
				announce("Locked cache! Find boltcutters in Maintenance first.")
				actor.noise_emitted.emit(actor.global_position)
				return false
			pickup.consume()
			if plan.expedition:
				actor.noise_emitted.emit(pickup.global_position)
			if actor.supplies.has(pickup.kind):
				actor.supplies[pickup.kind] += 1
			else:
				actor.inventory.append(pickup.kind)
			if pickup.kind in plan.required:
				announce("Found " + pickup.kind.replace("_", " ") + ". Install it at the van.")
			elif pickup.kind == "boltcutters":
				announce("Boltcutters found. Woods caches can now be opened with E.")
			else:
				announce("Packed " + pickup.kind.replace("_", " ") + ". Q flare / R battery / C food.")
			return true
	for site in camp_map.sites:
		if not site.nearby(actor).is_empty():
			return site.interact(actor)
	if van.in_range(actor) and clear_path(actor.global_position, van.interaction_point()):
		var count := van.deliver(actor)
		if count > 0:
			announce("Installed %d component(s)." % count)
			return true
		if van.installed.size() == plan.required.size():
			return true
	announce("Nothing to use here. Tab shows supply locations.")
	actor.noise_emitted.emit(actor.global_position)
	return false


func nearby_downed(actor: CampPlayer) -> CampPlayer:
	if actor.status != CampPlayer.Status.ALIVE:
		return null
	for other: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if other != actor and other.status == CampPlayer.Status.DOWNED and actor.global_position.distance_to(other.global_position) <= config.interact_radius and clear_path(actor.global_position, other.global_position):
			return other
	return null


func advance_revive(actor: CampPlayer, target: CampPlayer, holding: bool, delta: float) -> void:
	if paused or finished or not holding or target == null or not actor.is_in_group("survivors") or not target.is_in_group("survivors") or actor.status != CampPlayer.Status.ALIVE or target.status != CampPlayer.Status.DOWNED or actor.global_position.distance_to(target.global_position) > config.interact_radius or not clear_path(actor.global_position, target.global_position):
		revive_target = null
		revive_progress = 0.0
		return
	if revive_target != target:
		revive_target = target
		revive_progress = 0.0
	revive_progress += delta
	var duration := 1.2 if actor.supplies["medkit"] > 0 else config.revive_seconds
	if revive_progress >= duration:
		if actor.supplies["medkit"] > 0:
			actor.supplies["medkit"] -= 1
		target.set_status(CampPlayer.Status.ALIVE)
		revive_target = null
		revive_progress = 0.0
		announce("Survivor revived. Move before the stalker returns!")


func _on_noise(origin: Vector2) -> void:
	if not paused and not finished:
		for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
			enemy.hear_noise(origin)


func loud_noise(origin: Vector2, radius: float) -> void:
	if paused or finished:
		return
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		enemy.hear_stimulus(origin, radius)


func clear_path(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func context_prompt() -> String:
	if finished:
		return "Round complete. Replay or return to the menu."
	if player.status == CampPlayer.Status.BOARDED:
		return "YOU ARE ABOARD · Safe inside the van. Departure is automatic."
	if van.can_board(player):
		return "E · ENTER VAN  —  Board before the countdown ends!"
	if player.status == CampPlayer.Status.DOWNED:
		return "A teammate can hold E nearby to revive. Alone, no one can help."
	if nearby_downed(player) != null:
		return "HOLD E · REVIVE TEAMMATE"
	for pickup in pickups:
		if pickup.available and player.global_position.distance_to(pickup.global_position) <= config.interact_radius and clear_path(player.global_position, pickup.global_position):
			return "E · LOCKED CACHE / NEED BOLTCUTTERS" if pickup.locked and "boltcutters" not in player.inventory else "E · TAKE " + pickup.kind.replace("_", " ").to_upper()
	for site in camp_map.sites:
		var action := site.nearby(player)
		if not action.is_empty():
			return "E · " + action["label"] if site.cooldown <= 0 else "LET THE ECHO FADE..."
	if van.in_range(player):
		if van.running:
			return "E · ENTER VAN  —  Board before the countdown ends!"
		if van.installed.size() == plan.required.size():
			return "HOLD E · START VAN  %d%%" % int(van.start_progress / config.start_hold_seconds * 100)
		return "E · INSTALL SUPPLIES   |   NEED: " + ", ".join(missing_parts()).to_upper()
	return "E use · F light · Q flare · R battery · C food · Tab notes" if plan.expedition else "Find battery, fuel, key · E use · F light · Tab pack · Esc pause"


func missing_parts() -> Array[String]:
	var missing: Array[String] = []
	for part in plan.required:
		if part not in van.installed:
			missing.append(part)
	return missing


func announce(text: String) -> void:
	message = text
	message_time = 3.0


func finish_round(success: bool, detail: String) -> void:
	finished = true
	soundscape.stop_round()
	won = success
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		actor.controls_enabled = false
		actor.set_physics_process(false)
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		enemy.enabled = false
	for hazard in get_tree().get_nodes_in_group("hazards"):
		hazard.set_physics_process(false)
	hud.show_result(success, detail + "\nNight %d / %s" % [plan.seed_value, plan.weather])
	print(JSON.stringify({"event": "round_finished", "won": success, "result": detail}))


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	if event.is_action_pressed("pause"):
		paused = not paused
		for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
			enemy.enabled = not paused
		for flare in get_tree().get_nodes_in_group("flares"):
			flare.set_physics_process(not paused)
		for hazard in get_tree().get_nodes_in_group("hazards"):
			hazard.set_physics_process(not paused)
		for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
			actor.controls_enabled = not paused
			actor.set_physics_process(not paused)
		hud.show_pause(paused)
		get_viewport().set_input_as_handled()
	elif not paused and event.is_action_pressed("interact") and not event.is_echo():
		try_interact(player)
		get_viewport().set_input_as_handled()
	elif not paused and event.is_action_pressed("inventory"):
		hud.inventory_label.visible = not hud.inventory_label.visible
		hud.chart.visible = hud.inventory_label.visible
		get_viewport().set_input_as_handled()
	elif not paused and event.is_action_pressed("use_flare"):
		use_supply(player, "flare")
	elif not paused and event.is_action_pressed("recharge"):
		use_supply(player, "battery_pack")
	elif not paused and event.is_action_pressed("eat"):
		use_supply(player, "rations")
	elif not paused and event.is_action_pressed("flashlight"):
		if not player.expedition or player.flashlight_charge > 0:
			player.flashlight_on = not player.flashlight_on
		else:
			announce("Flashlight empty. R uses a spare battery.")
		get_viewport().set_input_as_handled()


func return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func restart_round() -> void:
	var session: Node = get_node("/root/Session")
	session.next_seed = 0
	session.load_game()


func retry_round() -> void:
	get_node("/root/Session").load_game(true)


func use_supply(actor: CampPlayer, kind: String) -> bool:
	if paused or finished or actor.status != CampPlayer.Status.ALIVE or not actor.is_in_group("survivors") or actor.supplies.get(kind, 0) <= 0:
		return false
	if kind == "flare":
		var flare := preload("res://scripts/items/flare.gd").new()
		var target := actor.global_position + actor.facing * 28
		flare.position = target if clear_path(actor.global_position, target) else actor.global_position
		world_objects.add_child(flare)
		actor.noise_emitted.emit(flare.global_position)
		announce("Flare out! Teeth hate it. Wings don't.")
	elif kind == "battery_pack":
		if actor.flashlight_charge >= config.flashlight_capacity:
			return false
		actor.flashlight_charge = minf(config.flashlight_capacity, actor.flashlight_charge + 70)
		actor.flashlight_on = true
	elif kind == "rations":
		if actor.stamina >= config.stamina_max:
			return false
		actor.stamina = config.stamina_max
		actor.exhausted = false
	else:
		return false
	actor.supplies[kind] -= 1
	return true


func _spawn_cryptids() -> void:
	for encounter in plan.encounters:
		var enemy: CampCryptid = preload("res://scenes/actors/cryptid.tscn").instantiate()
		enemy.species = encounter["species"]
		enemy.config = config
		enemy.position = encounter["position"]
		enemy.patrol.clear()
		var start: Vector2i = encounter["cell"]
		enemy.patrol.assign(plan.woods.roaming_route(start))
		world_objects.add_child(enemy)


func _apply_weather() -> void:
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		# Never mutate the shared default resource or another creature's tuning.
		enemy.config = enemy.config.duplicate() as CampConfig
		if plan.expedition and enemy == killer:
			enemy.config.sight_radius = 150
			enemy.config.hearing_radius = 220
		if plan.weather == "fog":
			enemy.config.sight_radius *= 0.72
		elif plan.weather == "rain":
			enemy.config.hearing_radius *= 0.7
