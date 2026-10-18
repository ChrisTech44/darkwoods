class_name Snares
extends Node2D
## Headline traps on trail cells survivors have already walked (max 4 armed).
## The Groundskeeper sets rake snares; the stalker sets bear traps, which also
## bite (15 damage) with a loud snap. Either holds a survivor for 4 s; a
## teammate frees them at once (E), and anyone can disarm an armed trap quietly
## (E). Traps glint in a flashlight within 90 px.

const MAX_ARMED := 4
const PLACE_SECONDS := 18.0
const TRIGGER_RADIUS := 9.0
const HOLD_SECONDS := 4.0
const RATTLE_RADIUS := 320.0
const DISARM_RADIUS := 22.0
const SPACING := 150.0
## The stalker is pickier than the Groundskeeper about where he lays steel.
const BEAR_TRAP_SECONDS := 30.0
const BEAR_TRAP_BITE := 15.0
var level: Node2D
## {position, armed}
var snares: Array[Dictionary] = []
var place_clock := PLACE_SECONDS


func _ready() -> void:
	z_index = 0


func _physics_process(delta: float) -> void:
	var net: Node = get_node("/root/Net")
	if level.paused or level.finished or net.active and (not multiplayer.is_server() or net.waiting):
		return
	advance(delta)


func active() -> bool:
	return level.plan.expedition


## The stalker's bear traps (the rake-snare variant belonged to the old
## Groundskeeper headliner and is kept only as data).
func kind() -> String:
	return "bear_trap"


func advance(delta: float) -> void:
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		actor.snared = maxf(0.0, actor.snared - delta)
	if not active():
		return
	place_clock -= delta
	var keeper: CampKiller = level.killer
	if place_clock <= 0.0 and keeper.enabled and keeper.state == CampKiller.State.PATROL:
		place_clock = PLACE_SECONDS if kind() == "snare" else BEAR_TRAP_SECONDS
		try_place(keeper.global_position)
	for snare: Dictionary in snares:
		if not snare["armed"]:
			continue
		for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
			if actor.status == CampPlayer.Status.ALIVE and actor.hidden_spot < 0 and actor.vault_time <= 0.0 and actor.global_position.distance_to(snare["position"]) <= TRIGGER_RADIUS:
				snare["armed"] = false
				actor.snared = HOLD_SECONDS
				actor.velocity = Vector2.ZERO
				level.loud_noise(snare["position"], RATTLE_RADIUS)
				if kind() == "bear_trap":
					actor.invulnerability = 0.0
					actor.receive_hit(BEAR_TRAP_BITE)
					level.announce("SNAP! A BEAR TRAP bites your leg. A teammate can pry it open (E).", actor)
				else:
					level.announce("SNARED! The trap rattles. A teammate can free you (E); otherwise it gives in 4s.", actor)
				break
	queue_redraw()


## Place on a walked woods trail cell, away from camp and other snares.
func try_place(at: Vector2) -> bool:
	if snares.filter(func(snare: Dictionary) -> bool: return snare["armed"]).size() >= MAX_ARMED:
		return false
	if not CampMap.is_woods(at) or not level.plan.woods.walkable(at):
		return false
	var cell: Vector2i = level.plan.woods.cell_at(at)
	if not level.plan.woods.visited.has(cell):
		return false
	for snare: Dictionary in snares:
		if snare["armed"] and snare["position"].distance_to(at) < SPACING:
			return false
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.global_position.distance_to(at) < 60.0:
			return false
	snares.append({"position": at.round(), "armed": true})
	if snares.size() > 12:
		snares.pop_front()
	return true


func prompt(actor: CampPlayer) -> String:
	var friend := _snared_friend(actor)
	if friend != null:
		return "E · FREE TEAMMATE FROM THE TRAP"
	if actor.snared > 0.0:
		return "TRAPPED %.1fs · A TEAMMATE CAN FREE YOU" % actor.snared
	if _snare_near(actor) >= 0:
		return "E · DISARM BEAR TRAP (QUIET)"
	return ""


func interact(actor: CampPlayer) -> bool:
	var friend := _snared_friend(actor)
	if friend != null:
		friend.snared = 0.0
		level.announce("Pried the snare open. Go!", friend)
		level.announce("You freed a teammate.", actor)
		level.abilities.stat(actor)["revives"] += 1
		return true
	var index := _snare_near(actor)
	if index >= 0:
		snares[index]["armed"] = false
		level.announce("Snare disarmed quietly.", actor)
		queue_redraw()
		return true
	return false


func _snared_friend(actor: CampPlayer) -> CampPlayer:
	if actor.status != CampPlayer.Status.ALIVE or actor.snared > 0.0:
		return null
	for other: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if other != actor and other.snared > 0.0 and actor.global_position.distance_to(other.global_position) <= level.config.interact_radius:
			return other
	return null


func _snare_near(actor: CampPlayer) -> int:
	if actor.status != CampPlayer.Status.ALIVE or actor.snared > 0.0:
		return -1
	for index in range(snares.size()):
		if snares[index]["armed"] and actor.global_position.distance_to(snares[index]["position"]) <= DISARM_RADIUS:
			return index
	return -1


func snapshot() -> Array:
	return snares.duplicate(true)


func restore(state: Array) -> void:
	snares.assign(state)
	queue_redraw()


func _draw() -> void:
	var viewer: CampPlayer = level.player
	for snare: Dictionary in snares:
		var at: Vector2 = snare["position"]
		var close: bool = viewer != null and viewer.flashlight_on and viewer.global_position.distance_to(at) <= 90.0
		var alpha := 1.0 if close else 0.45
		if not snare["armed"]:
			alpha *= 0.6
		var art := kind()
		if PixelArt.draw_in(self, art if snare["armed"] else art + "_sprung", Rect2(at - Vector2(9, 9), Vector2(18, 13)), Color(1, 1, 1, alpha)):
			pass
		else:
			# Fallback: steel jaws drawn as two arcs and a chain.
			var jaw := Color(0.72, 0.74, 0.7, alpha)
			draw_arc(at, 6.0, PI, TAU, 10, jaw, 1.5)
			draw_arc(at, 6.0, 0.0, PI, 10, jaw, 1.5)
			draw_line(at + Vector2(6, 0), at + Vector2(11, 3), Color(0.5, 0.48, 0.42, alpha), 1.0)
		if close and snare["armed"]:
			var glint := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
			draw_line(at + Vector2(-3, -5), at + Vector2(-1, -7), Color(1, 1, 0.9, glint), 1.0)
