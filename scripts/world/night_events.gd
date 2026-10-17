class_name NightEvents
extends Node2D
## Deferred F2 night events, triggered by NightClock from the seeded schedule:
## - The Hunt Begins: a horn; for 60 s roamers converge on the last loud noise
##   heard inside the inner ring.
## - The Stalker's Gift: a marked crate of supplies in a named region. Opening it
##   rings a bell the killer hears from anywhere (bait).
## - Lost Camper: a counselor calls from a region; the first survivor to reach
##   them is followed back to camp (+medkit, +score). They freeze if chased.
## Host-authoritative; state replicates in snapshots.

const HUNT_SECONDS := 60.0
const HUNT_PULSE := 10.0
const CAMPER_SPEED := 46.0
const CAMPER_FOLLOW := 22.0
const CAMPER_PANIC := 2.0
const GIFT_SUPPLIES := {"flare": 2, "battery_pack": 1, "medkit": 1}
var level: Node2D
var hunt_remaining := 0.0
var hunt_clock := 0.0
var last_loud := Vector2.INF
var gift_at := Vector2.INF
var gift_open := false
var camper_at := Vector2.INF
var camper_leader := 0
var camper_panic := 0.0
var camper_saved := false
var camper_body: CharacterBody2D
var camper_path: PackedVector2Array = []
var camper_path_clock := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 0
	rng.seed = level.plan.seed_value + 9393


func _physics_process(delta: float) -> void:
	var net: Node = get_node("/root/Net")
	if level.paused or level.finished or net.active and (not multiplayer.is_server() or net.waiting):
		return
	advance(delta)


func heard_loud(origin: Vector2) -> void:
	if origin.distance_to(CampMap.CAMP_BOUNDS.get_center()) <= CampKiller.INNER_RING:
		last_loud = origin


func start(kind: String) -> bool:
	var zones: Array = level.plan.woods.zones
	match kind:
		"hunt":
			hunt_remaining = HUNT_SECONDS
			hunt_clock = 0.0
			if level.soundscape != null:
				level.soundscape.hunting_horn()
			level.announce("A HUNTING HORN SOUNDS. The Hunt Begins: for a minute, everything in the woods goes to the last loud noise near camp. Stay quiet!")
			return true
		"gift":
			var zone: Dictionary = zones[rng.randi_range(0, 8)]
			gift_at = zone["position"] + Vector2(90, 110)
			level.pins.append({"owner": -2, "slot": 1, "position": gift_at.round(), "name": "GIFT", "place": WoodsLayout.short_name(zone)})
			level.announce("A crate sits in the open at the %s, tied with a bow. The Stalker's Gift: supplies... and a bell on the lid." % WoodsLayout.short_name(zone))
			return true
		"camper":
			var zone: Dictionary = zones[rng.randi_range(0, 8)]
			camper_at = zone["position"] + Vector2(-100, 100)
			_spawn_camper()
			level.pins.append({"owner": -3, "slot": 2, "position": camper_at.round(), "name": "CAMPER", "place": WoodsLayout.short_name(zone)})
			level.announce("A lost camper is calling from the %s! Find them; they will follow you back to camp." % WoodsLayout.short_name(zone))
			return true
	return false


func _spawn_camper() -> void:
	camper_body = CharacterBody2D.new()
	camper_body.collision_layer = 0
	camper_body.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	camper_body.add_child(shape)
	camper_body.position = camper_at
	add_child(camper_body)


func advance(delta: float) -> void:
	if hunt_remaining > 0.0:
		hunt_remaining = maxf(0.0, hunt_remaining - delta)
		hunt_clock -= delta
		if hunt_clock <= 0.0 and last_loud != Vector2.INF:
			hunt_clock = HUNT_PULSE
			for enemy: CampCryptid in get_tree().get_nodes_in_group("cryptids"):
				if enemy.enabled and not enemy.home.has_area():
					enemy.hear_stimulus(last_loud, INF)
	if is_instance_valid(camper_body) and not camper_saved:
		_advance_camper(delta)
	queue_redraw()


func _advance_camper(delta: float) -> void:
	camper_panic = maxf(0.0, camper_panic - delta)
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		if enemy.enabled and enemy.state == CampKiller.State.CHASE and enemy.global_position.distance_to(camper_body.global_position) < 150.0:
			if camper_panic <= 0.0:
				level.announce("The camper freezes in panic!")
			camper_panic = CAMPER_PANIC
	var leader: CampPlayer = _leader()
	if leader == null:
		for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
			if actor.status == CampPlayer.Status.ALIVE and actor.global_position.distance_to(camper_body.global_position) <= 40.0 and level.clear_path(actor.global_position, camper_body.global_position):
				camper_leader = actor.get_instance_id()
				level.announce("'Thank you! I'll stay right behind you.' Lead the camper back to camp.", actor)
				leader = actor
				break
	if leader != null and camper_panic <= 0.0:
		var goal := leader.global_position
		camper_path_clock -= delta
		if camper_path_clock <= 0.0:
			camper_path_clock = 0.5
			var map := level.get_world_2d().navigation_map
			camper_path = NavigationServer2D.map_get_path(map, camper_body.global_position, goal, true) if NavigationServer2D.map_get_iteration_id(map) > 0 else PackedVector2Array([goal])
		var next := goal
		while camper_path.size() > 1 and camper_body.global_position.distance_to(camper_path[0]) < 4.0:
			camper_path.remove_at(0)
		if not camper_path.is_empty():
			next = camper_path[0]
		if camper_body.global_position.distance_to(goal) > CAMPER_FOLLOW:
			camper_body.velocity = camper_body.global_position.direction_to(next) * CAMPER_SPEED
			camper_body.move_and_slide()
	camper_at = camper_body.global_position
	if leader != null and CampMap.CAMP_BOUNDS.has_point(camper_at):
		camper_saved = true
		leader.pack("medkit")
		level.announce("The camper is safe in camp! They hand you a medkit.", leader)
		level.announce("Lost camper rescued. +250 score.")
		level.pins = level.pins.filter(func(pin: Dictionary) -> bool: return pin["owner"] != -3)
		camper_body.queue_free()


func _leader() -> CampPlayer:
	if camper_leader == 0:
		return null
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.get_instance_id() == camper_leader:
			return actor if actor.status == CampPlayer.Status.ALIVE else null
	return null


func prompt(actor: CampPlayer) -> String:
	if gift_at != Vector2.INF and not gift_open and actor.global_position.distance_to(gift_at) <= level.config.interact_radius:
		return "E · OPEN THE GIFT CRATE (A BELL IS TIED TO THE LID)"
	return ""


func interact(actor: CampPlayer) -> bool:
	if prompt(actor).is_empty():
		return false
	gift_open = true
	for kind: String in GIFT_SUPPLIES:
		for unit in range(GIFT_SUPPLIES[kind]):
			if actor.can_pack(kind):
				actor.pack(kind)
			else:
				level.spawn_dropped(kind, gift_at + Vector2(unit * 6 - 6, 10))
	level.loud_noise(gift_at, 700)
	level.killer.hear_stimulus(gift_at, INF)
	level.pins = level.pins.filter(func(pin: Dictionary) -> bool: return pin["owner"] != -2)
	level.announce("The bell clangs across the woods. Supplies grabbed, and something is coming for its gift!", actor)
	return true


func snapshot() -> Dictionary:
	return {"hunt": hunt_remaining, "gift": gift_at, "gift_open": gift_open, "camper": camper_at, "saved": camper_saved, "panic": camper_panic}


func restore(state: Dictionary) -> void:
	if state.is_empty():
		return
	hunt_remaining = state["hunt"]
	gift_at = state["gift"]
	gift_open = state["gift_open"]
	camper_at = state["camper"]
	camper_saved = state["saved"]
	camper_panic = state["panic"]
	queue_redraw()


func _draw() -> void:
	if gift_at != Vector2.INF and not gift_open:
		if not PixelArt.draw_standing(self, "gift_crate", gift_at + Vector2(0, 6), 18):
			draw_rect(Rect2(gift_at - Vector2(8, 10), Vector2(16, 14)), Color("6d4e31"))
			draw_line(gift_at + Vector2(0, -10), gift_at + Vector2(0, 4), Color("b33a2c"), 2.0)
			draw_line(gift_at + Vector2(-8, -3), gift_at + Vector2(8, -3), Color("b33a2c"), 2.0)
	if camper_at != Vector2.INF and not camper_saved:
		var frame := 0 if camper_panic > 0.0 else int(Time.get_ticks_msec() / 220) % 2 + 1
		draw_circle(camper_at + Vector2(0, 1), 6, Color(0, 0, 0, 0.35))
		draw_texture_rect_region(preload("res://assets/sprites/camper.png"), Rect2(camper_at - Vector2(12, 29), Vector2(24, 32)), Rect2(frame * 24, 0, 24, 32), Color("e6e0c8") if camper_panic <= 0.0 else Color("c8b0a0"))
		if camper_panic > 0.0:
			draw_string(ThemeDB.fallback_font, camper_at + Vector2(-2, -32), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ee947e"))
