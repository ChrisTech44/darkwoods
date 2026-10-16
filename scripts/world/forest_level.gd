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


func _ready() -> void:
	world_objects = Node2D.new()
	world_objects.name = "WorldObjects"
	world_objects.y_sort_enabled = true
	add_child(world_objects)
	camp_map = CampMap.new()
	camp_map.z_index = -1
	camp_map.objects = world_objects
	add_child(camp_map)
	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(96, 384)
	player.config = config
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
	world_objects.add_child(killer)
	var night := preload("res://scripts/ui/night_overlay.gd").new()
	night.player = player
	add_child(night)
	van = preload("res://scenes/world/escape_van.tscn").instantiate()
	van.config = config
	van.position = Vector2(96, 300)
	world_objects.add_child(van)
	var locations: Array[Vector2] = CampMap.PICKUP_POSITIONS
	for index in range(3):
		var pickup: CampPickup = preload("res://scenes/items/pickup.tscn").instantiate()
		pickup.kind = CampVan.PARTS[index]
		pickup.position = locations[index]
		pickups.append(pickup)
		add_child(pickup)
	hud = preload("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	hud.chart.camp_map = camp_map
	hud.chart.player = player
	hud.chart.van = van
	hud.menu_requested.connect(return_to_menu)
	hud.restart_requested.connect(restart_round)
	print(JSON.stringify({"event": "round_ready", "milestone": "M1"}))


func _process(_delta: float) -> void:
	var heading := "VAN %d/3  ·  SEARCH THE CAMP" % van.installed.size()
	if van.installed.size() == 3:
		heading = "VAN REPAIRED  ·  HOLD E AT THE REAR TO START"
	if van.running:
		heading = "DEPARTING IN %.1fs  ·  %d ABOARD" % [van.remaining, van.passengers.size()]
	if finished:
		heading = "ROUND COMPLETE  ·  ESCAPED" if won else "ROUND COMPLETE  ·  NO ESCAPE"
	elif player.status == CampPlayer.Status.DOWNED:
		heading = "DOWNED  ·  BLEEDING OUT IN %.1fs" % player.bleedout
	var detail := context_prompt()
	if revive_progress > 0.0:
		detail = "HOLD E · REVIVE  %d%%" % int(revive_progress / config.revive_seconds * 100)
	hud.threat_label.text = ""
	if not finished and killer.global_position.distance_to(player.global_position) < 155.0:
		hud.threat_label.text = "SPOTTED · RUN!" if killer.state == CampKiller.State.CHASE else "FOOTSTEPS NEARBY · KEEP QUIET"
	if message_time > 0.0:
		detail = message + "\n" + detail
	hud.set_status(heading, detail, player.stamina / config.stamina_max)
	hud.inventory_label.text = "CARRYING: " + (", ".join(player.inventory).to_upper() if not player.inventory.is_empty() else "NOTHING") + "\nVAN: " + ", ".join(van.installed).to_upper()
	hud.location_label.text = camp_map.location_label(player.global_position)
	hud.inventory_label.text += "\n1  BATTERY · FERN BUNK CABIN\n2  FUEL · MAINTENANCE\n3  KEY · RANGER LODGE\nCYAN · YOU   CREAM · VAN\nTAB · CLOSE FIELD MAP"


func _physics_process(delta: float) -> void:
	if paused or finished:
		return
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
			pickup.consume()
			actor.inventory.append(pickup.kind)
			announce("Picked up " + pickup.kind + ". Return supplies to the van.")
			return true
	if van.in_range(actor) and clear_path(actor.global_position, van.interaction_point()):
		var count := van.deliver(actor)
		if count > 0:
			announce("Installed %d component(s)." % count)
			return true
		if van.installed.size() == 3:
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
	if revive_progress >= config.revive_seconds:
		target.set_status(CampPlayer.Status.ALIVE)
		revive_target = null
		revive_progress = 0.0
		announce("Survivor revived. Move before the stalker returns!")


func _on_noise(origin: Vector2) -> void:
	if not paused and not finished:
		killer.hear_noise(origin)


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
			return "E · PICK UP " + pickup.kind.to_upper()
	if van.in_range(player):
		if van.running:
			return "E · ENTER VAN  —  Board before the countdown ends!"
		if van.installed.size() == 3:
			return "HOLD E · START VAN  %d%%" % int(van.start_progress / config.start_hold_seconds * 100)
		return "E · INSTALL SUPPLIES   |   NEED: " + ", ".join(missing_parts()).to_upper()
	return "Find battery, fuel, key · E use · F light · Tab pack · Esc pause"


func missing_parts() -> Array[String]:
	var missing: Array[String] = []
	for part in CampVan.PARTS:
		if part not in van.installed:
			missing.append(part)
	return missing


func announce(text: String) -> void:
	message = text
	message_time = 3.0


func finish_round(success: bool, detail: String) -> void:
	finished = true
	won = success
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		actor.controls_enabled = false
		actor.set_physics_process(false)
	killer.enabled = false
	hud.show_result(success, detail)
	print(JSON.stringify({"event": "round_finished", "won": success, "result": detail}))


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	if event.is_action_pressed("pause"):
		paused = not paused
		killer.enabled = not paused
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
	elif not paused and event.is_action_pressed("flashlight"):
		player.flashlight_on = not player.flashlight_on
		get_viewport().set_input_as_handled()


func return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func restart_round() -> void:
	get_tree().reload_current_scene()
