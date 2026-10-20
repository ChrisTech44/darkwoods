class_name FieldEscapes
extends Node2D
## F5b: Boat and Ranger Gate. Authority owns every item, hold, attack and result.
const BOAT_PARTS: Array[String] = ["outboard_motor", "boat_fuel", "drain_plug"]
const GATE_CODES: Array[String] = ["gate_code_1", "gate_code_2", "gate_code_3"]
const BOAT_SECONDS := 25.0
const BRIDGE_SECONDS := 8.0
const OPEN_SECONDS := 4.0
const BOAT_RADIUS := 80.0
var level: Node2D
var active := false
## Tonight's field escapes (see RoundPlan.escape_options).
var boat_enabled := false
var gate_enabled := false
var boat_point := Vector2.ZERO
var gate_point := Vector2.ZERO
var breaker_point := Vector2.ZERO
var bridge := Vector2.ZERO
var boat_installed: Array[String] = []
var gate_installed: Array[String] = []
var boat_started := false
var boat_remaining := BOAT_SECONDS
var gate_powered := false
var gate_open := false
var gate_progress := 0.0
var gate_actor: CampPlayer
var bridge_started := false
var bridge_remaining := BRIDGE_SECONDS
var boat_occupied := false
var barrage: LakeBarrage
var gate_body: StaticBody2D
var floodlights: Array[PointLight2D] = []
var art: Node2D
var pulse := 0.0
var alarm_clock := 0.0
var launch_camera: Camera2D
var previous_zoom := Vector2.ONE
var previous_offset := Vector2.ZERO

func _ready() -> void:
	boat_enabled = level.plan.expedition and level.plan.has_escape("boat")
	gate_enabled = level.plan.expedition and level.plan.has_escape("gate")
	active = boat_enabled or gate_enabled
	if not level.plan.expedition:
		return
	boat_point = level.plan.woods.zones[12]["position"] + Vector2(0,-95)
	gate_point = level.plan.woods.zones[13]["position"] + Vector2(0,500)
	breaker_point = gate_point + Vector2(-116,28)
	bridge = level.plan.woods.zones[13]["position"] + Vector2(0,-500)
	if gate_enabled:
		_build_gate()
	art = preload("res://scripts/world/field_escape_structures.gd").new()
	art.escapes = self
	add_child(art)
	barrage=LakeBarrage.new()
	barrage.escapes=self
	add_child(barrage)

func _build_gate() -> void:
	gate_body = StaticBody2D.new()
	gate_body.collision_layer = CampPlayer.BARRIER_LAYER
	gate_body.collision_mask = 0
	gate_body.position = gate_point + Vector2(0,-28)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(160,12)
	shape.shape = rect
	gate_body.add_child(shape)
	add_child(gate_body)
	for side in [-1,1]:
		var lamp := CampLights.lamp(self, gate_point + Vector2(side*100,-22), 230, Color("e2cf98"), 1.4)
		lamp.enabled = false
		floodlights.append(lamp)
	for index in range(5):
		var at: Vector2 = level.plan.woods.zones[13]["position"] + Vector2(70 if index%2==0 else -70,-500+index*200)
		var lamp := CampLights.lamp(self,at,175,Color("d6ce9b"),0.9)
		lamp.enabled = false
		floodlights.append(lamp)

func _process(delta: float) -> void:
	if not active:
		return
	pulse += delta
	_frame_launch(delta)
	for lamp in floodlights:
		lamp.enabled = gate_powered
	queue_redraw()

## Keep the compact dodge arena visible around the HUD, on the local view only.
func _frame_launch(delta: float) -> void:
	if ServerRuntime.requested() or not is_instance_valid(level.player):return
	var actor: CampPlayer=level.player
	var framing: bool=boat_started and not level.finished and actor.status==CampPlayer.Status.ALIVE and actor.position.distance_to(boat_point)<=BOAT_RADIUS+20
	if framing:
		var camera: Camera2D=actor.get_node("Camera2D")
		if not is_instance_valid(launch_camera) or launch_camera!=camera:
			launch_camera=camera;previous_zoom=camera.zoom;previous_offset=camera.offset
		camera.zoom=camera.zoom.lerp(Vector2.ONE*.65,minf(1,delta*8))
		var target:=boat_point-camera.global_position+Vector2(0,20)
		camera.offset=camera.offset.lerp(target,minf(1,delta*8))
	elif is_instance_valid(launch_camera):
		launch_camera.zoom=previous_zoom;launch_camera.offset=previous_offset;launch_camera=null

func near(actor: CampPlayer, point: Vector2) -> bool:
	return active and CreatureSamples.can_interact(actor) and actor.is_in_group("survivors") and actor.status == CampPlayer.Status.ALIVE and actor.hidden_spot < 0 and actor.global_position.distance_to(point) <= actor.config.interact_radius and level.clear_path(actor.global_position, point)

func prompt(actor: CampPlayer) -> String:
	if not active:
		return ""
	if boat_enabled and near(actor, boat_point):
		if boat_started:
			return "BOAT %.1fs · CIRCLE ADVANCES / DODGE SHOTS" % boat_remaining
		if boat_installed.size() < 3:
			for kind in BOAT_PARTS:
				if kind in actor.inventory and kind not in boat_installed:
					return "E · INSTALL %s (%d/3)" % [part_name(kind), boat_installed.size()]
			return "BOAT REPAIR · NEED %s (%d/3)" % [part_name(next_boat_part()), boat_installed.size()]
		return "E · START / HOLD DOCK CIRCLE FOR 25s"
	if not gate_enabled:
		return ""
	if near(actor, breaker_point):
		return "FLOODLIGHTS ON · GATE ALARM DRAWS THE STALKER" if gate_powered else "E · POWER FLOODLIGHTS / NEED NORTH SUBSTATION"
	if near(actor, gate_point):
		if gate_open:
			return "GATE OPEN · RUN NORTH ALONG ROAD TO BRIDGE"
		if gate_installed.size() < 3:
			return "E · FIT THREE REGIONAL CODE FRAGMENTS (%d/3)" % gate_installed.size()
		if not gate_powered:
			return "RESET FLOODLIGHT BREAKER TO THE LEFT"
		return "HOLD E · OPEN GATE %d%%" % int(gate_progress/OPEN_SECONDS*100)
	if gate_open and actor.status == CampPlayer.Status.ALIVE and actor.global_position.distance_to(bridge) <= 70:
		return "BRIDGE EVACUATION %.1fs · STAY ON BRIDGE" % bridge_remaining
	return ""

func interact(actor: CampPlayer) -> bool:
	if not active or not level.rescue.authority() or level.paused or level.finished:
		return false
	if boat_enabled and near(actor, boat_point):
		if boat_started:
			return true
		var count := _install(actor, BOAT_PARTS, boat_installed)
		if count > 0:
			level.announce("Boat fitted: %d/3 components. T shows the remaining locations." % boat_installed.size())
			return true
		if boat_installed.size() == 3:
			boat_started = true
			level.loud_noise(boat_point,1100)
			level.announce("BOAT: hold the dock circle for 25s of progress. Leaving pauses it. Dodge the Lake Thing's water shots; flares block nearby shots!")
			return true
		level.announce(prompt(actor), actor)
		return false
	if not gate_enabled:
		return false
	if near(actor, breaker_point):
		if gate_powered:
			return true
		if not level.rescue.powered:
			level.announce("Fit the mill emergency fuse at the north Power Substation first.",actor)
			return false
		gate_powered = true
		SurvivorKits.progress(actor,"gate:power")
		# The alarm is an explicit sensed location, never a player-position reveal.
		level.loud_noise(gate_point,1000)
		level.killer.hear_stimulus(gate_point,6000)
		level.announce("Ranger floodlights on. A forest-wide road alarm calls the stalker toward the gate; it must travel there normally.")
		return true
	if near(actor, gate_point):
		_install(actor, GATE_CODES, gate_installed)
		level.announce(prompt(actor),actor)
		return true
	return false

func _install(actor: CampPlayer, parts: Array[String], installed: Array[String]) -> int:
	var count := 0
	for kind in parts:
		if kind in actor.inventory and kind not in installed:
			actor.inventory.erase(kind)
			installed.append(kind)
			SurvivorKits.progress(actor,"field:"+kind)
			count += 1
	return count

func advance(delta: float) -> void:
	if not active or not level.rescue.authority() or level.paused or level.finished:
		return
	_assistance()
	var operator: CampPlayer
	var net: Node = get_node("/root/Net")
	if net.active:
		for actor: CampPlayer in net.actors.values():
			if net.holding(net.actors.find_key(actor)) and near(actor, gate_point) and (operator == null or actor == gate_actor):
				operator = actor
	elif Input.is_action_pressed("interact") and near(level.player, gate_point):
		operator = level.player
	advance_gate(operator,delta)
	if gate_powered:
		alarm_clock -= delta
		if alarm_clock <= 0:
			alarm_clock = 12.0
			level.killer.hear_stimulus(gate_point,6000)
	if boat_started:
		barrage.advance(delta)
		boat_occupied = not boat_crew().is_empty()
		if boat_occupied:boat_remaining = maxf(0.0,boat_remaining-delta)
		if boat_remaining <= 0:
			barrage.stop()
			_extract("BOAT",boat_point,BOAT_RADIUS)
			return
	if gate_open and not bridge_started:
		for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
			if actor.status == CampPlayer.Status.ALIVE and actor.hidden_spot < 0 and actor.global_position.distance_to(bridge) <= 64 and level.clear_path(actor.global_position,bridge):
				bridge_started = true
				level.announce("BRIDGE EVACUATION IN 8s. Reach the north bridge now; standing survivors still outside will be left behind!")
				break
	if bridge_started:
		bridge_remaining = maxf(0.0,bridge_remaining-delta)
		if bridge_remaining <= 0:
			_extract("RANGER GATE",bridge,64)

func _assistance() -> void:
	var net: Node = get_node("/root/Net")
	var actors := get_tree().get_nodes_in_group("survivors")
	for actor: CampPlayer in actors:
		actor.motor_assisted = false
		actor.assisting_motor = false
	for carrier: CampPlayer in actors:
		if carrier.status != CampPlayer.Status.ALIVE or "outboard_motor" not in carrier.inventory or carrier.hidden_spot >= 0:
			continue
		for helper: CampPlayer in actors:
			if helper == carrier or helper.status != CampPlayer.Status.ALIVE or helper.hidden_spot >= 0 or "outboard_motor" in helper.inventory:
				continue
			var holding: bool = net.holding(net.actors.find_key(helper)) if net.active and net.actors.find_key(helper) != null else (helper == level.player and Input.is_action_pressed("interact"))
			if holding and helper.global_position.distance_to(carrier.global_position) <= 48 and level.clear_path(helper.global_position,carrier.global_position):
				carrier.motor_assisted = true
				helper.assisting_motor = true
				break

func advance_gate(actor: CampPlayer, delta: float) -> void:
	if not active or not gate_enabled or not level.rescue.authority() or level.paused or level.finished or gate_open:
		return
	if actor == null or not near(actor,gate_point) or not gate_powered or gate_installed.size() != 3:
		gate_progress = 0
		gate_actor = null
		return
	if gate_actor != actor:
		gate_progress = 0
		gate_actor = actor
	gate_progress = minf(OPEN_SECONDS,gate_progress+delta)
	if gate_progress >= OPEN_SECONDS:
		gate_open = true
		gate_body.get_child(0).set_deferred("disabled",true)
		level.loud_noise(gate_point,1000)
		level.killer.hear_stimulus(gate_point,6000)
		level.announce("RANGER GATE OPEN. Follow the floodlit road NORTH to the bridge. The stalker follows the alarm, not hidden player positions.")

## At least one standing, visible, unheld survivor advances the shared launch.
func boat_crew() -> Array[CampPlayer]:
	var crew: Array[CampPlayer]=[]
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status==CampPlayer.Status.ALIVE and actor.hidden_spot<0 and not actor.has_effect("held") and not actor.has_effect("asleep") and actor.position.distance_to(boat_point)<=BOAT_RADIUS and level.clear_path(actor.position,boat_point):crew.append(actor)
	return crew

func _extract(route: String, point: Vector2, radius: float) -> void:
	for survivor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		SurvivorKits.settle(survivor)
	var rescued := 0
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status == CampPlayer.Status.ALIVE and actor.hidden_spot < 0 and actor.global_position.distance_to(point) <= radius and level.clear_path(actor.global_position,point):
			actor.set_status(CampPlayer.Status.ESCAPED)
			rescued += 1
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status == CampPlayer.Status.DOWNED and rescued > 0:
			actor.set_status(CampPlayer.Status.ESCAPED)
			rescued += 1
		elif actor.status in [CampPlayer.Status.ALIVE,CampPlayer.Status.DOWNED,CampPlayer.Status.BOARDED]:
			actor.set_status(CampPlayer.Status.LEFT_BEHIND)
	level.escape_route = route
	level.finish_round(rescued > 0,"%s evacuation: %d survivor(s) recovered. You: %s." % [route,rescued,CampPlayer.Status.keys()[level.player.status].to_lower().replace("_"," ")])

func heading() -> String:
	var other := INF
	if level.van.running: other = level.van.remaining
	if level.rescue.started: other = minf(other,level.rescue.remaining)
	if boat_started and boat_remaining <= other and (not bridge_started or boat_remaining <= bridge_remaining):
		return "BOAT %.1fs · %s" % [boat_remaining,"DODGE / STAY IN CIRCLE" if boat_occupied else "PAUSED / ENTER DOCK CIRCLE"]
	if bridge_started and bridge_remaining <= other:
		return "BRIDGE EVACUATION %.1fs · NORTH RANGER ROAD" % bridge_remaining
	if gate_open and other == INF and not boat_started and not bridge_started:
		return "RANGER GATE OPEN · RUN NORTH TO THE BRIDGE"
	return ""

static func part_name(kind: String) -> String:
	return {"outboard_motor": "MOTOR", "boat_fuel": "MARINE FUEL", "drain_plug": "DRAIN PLUG"}.get(kind, kind.to_upper())

func next_boat_part() -> String:
	for kind in BOAT_PARTS:
		if kind not in boat_installed:
			return kind
	return ""

func boat_step(kind: String) -> String:
	if kind in boat_installed:
		return "✓ %s INSTALLED" % part_name(kind)
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if kind in actor.inventory:
			return "· %s: %s → DOCK REPAIR" % [part_name(kind), "YOU" if actor == level.player else (actor.peer_name if not actor.peer_name.is_empty() else "TEAMMATE")]
	var at := Vector2.ZERO
	for item: Dictionary in level.plan.loot:
		if item["kind"] == kind: at = item["position"]
	for pickup: CampPickup in level.pickups:
		if pickup.kind == kind and pickup.available:
			at = pickup.global_position
	var region: Dictionary = level.plan.woods.zone_at(at)
	var where: String = WoodsLayout.short_name(region) if not region.is_empty() else "DROPPED / SEE MAP"
	return "· %s / %s" % [part_name(kind), where]

func pack_text(page: String) -> String:
	if page == "boat":
		var text := "BOAT · LAKESHORE DOCK (SOUTHEAST)\n"
		for kind in BOAT_PARTS:
			text += boat_step(kind) + "\n"
		return text + "FIT ALL PARTS: MARKED REPAIR PAD ON DOCK\nMOTOR: 75% WALK; TEAMMATE HOLDS E TO HELP\nE: START / STAY IN CIRCLE TO ADVANCE 25s\nDODGE WATER SHOTS; LEAVING PAUSES PROGRESS"
	var text := "RANGER GATE · NORTH ROAD → BRIDGE\n"
	for kind in GATE_CODES:
		text += ("✓ " if kind in gate_installed else "· ") + kind.replace("_"," ").to_upper() + " / " + WoodsLayout.short_name(level.plan.woods.zones[level.plan.gate_regions[kind]]) + "\n"
	return text + ("✓ " if gate_powered else "· ") + "FLOODLIGHTS / SUBSTATION + GATE BREAKER\nHOLD E 4s / RUN NORTH\nFIRST AT BRIDGE STARTS 8s TEAM EVACUATION"

func snapshot() -> Dictionary:
	return {"boat_installed":boat_installed.duplicate(),"gate_installed":gate_installed.duplicate(),"boat_started":boat_started,"boat_remaining":boat_remaining,"gate_powered":gate_powered,"gate_open":gate_open,"gate_progress":gate_progress,"bridge_started":bridge_started,"bridge_remaining":bridge_remaining,"boat_occupied":boat_occupied,"barrage":barrage.snapshot() if barrage!=null else {}}

func restore(state: Dictionary) -> void:
	boat_installed.assign(state["boat_installed"])
	gate_installed.assign(state["gate_installed"])
	for field in ["boat_started","boat_remaining","gate_powered","gate_open","gate_progress","bridge_started","bridge_remaining","boat_occupied"]:
		set(field,state[field])
	if barrage!=null:barrage.restore(state.get("barrage",{}))
	if gate_enabled:
		gate_body.get_child(0).set_deferred("disabled",gate_open)

func _draw() -> void:
	if level.plan.expedition:
		FieldEscapeArt.draw_boat(self,boat_point,boat_installed,boat_started,pulse,boat_enabled)
	if not active:
		return
	if gate_enabled:
		draw_arc(bridge,64,0,TAU,40,Color("bfd5b9"),2)
