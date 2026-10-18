extends CreatureBrain
## Bear Hug: the relentless hugger. A giant patched camp teddy. Once it has
## seen you it never loses you: it plods after you wherever you go. When it
## catches you it HUGS: you're held and squeezed (5 health a second) until you
## mash E free or a teammate flashes it or pulls you loose. Then it sits down,
## content, for a while. Slow, so outpace it; but don't stop.

const SPEED := 42.0
const SQUEEZE := 5.0
var beloved: CampPlayer
var content := 0.0
var squeak := 0.0


func setup() -> void:
	display_name = "Bear Hug"
	tip = "Once it sees you it follows forever, slowly. If it hugs you, mash E or get a teammate to flash it."
	body.config.sight_radius = 150


func fears_flare() -> bool:
	return false


func physics(delta: float) -> bool:
	content = maxf(0.0, content - delta)
	squeak -= delta
	var victim := body.held
	if is_instance_valid(victim):
		body.velocity = Vector2.ZERO
		victim.global_position = body.global_position + Vector2(0, 6)
		victim.health = maxf(0.0, victim.health - SQUEEZE * delta)
		victim.hurt_time = 0.2
		if victim.health <= 0.0:
			body.release_held()
			victim.set_status(CampPlayer.Status.DOWNED)
		return true
	if content > 0.0:
		body.velocity = Vector2.ZERO
		return true
	if not is_instance_valid(beloved) or beloved.status != CampPlayer.Status.ALIVE:
		beloved = nearest_seen(body.config.sight_radius)
		if beloved != null:
			announce("Something big and soft has noticed you. It wants a hug.", beloved)
	if is_instance_valid(beloved):
		if squeak <= 0.0:
			squeak = 0.7
			cue("footstep", -4.0, 1.9)
		if beloved.hidden_spot >= 0:
			# It waits outside your hiding spot, patiently.
			body.velocity = Vector2.ZERO
			return true
		if body.global_position.distance_to(beloved.global_position) <= body.config.attack_radius + 2.0:
			_hug(beloved)
			return true
		body.steer(beloved.global_position, SPEED, delta)
		return true
	wander(30.0, delta)
	return true


func _hug(actor: CampPlayer) -> void:
	if actor.has_effect("held") or actor.invulnerability > 0.0:
		return
	body.hold(actor, display_name, 1.0 / 15.0)
	cue("monster_7", 2.0, 0.6)
	announce("BEAR HUG! Mash E to wriggle free (or a teammate flashes it).", actor)


func on_released(_actor: CampPlayer) -> void:
	content = 20.0
	beloved = null


func contact(actor: CampPlayer) -> bool:
	_hug(actor)
	return true


func draw_over() -> void:
	if content > 0.0:
		PixelArt.draw_in(body, "heart_patch", Rect2(-5, -66, 10, 10))


func snapshot() -> Dictionary:
	return {"content": content}


func restore(state: Dictionary) -> void:
	content = state.get("content", 0.0)
