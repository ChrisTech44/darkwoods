extends CreatureBrain
## The Lantern Moth: lands on your face. It flies straight for the brightest
## light, settles over your eyes (a moth fills most of your screen) and drinks
## your flashlight until you swat it (Space flash), a teammate flashes it, or it
## has had its fill. Harmless otherwise. Bug spray keeps it off.

const ON_FACE := 9.0
const DRINK := 3.0
var riding: CampPlayer
var rested := 0.0


func setup() -> void:
	display_name = "The Lantern Moth"
	tip = "Drawn to your light; it lands on your face and drinks the battery. Swat it with a flash, or switch off."
	body.config.killer_chase_speed = 88
	body.config.sight_radius = 260
	body.config.hearing_radius = 90


func senses(actor: CampPlayer) -> int:
	if actor.has_effect("bug_spray"):
		return 0
	return 1 if actor.flashlight_on or body.global_position.distance_to(actor.global_position) < 40.0 else 0


func fears_flare() -> bool:
	return false


func physics(delta: float) -> bool:
	rested = maxf(0.0, rested - delta)
	if is_instance_valid(riding):
		if riding.status != CampPlayer.Status.ALIVE or not riding.has_effect("face_moth"):
			_let_go()
			return true
		body.global_position = riding.global_position + Vector2(0, -22)
		body.velocity = Vector2.ZERO
		riding.flashlight_charge = maxf(0.0, riding.flashlight_charge - DRINK * delta)
		return true
	if rested > 0.0:
		wander(40.0, delta)
		return true
	# Flares draw it like a candle draws a moth.
	for flare in body.get_tree().get_nodes_in_group("flares"):
		if body.global_position.distance_to(flare.global_position) < 220.0 and body.has_line_of_sight(flare.global_position):
			body.steer(flare.global_position, 70.0, delta)
			return true
	return false


func contact(actor: CampPlayer) -> bool:
	if actor.has_effect("face_moth") or actor.has_effect("bug_spray"):
		return true
	riding = actor
	actor.add_effect("face_moth", ON_FACE)
	cue("lantern_moth_screech", 2.0, 1.2)
	announce("A MOTH LANDED ON YOUR FACE! Space swats it.", actor)
	return true


## Swatted off (a flash on the wearer or by a teammate).
func swat() -> void:
	if is_instance_valid(riding):
		riding.clear_effect("face_moth")
	_let_go()
	body.stun(2.0)


func _let_go() -> void:
	riding = null
	rested = 12.0
	body.global_position += Vector2(0, -6)


func on_stunned() -> void:
	if is_instance_valid(riding):
		riding.clear_effect("face_moth")
		riding = null
		rested = 12.0


func snapshot() -> Dictionary:
	return {"riding": is_instance_valid(riding)}


func restore(state: Dictionary) -> void:
	if not state.get("riding", false):
		riding = null
