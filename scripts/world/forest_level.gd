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
var revive_actor: CampPlayer
var revive_target: CampPlayer
var revive_progress: float = 0.0
var revive_duration: float = 3.0
var self_recovery_progress: float = 0.0
var help_pings: Array[Dictionary] = []
var blood_clock: float = 0.0
const KITLESS_REVIVE_FACTOR := 2.0
const SELF_RECOVERY_SECONDS := 8.0
const SOLO_LAST_CHANCE := 20.0
const HELP_PING_SECONDS := 8.0
var world_objects: Node2D
var plan := RoundPlan.new()
var soundscape: CampSoundscape
var sight: WoodsVisibility
var pins: Array[Dictionary] = []
var night_clock: NightClock
const PINS_PER_PLAYER := 3


func _ready() -> void:
	add_to_group("round_world")
	var session: Node = get_node("/root/Session")
	plan.generate(session.begin_run(), session.mode)
	if plan.expedition:
		message = "DUSK. Grab tools and supplies. The ranger radio reveals more parts as the night deepens."
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
	player.role = session.survivor
	player.expedition = plan.expedition
	world_objects.add_child(player)
	camp_map.focus = player
	player.get_node("Camera2D").enabled = true
	player.get_node("Camera2D").limit_left = int(CampMap.WORLD_BOUNDS.position.x)
	player.get_node("Camera2D").limit_top = int(CampMap.WORLD_BOUNDS.position.y)
	player.get_node("Camera2D").limit_right = int(CampMap.WORLD_BOUNDS.end.x)
	player.get_node("Camera2D").limit_bottom = int(CampMap.WORLD_BOUNDS.end.y)
	player.noise_emitted.connect(_on_noise)
	player.sprint_noise_emitted.connect(_on_sprint_noise)
	killer = preload("res://scenes/actors/killer.tscn").instantiate()
	killer.config = config
	# Visit central camp early, then tour the roads and cabin approaches.
	killer.position = Vector2(600,520)
	var perimeter: Array[Vector2]=[Vector2(360,520),Vector2(360,216),Vector2(960,216),Vector2(960,520),Vector2(1400,520),Vector2(960,840),Vector2(600,520)]
	if plan.seed_value % 2 == 1: perimeter.reverse()
	killer.patrol.assign([Vector2(360,520),Vector2(96,520),Vector2(96,384),Vector2(96,520)]+perimeter)
	world_objects.add_child(killer)
	_spawn_cryptids()
	_apply_weather()
	var night := preload("res://scripts/ui/night_overlay.gd").new()
	night.player = player
	night.level = self
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
	var trail := preload("res://scripts/world/blood_trail.gd").new()
	trail.z_index = -1
	add_child(trail)
	night_clock = NightClock.new()
	night_clock.name = "NightClock"
	night_clock.level = self
	add_child(night_clock)
	hud = preload("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	hud.chart.camp_map = camp_map
	hud.chart.player = player
	hud.chart.van = van
	hud.chart.plan = plan
	hud.chart.level = self
	var skyline := Skyline.new()
	skyline.level = self
	skyline.size = Vector2(384, 216)
	hud.root.add_child(skyline)
	hud.root.move_child(skyline, 0)
	hud.menu_requested.connect(return_to_menu)
	hud.restart_requested.connect(restart_round)
	hud.retry_requested.connect(retry_round)
	sight = WoodsVisibility.new()
	sight.player = player
	add_child(sight)
	soundscape = CampSoundscape.new()
	soundscape.level = self
	add_child(soundscape)
	if get_node("/root/Net").active:
		get_node("/root/Net").attach_world(self)
		var buttons: VBoxContainer=hud.result_panel.get_child(0)
		buttons.get_node("Restart").text="RETURN TO LOBBY (HOST)"
		buttons.get_node("Retry").text="RETRY SEED / LOBBY (HOST)"
		buttons.get_node("Restart").disabled=not multiplayer.is_server()
		buttons.get_node("Retry").disabled=not multiplayer.is_server()
	print(JSON.stringify({"event": "round_ready", "milestone": "M1"}))


func _process(_delta: float) -> void:
	var heading := "VAN %d/%d · %s" % [van.installed.size(), plan.required.size(), plan.weather.to_upper() + " NIGHT" if plan.expedition else "SEARCH CAMP"]
	if plan.expedition:
		var clock := night_clock
		heading = "VAN %d/%d · %s %s · %s" % [van.installed.size(), plan.required.size(), NightClock.PHASES[clock.phase], NightClock.clock_text(clock.elapsed), "DAWN IN " + NightClock.clock_text(NightClock.DAWN - clock.elapsed) if clock.phase == 3 else plan.weather.to_upper()]
	if van.installed.size() == plan.required.size():
		heading = "VAN REPAIRED  ·  HOLD E AT THE REAR TO START"
	if van.running:
		heading = "DEPARTING IN %.1fs  ·  %d ABOARD" % [van.remaining, van.passengers.size()]
	if finished:
		heading = "ROUND COMPLETE  ·  ESCAPED" if won else "ROUND COMPLETE  ·  NO ESCAPE"
	elif player.status == CampPlayer.Status.DEAD:
		heading = "ELIMINATED / WAITING FOR SURVIVORS"
	elif player.status == CampPlayer.Status.DOWNED:
		heading = "DOWNED · LAST CHANCE %ds" % int(maxf(0.0, SOLO_LAST_CHANCE - player.bleedout)) if solo_recovery_available(player) else "DOWNED · A TEAMMATE CAN REVIVE YOU"
	var detail := context_prompt()
	if revive_progress > 0.0:
		detail = "HOLD E · REVIVE  %d%%" % int(revive_progress / revive_duration * 100)
	if self_recovery_progress > 0.0:
		detail = "HOLD E · GET UP  %d%%" % int(self_recovery_progress / SELF_RECOVERY_SECONDS * 100)
	hud.threat_label.text = ""
	if player.wounded and player.status == CampPlayer.Status.ALIVE:
		hud.threat_label.text = "WOUNDED · MEDKIT (V) PATCHES"
	if not finished and killer.global_position.distance_to(player.global_position) < 155.0:
		hud.threat_label.text = "SPOTTED · RUN!" if killer.state == CampKiller.State.CHASE else "FOOTSTEPS NEARBY · KEEP QUIET"
	if player.notice_time > 0.0:
		detail=player.notice+"\n"+detail
	elif message_time > 0.0:
		detail = message + "\n" + detail
	hud.set_status(heading, detail, player.stamina / player.config.stamina_max)
	hud.inventory_label.text = "NIGHT %d / %s\nQ FLARE %d · R BATTERY %d · C FOOD %d\n" % [plan.seed_value, plan.weather.to_upper(), player.supplies["flare"], player.supplies["battery_pack"], player.supplies["rations"]]
	hud.inventory_label.text += plan.pack_description(van.installed, night_clock.phase if plan.expedition else 3)
	if plan.expedition:
		hud.inventory_label.text += "\nCUTTERS: " + ("YES" if "boltcutters" in player.inventory else "MAINT./%s WOODS BOX" % plan.toolbox_hint) + (" +BAR" if "crowbar" in player.inventory else "") + " · TAB CLOSE"
	else:
		hud.inventory_label.text += "\nM PIN · TAB CLOSE"
	hud.update_belt(player)
	hud.location_label.text = camp_map.location_label(player.global_position)
	if plan.expedition:
		var post := plan.woods.signpost_near(player.global_position)
		if not post.is_empty() and sight.can_see(post["position"]):
			hud.location_label.text = WoodsLayout.signpost_text(post)
	hud.supplies_label.text = "LIGHT %ds / FLARES %d" % [int(player.flashlight_charge), player.supplies["flare"]] if plan.expedition else "QUICK CAMP"
	for enemy: CampKiller in get_tree().get_nodes_in_group("cryptids"):
		if player.global_position.distance_to(enemy.global_position) < 180 and sight.can_see(enemy.global_position):
			hud.threat_label.text = enemy.species.replace("_", " ").to_upper() + " NEARBY"
	if player.hex_remaining > 0:
		hud.threat_label.text = "HEXED %.1fs / SLOWED!" % player.hex_remaining
	for lamp in camp_map.camp_lamps:
		lamp.enabled = not night_clock.blackout



func _physics_process(delta: float) -> void:
	if get_node("/root/Net").active and (not multiplayer.is_server() or get_node("/root/Net").waiting): return
	if paused or finished:
		return
	if plan.woods.valid(plan.woods.cell_at(player.global_position)):
		plan.woods.visited[plan.woods.cell_at(player.global_position)] = true
	message_time = maxf(0.0, message_time - delta)
	var net: Node=get_node("/root/Net")
	if net.active:
		if not multiplayer.is_server() or net.waiting: return
		_advance_network_holds(net,delta)
	else:
		var target := nearby_downed(player)
		advance_revive(player, target, Input.is_action_pressed("interact"), delta)
		advance_self_recovery(player, Input.is_action_pressed("interact"), delta)
		var was_running := van.running
		van.advance_start(player, Input.is_action_pressed("interact") and clear_path(player.global_position, van.interaction_point()), delta)
		if van.running and not was_running:
			van.board(player)
			announce("Engine started. Driver boarded automatically. Others: E to enter.")
	_advance_chase_toolkit(delta)
	var living := false
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status in [CampPlayer.Status.ALIVE, CampPlayer.Status.BOARDED]:
			living = true
		# A lone survivor gets a short last chance to pick themselves up.
		elif solo_recovery_available(actor) and actor.bleedout < SOLO_LAST_CHANCE:
			living = true
	if not living:
		finish_round(false, "No survivor made it out. You were caught in the woods.")
		return
	if van.running and van.remaining <= 0.0:
		var escaped := 0
		for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
			if (actor.status == CampPlayer.Status.BOARDED and actor in van.passengers) or (actor.status == CampPlayer.Status.DOWNED and not van.passengers.is_empty()):
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
			announce("You're aboard. Stay seated until departure.",actor)
		return entered
	if nearby_downed(actor) != null and actor.supplies.get("medkit",0)>0:
		return true
	for pickup in pickups:
		if pickup.available and actor.global_position.distance_to(pickup.global_position) <= config.interact_radius and clear_path(actor.global_position, pickup.global_position):
			var pried := false
			if pickup.locked and "boltcutters" not in actor.inventory:
				if "crowbar" not in actor.inventory:
					announce("Locked cache! Boltcutters: Maintenance or the woods toolbox. A crowbar works, loudly.",actor)
					actor.noise_emitted.emit(actor.global_position)
					return false
				pried = true
			if actor.supplies.has(pickup.kind) and not actor.can_pack(pickup.kind):
				announce("Belt full. Select a slot and G to drop its stack.",actor)
				return false
			if pickup.kind in ["boltcutters", "crowbar"] and pickup.kind in actor.inventory:
				announce("You already carry " + pickup.kind + ". Leave these for a teammate.",actor)
				return false
			pickup.consume()
			if pried:
				loud_noise(pickup.global_position, 500)
			if plan.expedition:
				actor.noise_emitted.emit(pickup.global_position)
			if actor.supplies.has(pickup.kind):
				actor.pack(pickup.kind)
			else:
				actor.inventory.append(pickup.kind)
			if pickup.kind in plan.required:
				announce(("Crowbar screech! " if pried else "") + "Found " + pickup.kind.replace("_", " ") + ". Install it at the van.",actor)
			elif pickup.kind == "boltcutters":
				announce("Boltcutters found. Woods caches can now be opened with E.",actor)
			elif pickup.kind == "crowbar":
				announce("Crowbar found. It pries caches open, but loudly.",actor)
			else:
				announce("Packed " + pickup.kind.replace("_", " ") + ". Q flare / R battery / C food.",actor)
			return true
	for site in camp_map.sites:
		if not site.nearby(actor).is_empty():
			return site.interact(actor)
	if near_generator(actor):
		return night_clock.restart_generator(actor)
	if van.in_range(actor) and clear_path(actor.global_position, van.interaction_point()):
		var count := van.deliver(actor)
		if count > 0:
			announce("Installed %d component(s)." % count,actor)
			return true
		if van.installed.size() == plan.required.size():
			return true
	announce("Hold E to revive. A medkit makes it faster." if nearby_downed(actor)!=null else "Nothing to use here. Tab shows supply locations.",actor)
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
	if revive_target != target or revive_actor != actor:
		revive_actor = actor
		revive_target = target
		revive_progress = 0.0
	revive_progress += delta
	# A medkit makes the revive fast; bare hands work too, just slower.
	var kit: bool = actor.supplies.get("medkit", 0) > 0
	revive_duration = actor.config.revive_seconds * (1.0 if kit else KITLESS_REVIVE_FACTOR)
	if revive_progress >= revive_duration:
		if kit:
			actor.supplies["medkit"] -= 1
			actor.tidy_belt()
		target.set_status(CampPlayer.Status.ALIVE)
		revive_target = null
		revive_progress = 0.0
		announce("Survivor revived, still wounded. Move before the stalker returns!")


func solo_recovery_available(actor: CampPlayer) -> bool:
	return actor.status == CampPlayer.Status.DOWNED and not actor.self_recovery_used and get_tree().get_nodes_in_group("survivors").size() == 1


func advance_self_recovery(actor: CampPlayer, holding: bool, delta: float) -> void:
	if paused or finished or not holding or not solo_recovery_available(actor):
		self_recovery_progress = 0.0
		return
	self_recovery_progress += delta
	if self_recovery_progress >= SELF_RECOVERY_SECONDS:
		self_recovery_progress = 0.0
		actor.self_recovery_used = true
		actor.set_status(CampPlayer.Status.ALIVE)
		loud_noise(actor.global_position, 500)
		announce("You drag yourself up, wounded. That groan carried. No second chances tonight.", actor)


## Downed survivors can call out: a marker for every teammate, and a small noise.
func call_for_help(actor: CampPlayer) -> bool:
	if paused or finished or actor.status != CampPlayer.Status.DOWNED or actor.help_cooldown > 0.0 or get_tree().get_nodes_in_group("survivors").size() < 2:
		return false
	actor.help_cooldown = 10.0
	help_pings.append({"position": actor.global_position.round(), "remaining": HELP_PING_SECONDS, "name": (actor.peer_name if not actor.peer_name.is_empty() else "SURVIVOR").left(8).to_upper()})
	loud_noise(actor.global_position, 160)
	announce("%s is down and calling for help!" % (actor.peer_name if not actor.peer_name.is_empty() else "A survivor"))
	return true


## Flashlight burst: briefly stuns creatures caught close in the beam. Costs light, has a cooldown.
func use_flash(actor: CampPlayer) -> int:
	if paused or finished or actor.status != CampPlayer.Status.ALIVE or actor.flash_cooldown > 0.0:
		return -1
	if plan.expedition and actor.flashlight_charge < CampPlayer.FLASH_COST:
		announce("Not enough light for a flash. R swaps in a battery.", actor)
		return -1
	if plan.expedition:
		actor.flashlight_charge -= CampPlayer.FLASH_COST
	actor.flashlight_on = true
	actor.flash_time = 0.18
	actor.flash_cooldown = CampPlayer.FLASH_COOLDOWN
	var stunned := 0
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		var offset := enemy.global_position - actor.global_position
		if enemy.enabled and offset.length() <= 90.0 and actor.facing.dot(offset.normalized()) >= 0.75 and clear_path(actor.global_position, enemy.global_position) and enemy.stun(1.5):
			stunned += 1
	announce("FLASH! %d stunned. Run!" % stunned if stunned > 0 else "Flash! Nothing caught in the beam.", actor)
	return stunned


func _advance_chase_toolkit(delta: float) -> void:
	for ping in help_pings.duplicate():
		ping["remaining"] -= delta
		if ping["remaining"] <= 0.0:
			help_pings.erase(ping)
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status == CampPlayer.Status.DOWNED:
			actor.bleedout += delta
	# Fresh blood draws nearby patrolling creatures to the newest drop.
	blood_clock -= delta
	if blood_clock > 0.0:
		return
	blood_clock = 2.5
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.wounded and actor.status == CampPlayer.Status.ALIVE and not actor.blood.is_empty():
			for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
				if enemy.state == CampKiller.State.PATROL:
					enemy.hear_stimulus(actor.blood.back(), 110.0)


func on_survivor_wounded(actor: CampPlayer) -> void:
	if get_node("/root/Net").active and not multiplayer.is_server(): return
	announce("WOUNDED! One more hit downs you. Run, then patch up with a medkit.", actor)


func _on_noise(origin: Vector2) -> void:
	if not paused and not finished:
		night_clock.note_noise()
		for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
			enemy.hear_stimulus(origin, enemy.config.hearing_radius * night_clock.hearing_scale())


func _on_sprint_noise(origin: Vector2) -> void:
	if not paused and not finished:
		for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
			enemy.hear_stimulus(origin, enemy.config.hearing_radius * player.sprint_hearing * night_clock.hearing_scale())


func loud_noise(origin: Vector2, radius: float) -> void:
	if paused or finished:
		return
	night_clock.note_noise()
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		enemy.hear_stimulus(origin, radius * night_clock.hearing_scale())


func clear_path(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func context_prompt() -> String:
	if finished:
		return "Round complete. Replay or return to the menu."
	if player.status == CampPlayer.Status.DEAD:
		return "Eliminated. Teammates can still escape; wait for the round result."
	if player.status == CampPlayer.Status.BOARDED:
		return "YOU ARE ABOARD · Safe inside the van. Departure is automatic."
	if van.can_board(player):
		return "E · ENTER VAN  —  Board before the countdown ends!"
	if player.status == CampPlayer.Status.DOWNED:
		if solo_recovery_available(player):
			return "HOLD E (8s) · DRAG YOURSELF UP · ONCE PER NIGHT, LOUD"
		return "WASD crawl · E call for help · a teammate holds E to revive you"
	if nearby_downed(player) != null:
		return "HOLD E · REVIVE (MEDKIT %ss)" % str(player.config.revive_seconds) if player.supplies.get("medkit",0)>0 else "HOLD E · REVIVE BARE-HANDED (%ss) · E grabs gear" % str(player.config.revive_seconds * KITLESS_REVIVE_FACTOR)
	for pickup in pickups:
		if pickup.available and player.global_position.distance_to(pickup.global_position) <= config.interact_radius and clear_path(player.global_position, pickup.global_position):
			if pickup.locked and "boltcutters" not in player.inventory:
				return "E · PRY CACHE WITH CROWBAR (LOUD)" if "crowbar" in player.inventory else "E · LOCKED CACHE / NEED BOLTCUTTERS OR CROWBAR"
			return "E · TAKE " + pickup.kind.replace("_", " ").to_upper()
	for site in camp_map.sites:
		var action := site.nearby(player)
		if not action.is_empty():
			return "E · " + action["label"] if site.cooldown <= 0 else "LET THE ECHO FADE..."
	if near_generator(player):
		return "E · RESTART GENERATOR (LOUD)"
	if van.in_range(player):
		if van.running:
			return "E · ENTER VAN  —  Board before the countdown ends!"
		if van.installed.size() == plan.required.size():
			return "HOLD E · START VAN  %d%%" % int(van.start_progress / player.config.start_hold_seconds * 100)
		return "E · INSTALL SUPPLIES   |   NEED: " + ", ".join(missing_parts()).to_upper()
	return "1-6 select · V use · G drop · E interact · Space flash · M pin" if plan.expedition else "Find battery, fuel, key · E use · F light · Tab pack · Esc pause"


## Shared team pin at the actor's feet. Each owner keeps their newest three.
func place_pin(actor: CampPlayer, owner: int, owner_name: String) -> bool:
	if paused or finished or actor.status != CampPlayer.Status.ALIVE or not actor.is_in_group("survivors"):
		return false
	var mine: Array[Dictionary] = []
	for pin in pins:
		if pin["owner"] == owner:
			mine.append(pin)
	if mine.size() >= PINS_PER_PLAYER:
		pins.erase(mine[0])
	var slot := 0
	var ids: Array = [owner]
	if get_node("/root/Net").active:
		ids = get_node("/root/Net").actors.keys()
		ids.sort()
	slot = maxi(0, ids.find(owner))
	var place := pin_place(actor.global_position)
	var label := owner_name.left(8).to_upper() if get_node("/root/Net").active else "PIN %d" % (mine.size() % PINS_PER_PLAYER + 1)
	pins.append({"owner": owner, "slot": slot, "position": actor.global_position.round(), "name": label, "place": place})
	announce("%s pinned %s for the team. M pins again." % [owner_name, place])
	return true


func pin_place(point: Vector2) -> String:
	if not CampMap.is_woods(point):
		return camp_map.location_label(point)
	var zone := plan.woods.zone_at(point)
	if not zone.is_empty():
		return WoodsLayout.short_name(zone)
	for landmark in plan.woods.landmarks:
		if point.distance_to(landmark["position"]) < 160:
			return landmark["label"]
	return "THE WOODS"


func near_generator(actor: CampPlayer) -> bool:
	return night_clock.blackout and actor.global_position.distance_to(night_clock.generator_point()) <= config.interact_radius * 1.5 and clear_path(actor.global_position, night_clock.generator_point())


## First light: the ranger patrol reaches camp. Survivors in camp or aboard are rescued.
func dawn() -> void:
	if finished:
		return
	var rescued := 0
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status == CampPlayer.Status.BOARDED or (actor.status == CampPlayer.Status.ALIVE and not CampMap.is_woods(actor.global_position)):
			actor.set_status(CampPlayer.Status.ESCAPED)
			rescued += 1
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status == CampPlayer.Status.DOWNED and rescued > 0 and not CampMap.is_woods(actor.global_position):
			actor.set_status(CampPlayer.Status.ESCAPED)
			rescued += 1
		elif actor.status in [CampPlayer.Status.ALIVE, CampPlayer.Status.DOWNED]:
			actor.set_status(CampPlayer.Status.LEFT_BEHIND)
	finish_round(rescued > 0, "Dawn broke. The ranger patrol rescued %d survivor(s) in camp. You: %s." % [rescued, CampPlayer.Status.keys()[player.status].to_lower().replace("_", " ")])


func missing_parts() -> Array[String]:
	var missing: Array[String] = []
	for part in plan.required:
		if part not in van.installed:
			missing.append(part)
	return missing


func announce(text: String, recipient: CampPlayer = null) -> void:
	if recipient != null:
		recipient.notice=text
		recipient.notice_time=3
		return
	message = text
	message_time = 3.0


func finish_round(success: bool, detail: String) -> void:
	finished = true
	if get_node("/root/Net").active: get_node("/root/Net").phase="results"
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
	if get_node("/root/Net").active:
		get_node("/root/Net").handle_input(event)
		return
	if not paused and event is InputEventKey and event.pressed and not event.echo and player.status == CampPlayer.Status.ALIVE:
		var keys := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
		var pads := [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6]
		var index := keys.find(event.physical_keycode)
		if index < 0:
			index = pads.find(event.physical_keycode)
		if index >= 0:
			player.selected_slot = index
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_G:
			drop_held(player)
			return
		if event.physical_keycode == KEY_V:
			use_supply(player, player.held_item())
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
	elif not paused and event.is_action_pressed("interact") and not event.is_echo() and player.status == CampPlayer.Status.DOWNED:
		call_for_help(player)
		get_viewport().set_input_as_handled()
	elif not paused and event.is_action_pressed("flash_burst") and not event.is_echo():
		use_flash(player)
		get_viewport().set_input_as_handled()
	elif not paused and event.is_action_pressed("interact") and not event.is_echo():
		try_interact(player)
		get_viewport().set_input_as_handled()
	elif not paused and event.is_action_pressed("inventory"):
		hud.inventory_label.visible = not hud.inventory_label.visible
		hud.chart.visible = hud.inventory_label.visible
		get_viewport().set_input_as_handled()
	elif not paused and event.is_action_pressed("map_pin"):
		place_pin(player, 1, "You")
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
	if get_node("/root/Net").active:
		get_node("/root/Net").leave()
		return
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func restart_round() -> void:
	if get_node("/root/Net").active:
		get_node("/root/Net").return_lobby(false)
		return
	var session: Node = get_node("/root/Session")
	session.next_seed = 0
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func retry_round() -> void:
	if get_node("/root/Net").active:
		get_node("/root/Net").return_lobby(true)
		return
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
		announce("Flare out! Teeth hate it. Wings don't.",actor)
	elif kind == "battery_pack":
		if actor.flashlight_charge >= config.flashlight_capacity:
			return false
		actor.flashlight_charge = minf(config.flashlight_capacity, actor.flashlight_charge + 70)
		actor.flashlight_on = true
	elif kind == "rations":
		if actor.stamina >= actor.config.stamina_max:
			return false
		actor.stamina = actor.config.stamina_max
		actor.exhausted = false
		for enemy: CampCryptid in get_tree().get_nodes_in_group("cryptids"):
			if enemy.species == "ration_moth": enemy.hear_stimulus(actor.global_position,600)
	elif kind == "noise_tin":
		var lure := NoiseLure.new()
		var target := actor.global_position + actor.facing * 52
		lure.position = target if clear_path(actor.global_position, target) else actor.global_position
		lure.level = self
		world_objects.add_child(lure)
		announce("Tin timer: three delayed rattles. Move away quietly.",actor)
	elif kind == "salt_ward":
		actor.ward_remaining = 4.0
		announce("Salt ward: four seconds of protection. Keep moving!",actor)
	elif kind == "medkit":
		if not actor.wounded:
			announce("You're not wounded. Save the medkit for a revive.", actor)
			return false
		actor.wounded = false
		actor.blood.clear()
		announce("Wound patched. One hit no longer downs you.", actor)
	elif kind == "glow_moss":
		actor.flashlight_charge = minf(actor.config.flashlight_capacity, actor.flashlight_charge + 35)
		actor.hex_remaining = 0
		announce("Glow moss clears hexes and restores 35 light charge.",actor)
	else:
		return false
	actor.supplies[kind] -= 1
	actor.tidy_belt()
	return true


func _spawn_cryptids() -> void:
	for encounter in plan.encounters:
		var enemy: CampCryptid = preload("res://scenes/actors/cryptid.tscn").instantiate()
		enemy.species = encounter["species"]
		enemy.config = config
		enemy.position = encounter["position"]
		enemy.home = encounter.get("home", Rect2())
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


func drop_held(actor: CampPlayer) -> bool:
	if paused or finished or actor.status != CampPlayer.Status.ALIVE:
		return false
	var kind := actor.held_item()
	if kind.is_empty() or actor.supplies.get(kind, 0) <= 0:
		return false
	# Reuse consumed transient units so repeated drop/recovery never grows state unboundedly.
	for index in range(actor.supplies[kind]):
		spawn_dropped(kind,actor.global_position)
	actor.supplies[kind] = 0
	actor.tidy_belt()
	loud_noise(actor.global_position, 130)
	announce("Dropped " + kind.replace("_", " ") + ". E to recover.",actor)
	return true


func _advance_network_holds(net: Node, delta: float) -> void:
	# A single deterministic actor owns each hold. Never sum work across survivors.
	var starter: CampPlayer
	var rescuer: CampPlayer
	var target: CampPlayer
	var ids: Array=net.actors.keys()
	ids.sort()
	for id: int in ids:
		var actor: CampPlayer=net.actors[id]
		if actor.status==CampPlayer.Status.DOWNED: advance_self_recovery(actor,net.holding(id),delta)
		if actor.status!=CampPlayer.Status.ALIVE or not net.holding(id): continue
		var downed := nearby_downed(actor)
		if downed!=null and rescuer==null:
			rescuer=actor
			target=downed
		elif starter==null and van.in_range(actor) and clear_path(actor.position,van.interaction_point()): starter=actor
	if rescuer!=null: advance_revive(rescuer,target,true,delta)
	else:
		revive_target=null
		revive_actor=null
		revive_progress=0
	var was_running := van.running
	van.advance_start(starter if starter!=null else player,starter!=null,delta)
	if not was_running and van.running and starter!=null:
		van.board(starter)
		announce("Engine started. Driver boarded. Others: E beside van to enter.")


func spawn_dropped(kind: String, at: Vector2) -> CampPickup:
	var pickup: CampPickup
	for candidate: CampPickup in pickups:
		if not candidate.available and candidate.has_meta("dropped_unit"):
			pickup=candidate
			break
	if pickup==null:
		pickup=preload("res://scenes/items/pickup.tscn").instantiate()
		pickup.set_meta("dropped_unit",true)
		pickups.append(pickup)
		add_child(pickup)
	pickup.kind=kind
	pickup.z_index=1
	pickup.position=at
	pickup.locked=false
	pickup.available=true
	pickup.show()
	pickup.queue_redraw()
	return pickup


func on_survivor_downed(actor: CampPlayer) -> void:
	if get_node("/root/Net").active and not multiplayer.is_server(): return
	drop_all_items(actor)
	announce("Survivor down! Gear dropped nearby. Hold E beside them to revive (a medkit is faster).")


func drop_all_items(actor: CampPlayer) -> void:
	var kinds: Array[String]=[]
	kinds.assign(actor.inventory)
	actor.inventory.clear()
	for kind: String in actor.supplies:
		for unit in range(actor.supplies[kind]): kinds.append(kind)
		actor.supplies[kind]=0
	actor.tidy_belt()
	for index in range(kinds.size()):
		spawn_dropped(kinds[index],_drop_position(actor.position,index))


func _drop_position(origin: Vector2, index: int) -> Vector2:
	# Keep gear outside the prone sprite, on reachable ground rather than through walls.
	var shape := CircleShape2D.new()
	shape.radius=5
	for radius in [32,40,48,56]:
		for step in range(32):
			var at: Vector2=origin+Vector2.from_angle((step+index*7)*TAU/32)*radius
			if not clear_path(origin,at): continue
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape=shape
			query.transform=Transform2D(0,at)
			query.collision_mask=1
			if get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): return at
	# Extremely cramped geometry: draw the pickup above the body so it remains visible.
	return origin
