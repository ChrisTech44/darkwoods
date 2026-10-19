extends CreatureBrain
## The Tollkeeper: a troll who claims a stretch of trail. He plants himself in
## the path and nobody passes without paying: E beside him drops one supply from
## your belt (the selected one first) into his bucket and he waves you through
## for a minute. Try to walk past without paying and he shoves you back down
## the trail (10 damage). Nothing to pay with? He takes it in blood (15 health).
## He never chases and ignores flashes and flares; the other way round is long.

const TOLL_REACH := 40.0
const SHOVE_REACH := 24.0
const PASS_SECONDS := 60.0
const SHOVE := 360.0
var post := Vector2.ZERO
var paid: Dictionary = {}
var shove_clock: Dictionary = {}
var bucket := 0


func setup() -> void:
	display_name = "The Tollkeeper"
	tip = "He blocks the trail. E pays one supply from your belt and he lets you pass for a minute; walking past unpaid gets you shoved back. No supplies? He takes 15 health."
	post = body.global_position


func physics(delta: float) -> bool:
	for table in [paid, shove_clock]:
		for id in table.keys():
			table[id] -= delta
			if table[id] <= 0.0:
				table.erase(id)
	# He stays on his post and watches the path.
	if body.global_position.distance_to(post) > 6.0:
		body.steer(post, 40.0, delta)
	else:
		body.velocity = Vector2.ZERO
	var watched := nearest_seen(TOLL_REACH * 2.0)
	if watched != null:
		body.facing = body.global_position.direction_to(watched.global_position)
	for actor in survivors():
		var id := actor.get_instance_id()
		if paid.has(id) or shove_clock.has(id):
			continue
		if body.global_position.distance_to(actor.global_position) <= SHOVE_REACH:
			shove_clock[id] = 1.5
			actor.invulnerability = 0.0
			actor.receive_hit(10.0)
			actor.shove(body.global_position.direction_to(actor.global_position) * SHOVE)
			cue("monster_8", 2.0, 1.25)
			announce("NO TOLL, NO TRAIL! The troll shoves you back. (E beside him to pay.)", actor)
	body.queue_redraw()
	return true


func prompt(actor: CampPlayer) -> String:
	if paid.has(actor.get_instance_id()) or actor.global_position.distance_to(body.global_position) > TOLL_REACH:
		return ""
	return "E · PAY THE TOLL: %s" % (_fare(actor).replace("_", " ").to_upper() if not _fare(actor).is_empty() else "15 HEALTH (YOU HAVE NOTHING)")


## The supply he takes: the selected one, else the first on the belt.
func _fare(actor: CampPlayer) -> String:
	var held := actor.held_item()
	if not held.is_empty() and actor.supplies.get(held, 0) > 0:
		return held
	for kind: String in actor.belt:
		if not kind.is_empty() and actor.supplies.get(kind, 0) > 0:
			return kind
	return ""


func interact(actor: CampPlayer) -> bool:
	CreatureSamples.encounter(actor,body)
	var fare := _fare(actor)
	if fare.is_empty():
		actor.invulnerability = 0.0
		actor.receive_hit(15.0)
		announce("Nothing to pay? The troll takes it in blood. Pass.", actor)
	else:
		actor.supplies[fare] -= 1
		actor.tidy_belt()
		bucket += 1
		announce("Clink. The troll drops your %s in his bucket and waves you through (60 s)." % fare.replace("_", " "), actor)
	paid[actor.get_instance_id()] = PASS_SECONDS
	cue("metal_clang", -4.0, 1.6)
	return true


func contact(_actor: CampPlayer) -> bool:
	return true


func stunnable() -> bool:
	return false


func fears_flare() -> bool:
	return false


func draw_over() -> void:
	# His lantern pool marks the toll line.
	body.draw_arc(Vector2.ZERO, SHOVE_REACH, 0, TAU, 24, Color(0.95, 0.75, 0.4, 0.35), 1.0)


func snapshot() -> Dictionary:
	return {"bucket": bucket}


func restore(state: Dictionary) -> void:
	bucket = state.get("bucket", 0)
