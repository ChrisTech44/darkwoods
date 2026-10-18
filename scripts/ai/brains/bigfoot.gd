extends CreatureBrain
## Bigfoot: the shy yeeter. It never hunts. Walk up on it in the dark and it
## panics: it grabs you and throws you across the clearing (10 damage, and you
## may drop what you hold). Catch it in your light from a distance and it
## bolts, dropping a tuft of fur worth score (once a night).

const STARTLE := 40.0
const SPOTTED := 160.0
const THROW := 560.0
var fleeing := 0.0
var flee_from_point := Vector2.ZERO
var cooldown := 0.0
var fur_dropped := false
var throws := 0


func setup() -> void:
	display_name = "Bigfoot"
	tip = "Shy. Light it up from far away and it runs (and drops fur). Sneak up on it and it throws you."


func senses(_actor: CampPlayer) -> int:
	return 0


func physics(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	fleeing = maxf(0.0, fleeing - delta)
	if fleeing > 0.0:
		flee_from(flee_from_point, 96.0, delta)
		return true
	for actor in survivors():
		var distance := body.global_position.distance_to(actor.global_position)
		if not body.has_line_of_sight(actor.global_position):
			continue
		if distance > 100.0 and distance <= SPOTTED and in_beam(actor, body.global_position, SPOTTED, 0.9):
			_spooked(actor)
			return true
		if distance <= STARTLE and cooldown <= 0.0 and not in_beam(actor, body.global_position, STARTLE + 10.0, 0.6):
			_yeet(actor)
			return true
	wander(28.0, delta)
	return true


func _spooked(actor: CampPlayer) -> void:
	fleeing = 6.0
	flee_from_point = actor.global_position
	cue("bigfoot_growl", 2.0, 1.25)
	var world: Node = level()
	if not fur_dropped and world != null:
		fur_dropped = true
		world.spawn_dropped("bigfoot_fur", body.global_position)
		world.announce("Bigfoot bolts into the trees, leaving a tuft of fur behind!", actor)


func _yeet(actor: CampPlayer) -> void:
	cooldown = 8.0
	throws += 1
	var away := body.global_position.direction_to(actor.global_position)
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	away = away.rotated(randf_range(-0.5, 0.5))
	actor.invulnerability = 0.0
	actor.receive_hit(10.0)
	actor.shove(away * THROW)
	cue("bigfoot_growl", 6.0)
	var world: Node = level()
	if world != null:
		if randf() < 0.5 and not actor.held_item().is_empty():
			world.drop_held(actor)
		world.announce("BIGFOOT YEETS %s!" % (actor.peer_name.to_upper() if not actor.peer_name.is_empty() else "YOU"))
	fleeing = 3.0
	flee_from_point = actor.global_position
