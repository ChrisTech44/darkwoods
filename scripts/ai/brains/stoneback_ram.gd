extends CreatureBrain
## The Ram: bowling. Territorial in the Quarry. After a 1.2 s CHARGE tell (a
## line and a ring at its target) it dashes straight through: everyone in its
## path is launched (30 damage) and doors in the way burst. Step aside.

const TELL := 1.2
const DASH_SECONDS := 0.6
const DASH_SPEED := 170.0
const LAUNCH := 600.0
var bowled: Dictionary = {}


func setup() -> void:
	display_name = "The Ram"
	tip = "A CHARGE ring warns you. Step out of its line: anyone in the path is launched like a bowling pin."
	body.config.killer_chase_speed = 60
	body.config.sight_radius = 200
	body.door_force = 40.0


func physics(delta: float) -> bool:
	body.power_clock = maxf(0.0, body.power_clock - delta)
	if body.dash_remaining > 0.0:
		_dash(delta)
		return true
	if body.power_tell > 0.0:
		body.power_tell -= delta
		body.velocity = Vector2.ZERO
		body.queue_redraw()
		if body.power_tell <= 0.0:
			body.dash_direction = body.global_position.direction_to(body.power_aim)
			body.dash_remaining = DASH_SECONDS
			bowled.clear()
			cue("monster_8", 6.0)
		return true
	var target := body.visible_target
	if is_instance_valid(target) and body.power_clock <= 0.0 and body.has_line_of_sight(target.global_position) and body.nearby_flare() == Vector2.INF:
		body.power_clock = 6.5
		body.power_aim = target.global_position
		body.power_tell = TELL
		return true
	return false


func _dash(delta: float) -> void:
	body.dash_remaining -= delta
	if body.home.has_area() and not body.home.has_point(body.global_position + body.dash_direction * 10.0):
		body.dash_remaining = 0.0
		return
	body.velocity = body.dash_direction * DASH_SPEED
	body.facing = body.dash_direction
	body.move_and_slide()
	if body.get_slide_collision_count() > 0:
		body.dash_remaining = 0.0
	for actor in survivors():
		var id := actor.get_instance_id()
		if bowled.has(id) or body.global_position.distance_to(actor.global_position) > 18.0:
			continue
		bowled[id] = true
		actor.invulnerability = 0.0
		actor.receive_hit(30.0)
		var side := body.dash_direction.orthogonal()
		if side.dot(actor.global_position - body.global_position) < 0.0:
			side = -side
		actor.shove((body.dash_direction + side * 0.6).normalized() * LAUNCH)
		announce("THE RAM BOWLS YOU OVER!", actor)
	body.queue_redraw()


func contact(actor: CampPlayer) -> bool:
	# A shove when it walks into you outside a charge.
	if body.land_hit(actor, 15.0):
		actor.shove(body.global_position.direction_to(actor.global_position) * 300.0)
	return true
