class_name RadioRescue
extends Node2D
## F5a: host-owned alternate expedition escape. Clients only restore snapshots.
const TRANSMIT_SECONDS := 6.0
const HOLDOUT_SECONDS := 40.0
const ZONE_RADIUS := 96.0
const SOCKET_OFFSETS: Array[Vector2] = [Vector2(-65, 32), Vector2(65, 32), Vector2(0, -65)]
var level: Node2D
var active := false
## Relay interaction/landing only on radio nights; scenery exists every Expedition.
var relay_enabled := false
var powered := false
var transmitted := false
var signals: Array[bool] = [false, false, false]
var progress := 0.0
var remaining := HOLDOUT_SECONDS
var started := false
var starter: CampPlayer
var pack_selected := false
var power_point := Vector2.ZERO
var relay_point := Vector2.ZERO
var landing := Vector2.ZERO
var lamps: Array[PointLight2D] = []
var pulse := 0.0
var noise_clock := 0.0


func _ready() -> void:
	set_meta("stand_in_world", true)
	relay_enabled = level.plan.expedition and level.plan.has_escape("radio")
	active = level.plan.expedition and (relay_enabled or level.plan.has_escape("gate"))
	if not level.plan.expedition:
		return
	power_point = level.plan.woods.zones[9]["position"] + Vector2(0, 48)
	relay_point = level.plan.woods.zones[10]["position"] + Vector2(0, 56)
	landing = level.plan.woods.zones[8]["position"] + Vector2(0, 230)
	var structures := preload("res://scripts/world/rescue_structures.gd").new()
	structures.rescue = self
	add_child(structures)
	if not active:
		return
	for offset in SOCKET_OFFSETS:
		var lamp := CampLights.lamp(self, landing + offset, 150, Color("ff9c66"), 2.0)
		lamp.enabled = false
		lamps.append(lamp)
	lamps.append(CampLights.lamp(self, power_point, 180, Color("b1d59b"), 0.9))
	lamps.append(CampLights.lamp(self, relay_point, 180, Color("b4d8db"), 0.9))


func _process(delta: float) -> void:
	if not active:
		return
	pulse += delta
	for index in range(3):
		lamps[index].enabled = signals[index]
	lamps[3].enabled = powered
	lamps[4].enabled = powered and relay_enabled
	queue_redraw()


func authority() -> bool:
	var net: Node = get_node("/root/Net")
	return not net.active or (multiplayer.is_server() and not net.waiting)


func near(actor: CampPlayer, point: Vector2) -> bool:
	return active and CreatureSamples.can_interact(actor) and actor.is_in_group("survivors") and actor.status == CampPlayer.Status.ALIVE and actor.hidden_spot < 0 and actor.global_position.distance_to(point) <= actor.config.interact_radius and level.clear_path(actor.global_position, point)


func prompt(actor: CampPlayer) -> String:
	if not active:
		return ""
	if near(actor, power_point):
		return "SUBSTATION ONLINE · FIND RADIO RELAY" if powered else "E · FIT EMERGENCY FUSE / T FOR LOCATION"
	if not relay_enabled:
		return ""
	if near(actor, relay_point):
		if transmitted:
			return "DISTRESS SENT · SIGNAL LANDING ZONE SOUTH OF CHAPEL"
		if not powered:
			return "RELAY OFFLINE · RESTORE POWER SUBSTATION"
		return "HOLD E · CLIMB / TRANSMIT  %d%%" % int(progress / TRANSMIT_SECONDS * 100)
	for index in range(3):
		if near(actor, landing + SOCKET_OFFSETS[index]):
			return "SIGNAL %d LIT · STAY INSIDE THE CIRCLE" % (index + 1) if signals[index] else "E · LOAD FLARE INTO SIGNAL %d (%d/3 LIT)" % [index + 1, signals.count(true)]
	if near(actor, landing):
		return heading() + " · STAY INSIDE THE CIRCLE" if started else ("E · START 40s RESCUE HOLDOUT / GATHER TEAM FIRST" if transmitted and signals.count(true) == 3 else "LANDING ZONE · NEED DISTRESS CALL + THREE SIGNALS")
	return ""


func interact(actor: CampPlayer) -> bool:
	if not authority() or level.finished or level.paused:
		return false
	if near(actor, power_point):
		if powered:
			return true
		if "rescue_fuse" not in actor.inventory:
			var region: int=level.plan.objective_zone.get("rescue_fuse",3)
			level.announce("Emergency fuse: %s. It uses no belt slot; bring it to this cabinet." % WoodsLayout.short_name(level.plan.woods.zones[region]),actor)
			return false
		actor.inventory.erase("rescue_fuse")
		powered = true
		SurvivorKits.progress(actor,"substation:power")
		level.loud_noise(power_point, 750)
		level.announce("Rescue circuit restored. Transmit from the Radio Relay Station and light three chapel signals." if relay_enabled else "Substation restored. The Ranger Gate breaker can now power its floodlights.")
		return true
	if not relay_enabled:
		return false
	if near(actor, relay_point):
		level.announce(prompt(actor), actor)
		return powered
	for index in range(3):
		if near(actor, landing + SOCKET_OFFSETS[index]):
			if signals[index]:
				return true
			if actor.supplies["flare"] <= 0:
				level.announce("A signal needs one flare. Check the emergency stash beside the circle.", actor)
				return false
			actor.supplies["flare"] -= 1
			actor.tidy_belt()
			signals[index] = true
			SurvivorKits.progress(actor,"signal:"+str(index))
			level.loud_noise(landing + SOCKET_OFFSETS[index], 600)
			level.announce("Rescue signal %d/3 lit. Signals burn until rescue; Q throws an ordinary short-lived flare." % signals.count(true))
			return true
	if near(actor, landing) and transmitted and signals.count(true) == 3:
		if not started:
			started = true
			level.announce("RESCUE IN 40 SECONDS. Everyone standing: enter the chapel landing circle! Downed teammates are rescued with you.")
			level.loud_noise(landing, 1000)
		return true
	return false


func advance(delta: float) -> void:
	if not active or not authority() or level.paused or level.finished:
		return
	if not relay_enabled:
		return
	var net: Node = get_node("/root/Net")
	var actor: CampPlayer
	if powered and not transmitted:
		if net.active:
			var ids: Array = net.actors.keys()
			ids.sort()
			# Retain the current operator; another player cannot inherit their hold.
			if is_instance_valid(starter) and near(starter, relay_point) and net.actors.find_key(starter) != null and net.holding(net.actors.find_key(starter)):
				actor = starter
			else:
				for id: int in ids:
					if net.holding(id) and near(net.actors[id], relay_point):
						actor = net.actors[id]
						break
		elif Input.is_action_pressed("interact") and near(level.player, relay_point):
			actor = level.player
	advance_transmit(actor, delta)
	if started:
		remaining = maxf(0.0, remaining - delta)
		noise_clock -= delta
		if noise_clock <= 0:
			noise_clock = 8.0
			# Broadcast a real audible location, never teleport or target unsensed players.
			level.loud_noise(landing, 1000)
		if remaining <= 0:
			_extract()


func advance_transmit(actor: CampPlayer, delta: float) -> void:
	if not authority() or not active or level.paused or level.finished or transmitted:
		return
	if actor == null or not powered or not near(actor, relay_point):
		progress = 0.0
		starter = null
		return
	if starter != actor:
		progress = 0.0
		starter = actor
	progress = minf(TRANSMIT_SECONDS, progress + delta)
	if progress >= TRANSMIT_SECONDS:
		transmitted = true
		SurvivorKits.progress(actor,"radio:transmit")
		level.loud_noise(relay_point, 950)
		level.announce("Distress call received. Light all three signal holders south of the Drowned Chapel, then hold the landing zone.")


func _extract() -> void:
	for survivor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		SurvivorKits.settle(survivor)
	var rescued := 0
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status == CampPlayer.Status.ALIVE and actor.hidden_spot < 0 and actor.global_position.distance_to(landing) <= ZONE_RADIUS and level.clear_path(actor.global_position, landing):
			actor.set_status(CampPlayer.Status.ESCAPED)
			rescued += 1
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status == CampPlayer.Status.DOWNED and rescued > 0:
			actor.set_status(CampPlayer.Status.ESCAPED)
			rescued += 1
		elif actor.status in [CampPlayer.Status.ALIVE, CampPlayer.Status.DOWNED, CampPlayer.Status.BOARDED]:
			actor.set_status(CampPlayer.Status.LEFT_BEHIND)
	level.escape_route = "RADIO RESCUE"
	level.finish_round(rescued > 0, "Radio rescue arrived. %d survivor(s) recovered. You: %s." % [rescued, CampPlayer.Status.keys()[level.player.status].to_lower().replace("_", " ")])


func heading() -> String:
	if started:
		return "RADIO RESCUE %.1fs · CHAPEL LANDING CIRCLE" % remaining
	return "RADIO SENT · CHAPEL SIGNALS %d/3" % signals.count(true)


func show_in_pack(_actor: CampPlayer) -> bool:
	return pack_selected and relay_enabled


func pack_text() -> String:
	var region: int=level.plan.objective_zone.get("rescue_fuse",3)
	return "RADIO RESCUE\n%s FUSE / %s → SUBSTATION\n%s RADIO RELAY / HOLD E 6s TO TRANSMIT\nCHAPEL LANDING / 3 FLARES: %d/3 LIT\nE AT CIRCLE: START 40s HOLD / DOWNED TEAM RESCUED" % ["✓" if powered else "·",WoodsLayout.short_name(level.plan.woods.zones[region]), "✓" if transmitted else "·", signals.count(true)]


func snapshot() -> Dictionary:
	return {"powered": powered, "transmitted": transmitted, "signals": signals.duplicate(), "progress": progress, "remaining": remaining, "started": started}


func restore(state: Dictionary) -> void:
	powered = state["powered"]
	transmitted = state["transmitted"]
	signals.assign(state["signals"])
	progress = state["progress"]
	remaining = state["remaining"]
	started = state["started"]


func _draw() -> void:
	if not active:
		return
	if not relay_enabled:
		return
	var tint := Color("e1c28b") if transmitted else Color("8a9b86")
	draw_arc(landing, ZONE_RADIUS, 0, TAU, 64, tint, 2)
	if not PixelArt.draw_in(self, "helipad", Rect2(landing - Vector2(40, 26), Vector2(80, 50))):
		for side in [-1, 1]:
			draw_line(landing + Vector2(side * 20, -27), landing + Vector2(side * 20, 27), tint, 4)
		draw_line(landing + Vector2(-20, 0), landing + Vector2(20, 0), tint, 4)
	for index in range(3):
		var at := landing + SOCKET_OFFSETS[index]
		draw_circle(at, 10, Color("182c2c"))
		draw_arc(at, 9, 0, TAU, 12, Color("b2ab89"), 2)
		draw_rect(Rect2(at + Vector2(-3, -9), Vector2(6, 10)), Color("d29a68") if signals[index] else Color("56675d"))
		if signals[index]:
			PixelArt.draw_standing(self,"f5_beacon",at+Vector2(0,8),22)
			for spark in range(6):
				var rise := fmod(pulse * 13 + spark * 3, 18)
				draw_rect(Rect2(at + Vector2(sin(spark + pulse) * 5, -rise - 8), Vector2(2, 2)), Color("ffcb8b"))
	draw_string(ThemeDB.fallback_font, landing + Vector2(-67, 116), "RESCUE LANDING ZONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, tint)
	for point in [power_point, relay_point]:
		draw_circle(point, 3, Color("bbd9a2") if powered else Color("cc8b61"))
	if transmitted:
		# A distant approach silhouette, revealed only within the landing-zone view.
		var at := landing + Vector2(0, -160 - remaining * 3)
		if started and remaining < 12:
			if not PixelArt.draw_in(self, "helicopter", Rect2(at - Vector2(30, 30), Vector2(60, 50))):
				draw_rect(Rect2(at - Vector2(9, 15), Vector2(18, 30)), Color("7d9690"))
			# Spinning rotor blur over the airframe.
			draw_line(at + Vector2.from_angle(pulse * 20.0) * 34, at - Vector2.from_angle(pulse * 20.0) * 34, Color(0.85, 0.88, 0.8, 0.5), 2)
