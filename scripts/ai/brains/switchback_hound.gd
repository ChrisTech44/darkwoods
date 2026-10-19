extends CreatureBrain
## Buster, the stalker's hound: tracker and alarm. It follows fresh blood, and
## when it sees a survivor it keeps its distance and BARKS, calling its master
## straight to them. It drags downed survivors toward the stalker's hook.
## Throw it food (rations within reach) and it's your friend for a minute: it
## follows you, never barks at you and growls when creatures come close.

const BARK_RANGE := 180.0
const KEEP_AWAY := 95.0
const DRAG_SPEED := 30.0
var bark_cooldown := 0.0
var barking := 0.0
var friend: CampPlayer
var friendly := 0.0
var dragging: CampPlayer
var growl_cooldown := 0.0


func setup() -> void:
	display_name = "Buster, the Stalker's Hound"
	tip = "It barks to call the stalker and drags the downed to his hook. Throw it rations and it's your friend for a minute."
	body.config.killer_chase_speed = 90
	body.config.sight_radius = BARK_RANGE


func senses(actor: CampPlayer) -> int:
	return 0 if friendly > 0.0 and actor == friend else -1


func physics(delta: float) -> bool:
	bark_cooldown = maxf(0.0, bark_cooldown - delta)
	barking = maxf(0.0, barking - delta)
	growl_cooldown = maxf(0.0, growl_cooldown - delta)
	friendly = maxf(0.0, friendly - delta)
	if friendly > 0.0 and is_instance_valid(friend) and friend.status == CampPlayer.Status.ALIVE:
		_heel(delta)
		return true
	if is_instance_valid(dragging):
		_drag(delta)
		return true
	for actor: CampPlayer in body.get_tree().get_nodes_in_group("survivors"):
		if actor.status == CampPlayer.Status.DOWNED and body.global_position.distance_to(actor.global_position) < 260.0 and body.has_line_of_sight(actor.global_position):
			if body.steer(actor.global_position, 80.0, delta) or body.global_position.distance_to(actor.global_position) < 14.0:
				dragging = actor
				announce("Buster has %s by the ankle and is dragging them away!" % (actor.peer_name if not actor.peer_name.is_empty() else "a survivor"))
			return true
	var seen := nearest_seen(BARK_RANGE)
	if seen != null:
		body.facing = body.global_position.direction_to(seen.global_position)
		if bark_cooldown <= 0.0:
			_bark(seen)
		# Keep a wary distance; it's an alarm, not a fighter.
		if body.global_position.distance_to(seen.global_position) < KEEP_AWAY:
			flee_from(seen.global_position, 70.0, delta)
		else:
			body.velocity = Vector2.ZERO
		return true
	# Nose down: the freshest blood within reach.
	var scent := _scent()
	if scent != Vector2.INF:
		body.steer(scent, 70.0, delta)
		return true
	wander(42.0, delta)
	return true


func _bark(at: CampPlayer) -> void:
	CreatureSamples.encounter(at,body)
	bark_cooldown = 7.0
	barking = 1.2
	cue("dog_bark", 4.0)
	var world: Node = level()
	if world != null:
		world.killer.hear_stimulus(at.global_position, INF)
		world.loud_noise(body.global_position, 260)
	announce("Buster BARKS! His master heard that.", at)


func _scent() -> Vector2:
	var best := Vector2.INF
	for actor in survivors():
		if actor.blood.is_empty():
			continue
		var drop: Vector2 = actor.blood.back()
		if body.global_position.distance_to(drop) < 600.0 and (best == Vector2.INF or body.global_position.distance_to(drop) < body.global_position.distance_to(best)):
			best = drop
	return best


func _drag(delta: float) -> void:
	if dragging.status != CampPlayer.Status.DOWNED:
		dragging = null
		return
	var world: Node = level()
	var goal: Vector2 = world.hook_point() if world != null and world.has_method("hook_point") else body.global_position
	if goal == Vector2.INF:
		goal = world.killer.global_position
	if body.steer(goal, DRAG_SPEED, delta):
		dragging = null
		return
	dragging.global_position = body.global_position - body.facing * 12.0


func contact(_actor: CampPlayer) -> bool:
	return true


## Thrown food within reach: a friend for 60 s.
func bait(actor: CampPlayer) -> bool:
	if body.global_position.distance_to(actor.global_position) > 140.0:
		return false
	friend = actor
	friendly = 60.0
	dragging = null
	body.visible_target = null
	body.transition(CampKiller.State.PATROL)
	cue("dog_whine", 0.0, 1.0, 3.5)
	announce("Buster gobbles the food and wags his tail. Good boy! (60 s)", actor)
	return true


func _heel(delta: float) -> void:
	var spot: Vector2 = friend.global_position + Vector2(-18, 10)
	if body.global_position.distance_to(spot) > 22.0:
		body.steer(spot, 95.0, delta)
	else:
		body.velocity = Vector2.ZERO
	if growl_cooldown > 0.0:
		return
	for enemy: CampKiller in body.get_tree().get_nodes_in_group("killers"):
		if enemy != body and enemy.enabled and enemy.global_position.distance_to(friend.global_position) < 170.0:
			growl_cooldown = 6.0
			cue("monster_10", 0.0, 0.8)
			var side := friend.global_position.direction_to(enemy.global_position)
			announce("Buster growls toward the %s." % _compass(side), friend)
			return


static func _compass(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "east" if direction.x > 0 else "west"
	return "south" if direction.y > 0 else "north"


func draw_over() -> void:
	if barking > 0.0:
		body.draw_string(ThemeDB.fallback_font, Vector2(-14, -48), "WOOF!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("f4d3a0"))
	if friendly > 0.0:
		PixelArt.draw_in(body, "heart_patch", Rect2(-5, -56, 10, 10))


func snapshot() -> Dictionary:
	return {"barking": barking, "friendly": friendly}


func restore(state: Dictionary) -> void:
	barking = state.get("barking", 0.0)
	friendly = state.get("friendly", 0.0)
