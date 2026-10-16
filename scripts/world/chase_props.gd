class_name ChaseProps
extends Node2D
## F3b chase toolkit props: hiding spots (breath meter, witnesses), doors that slam
## shut and must be broken through, and one-use knock-overs. Host owns all outcomes.

const HIDE_RADIUS := 20.0
const BREATH_DRAIN := 0.25
const BREATH_RECOVER := 0.2
const BREATH_THREAT := 120.0
const WITNESS_SECONDS := 15.0
const DOOR_REACH := 18.0
const DOOR_BREAK_SECONDS := 2.5
const DOOR_BROKEN_SECONDS := 20.0
const KNOCK_RADIUS := 24.0
const KNOCK_BLOCK_SECONDS := 6.0
const KNOCK_STUN := 2.0
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


func _add_building(building: CampBuilding, camp_map: CampMap) -> void:
	var interior := building.bounds.grow(-26)
	var added := 0
	for furnishing in building.furnishings:
		if added >= (2 if building.furnishings.size() >= 4 else 1) or not SPOT_LABELS.has(furnishing["type"]):
			continue
		var rect: Rect2 = furnishing["rect"]
		for side in [Vector2.DOWN, Vector2.RIGHT, Vector2.LEFT, Vector2.UP]:
			var at: Vector2 = (rect.get_center() + side * (rect.size * 0.5 + Vector2.ONE * 9)).round()
			if interior.has_point(at) and _clear(at, camp_map, 7):
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
	var pile: Vector2 = building.door + Vector2(-40, 30)
	if CampMap.CAMP_BOUNDS.has_point(pile) and _clear(pile, camp_map, 14) and not building.bounds.grow(8).has_point(pile):
		_add_knock(pile, "WOODPILE")


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
	for cell in corridors:
		var bush := woods.center(cell) + Vector2(rng.randi_range(-36, 36), rng.randi_range(-36, 36))
		if _spaced(bush, brush, 520) and woods.signpost_near(bush, 120).is_empty():
			brush.append(bush)
			spots.append({"position": bush.round(), "label": "IN THICK BRUSH", "woods": true})
		var deadfall := woods.center(cell) + Vector2(30, -30)
		if logs.size() < 60 and _spaced(deadfall, logs, 900) and deadfall.distance_to(bush) > 40:
			logs.append(deadfall)
			_add_knock(deadfall.round(), "DEADFALL")


func _add_knock(at: Vector2, label: String) -> void:
	knocks.append({"position": at, "label": label, "state": 0, "remaining": 0.0, "rect": Rect2(), "body": _body(Rect2(at, Vector2.ONE * 4))})


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


func _occupied(index: int) -> bool:
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.hidden_spot == index:
			return true
	return false


func prompt(actor: CampPlayer) -> String:
	if actor.hidden_spot >= 0:
		return "HIDING %s · E LEAVE · BREATH %d%%" % [spots[actor.hidden_spot]["label"], int(actor.breath * 100)]
	var spot := spot_near(actor)
	if spot >= 0:
		return "E · HIDE " + spots[spot]["label"]
	var knock := knock_near(actor)
	if knock >= 0:
		return "E · KNOCK OVER %s (LOUD, BLOCKS 6s)" % knocks[knock]["label"]
	var door := door_near(actor)
	if door >= 0:
		if doors[door]["broken"] > 0.0:
			return "DOOR SMASHED"
		return "E · SLAM DOOR SHUT" if doors[door]["open"] else "E · OPEN DOOR"
	return ""


func interact(actor: CampPlayer) -> bool:
	if actor.hidden_spot >= 0:
		leave(actor)
		return true
	var spot := spot_near(actor)
	if spot >= 0:
		return hide_actor(actor, spot)
	var knock := knock_near(actor)
	if knock >= 0:
		return knock_over(actor, knock)
	var door := door_near(actor)
	if door >= 0:
		return toggle_door(actor, door)
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
		var blocked: Rect2 = door["rect"].grow(3)
		for node in get_tree().get_nodes_in_group("survivors") + get_tree().get_nodes_in_group("killers"):
			if blocked.has_point(node.global_position):
				level.announce("Something is in the doorway.", actor)
				return false
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
	var toward := actor.facing.normalized()
	var center: Vector2 = knock["position"] + toward * 22
	var size := Vector2(12, 44) if absf(toward.x) > absf(toward.y) else Vector2(44, 12)
	var rect := Rect2(center - size * 0.5, size)
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


func snapshot() -> Dictionary:
	var door_rows := []
	for door in doors:
		door_rows.append([door["open"], door["progress"], door["broken"]])
	var knock_rows := []
	for knock in knocks:
		knock_rows.append([knock["state"], knock["remaining"], knock["rect"]])
	return {"doors": door_rows, "knocks": knock_rows}


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
	if changed:
		queue_redraw()


func _draw() -> void:
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
				for row in range(3):
					for column in range(3 - row):
						draw_circle(at + Vector2(-8 + column * 8 + row * 4, -row * 6), 4, Color("7a5a3a"))
						draw_circle(at + Vector2(-8 + column * 8 + row * 4, -row * 6), 2, Color("b3926a"))
			1:
				var rect: Rect2 = knock["rect"]
				draw_rect(rect, Color("6e5034"))
				var long := rect.size.x > rect.size.y
				for step in range(0, int(rect.size.x if long else rect.size.y), 8):
					var mark := rect.position + (Vector2(step + 4, rect.size.y * 0.5) if long else Vector2(rect.size.x * 0.5, step + 4))
					draw_circle(mark, 2, Color("b3926a"))
			2:
				for index in range(5):
					draw_rect(Rect2(at + Vector2(-12 + index * 6, index % 2 * 4), Vector2(5, 2)), Color("5d4630"))
