extends CreatureBrain
## The Seamstress: sews survivors together. From a distance she whips a thread
## (0.8 s wind-up) that stitches her target to the nearest teammate, or, alone,
## to the spot where they stand, for 25 s: you can't get more than 80 px apart
## and you drag each other. Scissors cut the thread.

const WHIP_RANGE := 120.0
const WINDUP := 0.8
const STITCH := 25.0
var windup := 0.0
var aim: CampPlayer
var cooldown := 2.0


func setup() -> void:
	display_name = "The Seamstress"
	tip = "Her thread stitches you to a teammate (or the ground) for 25 s. Scissors cut it."
	body.config.killer_chase_speed = 56
	body.config.sight_radius = 190


func physics(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	if windup > 0.0:
		windup -= delta
		body.velocity = Vector2.ZERO
		body.queue_redraw()
		if windup <= 0.0 and is_instance_valid(aim):
			_stitch(aim)
		return true
	var target := nearest_seen(WHIP_RANGE)
	if target != null and cooldown <= 0.0 and not target.has_effect("tethered"):
		aim = target
		windup = WINDUP
		body.facing = body.global_position.direction_to(target.global_position)
		cue("monster_7", 0.0, 1.3)
		return true
	if target != null and body.global_position.distance_to(target.global_position) < 90.0:
		flee_from(target.global_position, 60.0, delta)
		return true
	return false


func contact(_actor: CampPlayer) -> bool:
	return true


func _stitch(target: CampPlayer) -> void:
	cooldown = 18.0
	if target.status != CampPlayer.Status.ALIVE or not body.has_line_of_sight(target.global_position):
		return
	var partner: CampPlayer
	for other in survivors():
		if other != target and other.global_position.distance_to(target.global_position) < 400.0 and (partner == null or other.global_position.distance_to(target.global_position) < partner.global_position.distance_to(target.global_position)):
			partner = other
	CreatureSamples.encounter(target,body)
	target.add_effect("tethered", STITCH)
	if partner != null:
		partner.add_effect("tethered", STITCH)
		target.set_meta("tether_partner", partner)
		partner.set_meta("tether_partner", target)
		target.effect_data["tether_to"] = partner.global_position
		partner.effect_data["tether_to"] = target.global_position
		announce("STITCHED! You and %s are sewn together for 25 s. Scissors cut it." % (partner.peer_name if not partner.peer_name.is_empty() else "a teammate"))
	else:
		if target.has_meta("tether_partner"):
			target.remove_meta("tether_partner")
		target.effect_data["tether_to"] = target.global_position
		announce("STITCHED to the ground! You can't get far for 25 s. Scissors cut it.", target)


func draw_over() -> void:
	if windup > 0.0 and is_instance_valid(aim):
		body.draw_line(Vector2(0, -24), body.to_local(aim.global_position) + Vector2(0, -12), Color(0.9, 0.86, 0.75, 0.4 + (1.0 - windup / WINDUP) * 0.5), 1.0)


func snapshot() -> Dictionary:
	return {"windup": windup, "aim": aim.global_position if is_instance_valid(aim) and windup > 0.0 else Vector2.INF}


func restore(state: Dictionary) -> void:
	windup = state.get("windup", 0.0)
