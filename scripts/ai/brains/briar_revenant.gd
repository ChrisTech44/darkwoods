extends CreatureBrain
## The Scarecrow: only moves when nobody is looking. It is frozen while any
## survivor's flashlight is on it or someone close by faces it. Unwatched, it
## rushes the nearest survivor and its touch is brutal (60). A flash can't
## freeze it; only watching does, so teammates take turns keeping eyes on it.

const SPEED := 128.0
const WATCH_REACH := 270.0
const TOUCH := 60.0
var watched := false
var rustle := 0.0


func setup() -> void:
	display_name = "The Scarecrow"
	tip = "It only moves when no one is watching. Keep a light on it and back away; take turns as a team."
	body.config.sight_radius = 400
	body.config.hearing_radius = 260


func stunnable() -> bool:
	return false


func fears_flare() -> bool:
	return false


func is_watched() -> bool:
	for actor in survivors():
		var distance := body.global_position.distance_to(actor.global_position)
		if distance > WATCH_REACH or not body.has_line_of_sight(actor.global_position):
			continue
		if in_beam(actor, body.global_position, WATCH_REACH, 0.6):
			return true
		# Up close, simply facing it is enough (you can see it in the gloom).
		if distance < 90.0 and actor.facing.dot(actor.global_position.direction_to(body.global_position)) > 0.3:
			return true
	return false


func physics(delta: float) -> bool:
	watched = is_watched()
	if watched:
		body.velocity = Vector2.ZERO
		return true
	rustle -= delta
	if rustle <= 0.0 and body.velocity.length() > 1.0:
		rustle = 2.5
		cue("revenant_screech", -6.0, 0.7)
	body.config.killer_chase_speed = SPEED
	body.config.killer_patrol_speed = 60.0
	return false


func contact(actor: CampPlayer) -> bool:
	if watched:
		return true
	body.land_hit(actor, TOUCH)
	return true


func draw() -> bool:
	# Stock still, it's just a scarecrow on a pole... until it isn't.
	body.draw_circle(Vector2(0, 2), 9, Color(0, 0, 0, 0.4))
	if watched:
		body.draw_line(Vector2(0, 2), Vector2(0, -60), Color("4a3a28"), 2.0)
	body.draw_sheet(Color(0.95, 0.9, 0.82) if watched else Color.WHITE)
	return true


func snapshot() -> Dictionary:
	return {"watched": watched}


func restore(state: Dictionary) -> void:
	watched = state.get("watched", false)
