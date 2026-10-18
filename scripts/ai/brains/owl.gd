extends CreatureBrain
## The Night Owl: carry-off. It glides over the treetops (walls don't stop it)
## hunting for a survivor with no teammate within 150 px. Its shadow grows on
## the ground under them for 1.5 s, then it dives: still under the shadow and
## you're snatched and carried about 700 px to a random clearing (10 damage
## when it drops you). A flare nearby makes it drop you and veer off; a flash
## stuns it into letting go. Stick together.

const CRUISE := 70.0
const CARRY_SPEED := 115.0
const ISOLATION := 150.0
const DIVE_TELL := 1.5
const LOCK_AT := 0.3
var target: CampPlayer
var dive := 0.0
var shadow := Vector2.INF
var drop_at := Vector2.INF
var home_point := Vector2.ZERO
var drift := 0.0
var cooldown := 6.0
var hoot := 0.0


func setup() -> void:
	display_name = "The Night Owl"
	tip = "It snatches survivors who wander alone and drops them far away. Stay together; a flare makes it let go."
	body.collision_layer = 0
	body.collision_mask = 0
	# It flies above the treetops: drawn over the sight mask, like tall
	# silhouettes, so you can see it circling (and carrying someone).
	body.z_index = 101
	home_point = body.global_position


func senses(_actor: CampPlayer) -> int:
	return 0


func physics(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	hoot -= delta
	if is_instance_valid(body.held):
		_carry(body.held, delta)
		return true
	if dive > 0.0:
		_dive(delta)
		return true
	if not is_instance_valid(target) or target.status != CampPlayer.Status.ALIVE or not _isolated(target):
		target = _pick()
	if is_instance_valid(target) and cooldown <= 0.0:
		_fly_to(target.global_position + Vector2(0, -6), CRUISE * 1.3, delta)
		if body.global_position.distance_to(target.global_position) < 50.0:
			dive = DIVE_TELL
			shadow = target.global_position
			cue("owl", 6.0, 0.8)
		return true
	# Lazy circles over its patch of forest.
	drift += delta * 0.4
	_fly_to(home_point + Vector2(cos(drift), sin(drift * 0.8)) * 240.0, CRUISE, delta)
	if hoot <= 0.0:
		hoot = randf_range(9.0, 16.0)
		cue("owl", -4.0)
	return true


func _isolated(actor: CampPlayer) -> bool:
	if not CampMap.is_woods(actor.global_position):
		return false
	for other in survivors():
		if other != actor and other.global_position.distance_to(actor.global_position) < ISOLATION:
			return false
	return true


func _pick() -> CampPlayer:
	var best: CampPlayer
	for actor in survivors():
		var distance := body.global_position.distance_to(actor.global_position)
		if distance < 420.0 and _isolated(actor) and (best == null or distance < body.global_position.distance_to(best.global_position)):
			best = actor
	return best


func _fly_to(point: Vector2, speed: float, delta: float) -> void:
	if CampKiller.camp_closed:
		point = CampKiller.outside_camp(point)
	var step := point - body.global_position
	body.velocity = step.limit_length(speed)
	if step.length() > 1.0:
		body.facing = step.normalized()
	var next: Vector2 = body.global_position + body.velocity * delta
	if CampKiller.camp_closed and CampKiller.in_camp(next) and not CampKiller.in_camp(body.global_position):
		# Even the owl won't cross the camp lanterns before Deep Night.
		next = CampKiller.outside_camp(next)
	body.global_position = next
	body.stride += body.velocity.length() * delta
	body.queue_redraw()


func _dive(delta: float) -> void:
	dive -= delta
	if not is_instance_valid(target) or _flare_near(target.global_position):
		_abort()
		return
	if dive > LOCK_AT:
		# The shadow tracks its prey until the last moment, then commits.
		shadow = target.global_position
	body.velocity = Vector2.ZERO
	body.queue_redraw()
	if dive > 0.0:
		return
	if target.status == CampPlayer.Status.ALIVE and target.hidden_spot < 0 and target.global_position.distance_to(shadow) < 26.0 and not target.has_effect("held"):
		body.global_position = target.global_position
		body.hold(target, display_name, 1.0 / 10.0)
		drop_at = reachable(target.global_position + Vector2.from_angle(randf() * TAU) * 700.0)
		if CampKiller.in_camp(drop_at) or not CampMap.is_woods(drop_at):
			drop_at = reachable(target.global_position - (CampMap.CAMP_BOUNDS.get_center() - target.global_position).normalized() * 700.0)
		cue("owl", 8.0, 1.3)
		announce("THE NIGHT OWL SNATCHES YOU! Mash E, or hope for a flare.", target)
	else:
		cooldown = 5.0
	shadow = Vector2.INF


func _carry(victim: CampPlayer, delta: float) -> void:
	body.carrying = true
	if _flare_near(body.global_position):
		_drop(victim, "A flare! The owl lets go.")
		return
	_fly_to(drop_at, CARRY_SPEED, delta)
	victim.global_position = body.global_position
	if body.global_position.distance_to(drop_at) < 6.0:
		_drop(victim, "The owl drops you somewhere deep in the woods.")


func _drop(victim: CampPlayer, line: String) -> void:
	body.release_held()
	victim.invulnerability = 0.0
	victim.receive_hit(10.0)
	announce(line, victim)
	_abort()


func _abort() -> void:
	body.carrying = false
	dive = 0.0
	shadow = Vector2.INF
	target = null
	cooldown = 18.0


func on_released(_actor: CampPlayer) -> void:
	_abort()


func _flare_near(point: Vector2) -> bool:
	for flare in body.get_tree().get_nodes_in_group("flares"):
		if flare.global_position.distance_to(point) < 120.0:
			return true
	return false


func contact(_actor: CampPlayer) -> bool:
	return true


func draw() -> bool:
	# Ground shadow under the flying owl, and the growing dive shadow.
	body.draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
	body.draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.3))
	body.draw_set_transform(Vector2.ZERO)
	if shadow != Vector2.INF:
		var grow := 1.0 - clampf(dive / DIVE_TELL, 0.0, 1.0)
		var at := body.to_local(shadow)
		body.draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
		body.draw_circle(Vector2.ZERO, 8.0 + grow * 22.0, Color(0, 0, 0, 0.25 + grow * 0.35))
		body.draw_set_transform(Vector2.ZERO)
	# Carrying, its talons grip the survivor's shoulders; otherwise it soars higher.
	body.draw_sheet(Color.WHITE, 14.0 if body.carrying else 34.0)
	return true


func snapshot() -> Dictionary:
	return {"dive": dive, "shadow": shadow}


func restore(state: Dictionary) -> void:
	dive = state.get("dive", 0.0)
	shadow = state.get("shadow", Vector2.INF)
