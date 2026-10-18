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
var escape_route: String = ""
var message: String = "Search camp buildings. Tab opens your notebook: map, plan and field guide."
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
## The Seamstress's thread: stitched survivors stay within this distance.
const TETHER_LENGTH := 80.0
## New items from the monster revamp (belt supplies).
const CREATURE_ITEMS: Array[String] = ["garlic", "wolfsbane", "bug_spray", "scissors", "train_ticket", "air_horn", "coffee"]
const ITEM_HINTS := {"garlic": "Vampires can't stand it.", "wolfsbane": "Throw it at a werewolf.", "bug_spray": "Moths and imps hate it.",
	"scissors": "Cuts a Seamstress thread.", "train_ticket": "The Conductor honours it.", "air_horn": "Stuns the stalker. Very loud.", "coffee": "Keeps you awake."}
const HELP_PING_SECONDS := 8.0
var world_objects: Node2D
var plan := RoundPlan.new()
var soundscape: CampSoundscape
var sight: WoodsVisibility
var pins: Array[Dictionary] = []
## Host sound events for clients ({id, cue, at, gain, pitch, length, time}); see CampSoundscape.broadcast.
var sound_log: Array[Dictionary] = []
var night_clock: NightClock
var objective_page := 0
var escapes: FieldEscapes
var rescue: RadioRescue
var props: ChaseProps
var abilities: SurvivorAbilities
var signal_fire: SignalFire
var snares: Snares
var events: NightEvents
## End-of-night award titles (host computes, clients receive in snapshots).
var awards_text := ""
## F8: tonight's score card (host computes; clients receive it) and local journal.
var score_card: Dictionary = {}
var notes_read := 0
## Bigfoot fur tufts recovered tonight (+300 score each).
var furs := 0
## Night feats for badges (e.g. "mower": the Groundskeeper's spark plug pulled). Synced.
var feats: Array[String] = []
## The stalker's calling cards: {position, text}, newest last (synced).
var cards: Array[Dictionary] = []
const MAX_CARDS := 8
var tonight_seen: Dictionary = {}
var profile_recorded := false
## Team-wide clue chain per locked-cache part: 0 direction, 1 region named, 2 cache found.
var clues: Dictionary = {}
const PINS_PER_PLAYER := 3
## F5c van finale: expedition departures are a 20 s hold-out; the engine revs
## every few seconds and every creature in earshot comes for the van.
const EXPEDITION_DEPARTURE := 20.0
const VAN_REV_SECONDS := 5.0
var van_rev_clock := 0.0


func _ready() -> void:
	add_to_group("round_world")
	var session: Node = get_node("/root/Session")
	plan.generate(session.begin_run(), session.mode)
	if plan.expedition:
		config = config.duplicate() as CampConfig
		config.extraction_seconds = EXPEDITION_DEPARTURE
	for kind: String in plan.cache_zone:
		clues[kind] = 1 if kind == "fuel" else 0
	# The Scout read the trail maps before dark: one extra part's region is known.
	if session.survivor == "scout":
		for kind: String in plan.cache_zone:
			if clues[kind] == 0:
				clues[kind] = 1
				break
	if plan.expedition:
		message = "DUSK. Corkboard: fuel is at the %s; notes on the roads name the rest. Rumour: %s might get you out too (T). Camp stays safe until Deep Night." % [plan.region_name("fuel"), plan.rumour_text()]
		message += " Tonight THE %s hunts." % plan.headline.to_upper()
		if not plan.modifiers.is_empty():
			message += " %s." % plan.modifier_text()
		message_time = 10.0
	world_objects = Node2D.new()
	world_objects.name = "WorldObjects"
	world_objects.y_sort_enabled = true
	add_child(world_objects)
	var standing := StandingProps.new()
	standing.name = "StandingProps"
	standing.world = world_objects
	add_child(standing)
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
	killer.headline = plan.headline
	# Visit central camp early, then tour the roads and cabin approaches.
	killer.position = Vector2(600,520)
	killer.patrol.assign(camp_tour())
	# Expeditions: camp is off limits to every creature until Deep Night, so
	# the stalker starts out prowling a stretch of woods beyond camp.
	CampKiller.camp_closed = plan.expedition
	if plan.expedition:
		var den := woods_den()
		killer.position = plan.woods.center(den)
		killer.patrol.assign(plan.woods.roaming_route(den, 24))
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
		if item.has("anchor"):
			pickup.position = porch(item["anchor"])
		pickup.locked = item["locked"]
		if item.has("part"):
			pickup.set_meta("part", item["part"])
		pickups.append(pickup)
		add_child(pickup)
	var scrawls := CallingCards.new()
	scrawls.level = self
	add_child(scrawls)
	var trail := preload("res://scripts/world/blood_trail.gd").new()
	trail.z_index = -1
	add_child(trail)
	props = ChaseProps.new()
	props.name = "ChaseProps"
	props.level = self
	add_child(props)
	abilities = SurvivorAbilities.new()
	abilities.name = "Abilities"
	abilities.level = self
	add_child(abilities)
	night_clock = NightClock.new()
	night_clock.name = "NightClock"
	night_clock.level = self
	add_child(night_clock)
	rescue = RadioRescue.new()
	rescue.name = "RadioRescue"
	rescue.level = self
	add_child(rescue)
	escapes = FieldEscapes.new()
	escapes.name = "FieldEscapes"
	escapes.level = self
	add_child(escapes)
	events = NightEvents.new()
	events.name = "NightEvents"
	events.level = self
	add_child(events)
	snares = Snares.new()
	snares.name = "Snares"
	snares.level = self
	add_child(snares)
	signal_fire = SignalFire.new()
	signal_fire.name = "SignalFire"
	signal_fire.level = self
	add_child(signal_fire)
	hud = preload("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	hud.chart.camp_map = camp_map
	hud.chart.player = player
	hud.chart.van = van
	hud.chart.plan = plan
	hud.chart.level = self
	hud.notebook.level = self
	hud.notebook.online = get_node("/root/Net").active
	hud.moon_dial.level = self
	hud.broadcast.level = self
	hud.effects_overlay.player = player
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
	sight.canopy = camp_map.woods_canopy
	add_child(sight)
	soundscape = CampSoundscape.new()
	soundscape.level = self
	add_child(soundscape)
	if get_node("/root/Net").active:
		get_node("/root/Net").attach_world(self)
	if plan.has_modifier("lone_wolf"):
		_scatter_survivors()
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
		heading = "VAN %d/%d · %s %s · %s" % [van.installed.size(), plan.required.size(), NightClock.PHASES[clock.phase], NightClock.clock_text(clock.elapsed), plan.weather.to_upper()]
	if van.installed.size() == plan.required.size():
		heading = "VAN REPAIRED  ·  HOLD E AT THE REAR TO START"
	if van.running:
		heading = "DEPARTING IN %.1fs  ·  %d ABOARD" % [van.remaining, van.passengers.size()]
	if plan.expedition and rescue.transmitted and (not van.running or (rescue.started and rescue.remaining <= van.remaining)):
		heading = rescue.heading()
	if plan.expedition and not escapes.heading().is_empty():
		heading = escapes.heading()
	if plan.expedition and not signal_fire.heading().is_empty():
		heading = signal_fire.heading()
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
	var energy: float = player.stamina / player.config.stamina_max
	hud.set_health(player.health if player.status == CampPlayer.Status.ALIVE else 0.0, player.wounded and player.status == CampPlayer.Status.ALIVE, player.hurt_time)
	if player.wounded and player.status == CampPlayer.Status.ALIVE:
		hud.threat_label.text = "WOUNDED %d HP · MEDKIT HEALS" % ceili(player.health)
	if player.hidden_spot >= 0:
		hud.threat_label.text = "HOLD YOUR BREATH" if player.breath < 0.999 else "HIDDEN"
		energy = player.breath
	if not finished and killer.global_position.distance_to(player.global_position) < 155.0 and sight.can_see(killer.global_position):
		note_sighting(plan.headline)
	if player.notice_time > 0.0:
		detail=player.notice+"\n"+detail
	elif message_time > 0.0:
		detail = message + "\n" + detail
	hud.set_status(heading, detail, energy)
	hud.inventory_label.text = "NIGHT %d / %s%s\nQ FLARE %d · R BATTERY %d · C FOOD %d\n" % [plan.seed_value, plan.weather.to_upper(), (" / " + plan.headline.to_upper() + ((" / " + plan.modifier_text()) if not plan.modifiers.is_empty() else "")) if plan.expedition else "", player.supplies["flare"], player.supplies["battery_pack"], player.supplies["rations"]]
	hud.inventory_label.text += rescue.pack_text() if plan.expedition and rescue.show_in_pack(player) else plan.pack_description(van.installed, night_clock.phase if plan.expedition else 3, clues)
	var page := current_page()
	if page in ["boat", "gate"]:
		hud.inventory_label.text = "NIGHT %d\n" % plan.seed_value + escapes.pack_text(page)
	elif page == "signal":
		hud.inventory_label.text = "NIGHT %d\n" % plan.seed_value + signal_fire.pack_text()
	if plan.expedition and page in ["van", "radio"]:
		hud.inventory_label.text += "\nCUTTERS: " + ("YES" if "boltcutters" in player.inventory else "MAINT./%s WOODS BOX" % plan.toolbox_hint) + (" +BAR" if "crowbar" in player.inventory else "")
	hud.update_belt(player)
	hud.location_label.text = camp_map.location_label(player.global_position)
	if plan.expedition:
		var post := plan.woods.signpost_near(player.global_position)
		if not post.is_empty() and sight.can_see(post["position"]):
			hud.location_label.text = WoodsLayout.signpost_text(post)
	if player.has_effect("lost"):
		hud.location_label.text = "LOST · ??? (stay beside a teammate, or read a ranger note)"
	hud.supplies_label.text = "LIGHT %ds / FLARES %d" % [int(player.flashlight_charge / player.light_drain), player.supplies["flare"]] if plan.expedition else "QUICK CAMP"
	hud.ability_label.text = abilities.status_text(player) + " · H GIVE" if player.status == CampPlayer.Status.ALIVE else ""
	for enemy: CampKiller in get_tree().get_nodes_in_group("cryptids"):
		# No on-screen monster readout: listen for calls and your heartbeat.
		if player.global_position.distance_to(enemy.global_position) < 180 and sight.can_see(enemy.global_position):
			# Disguised or buried creatures only count once they show themselves.
			var cryptid: CampCryptid = enemy
			if cryptid.species == "mimic" and cryptid.brain != null and cryptid.brain.revealed <= 0.0:
				continue
			if cryptid.species == "bog_hands" and cryptid.brain != null and cryptid.brain.sinking <= 0.0:
				continue
			note_sighting(enemy.species)
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
			_van_started()
	rescue.advance(delta)
	escapes.advance(delta)
	signal_fire.advance(delta)
	if van.running and plan.expedition and not finished:
		van_rev_clock -= delta
		if van_rev_clock <= 0.0:
			van_rev_clock = VAN_REV_SECONDS
			loud_noise(van.global_position, 900)
	if finished:
		return
	_advance_chase_toolkit(delta)
	_advance_effects(delta)
	_advance_clues()
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
		escape_route = "VAN"
		finish_round(escaped > 0, detail)


func try_interact(actor: CampPlayer) -> bool:
	if paused or finished or actor.status != CampPlayer.Status.ALIVE or not actor.is_in_group("survivors"):
		return false
	# Held by a creature: every press wriggles toward breaking free.
	if actor.has_effect("held"):
		var captor: Node = actor.holder
		if actor.wriggle():
			if captor is CampKiller and captor.traits != null:
				# Tearing free of the stalker leaves you sprawled, empty-handed.
				actor.add_effect("tripped", 1.0)
				drop_held(actor)
				announce("You tear free and hit the ground! Whatever you held went flying. RUN!", actor)
			else:
				announce("You wriggle free!", actor)
		return true
	if actor.has_effect("asleep") or actor.has_effect("tripped"):
		return false
	# Pull a held teammate loose (counts double).
	for other: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if other != actor and other.has_effect("held") and actor.global_position.distance_to(other.global_position) <= config.interact_radius * 1.6:
			other.wriggle()
			if other.wriggle():
				announce("%s pulled you free!" % (actor.peer_name if not actor.peer_name.is_empty() else "A teammate"), other)
			return true
	if actor.has_effect("frog"):
		announce("Ribbit. Frogs can't do that.", actor)
		return false
	if actor.hidden_spot >= 0:
		return props.interact(actor)
	if not snares.prompt(actor).is_empty():
		return snares.interact(actor)
	var creature := creature_prompt(actor)
	if not creature.is_empty():
		return creature[0].brain.interact(actor)
	if not events.prompt(actor).is_empty():
		return events.interact(actor)
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
					soundscape.broadcast("lock_rattle", pickup.global_position)
					actor.noise_emitted.emit(actor.global_position)
					return false
				pried = true
			if actor.supplies.has(pickup.kind) and not actor.can_pack(pickup.kind):
				announce("Belt full. Select a slot and G to drop its stack.",actor)
				return false
			if pickup.kind in ["boltcutters", "crowbar"] and pickup.kind in actor.inventory:
				announce("You already carry " + pickup.kind + ". Leave these for a teammate.",actor)
				return false
			if pickup.kind == "ranger_note":
				pickup.consume()
				actor.clear_effect("lost")
				read_note(pickup.get_meta("part", ""))
				return true
			if pickup.kind == "bigfoot_fur":
				pickup.consume()
				furs += 1
				announce("Bigfoot fur! Proof for the camp journal (+300 score).", actor)
				return true
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
			elif pickup.kind in FieldEscapes.BOAT_PARTS or pickup.kind.begins_with("gate_code_") or pickup.kind in SignalFire.PARTS:
				announce("Objective recovered. T cycles escape plans. Motor carriers: G sets it down; a teammate can hold E nearby to help.", actor)
			elif pickup.kind == "rescue_fuse":
				announce("Emergency fuse found. Fit it at the north Power Substation; relay station lies east.", actor)
			elif pickup.kind == "boltcutters":
				announce("Boltcutters found. Woods caches can now be opened with E.",actor)
			elif pickup.kind == "crowbar":
				announce("Crowbar found. It pries caches open, but loudly.",actor)
			elif pickup.kind in CREATURE_ITEMS:
				announce("Packed %s. Select it (1-6) and V to use. %s" % [pickup.kind.replace("_", " "), ITEM_HINTS.get(pickup.kind, "")], actor)
			else:
				announce("Packed " + pickup.kind.replace("_", " ") + ". Q flare / R battery / C food.",actor)
			return true
	if not escapes.prompt(actor).is_empty():
		return escapes.interact(actor)
	if not signal_fire.prompt(actor).is_empty():
		return signal_fire.interact(actor)
	if not rescue.prompt(actor).is_empty():
		return rescue.interact(actor)
	for site in camp_map.sites:
		if not site.nearby(actor).is_empty():
			return site.interact(actor)
	if near_generator(actor):
		return night_clock.restart_generator(actor)
	if props.interact(actor):
		return true
	if van.in_range(actor) and clear_path(actor.global_position, van.interaction_point()):
		var count := van.deliver(actor)
		if count > 0:
			announce("Installed %d component(s)." % count,actor)
			return true
		if van.installed.size() == plan.required.size():
			return true
	announce("Hold E to revive. A medkit makes it faster." if nearby_downed(actor)!=null else "Nothing to use here. Tab opens the map and plan.",actor)
	actor.noise_emitted.emit(actor.global_position)
	return false


## Whether `actor` is holding E right now (local key offline, input packets online).
func holding(actor: CampPlayer) -> bool:
	var net: Node = get_node("/root/Net")
	if net.active:
		var id: Variant = net.actors.find_key(actor)
		return id != null and net.holding(id)
	return actor == player and Input.is_action_pressed("interact")


## A creature that offers an E action beside it (the mower's spark plug, a toll).
func creature_prompt(actor: CampPlayer) -> Array:
	for enemy: CampCryptid in get_tree().get_nodes_in_group("cryptids"):
		if enemy.enabled and enemy.brain != null and enemy.brain.has_method("prompt"):
			var text: String = enemy.brain.prompt(actor)
			if not text.is_empty():
				return [enemy, text]
	return []


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
		abilities.stat(actor)["revives"] += 1
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
	# A flash swats a moth off your own face, or off a teammate's in front of you.
	var swatted := false
	for enemy: CampCryptid in get_tree().get_nodes_in_group("cryptids"):
		if enemy.brain != null and enemy.brain.has_method("swat") and is_instance_valid(enemy.brain.riding):
			var wearer: CampPlayer = enemy.brain.riding
			if wearer == actor or (wearer.global_position.distance_to(actor.global_position) < 70.0 and actor.facing.dot(actor.global_position.direction_to(wearer.global_position)) > 0.5):
				enemy.brain.swat()
				swatted = true
				announce("SWAT! The moth tumbles away.", wearer)
	actor.flash_time = 0.18
	actor.flash_cooldown = CampPlayer.FLASH_COOLDOWN
	var stunned := 0
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		var offset := enemy.global_position - actor.global_position
		if enemy.enabled and offset.length() <= 90.0 and actor.facing.dot(offset.normalized()) >= 0.75 and clear_path(actor.global_position, enemy.global_position) and enemy.stun(1.5):
			stunned += 1
	if not swatted:
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


## Creature effects the level owns: stitched pairs stay within reach of each
## other, and sneezy survivors sneeze loudly now and then.
func _advance_effects(delta: float) -> void:
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status != CampPlayer.Status.ALIVE:
			continue
		if actor.has_effect("tethered"):
			var partner: Variant = actor.get_meta("tether_partner") if actor.has_meta("tether_partner") else null
			var anchor: Vector2 = actor.effect_data.get("tether_to", actor.global_position)
			if is_instance_valid(partner) and partner.has_effect("tethered"):
				anchor = partner.global_position
			elif partner != null:
				actor.clear_effect("tethered")
				actor.remove_meta("tether_partner")
				continue
			actor.effect_data["tether_to"] = anchor
			var gap := actor.global_position.distance_to(anchor)
			if gap > TETHER_LENGTH:
				# The thread drags you back toward the other end.
				actor.move_and_collide(actor.global_position.direction_to(anchor) * minf(gap - TETHER_LENGTH, 220.0 * delta))
		if actor.has_effect("sneezy"):
			var clock: float = actor.get_meta("sneeze_clock", randf_range(3.0, 7.0)) - delta
			if clock <= 0.0:
				clock = randf_range(5.0, 9.0)
				actor.add_effect("achoo", 0.9)
				loud_noise(actor.global_position, 260)
			actor.set_meta("sneeze_clock", clock)


func read_note(kind: String) -> void:
	if not clues.has(kind):
		return
	var region := plan.region_name(kind)
	if clues[kind] < 1:
		clues[kind] = 1
		notes_read += 1
		announce("Ranger note: the %s was stashed at the %s." % [kind.replace("_", " ").to_upper(), region])
	else:
		announce("Ranger note: %s at the %s. You already knew." % [kind.replace("_", " ").to_upper(), region])


## Walking into a part's region names it; once its cache is revealed, it is marked.
func _advance_clues() -> void:
	if clues.is_empty():
		return
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status != CampPlayer.Status.ALIVE:
			continue
		var zone := plan.woods.zone_at(actor.global_position)
		if zone.is_empty():
			continue
		var index := plan.woods.zones.find(zone)
		for kind: String in clues:
			if plan.cache_zone[kind] != index or clues[kind] >= 2:
				continue
			var revealed := false
			for pickup in pickups:
				if pickup.kind == kind and pickup.available:
					revealed = true
			if revealed:
				clues[kind] = 2
				announce("The %s cache is here at the %s. It's on your map." % [kind.replace("_", " ").to_upper(), plan.region_name(kind)])
			elif clues[kind] < 1:
				clues[kind] = 1
				announce("Fresh boot prints: something will be stashed here at the %s (%s)." % [plan.region_name(kind), kind.replace("_", " ").to_upper()])


func on_survivor_wounded(actor: CampPlayer) -> void:
	if get_node("/root/Net").active and not multiplayer.is_server(): return
	announce("BADLY HURT (%d health) and bleeding. Break line of sight, then use a medkit." % ceili(actor.health), actor)


func _on_noise(origin: Vector2) -> void:
	if not paused and not finished:
		night_clock.note_noise()
		if events != null:
			events.heard_loud(origin)
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
	if events != null:
		events.heard_loud(origin)
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
	if player.hidden_spot >= 0:
		return props.prompt(player)
	var snare_prompt := snares.prompt(player)
	if not snare_prompt.is_empty():
		return snare_prompt
	var creature := creature_prompt(player)
	if not creature.is_empty():
		return creature[1]
	var event_prompt := events.prompt(player)
	if not event_prompt.is_empty():
		return event_prompt
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
	var field_prompt := escapes.prompt(player)
	if not field_prompt.is_empty():
		return field_prompt
	var fire_prompt := signal_fire.prompt(player)
	if not fire_prompt.is_empty():
		return fire_prompt
	var rescue_prompt := rescue.prompt(player)
	if not rescue_prompt.is_empty():
		return rescue_prompt
	for site in camp_map.sites:
		var action := site.nearby(player)
		if not action.is_empty():
			return "E · " + action["label"] if site.cooldown <= 0 else "LET THE ECHO FADE..."
	if near_generator(player):
		return "E · RESTART GENERATOR (LOUD)"
	var prop_prompt := props.prompt(player)
	if not prop_prompt.is_empty() and not van.in_range(player):
		return prop_prompt
	if van.in_range(player):
		if van.running:
			return "E · ENTER VAN  —  Board before the countdown ends!"
		if van.installed.size() == plan.required.size():
			return "HOLD E · START VAN  %d%%" % int(van.start_progress / player.config.start_hold_seconds * 100)
		return "E · INSTALL SUPPLIES   |   NEED: " + ", ".join(missing_parts()).to_upper()
	if "outboard_motor" in player.inventory:
		return "MOTOR: G drop · teammate holds E nearby to help · T escape plans"
	return "1-6 select · V use · G drop · E interact · Space flash · Tab notebook · T plans" if plan.expedition else "Find battery, fuel, key · E use · F light · Tab notebook · Esc pause"


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


## Lone Wolf: each survivor starts at a different camp building door.
func _scatter_survivors() -> void:
	var doors: Array[Vector2] = []
	for building: CampBuilding in camp_map.buildings:
		doors.append(building.door + Vector2(0, 14))
	var actors: Array = get_tree().get_nodes_in_group("survivors")
	var net: Node = get_node("/root/Net")
	if net.active:
		var ids: Array = net.actors.keys()
		ids.sort()
		actors = ids.map(func(id: int) -> CampPlayer: return net.actors[id])
	for index in range(actors.size()):
		actors[index].position = doors[(plan.seed_value + index * 3) % doors.size()]


func compute_score(success: bool) -> Dictionary:
	var relics := 0
	for site: ForestSite in camp_map.sites:
		for action in site.actions:
			if action["kind"] == "relic" and action["used"]:
				relics += 1
	var revives := 0
	for row: Dictionary in abilities.stats.values():
		revives += int(row["revives"])
	var card := CampProfile.score_night(success, escape_route, relics, notes_read, revives, tonight_seen.size(), plan.modifiers.size(), success and escape_route != "VAN")
	if events.camper_saved:
		card["score"] = int(card["score"]) + 250
		card["grade"] = CampProfile.grade(card["score"])
		card["lines"].append("LOST CAMPER +250")
	if furs > 0:
		card["score"] = int(card["score"]) + 300 * furs
		card["grade"] = CampProfile.grade(card["score"])
		card["lines"].append("BIGFOOT FUR ×%d +%d" % [furs, 300 * furs])
	return card


## Local journal/badges for this machine's player (once per night). Returns any
## newly earned badges as result-screen lines.
func record_profile(success: bool) -> String:
	if profile_recorded or not plan.expedition:
		return ""
	profile_recorded = true
	var session: Node = get_node("/root/Session")
	var helped: bool = int(abilities.stat(player)["revives"]) > 0
	var earned: Array[String] = session.profile.record_night(plan.seed_value, score_card, success, escape_route, plan.headline, plan.modifiers, session.daily, helped, feats)
	var text := ""
	for id in earned:
		text += "\nNEW BADGE: " + CampProfile.BADGES[id][0]
	var best: int = session.profile.best(plan.seed_value)
	if best > 0:
		text += "\nBEST ON NIGHT %d: %d" % [plan.seed_value, best]
	return text


## First sightings unlock journal entries (local to this player).
func note_sighting(species: String) -> void:
	if tonight_seen.has(species):
		return
	tonight_seen[species] = true
	if plan.expedition and get_node("/root/Session").profile.record_sighting(species):
		announce("New journal entry: %s." % CampProfile.display_name(species), player)


func _van_started() -> void:
	if plan.expedition:
		# The finale: the engine roar brings everything into camp whatever the hour.
		open_camp()
		van_rev_clock = VAN_REV_SECONDS
		loud_noise(van.global_position, 1200)
		killer.hear_stimulus(van.global_position, 6000)
		announce("ENGINE ROARS. %ds to departure; the woods heard it. Everyone: E beside the van to board!" % int(EXPEDITION_DEPARTURE))
	else:
		announce("Engine started. Driver boarded automatically. Others: E to enter.")


## Select tonight's escape plan `index` (T or a click in the notebook).
func select_route(index: int) -> void:
	if not plan.expedition:
		return
	objective_page = posmod(index, plan.escape_options.size())
	rescue.pack_selected = current_page() == "radio"


## Tonight's objective page shown by T ("van", "radio", "boat", "gate" or "signal").
func current_page() -> String:
	if not plan.expedition:
		return "van"
	return plan.escape_options[clampi(objective_page, 0, plan.escape_options.size() - 1)]


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
	var titles := abilities.awards()
	if plan.expedition:
		score_card = compute_score(success)
		titles.push_front("SCORE %d · GRADE %s" % [score_card["score"], score_card["grade"]])
	awards_text = ("\n" + "\n".join(titles)) if not titles.is_empty() else ""
	hud.show_result(success, detail + "\nNight %d / %s" % [plan.seed_value, plan.weather] + awards_text + record_profile(success))
	print(JSON.stringify({"event": "round_finished", "won": success, "result": detail}))


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	if plan.expedition and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		# T opens the plan; with the notebook already on the plan or map, it picks the next route.
		if hud.notebook.visible and hud.notebook.view in ["plan", "map"]:
			select_route((objective_page + 1) % plan.escape_options.size())
		else:
			hud.notebook.open_view("plan")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory") and not event.is_echo() and not paused:
		hud.notebook.cycle(event is InputEventWithModifiers and event.shift_pressed)
		get_viewport().set_input_as_handled()
		return
	if hud.notebook.visible and event.is_action_pressed("pause"):
		hud.notebook.close()
		get_viewport().set_input_as_handled()
		return
	if hud.notebook.visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Z:
		hud.notebook.secondary()
		get_viewport().set_input_as_handled()
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
		if event.physical_keycode == KEY_X:
			abilities.use(player)
			return
		if event.physical_keycode == KEY_H:
			abilities.give(player)
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
		if player.has_effect("dark"):
			announce("The card's curse: your flashlight won't light.", player)
		elif not player.expedition or player.flashlight_charge > 0:
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
	if actor.has_effect("held") or actor.has_effect("asleep") or actor.has_effect("tripped"):
		return false
	if actor.has_effect("frog"):
		announce("Ribbit. Frogs can't use items.", actor)
		return false
	if kind == "flare":
		abilities.stat(actor)["flares"] += 1
		var flare := preload("res://scripts/items/flare.gd").new()
		var target := actor.global_position + actor.facing * 28
		flare.position = target if clear_path(actor.global_position, target) else actor.global_position
		world_objects.add_child(flare)
		actor.noise_emitted.emit(flare.global_position)
		announce("Flare out! Teeth hate it. Wings don't.",actor)
	elif kind == "battery_pack":
		if actor.flashlight_charge >= config.flashlight_capacity:
			return false
		actor.flashlight_charge = minf(config.flashlight_capacity, actor.flashlight_charge + (40 if plan.has_modifier("dead_batteries") else 70))
		actor.flashlight_on = true
	elif kind == "rations":
		if actor.stamina >= actor.config.stamina_max and actor.health >= CampPlayer.MAX_HEALTH:
			return false
		actor.stamina = actor.config.stamina_max
		actor.exhausted = false
		actor.heal(CampPlayer.RATION_HEAL)
		# Food is also bait: a hound or a jackal within reach takes it instead.
		for enemy: CampCryptid in get_tree().get_nodes_in_group("cryptids"):
			if enemy.brain != null and enemy.brain.has_method("bait") and enemy.brain.bait(actor):
				break
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
		if actor.health >= CampPlayer.MAX_HEALTH:
			announce("You're at full health. Save the medkit for a revive.", actor)
			return false
		actor.heal(CampPlayer.MEDKIT_HEAL)
		announce("Medkit: +%d health (%d/%d)." % [int(CampPlayer.MEDKIT_HEAL), ceili(actor.health), int(CampPlayer.MAX_HEALTH)], actor)
	elif kind == "glow_moss":
		actor.flashlight_charge = minf(actor.config.flashlight_capacity, actor.flashlight_charge + 35)
		actor.hex_remaining = 0
		actor.add_effect("glowing", 60.0)
		announce("Glow moss: hexes cleared, +35 light, and you glow for 60 s (nothing can snuff it).",actor)
	elif kind == "garlic":
		actor.add_effect("garlic", 60.0)
		announce("You reek of garlic. Vampires keep their distance for 60 s.", actor)
	elif kind == "bug_spray":
		actor.add_effect("bug_spray", 45.0)
		announce("Pssssht. Moths and imps keep off for 45 s.", actor)
	elif kind == "coffee":
		actor.add_effect("coffee", 90.0)
		actor.clear_effect("drowsy")
		actor.stamina = actor.config.stamina_max
		actor.exhausted = false
		announce("Camp coffee: wide awake for 90 s, and full stamina.", actor)
	elif kind == "scissors":
		var cut := false
		for other: CampPlayer in get_tree().get_nodes_in_group("survivors"):
			if other.has_effect("tethered") and (other == actor or other.global_position.distance_to(actor.global_position) <= config.interact_radius * 1.6):
				for end: CampPlayer in [other, other.get_meta("tether_partner") if other.has_meta("tether_partner") else null]:
					if is_instance_valid(end):
						end.clear_effect("tethered")
						if end.has_meta("tether_partner"):
							end.remove_meta("tether_partner")
				cut = true
		if not cut:
			announce("Nothing to cut. Scissors snip a Seamstress thread.", actor)
			return false
		soundscape.broadcast("scissors", actor.global_position, 0.0, 1.0)
		announce("Snip! The thread falls away.")
	elif kind == "wolfsbane":
		var struck := false
		for enemy: CampCryptid in get_tree().get_nodes_in_group("cryptids"):
			var offset := enemy.global_position - actor.global_position
			if enemy.brain != null and enemy.brain.has_method("repel") and offset.length() < 150.0 and actor.facing.dot(offset.normalized()) > 0.5:
				enemy.brain.repel(90.0)
				struck = true
		announce("Wolfsbane! The beast whimpers and turns back." if struck else "The wolfsbane lands in the dirt. Throw it at a werewolf.", actor)
	elif kind == "air_horn":
		var stunned := false
		if killer.enabled and killer.global_position.distance_to(actor.global_position) < 280.0:
			killer.release_held()
			killer.stun_immunity = 0.0
			stunned = killer.stun(5.0)
		loud_noise(actor.global_position, 1500)
		soundscape.broadcast("air_horn", actor.global_position)
		announce("HOOOONK! The %s staggers, stunned!" % plan.headline.to_upper() if stunned else "HOOOONK! Everything in the woods heard that.", actor)
	elif kind == "train_ticket":
		announce("Keep it handy: the Conductor gives ticket holders a free ride to camp.", actor)
		return false
	else:
		return false
	actor.supplies[kind] -= 1
	actor.tidy_belt()
	return true


func camp_tour() -> Array[Vector2]:
	var perimeter: Array[Vector2]=[Vector2(360,520),Vector2(360,216),Vector2(960,216),Vector2(960,520),Vector2(1400,520),Vector2(960,840),Vector2(600,520)]
	if plan.seed_value % 2 == 1: perimeter.reverse()
	var tour: Array[Vector2] = [Vector2(360,520),Vector2(96,520),Vector2(96,384),Vector2(96,520)]
	tour.append_array(perimeter)
	return tour


## A seeded woods clearing well clear of camp where the stalker waits out the first half.
func woods_den() -> Vector2i:
	var options: Array[Vector2i] = []
	var middle := CampMap.CAMP_BOUNDS.get_center()
	for cell: Vector2i in plan.woods.links:
		var distance := plan.woods.center(cell).distance_to(middle)
		if distance >= RoundPlan.SAFE_RADIUS and distance <= RoundPlan.SAFE_RADIUS + 500.0 and plan.woods.zone_at(plan.woods.center(cell)).is_empty():
			options.append(cell)
	if options.is_empty():
		return WoodsLayout.ENTRY + Vector2i(-6, 0)
	options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y * WoodsLayout.SIZE.x + a.x < b.y * WoodsLayout.SIZE.x + b.x)
	return options[posmod(plan.seed_value * 7919, options.size())]


## Open ground just beside a camp building's door (camp creature items).
func porch(label: String) -> Vector2:
	for building: CampBuilding in camp_map.buildings:
		if building.label != label:
			continue
		# The first spot beside the door that's clear of walls, trees and props.
		for offset: Vector2 in [Vector2(30, 44), Vector2(-30, 44), Vector2(0, 56), Vector2(48, 52), Vector2(-48, 52)]:
			var spot: Vector2 = building.door + offset
			if not camp_map.obstacles.any(func(rect: Rect2) -> bool: return rect.grow(8).has_point(spot)):
				return spot
		return building.door + Vector2(0, 40)
	return Vector2(150, 420)


## The stalker's hook: a post in his woods lair (expeditions only).
func hook_point() -> Vector2:
	if not plan.expedition:
		return Vector2.INF
	return plan.woods.center(woods_den()) + Vector2(0, 24)


func pin_hook() -> void:
	_pin_once(-5, 4, hook_point(), "HOOK")


func pin_den(at: Vector2) -> void:
	_pin_once(-4, 3, at, "DEN")


func _pin_once(owner: int, slot: int, at: Vector2, label: String) -> void:
	if pins.any(func(pin: Dictionary) -> bool: return pin["owner"] == owner and pin["position"].distance_to(at) < 4.0):
		return
	pins.append({"owner": owner, "slot": slot, "position": at.round(), "name": label, "place": pin_place(at)})


func add_card(at: Vector2, text: String) -> void:
	cards.append({"position": at.round(), "text": text})
	while cards.size() > MAX_CARDS:
		cards.pop_front()


## Deep Night: creatures may now enter camp, and the stalker tours it.
func open_camp() -> void:
	if not CampKiller.camp_closed:
		return
	CampKiller.camp_closed = false
	killer.patrol.assign(camp_tour())
	killer.patrol_index = 0


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
		# One junk pile per Trash Jackal den.
		if enemy.brain != null and "den" in enemy.brain and not world_objects.get_children().any(func(node: Node) -> bool: return node is JackalDen and node.position.distance_to(enemy.brain.den) < 4.0):
			var pile := JackalDen.new()
			pile.position = enemy.brain.den
			world_objects.add_child(pile)


func _apply_weather() -> void:
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		# Never mutate the shared default resource or another creature's tuning.
		enemy.config = enemy.config.duplicate() as CampConfig
		if plan.expedition and enemy == killer:
			enemy.config.sight_radius = 150
			enemy.config.hearing_radius = 220
		if plan.weather == "fog":
			enemy.config.sight_radius *= 0.72
		if plan.has_modifier("silent_night"):
			enemy.config.hearing_radius *= 1.15
		if plan.has_modifier("blood_moon") and enemy == killer:
			enemy.config.killer_chase_speed *= 1.08
		elif plan.weather == "rain":
			enemy.config.hearing_radius *= 0.7


func drop_held(actor: CampPlayer) -> bool:
	if paused or finished or actor.status != CampPlayer.Status.ALIVE:
		return false
	if "outboard_motor" in actor.inventory:
		actor.inventory.erase("outboard_motor")
		spawn_dropped("outboard_motor", _drop_position(actor.global_position, 0))
		announce("Motor set down. E to pick up; sprint is available again.", actor)
		return true
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
		_van_started()


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
	abilities.stat(actor)["downs"] += 1
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
			query.collision_mask=1 | CampPlayer.WATER_LAYER
			if get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): return at
	# Extremely cramped geometry: draw the pickup above the body so it remains visible.
	return origin
