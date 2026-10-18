extends CreatureBrain
## The Banshee: she drifts toward the living and screams. A long INHALE (a pale
## ring swells around her for 1.6 s), then a wail: everyone inside the ring
## with a clear line to her is DEAFENED for 25 s. Deafened, the world goes
## muffled: you can't hear the stalker's whistle, creature calls or your own
## heartbeat warning. Get out of the ring or behind something solid before she
## lets go. Her touch is cold (10 damage).

const SCREAM_REACH := 200.0
const INHALE := 1.6
const DEAF_SECONDS := 25.0
const COOLDOWN := 16.0
var inhale := 0.0
var cooldown := 5.0
var wail := 0.0


func setup() -> void:
	display_name = "The Banshee"
	tip = "A swelling ring means she's drawing breath: get out of it or behind cover, or her scream leaves you deaf for 25 s (no whistle, no heartbeat)."
	body.config.sight_radius = 220
	body.config.killer_chase_speed = 44
	body.config.killer_patrol_speed = 26


func physics(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	wail = maxf(0.0, wail - delta)
	if inhale > 0.0:
		inhale -= delta
		body.velocity = Vector2.ZERO
		body.queue_redraw()
		if inhale <= 0.0:
			_scream()
		return true
	var near := nearest_seen(SCREAM_REACH * 0.8)
	if near != null and cooldown <= 0.0:
		inhale = INHALE
		cue("gasp", 6.0, 0.55)
		return true
	return false


func _scream() -> void:
	cooldown = COOLDOWN
	wail = 0.8
	cue("revenant_screech", 10.0, 1.35)
	for actor: CampPlayer in body.get_tree().get_nodes_in_group("survivors"):
		if actor.status == CampPlayer.Status.DEAD or actor.status == CampPlayer.Status.ESCAPED:
			continue
		if body.global_position.distance_to(actor.global_position) <= SCREAM_REACH and body.has_line_of_sight(actor.global_position):
			actor.add_effect("deaf", DEAF_SECONDS)
			announce("THE BANSHEE WAILS. Your ears ring... everything sounds far away (25 s).", actor)


func on_stunned() -> void:
	inhale = 0.0
	cooldown = COOLDOWN * 0.5


func contact(actor: CampPlayer) -> bool:
	body.land_hit(actor, 10.0)
	return true


func draw_over() -> void:
	if inhale > 0.0:
		var t := 1.0 - inhale / INHALE
		body.draw_arc(Vector2(0, -20), 20.0 + t * (SCREAM_REACH - 20.0), 0, TAU, 48, Color(0.85, 0.9, 1.0, 0.25 + t * 0.5), 2.0)
	if wail > 0.0:
		for index in range(3):
			var r := (0.8 - wail) * 260.0 + index * 22.0
			body.draw_arc(Vector2(0, -20), r, 0, TAU, 48, Color(0.9, 0.95, 1.0, wail), 1.0)


func snapshot() -> Dictionary:
	return {"inhale": inhale, "wail": wail}


func restore(state: Dictionary) -> void:
	inhale = state.get("inhale", 0.0)
	wail = state.get("wail", 0.0)
