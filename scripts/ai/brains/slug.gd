extends CreatureBrain
## The Slug: a bear-sized slug that leaves a glistening trail. Step in the slime
## and you SKATE (you speed up slowly, can't stop or turn sharply) for a few
## seconds; get touched and you're coated for 8 s. It is slow, but its trails
## linger for a minute across the paths you need. Salt: a survivor with a salt
## ward up makes it shrivel and flee, and dissolves the slime around them.

const SPEED := 20.0
const CHASE_SPEED := 30.0
const DROP_EVERY := 14.0
const PUDDLE_RADIUS := 13.0
const PUDDLE_SECONDS := 60.0
const MAX_PUDDLES := 48
const SALT_REACH := 46.0
## [position, seconds left]
var puddles: Array = []
var travelled := 0.0
var last := Vector2.ZERO
var shrivel := 0.0


func setup() -> void:
	display_name = "The Slug"
	tip = "Its slime trail makes you skate for a few seconds. Walk around the shine; a salt ward makes it shrivel and dissolves the slime."
	body.config.killer_chase_speed = CHASE_SPEED
	body.config.killer_patrol_speed = SPEED
	last = body.global_position


func physics(delta: float) -> bool:
	shrivel = maxf(0.0, shrivel - delta)
	for puddle in puddles.duplicate():
		puddle[1] -= delta
		if puddle[1] <= 0.0:
			puddles.erase(puddle)
	travelled += body.global_position.distance_to(last)
	last = body.global_position
	if travelled >= DROP_EVERY:
		travelled = 0.0
		puddles.append([body.global_position + Vector2(randf_range(-3, 3), randf_range(-2, 2)), PUDDLE_SECONDS])
		while puddles.size() > MAX_PUDDLES:
			puddles.pop_front()
	for actor in survivors():
		# Salt dissolves nearby slime and sends the slug off.
		if actor.ward_remaining > 0.0:
			puddles = puddles.filter(func(puddle: Array) -> bool: return puddle[0].distance_to(actor.global_position) > SALT_REACH * 1.5)
			if body.global_position.distance_to(actor.global_position) <= SALT_REACH and shrivel <= 0.0:
				shrivel = 10.0
				cue("bog_gurgle", 4.0, 1.6)
				announce("The salt hisses! The slug shrivels and slithers off.", actor)
			continue
		for puddle in puddles:
			if puddle[0].distance_to(actor.global_position) <= PUDDLE_RADIUS:
				if not actor.has_effect("slimed"):
					announce("SLIME! You're skating. Steer gently.", actor)
				actor.add_effect("slimed", 2.5)
				break
	if shrivel > 0.0:
		var nearest := nearest_seen(400.0)
		if nearest != null:
			flee_from(nearest.global_position, CHASE_SPEED, delta)
		else:
			body.velocity = Vector2.ZERO
		return true
	return false


func contact(actor: CampPlayer) -> bool:
	if body.land_hit(actor, 10.0):
		actor.add_effect("slimed", 8.0)
		actor.skid = actor.velocity
		cue("bog_gurgle", 2.0, 0.6)
		announce("The slug slimes you head to toe. You're skating for 8 s!", actor)
	return true


func fears_flare() -> bool:
	return false


func draw() -> bool:
	# The trail, under the slug.
	for puddle: Array in puddles:
		var at := body.to_local(puddle[0])
		var fade := clampf(puddle[1] / 12.0, 0.0, 1.0)
		body.draw_set_transform(at, 0.0, Vector2(1.0, 0.55))
		body.draw_circle(Vector2.ZERO, PUDDLE_RADIUS, Color(0.55, 0.45, 0.75, 0.32 * fade))
		body.draw_circle(Vector2(-3, -3), 3.0, Color(0.9, 0.85, 1.0, 0.35 * fade))
		body.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if shrivel > 0.0:
		body.draw_sheet(Color(0.8, 0.75, 0.7), 0.0)
		return true
	return false


func snapshot() -> Dictionary:
	return {"puddles": puddles, "shrivel": shrivel}


func restore(state: Dictionary) -> void:
	puddles = state.get("puddles", [])
	shrivel = state.get("shrivel", 0.0)
