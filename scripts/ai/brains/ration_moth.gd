extends CreatureBrain
## The Puffball: spore puffs. It drifts toward people; when one comes close it
## swells (a pale cloud grows for 1.2 s) and bursts. Anyone caught in the puff
## gets HELIUM VOICE for 60 s (everyone hears them squeak on voice chat) and
## SNEEZES loudly every few seconds for 30 s. Standing still holds your breath.

const SWELL := 1.2
const BURST := 78.0
var swelling := 0.0
var cooldown := 2.0
var burst_time := 0.0


func setup() -> void:
	display_name = "The Puffball"
	tip = "Its spores give you a squeaky helium voice and loud sneezes. Walk around it, or stand still to hold your breath."
	body.config.killer_chase_speed = 46
	body.config.sight_radius = 160


func fears_flare() -> bool:
	return false


func physics(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	burst_time = maxf(0.0, burst_time - delta)
	if swelling > 0.0:
		swelling -= delta
		body.velocity = Vector2.ZERO
		body.queue_redraw()
		if swelling <= 0.0:
			_burst()
		return true
	var near := nearest_seen(110.0)
	if near != null and cooldown <= 0.0:
		swelling = SWELL
		cue("screech_5", -2.0, 1.6)
		return true
	if near != null:
		return false
	wander(30.0, delta)
	return true


func contact(_actor: CampPlayer) -> bool:
	# It drifts into people; the spores are the threat.
	return true


func _burst() -> void:
	cooldown = 10.0
	burst_time = 0.8
	var caught := 0
	for actor in survivors():
		if body.global_position.distance_to(actor.global_position) > BURST or not body.has_line_of_sight(actor.global_position):
			continue
		if actor.velocity.length() < 1.0:
			announce("You held your breath. The spores drift past.", actor)
			continue
		actor.add_effect("helium", 60.0)
		actor.add_effect("sneezy", 30.0)
		caught += 1
		announce("PUFF! Your voice goes squeaky and your nose tickles...", actor)
	if caught > 0:
		cue("witch_cackle", 0.0, 2.2)


func draw_over() -> void:
	if swelling > 0.0:
		var grow := 1.0 - swelling / SWELL
		body.draw_circle(Vector2(0, -20), 14.0 + grow * 40.0, Color(0.92, 0.9, 0.78, 0.12 + grow * 0.2))
	if burst_time > 0.0:
		var spread := 1.0 - burst_time / 0.8
		body.draw_arc(Vector2(0, -12), 20.0 + spread * BURST, 0, TAU, 32, Color(0.95, 0.92, 0.8, 0.5 * (1.0 - spread)), 3.0)


func snapshot() -> Dictionary:
	return {"swelling": swelling, "burst": burst_time}


func restore(state: Dictionary) -> void:
	swelling = state.get("swelling", 0.0)
	burst_time = state.get("burst", 0.0)
