extends CreatureBrain
## The Peeper: a staring contest. It lurks at the edge of trails. Put your beam
## on it, or face it up close, and you're LOCKED: you can't move and slowly
## lose health while it stares. It breaks off when a teammate steps into the
## line of its stare or flashes it, or after it blinks (7 s). Don't look at it.

const REACH := 170.0
const DRAIN := 4.0
const BLINK := 7.0
var stare := 0.0
var cooldown := 0.0


func setup() -> void:
	display_name = "The Peeper"
	tip = "Don't put your light on it or face it up close, or it locks you in a stare. A teammate stepping between you breaks it."


func senses(_actor: CampPlayer) -> int:
	return 0


func physics(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	var victim := body.held
	if is_instance_valid(victim):
		_stare(victim, delta)
		return true
	stare = 0.0
	if cooldown <= 0.0:
		for actor in survivors():
			var offset := body.global_position - actor.global_position
			if offset.length() > REACH or actor.has_effect("held") or not body.has_line_of_sight(actor.global_position):
				continue
			var looking := actor.facing.dot(offset.normalized())
			if in_beam(actor, body.global_position, REACH, 0.88) or (offset.length() < 110.0 and looking > 0.9):
				body.hold(actor, display_name, 1.0 / 20.0)
				body.facing = -offset.normalized()
				cue("screech_1", 4.0, 0.7)
				announce("THE PEEPER CAUGHT YOUR EYE. You can't look away! A teammate can step between you.", actor)
				return true
	wander(22.0, delta)
	return true


func _stare(victim: CampPlayer, delta: float) -> void:
	body.velocity = Vector2.ZERO
	stare += delta
	victim.facing = victim.global_position.direction_to(body.global_position)
	victim.health = maxf(0.0, victim.health - DRAIN * delta)
	victim.hurt_time = 0.2
	if victim.health <= 0.0:
		_end(victim)
		victim.set_status(CampPlayer.Status.DOWNED)
		return
	if stare >= BLINK or _blocked(victim):
		_end(victim)
		announce("The stare breaks. Look away!", victim)


## A teammate standing on the line between the Peeper and its victim.
func _blocked(victim: CampPlayer) -> bool:
	for other in survivors():
		if other == victim:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(other.global_position, body.global_position, victim.global_position)
		if closest.distance_to(other.global_position) < 18.0:
			return true
	return false


func _end(victim: CampPlayer) -> void:
	cooldown = 6.0
	stare = 0.0
	if body.held == victim:
		body.release_held()


func on_released(_actor: CampPlayer) -> void:
	cooldown = 6.0
	stare = 0.0


func contact(_actor: CampPlayer) -> bool:
	return true


func draw_over() -> void:
	if stare > 0.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		body.draw_arc(Vector2(0, -40), 12.0 + pulse * 3.0, 0, TAU, 20, Color(0.95, 0.85, 0.5, 0.6), 1.5)


func snapshot() -> Dictionary:
	return {"stare": stare}


func restore(state: Dictionary) -> void:
	stare = state.get("stare", 0.0)
