extends CreatureBrain
## The Paparazzo: flash photography. It creeps up, its shutter whines for a
## second, then its camera fires: everyone in view who is facing it is blinded
## white for 3 s, and everyone it can see is PHOTOGRAPHED: the picture goes to
## the stalker, who learns where they are. Turn away; break line of sight.

const SNAP_RANGE := 130.0
const FLASH_REACH := 210.0
const WHINE := 1.0
var whine := 0.0
var flashed := 0.0
var cooldown := 3.0


func setup() -> void:
	display_name = "The Paparazzo"
	tip = "Its flash blinds anyone facing it and sends your picture to the stalker. Turn away and break line of sight."
	body.config.killer_chase_speed = 50
	body.config.sight_radius = 200


func physics(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	flashed = maxf(0.0, flashed - delta)
	if whine > 0.0:
		whine -= delta
		body.velocity = Vector2.ZERO
		body.queue_redraw()
		if whine <= 0.0:
			_snap()
		return true
	var subject := nearest_seen(SNAP_RANGE)
	if subject != null and cooldown <= 0.0:
		whine = WHINE
		body.facing = body.global_position.direction_to(subject.global_position)
		cue("camera_charge", 0.0, 1.0, WHINE + 0.1)
		return true
	if flashed > 0.0:
		# After a shot it slinks off to frame the next one.
		if subject != null:
			flee_from(subject.global_position, 60.0, delta)
		return true
	return false


func contact(_actor: CampPlayer) -> bool:
	return true


func _snap() -> void:
	cooldown = 12.0
	flashed = 4.0
	var world: Node = level()
	for actor in survivors():
		var offset := body.global_position - actor.global_position
		if offset.length() > FLASH_REACH or not body.has_line_of_sight(actor.global_position):
			continue
		if actor.facing.dot(offset.normalized()) > 0.0:
			actor.add_effect("whiteout", 3.0)
		actor.add_effect("marked", 20.0)
		if world != null:
			world.killer.hear_stimulus(actor.global_position, INF)
		announce("SNAP! Your photo is on its way to the stalker.", actor)
	cue("camera_shutter", 2.0)


func draw_over() -> void:
	if whine > 0.0:
		var t := 1.0 - whine / WHINE
		body.draw_arc(Vector2(0, -40), 6.0 + t * 10.0, 0, TAU, 16, Color(1, 1, 1, 0.3 + t * 0.6), 2.0)
	if flashed > 3.6:
		body.draw_circle(Vector2(0, -40), 40.0, Color(1, 1, 0.95, (flashed - 3.6) * 2.0))


func snapshot() -> Dictionary:
	return {"whine": whine, "flashed": flashed}


func restore(state: Dictionary) -> void:
	whine = state.get("whine", 0.0)
	flashed = state.get("flashed", 0.0)
