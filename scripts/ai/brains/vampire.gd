extends CreatureBrain
## The Vampire: hypnotises. A survivor it can see (and who isn't holding their
## beam on it) is drawn toward it; when it reaches them it latches on and
## drains health, healing itself, until they wriggle free (E), a teammate
## flashes it or pulls them loose. Garlic keeps it away entirely.

const GAZE := 170.0
const DRAIN := 6.0
const GARLIC_DISTANCE := 120.0
## A gaze holds for at most GAZE_HOLD seconds, then it must look away a while.
const GAZE_HOLD := 4.0
const GAZE_REST := 6.0
var gaze_time := 0.0
var gaze_rest := 0.0
var gaze_target: CampPlayer
## Client-side copy of "someone is in its gaze" for drawing.
var gazing := false
var latched := false


func setup() -> void:
	display_name = "The Vampire"
	tip = "Garlic keeps it away. Hold your beam on it to slow it and break its pull; mash E if it bites."
	body.config.killer_chase_speed = 72


func senses(actor: CampPlayer) -> int:
	return 0 if actor.has_effect("garlic") else -1


func physics(delta: float) -> bool:
	if is_instance_valid(body.held):
		_drain(body.held, delta)
		return true
	latched = false
	# Garlic: keep a respectful distance from anyone carrying its smell.
	for actor in survivors():
		if actor.has_effect("garlic") and body.global_position.distance_to(actor.global_position) < GARLIC_DISTANCE:
			if gazing: _rest()
			flee_from(actor.global_position, 80.0, delta)
			return true
	gaze_rest = maxf(0.0, gaze_rest - delta)
	var victim := nearest_seen(GAZE)
	var scared := body.nearby_flare() != Vector2.INF
	var eligible := victim != null and not scared and not victim.has_effect("garlic") and not in_beam(victim, body.global_position, GAZE, 0.8)
	if gazing and (not eligible or victim != gaze_target):
		_rest()
	gaze_target = null
	gazing = false
	if eligible and gaze_rest <= 0.0:
		gaze_time += delta
		if gaze_time >= GAZE_HOLD:
			_rest()
		else:
			gaze_target = victim
			gazing = true
			victim.add_effect("hypnotized", 0.25)
			victim.effect_data["pull_to"] = body.global_position
	# A steady beam slows it; otherwise it glides in.
	var lit := victim != null and in_beam(victim, body.global_position, 145.0, 0.88)
	body.config.killer_chase_speed = 40.0 if lit else 72.0
	return false


func contact(actor: CampPlayer) -> bool:
	if gaze_rest > 0.0 or actor.has_effect("garlic") or actor.has_effect("held"):
		return true
	body.hold(actor, display_name, 1.0 / 8.0)
	latched = true
	cue("vampire_snarl", 4.0)
	announce("THE VAMPIRE BITES! Mash E to tear free, or a teammate flashes it.", actor)
	return true


func _drain(actor: CampPlayer, delta: float) -> void:
	latched = true
	body.velocity = Vector2.ZERO
	body.facing = body.global_position.direction_to(actor.global_position)
	body.global_position = actor.global_position + Vector2(-10 if body.facing.x > 0 else 10, -2)
	actor.receive_drain(DRAIN * delta)
	actor.hurt_time = 0.3
	if actor.health <= 0.0:
		body.release_held()
		actor.set_status(CampPlayer.Status.DOWNED)


func _rest() -> void:
	if is_instance_valid(gaze_target):
		gaze_target.clear_effect("hypnotized")
	gaze_time = 0.0
	gaze_rest = GAZE_REST
	gazing = false


func on_stunned() -> void:
	_rest()


func on_released(actor: CampPlayer) -> void:
	latched = false
	actor.clear_effect("hypnotized")
	_rest()


func draw_over() -> void:
	if gazing or latched:
		# Red eyes while it holds someone's gaze.
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
		body.draw_circle(Vector2(-3, -46), 1.6, Color(1, 0.2, 0.25, pulse))
		body.draw_circle(Vector2(3, -46), 1.6, Color(1, 0.2, 0.25, pulse))


func snapshot() -> Dictionary:
	return {"gaze": gazing, "latched": latched}


func restore(state: Dictionary) -> void:
	latched = state.get("latched", false)
	gazing = state.get("gaze", false)
