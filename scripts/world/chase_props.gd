class_name ChaseProps
extends Node2D
## F3b chase toolkit props: hiding spots (breath meter, witnesses), doors that slam
## shut and must be broken through, and one-use knock-overs. Host owns all outcomes.

const HIDE_RADIUS := 20.0
const BREATH_DRAIN := 0.25
const BREATH_RECOVER := 0.2
const BREATH_THREAT := 120.0
const WITNESS_SECONDS := 15.0
const DOOR_REACH := 22.0
const DOOR_BREAK_SECONDS := 2.5
const DOOR_BROKEN_SECONDS := 20.0
const KNOCK_RADIUS := 24.0
const KNOCK_BLOCK_SECONDS := 6.0
const KNOCK_STUN := 2.0
const KNOCK_MAX_SPAN := 180.0
const CAMP_PILES := 4
const BARRIER_REACH := 22.0
const VAULT_SECONDS := 0.45
var gate_links: Array[NavigationLink2D] = []
var gate_bodies: Array[StaticBody2D] = []
var vaults: Dictionary = {}
const SPOT_LABELS := {"bed": "UNDER BUNK", "medical": "UNDER COT", "shelf": "IN LOCKER", "crate": "BEHIND CRATES", "canoe": "UNDER CANOE", "shower": "IN SHOWER STALL", "table": "UNDER TABLE", "desk": "UNDER DESK", "bench": "UNDER BENCH"}
var level: Node2D
var spots: Array[Dictionary] = []
var doors: Array[Dictionary] = []
var knocks: Array[Dictionary] = []
var witnesses: Dictionary = {}


func _ready() -> void:
	z_index = 0
	var camp_map: CampMap = level.camp_map
	for building in camp_map.buildings + camp_map.forest_buildings:
		_add_building(building, camp_map)
	_add_woods(level.plan.woods, level.plan.seed_value)
	_add_barriers(level.plan.woods)


func _add_building(building: CampBuilding, camp_map: CampMap) -> void:
	var interior := building.bounds.grow(-26)
	var added := 0
	for furnishing in building.furnishings:
		if added >= (2 if building.furnishings.size() >= 4 else 1) or not SPOT_LABELS.has(furnishing["type"]):
			continue
		var rect: Rect2 = furnishing["rect"]
		for side in [Vector2.DOWN, Vector2.RIGHT, Vector2.LEFT, Vector2.UP]:
			var at: Vector2 = (rect.get_center() + side * (rect.size * 0.5 + Vector2.ONE * 9)).round()
			if interior.has_point(at) and _clear(at, camp_map, 7) and not building.door_rect.grow(30).has_point(at):
				spots.append({"position": at, "label": SPOT_LABELS[furnishing["type"]], "woods": false})
				added += 1
				break
	var body := _body(building.door_rect)
	# A closed door blocks flashlight spill as well as movement and sight.
	var occluder := LightOccluder2D.new()
	var polygon := OccluderPolygon2D.new()
	var half: Vector2 = building.door_rect.size * 0.5
	polygon.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	occluder.occluder = polygon
	occluder.visible = false
	body.add_child(occluder)
	doors.append({"rect": building.door_rect, "body": body, "open": true, "progress": 0.0, "broken": 0.0, "label": building.label})


func _add_woods(woods: WoodsLayout, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7331
	var corridors: Array[Vector2i] = []
	for cell: Vector2i in woods.links:
		var at := woods.center(cell)
		if woods.links[cell].size() == 2 and woods.zone_at(at).is_empty() and at.distance_to(CampMap.CAMP_BOUNDS.get_center()) > 700:
			corridors.append(cell)
	corridors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y * WoodsLayout.SIZE.x + a.x < b.y * WoodsLayout.SIZE.x + b.x)
	for index in range(corridors.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var cell := corridors[index]
		corridors[index] = corridors[swap]
		corridors[swap] = cell
	var brush: Array[Vector2] = []
	var logs: Array[Vector2] = []
	# Woodpiles on the first straight stretches of the trails leading out of camp.
	var approaches := corridors.filter(func(cell: Vector2i) -> bool:
		var distance := woods.center(cell).distance_to(CampMap.CAMP_BOUNDS.get_center())
		return distance > 750 and distance < 1300)
	approaches.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := woods.center(a).distance_to(CampMap.CAMP_BOUNDS.get_center())
		var db := woods.center(b).distance_to(CampMap.CAMP_BOUNDS.get_center())
		return da < db if da != db else a.y * WoodsLayout.SIZE.x + a.x < b.y * WoodsLayout.SIZE.x + b.x)
	var piles := 0
	for cell: Vector2i in approaches:
		if piles >= CAMP_PILES:
			break
		var middle := _straight_middle(woods, cell)
		if middle != Vector2.INF and _spaced(middle, logs, 500) and _add_knock(woods, middle, _across(woods, cell), "WOODPILE"):
			logs.append(middle)
			piles += 1
	for cell in corridors:
		var bush := CampMap.off_seam(woods.center(cell) + Vector2(rng.randi_range(-36, 36), rng.randi_range(-36, 36)))
		if _spaced(bush, brush, 520) and woods.signpost_near(bush, 120).is_empty():
			brush.append(bush)
			spots.append({"position": bush.round(), "label": "IN THICK BRUSH", "woods": true})
		# Deadfalls go on straight stretches, across the connecting trail segment.
		var middle := _straight_middle(woods, cell)
		if middle != Vector2.INF and logs.size() < 60 + piles and _spaced(middle, logs, 900) and middle.distance_to(bush) > 60 and _add_knock(woods, middle, _across(woods, cell), "DEADFALL"):
			logs.append(middle)


func _add_barriers(woods: WoodsLayout) -> void:
	for fence in woods.fences:
		_barrier_body(fence["rect"])
	for gate in woods.gates:
		gate_bodies.append(_barrier_body(gate["rect"]))
		# Closed gates are baked as obstacles; this link restores the route once opened.
		var link := NavigationLink2D.new()
		var travel: Vector2 = gate["toward_zone"]
		link.position = gate["position"]
		link.start_position = travel * 20.0
		link.end_position = -travel * 20.0
		link.bidirectional = true
		link.enabled = false
		add_child(link)
		gate_links.append(link)


func _barrier_body(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = CampPlayer.BARRIER_LAYER
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	(shape.shape as RectangleShape2D).size = rect.size
	body.position = rect.get_center()
	body.add_child(shape)
	add_child(body)
	return body


func gate_near(actor: CampPlayer) -> int:
	var gates: Array[Dictionary] = level.plan.woods.gates
	for index in range(gates.size()):
		if not gates[index]["open"] and gates[index]["rect"].grow(BARRIER_REACH).has_point(actor.global_position):
			return index
	return -1


func fence_near(actor: CampPlayer) -> int:
	var fences: Array[Dictionary] = level.plan.woods.fences
	for index in range(fences.size()):
		if fences[index]["rect"].grow(BARRIER_REACH).has_point(actor.global_position):
			return index
	return -1


## Only the region side has the latch, so you earn the shortcut by going deep.
func open_gate(actor: CampPlayer, index: int) -> bool:
	var gate: Dictionary = level.plan.woods.gates[index]
	var zone_side: bool = (actor.global_position - gate["position"]).dot(gate["toward_zone"]) > 0.0
	if not zone_side:
		level.announce("Ranger gate: the latch is on the far side.", actor)
		return false
	gate["open"] = true
	_apply_gate(index)
	level.loud_noise(gate["position"], 200)
	level.announce("Shortcut open: %s to the road. It's open for everything now." % WoodsLayout.short_name(level.plan.woods.zones[gate["zone"]]))
	return true


func _apply_gate(index: int) -> void:
	var open: bool = level.plan.woods.gates[index]["open"]
	(gate_bodies[index].get_child(0) as CollisionShape2D).set_deferred("disabled", open)
	gate_links[index].enabled = open
	queue_redraw()


## Hop a fence: half a second, quiet at a walk, loud at a sprint.
func vault(actor: CampPlayer, index: int) -> bool:
	var fence: Dictionary = level.plan.woods.fences[index]
	var travel: Vector2 = fence["travel"]
	var side := signf((actor.global_position - fence["position"]).dot(travel))
	if side == 0.0:
		side = 1.0
	var across := travel.orthogonal().abs()
	var lateral: float = (actor.global_position - fence["position"]).dot(across)
	var target: Vector2 = fence["position"] + across * lateral - travel * side * 18.0
	if not level.clear_path(actor.global_position, target):
		return false
	vaults[actor.get_instance_id()] = {"actor": weakref(actor), "from": actor.global_position, "to": target}
	actor.vault_time = VAULT_SECONDS
	actor.velocity = Vector2.ZERO
	actor.collision_mask &= ~CampPlayer.BARRIER_LAYER
	level.loud_noise(actor.global_position, 220.0 if actor.sprinting else 90.0)
	return true


## Midpoint of a straight corridor's trail segment, or INF if the cell bends.
func _straight_middle(woods: WoodsLayout, cell: Vector2i) -> Vector2:
	var ends: Array = woods.links[cell]
	if ends.size() != 2 or ends[0] - cell != -(ends[1] - cell):
		return Vector2.INF
	return woods.center(cell) + Vector2(ends[0] - cell) * WoodsLayout.CELL * 0.5


func _across(woods: WoodsLayout, cell: Vector2i) -> Vector2:
	return Vector2(woods.links[cell][0] - cell).orthogonal().abs()


## Measure the open trail across `axis` and lay the fall line wall to wall.
## Rejects spots wider than a chokepoint so a pile always truly closes the route.
func _add_knock(woods: WoodsLayout, at: Vector2, axis: Vector2, label: String) -> bool:
	var reach: Array[float] = [0.0, 0.0]
	for side in range(2):
		var direction := axis * (1.0 if side == 0 else -1.0)
		while reach[side] < KNOCK_MAX_SPAN and woods.walkable(at + direction * (reach[side] + 4.0)):
			reach[side] += 4.0
	if reach[0] + reach[1] > KNOCK_MAX_SPAN or reach[0] < 24.0 or reach[1] < 24.0:
		return false
	var start: Vector2 = at - axis * (reach[1] + 8.0)
	var finish: Vector2 = at + axis * (reach[0] + 8.0)
	var thickness := Vector2.ONE * 16.0 - axis * 16.0
	var block := Rect2(start.min(finish) - thickness * 0.5, (finish - start).abs() + thickness)
	var pile: Vector2 = CampMap.off_seam((at + axis * (reach[0] - 14.0)).round())
	knocks.append({"position": pile, "label": label, "state": 0, "remaining": 0.0, "rect": Rect2(), "block": block, "travel": axis.orthogonal().abs(), "body": _body(Rect2(pile, Vector2.ONE * 4))})
	return true


func _body(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	body.add_child(shape)
	add_child(body)
	_shape(body, rect, false)
	return body


func _shape(body: StaticBody2D, rect: Rect2, solid: bool) -> void:
	body.position = rect.get_center()
	var shape: CollisionShape2D = body.get_child(0)
	(shape.shape as RectangleShape2D).size = rect.size
	shape.set_deferred("disabled", not solid)
	if body.get_child_count() > 1:
		(body.get_child(1) as LightOccluder2D).visible = solid


func _clear(at: Vector2, camp_map: CampMap, margin: float) -> bool:
	for obstacle in camp_map.obstacles:
		if obstacle.grow(margin).has_point(at):
			return false
	return true


static func _spaced(at: Vector2, others: Array[Vector2], gap: float) -> bool:
	for other in others:
		if other.distance_to(at) < gap:
			return false
	return true


func _physics_process(delta: float) -> void:
	if level.paused or level.finished:
		return
	var net: Node = get_node("/root/Net")
	if net.active and (not multiplayer.is_server() or net.waiting):
		return
	advance(delta)


func advance(delta: float) -> void:
	for id in vaults.keys():
		var hop: Dictionary = vaults[id]
		var actor: CampPlayer = hop["actor"].get_ref()
		if not is_instance_valid(actor):
			vaults.erase(id)
			continue
		actor.vault_time = maxf(0.0, actor.vault_time - delta)
		actor.position = hop["from"].lerp(hop["to"], 1.0 - actor.vault_time / VAULT_SECONDS)
		if actor.vault_time <= 0.0:
			actor.collision_mask |= CampPlayer.BARRIER_LAYER
			vaults.erase(id)
	var enemies := get_tree().get_nodes_in_group("killers")
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.hidden_spot < 0:
			continue
		var at: Vector2 = spots[actor.hidden_spot]["position"]
		var threatened := enemies.any(func(enemy: CampKiller) -> bool: return enemy.enabled and enemy.global_position.distance_to(at) <= BREATH_THREAT)
		actor.breath = clampf(actor.breath + (-BREATH_DRAIN if threatened else BREATH_RECOVER) * delta, 0.0, 1.0)
		if actor.breath <= 0.0:
			leave(actor)
			actor.breath = 0.35
			level.loud_noise(at, 220)
			level.announce("You gasp for air! Everything nearby heard it.", actor)
			continue
		for watcher: Dictionary in witnesses.get(actor.hidden_spot, []):
			var enemy: CampKiller = watcher["enemy"].get_ref()
			if is_instance_valid(enemy) and enemy.enabled and enemy.global_position.distance_to(at) < 16:
				leave(actor)
				level.announce("It saw you hide. It's dragging you out!", actor)
				break
	for spot_index in witnesses.keys():
		var kept: Array = []
		for watcher: Dictionary in witnesses[spot_index]:
			watcher["remaining"] -= delta
			if watcher["remaining"] > 0.0:
				kept.append(watcher)
		witnesses[spot_index] = kept
	for door in doors:
		door["broken"] = maxf(0.0, door["broken"] - delta)
		if door["open"]:
			continue
		var center: Vector2 = door["rect"].get_center()
		var pushers: Array[CampKiller] = []
		for enemy: CampKiller in enemies:
			if enemy.enabled and enemy.stun_remaining <= 0.0 and door["rect"].grow(DOOR_REACH + 2.0).has_point(enemy.global_position):
				pushers.append(enemy)
				enemy.stuck_clock = 0.0
		var pushing := not pushers.is_empty()
		door["progress"] = door["progress"] + delta if pushing else maxf(0.0, door["progress"] - delta * 0.5)
		if door["progress"] >= DOOR_BREAK_SECONDS:
			door["open"] = true
			door["progress"] = 0.0
			door["broken"] = DOOR_BROKEN_SECONDS
			_shape(door["body"], door["rect"], false)
			# The breakers keep their own goal; only other creatures turn toward the crash.
			var goals := pushers.map(func(enemy: CampKiller) -> Array: return [enemy.last_seen, enemy.state])
			level.loud_noise(center, 300)
			for slot in range(pushers.size()):
				pushers[slot].last_seen = goals[slot][0]
				pushers[slot].state = goals[slot][1]
			level.announce("CRASH! Something broke through the %s door." % door["label"])
			queue_redraw()
	for knock in knocks:
		if knock["state"] == 1:
			knock["remaining"] -= delta
			if knock["remaining"] <= 0.0:
				knock["state"] = 2
				_shape(knock["body"], knock["rect"], false)
				queue_redraw()


func spot_near(actor: CampPlayer) -> int:
	for index in range(spots.size()):
		if actor.global_position.distance_to(spots[index]["position"]) <= HIDE_RADIUS and not _occupied(index) and level.clear_path(actor.global_position, spots[index]["position"]):
			return index
	return -1


func door_near(actor: CampPlayer) -> int:
	for index in range(doors.size()):
		if doors[index]["rect"].grow(DOOR_REACH).has_point(actor.global_position):
			return index
	return -1


func knock_near(actor: CampPlayer) -> int:
	for index in range(knocks.size()):
		if knocks[index]["state"] == 0 and actor.global_position.distance_to(knocks[index]["position"]) <= KNOCK_RADIUS:
			return index
	return -1


## A door wins when you're in or beside its gap, unless a hiding spot is right under you.
func _door_first(actor: CampPlayer) -> int:
	var door := door_near(actor)
	var spot := spot_near(actor)
	if door >= 0 and spot >= 0 and not doors[door]["rect"].grow(4).has_point(actor.global_position):
		var edge: Vector2 = actor.global_position.clamp(doors[door]["rect"].position, doors[door]["rect"].end)
		if actor.global_position.distance_to(spots[spot]["position"]) < actor.global_position.distance_to(edge):
			return -1
	return door


func _occupied(index: int) -> bool:
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.hidden_spot == index:
			return true
	return false


func prompt(actor: CampPlayer) -> String:
	if actor.hidden_spot >= 0:
		return "HIDING %s · E LEAVE · BREATH %d%%" % [spots[actor.hidden_spot]["label"], int(actor.breath * 100)]
	var door := _door_first(actor)
	if door >= 0:
		if doors[door]["broken"] > 0.0:
			return "DOOR SMASHED"
		return "E · SLAM DOOR SHUT" if doors[door]["open"] else "E · OPEN DOOR"
	var spot := spot_near(actor)
	if spot >= 0:
		return "E · HIDE " + spots[spot]["label"]
	var knock := knock_near(actor)
	if knock >= 0:
		return "E · KNOCK OVER %s ACROSS THE TRAIL (LOUD, 6s)" % knocks[knock]["label"]
	var gate := gate_near(actor)
	if gate >= 0:
		var gates: Array[Dictionary] = level.plan.woods.gates
		return "E · OPEN SHORTCUT GATE" if (actor.global_position - gates[gate]["position"]).dot(gates[gate]["toward_zone"]) > 0.0 else "RANGER GATE · LATCHED FROM THE FAR SIDE"
	if fence_near(actor) >= 0:
		return "E · VAULT FENCE (LOUD IF SPRINTING)"
	return ""


func interact(actor: CampPlayer) -> bool:
	if actor.hidden_spot >= 0:
		leave(actor)
		return true
	var door := _door_first(actor)
	if door >= 0:
		return toggle_door(actor, door)
	var spot := spot_near(actor)
	if spot >= 0:
		return hide_actor(actor, spot)
	var knock := knock_near(actor)
	if knock >= 0:
		return knock_over(actor, knock)
	var gate := gate_near(actor)
	if gate >= 0:
		return open_gate(actor, gate)
	var fence := fence_near(actor)
	if fence >= 0:
		return vault(actor, fence)
	return false


func hide_actor(actor: CampPlayer, index: int) -> bool:
	if actor.status != CampPlayer.Status.ALIVE or _occupied(index):
		return false
	var at: Vector2 = spots[index]["position"]
	# Anything that is chasing you or can see you right now remembers where you went.
	var watchers: Array = []
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		var chasing: bool = enemy.state == CampKiller.State.CHASE and enemy.visible_target == actor
		var seeing: bool = enemy.global_position.distance_to(actor.global_position) <= enemy.config.sight_radius and enemy.has_line_of_sight(actor.global_position) and enemy.can_sense(actor)
		if enemy.enabled and (chasing or seeing):
			watchers.append({"enemy": weakref(enemy), "remaining": WITNESS_SECONDS})
			enemy.last_seen = at
			enemy.transition(CampKiller.State.INVESTIGATE)
	witnesses[index] = watchers
	actor.position = at
	actor.velocity = Vector2.ZERO
	actor.hidden_spot = index
	actor.set_meta("light_before_hiding", actor.flashlight_on)
	actor.flashlight_on = false
	level.announce("Hiding %s. Hold still; breath runs out when something is close." % spots[index]["label"].to_lower(), actor)
	return true


func leave(actor: CampPlayer) -> void:
	if actor.hidden_spot < 0:
		return
	witnesses.erase(actor.hidden_spot)
	actor.hidden_spot = -1
	actor.flashlight_on = actor.get_meta("light_before_hiding", actor.flashlight_on) and (not actor.expedition or actor.flashlight_charge > 0.0)


func toggle_door(actor: CampPlayer, index: int) -> bool:
	var door: Dictionary = doors[index]
	if door["broken"] > 0.0:
		level.announce("The door is smashed off its hinges.", actor)
		return false
	if door["open"]:
		var gap: Rect2 = door["rect"]
		for node in get_tree().get_nodes_in_group("survivors") + get_tree().get_nodes_in_group("killers"):
			if node != actor and gap.grow(3).has_point(node.global_position):
				level.announce("Something is in the doorway.", actor)
				return false
		if gap.grow(4).has_point(actor.global_position):
			# Slamming it while running through: finish the step toward where you're headed.
			var inward: bool = actor.facing.y < 0.0 if absf(actor.facing.y) > 0.2 else actor.global_position.y < gap.get_center().y
			actor.position.y = gap.position.y - 9.0 if inward else gap.end.y + 9.0
		door["open"] = false
		door["progress"] = 0.0
		_shape(door["body"], door["rect"], true)
		level.loud_noise(door["rect"].get_center(), 120)
		level.announce("Door slammed. It won't hold forever.", actor)
	else:
		door["open"] = true
		_shape(door["body"], door["rect"], false)
	queue_redraw()
	return true


func knock_over(actor: CampPlayer, index: int) -> bool:
	var knock: Dictionary = knocks[index]
	var rect: Rect2 = knock["block"]
	var travel: Vector2 = knock["travel"]
	# Land on the far side of the pile from whatever is closest behind you.
	var line := rect.get_center()
	var side := signf((actor.global_position - line).dot(travel))
	var hunter := _nearest_hunter(actor.global_position, 320.0)
	if hunter != null:
		side = -signf((hunter.global_position - line).dot(travel))
	if side == 0.0:
		side = 1.0
	if rect.grow(6).has_point(actor.global_position):
		var target := actor.global_position - travel * (actor.global_position - line).dot(travel) + travel * side * 18.0
		if level.clear_path(actor.global_position, target):
			actor.position = target
	var stunned := 0
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		if enemy.enabled and rect.grow(10).has_point(enemy.global_position) and enemy.stun(KNOCK_STUN):
			stunned += 1
	var trapped := false
	for survivor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if rect.grow(6).has_point(survivor.global_position):
			trapped = true
	knock["state"] = 1
	knock["remaining"] = KNOCK_BLOCK_SECONDS
	knock["rect"] = rect
	# Never wall a survivor in; the stun still lands.
	_shape(knock["body"], rect, not trapped)
	level.loud_noise(knock["position"], 250)
	level.announce("%s down! %s" % [knocks[index]["label"], "%d stunned." % stunned if stunned > 0 else "The lane is blocked for a few seconds."], actor)
	queue_redraw()
	return true


func _nearest_hunter(from: Vector2, radius: float) -> CampKiller:
	var best: CampKiller
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		if enemy.enabled and enemy.global_position.distance_to(from) <= radius and (best == null or enemy.global_position.distance_to(from) < best.global_position.distance_to(from)):
			best = enemy
	return best


func _draw_rails(rect: Rect2, wood: Color, latched: bool) -> void:
	var long := rect.size.x > rect.size.y
	var span := rect.size.x if long else rect.size.y
	var along := Vector2.RIGHT if long else Vector2.DOWN
	var across := Vector2.DOWN if long else Vector2.RIGHT
	var start := rect.position + across * (rect.size.y if long else rect.size.x) * 0.5
	draw_line(start + across * 3 + Vector2(1, 2), start + across * 3 + along * span + Vector2(1, 2), Color(0, 0, 0, 0.35), 3)
	for offset in [-4.0, 2.0]:
		draw_line(start + across * offset, start + across * offset + along * span, wood.lightened(0.15), 3)
		draw_line(start + across * (offset - 1), start + across * (offset - 1) + along * span, wood.lightened(0.45), 1)
	for step in range(0, int(span) + 1, 16):
		var post := start + along * step
		draw_rect(Rect2(post - across * 7 - (along * 2), across * 12 + along * 4), Color("3d2f20"))
		draw_rect(Rect2(post - across * 7 - (along * 2), along * 4 + across * 2), Color("7d6446"))
	if latched:
		# Gates: a diagonal brace and a latch box mark them as openable.
		draw_line(start - across * 4, start + across * 2 + along * span, wood.lightened(0.3), 2)
		var middle := start + along * span * 0.5
		draw_rect(Rect2(middle - Vector2(5, 5), Vector2(10, 10)), Color("4a4a42"))
		draw_rect(Rect2(middle - Vector2(3, 3), Vector2(6, 6)), Color("d9c98f"))


func snapshot() -> Dictionary:
	var door_rows := []
	for door in doors:
		door_rows.append([door["open"], door["progress"], door["broken"]])
	var knock_rows := []
	for knock in knocks:
		knock_rows.append([knock["state"], knock["remaining"], knock["rect"]])
	var gate_rows := []
	for gate in level.plan.woods.gates:
		gate_rows.append(gate["open"])
	return {"doors": door_rows, "knocks": knock_rows, "gates": gate_rows}


func restore(state: Dictionary) -> void:
	var changed := false
	for index in range(mini(doors.size(), state["doors"].size())):
		var row: Array = state["doors"][index]
		var door: Dictionary = doors[index]
		if door["open"] != row[0]:
			changed = true
			_shape(door["body"], door["rect"], not row[0])
		door["open"] = row[0]
		door["progress"] = row[1]
		door["broken"] = row[2]
	for index in range(mini(knocks.size(), state["knocks"].size())):
		var row: Array = state["knocks"][index]
		var knock: Dictionary = knocks[index]
		if knock["state"] != row[0]:
			changed = true
			knock["rect"] = row[2]
			_shape(knock["body"], row[2], row[0] == 1)
		knock["state"] = row[0]
		knock["remaining"] = row[1]
	var gates: Array[Dictionary] = level.plan.woods.gates
	for index in range(mini(gates.size(), state.get("gates", []).size())):
		if gates[index]["open"] != state["gates"][index]:
			gates[index]["open"] = state["gates"][index]
			_apply_gate(index)
	if changed:
		queue_redraw()


func _draw() -> void:
	# The Maintenance generator the blackout event asks you to restart.
	PixelArt.draw_standing(self, "generator", level.night_clock.generator_point() + Vector2(-26, 6), 22)
	for fence: Dictionary in level.plan.woods.fences:
		_draw_rails(fence["rect"], Color("9a7b52"), false)
	for gate: Dictionary in level.plan.woods.gates:
		if not gate["open"]:
			_draw_rails(gate["rect"], Color("b39c6a"), true)
	for spot in spots:
		var at: Vector2 = spot["position"]
		if spot["woods"]:
			for index in range(7):
				var leaf := at + Vector2.from_angle(index * TAU / 7) * 8 + Vector2(0, -4)
				draw_circle(leaf, 7, Color("23402c"))
			draw_circle(at + Vector2(0, -6), 9, Color("2d5236"))
			for index in range(5):
				draw_rect(Rect2(at + Vector2(-8 + index * 4, -14 + index % 2 * 5), Vector2(2, 2)), Color("4f7a4c"))
		else:
			draw_rect(Rect2(at + Vector2(-4, -1), Vector2(8, 2)), Color(0.05, 0.07, 0.06, 0.6))
	for door in doors:
		var rect: Rect2 = door["rect"]
		if not door["open"]:
			draw_rect(rect, Color("6b4f33"))
			for x in range(int(rect.position.x) + 4, int(rect.end.x), 6):
				draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color("8c6a45"))
			draw_rect(Rect2(rect.end.x - 6, rect.get_center().y - 1, 2, 2), Color("d6c08a"))
		elif door["broken"] > 0.0:
			for index in range(4):
				draw_line(rect.position + Vector2(index * 7, 2), rect.position + Vector2(index * 7 + 5, rect.size.y), Color("5a4430"), 2)
	for knock in knocks:
		var at: Vector2 = knock["position"]
		match int(knock["state"]):
			0:
				if PixelArt.draw_standing(self, "woodpile", at + Vector2(0, 6), 30):
					continue
				for row in range(3):
					for column in range(3 - row):
						draw_circle(at + Vector2(-8 + column * 8 + row * 4, -row * 6), 4, Color("7a5a3a"))
						draw_circle(at + Vector2(-8 + column * 8 + row * 4, -row * 6), 2, Color("b3926a"))
			1:
				var rect: Rect2 = knock["rect"]
				var long := rect.size.x > rect.size.y
				draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0, 0, 0, 0.35))
				draw_rect(rect.grow(1), Color("2e2318"))
				draw_rect(rect, Color("8a6440"))
				# Bark grain along the log, with cut rings at both ends.
				var span := int(rect.size.x if long else rect.size.y)
				for step in range(3, span - 3, 5):
					var a := rect.position + (Vector2(step, 3) if long else Vector2(3, step))
					var b := a + (Vector2(3, 0) if long else Vector2(0, 3))
					draw_line(a, b, Color("5e4229"))
					draw_line(a + (Vector2(0, 8) if long else Vector2(8, 0)), b + (Vector2(0, 8) if long else Vector2(8, 0)), Color("5e4229"))
				draw_line(rect.position, rect.position + (Vector2(rect.size.x, 0) if long else Vector2(0, rect.size.y)), Color("b08a5c"))
				for end in [rect.position + rect.size * (Vector2(0, 0.5) if long else Vector2(0.5, 0)), rect.end - rect.size * (Vector2(0, 0.5) if long else Vector2(0.5, 0))]:
					draw_circle(end, 6, Color("c9a575"))
					draw_arc(end, 3, 0, TAU, 10, Color("8a6440"), 1)
			2:
				for index in range(5):
					draw_rect(Rect2(at + Vector2(-12 + index * 6, index % 2 * 4), Vector2(5, 2)), Color("5d4630"))
