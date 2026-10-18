extends CreatureBrain
## The Bog Hands: ankle-grabbers. They wait under a bubbling mud puddle on a
## trail. Step in and they grab: you're held, and after 6 s you're dragged
## under (downed). Mash E, or a teammate holds E beside you, to pull free. A
## flare in the puddle sends them back down. Walk around puddles.

const GRAB_RADIUS := 17.0
const SINK := 6.0
var sinking := 0.0
var rest := 0.0


func setup() -> void:
	display_name = "The Bog Hands"
	tip = "They hide in mud puddles on the trail. Walk around puddles; if they grab you, mash E or get a teammate to pull."
	body.collision_layer = 0


func senses(_actor: CampPlayer) -> int:
	return 0


func stunnable() -> bool:
	return is_instance_valid(body.held)


func physics(delta: float) -> bool:
	rest = maxf(0.0, rest - delta)
	body.velocity = Vector2.ZERO
	var victim := body.held
	if is_instance_valid(victim):
		sinking += delta
		victim.global_position = victim.global_position.move_toward(body.global_position, 20.0 * delta)
		if _flare_near():
			body.release_held()
			announce("The flare hisses in the mud; the hands let go!", victim)
			return true
		if sinking >= SINK:
			body.release_held()
			victim.health = 0.0
			victim.set_status(CampPlayer.Status.DOWNED)
			announce("The bog hands DRAG YOU UNDER!", victim)
			cue("bog_gurgle", 4.0, 0.75)
		return true
	sinking = 0.0
	if rest > 0.0 or _flare_near():
		return true
	for actor in survivors():
		if actor.global_position.distance_to(body.global_position) <= GRAB_RADIUS and not actor.has_effect("held") and actor.knock.length() < 30.0:
			body.hold(actor, display_name, 1.0 / 12.0)
			cue("bog_gurgle", 2.0, 1.1)
			announce("HANDS GRAB YOUR ANKLES! Mash E, or a teammate holds E to pull you out.", actor)
			break
	return true


func on_released(_actor: CampPlayer) -> void:
	rest = 15.0
	sinking = 0.0


func _flare_near() -> bool:
	for flare in body.get_tree().get_nodes_in_group("flares"):
		if flare.global_position.distance_to(body.global_position) < 70.0:
			return true
	return false


func contact(_actor: CampPlayer) -> bool:
	return true


func draw() -> bool:
	PixelArt.draw_in(body, "mud_puddle", Rect2(-18, -10, 36, 18))
	if sinking > 0.0:
		var rise := clampf(sinking * 3.0, 0.0, 1.0)
		body.draw_sheet(Color(1, 1, 1, rise), -14.0 + rise * 10.0)
	elif int(Time.get_ticks_msec() / 400 + int(body.global_position.x)) % 5 == 0:
		# A lazy bubble now and then.
		body.draw_circle(Vector2(4, -2), 1.5, Color(0.5, 0.55, 0.4, 0.8))
	return true


func snapshot() -> Dictionary:
	return {"sinking": sinking}


func restore(state: Dictionary) -> void:
	sinking = state.get("sinking", 0.0)
