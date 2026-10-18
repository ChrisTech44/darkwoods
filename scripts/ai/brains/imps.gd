extends CreatureBrain
## The Toadstool Imps: mischief. They scamper up giggling and tie your laces
## together: you trip (1.2 s) and drop what you were holding. Then they snatch
## it and hide it somewhere nearby, and tell you which way. A flash poofs them
## (they drop what they carried); bug spray keeps them away.

var loot := ""
var hide_at := Vector2.INF
var poofed := 0.0
var cooldown := 3.0
var giggle := 0.0


func setup() -> void:
	display_name = "The Toadstool Imps"
	tip = "They trip you and hide what you drop. A flash poofs them; bug spray keeps them off."
	body.config.killer_chase_speed = 82
	body.config.sight_radius = 180


func senses(actor: CampPlayer) -> int:
	return 0 if actor.has_effect("bug_spray") or poofed > 0.0 else -1


func fears_flare() -> bool:
	return false


func physics(delta: float) -> bool:
	poofed = maxf(0.0, poofed - delta)
	cooldown = maxf(0.0, cooldown - delta)
	giggle -= delta
	if poofed > 0.0:
		body.velocity = Vector2.ZERO
		return true
	for actor in survivors():
		if actor.has_effect("bug_spray") and body.global_position.distance_to(actor.global_position) < 110.0:
			flee_from(actor.global_position, 70.0, delta)
			return true
	if not loot.is_empty():
		if body.steer(hide_at, 90.0, delta):
			_hide()
		return true
	if body.state == CampKiller.State.CHASE and giggle <= 0.0:
		giggle = 3.0
		cue("giggle", -2.0, 1.05)
	if cooldown > 0.0:
		wander(46.0, delta)
		return true
	return false


func contact(actor: CampPlayer) -> bool:
	if cooldown > 0.0 or not loot.is_empty():
		return true
	cooldown = 12.0
	actor.add_effect("tripped", 1.2)
	cue("giggle", 3.0, 1.2)
	var kind := actor.held_item()
	if kind.is_empty() or actor.supplies.get(kind, 0) <= 0:
		announce("The imps tie your laces together. You go sprawling!", actor)
		return true
	actor.supplies[kind] -= 1
	actor.tidy_belt()
	loot = kind
	hide_at = reachable(body.global_position + Vector2.from_angle(randf() * TAU) * 320.0)
	announce("The imps trip you and run off with your %s!" % kind.replace("_", " ").to_upper(), actor)
	return true


func _hide() -> void:
	var world: Node = level()
	if world != null:
		world.spawn_dropped(loot, hide_at)
		var near: CampPlayer
		for actor in survivors():
			if near == null or actor.global_position.distance_to(hide_at) < near.global_position.distance_to(hide_at):
				near = actor
		if near != null:
			world.announce("Giggling from the %s: the imps hid your %s there." % [_compass(near.global_position.direction_to(hide_at)), loot.replace("_", " ")], near)
	loot = ""
	hide_at = Vector2.INF


static func _compass(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "east" if direction.x > 0 else "west"
	return "south" if direction.y > 0 else "north"


func on_stunned() -> void:
	var world: Node = level()
	if not loot.is_empty() and world != null:
		world.spawn_dropped(loot, body.global_position)
		world.announce("POOF! The imps vanish and drop the %s." % loot.replace("_", " "))
	loot = ""
	poofed = 25.0
	body.stun_remaining = 0.0
	if not body.patrol.is_empty():
		body.global_position = body.patrol[(body.patrol_index + body.patrol.size() / 2) % body.patrol.size()]


func draw() -> bool:
	if poofed > 0.0:
		if poofed > 24.0:
			body.draw_circle(Vector2(0, -12), 18.0 * (25.0 - poofed), Color(0.85, 0.82, 0.9, poofed - 24.0))
		return true
	body.draw_sheet()
	if not loot.is_empty():
		PixelArt.draw_in(body, loot, Rect2(-5, -50, 10, 10))
	return true


func snapshot() -> Dictionary:
	return {"loot": loot, "poofed": poofed}


func restore(state: Dictionary) -> void:
	loot = state.get("loot", "")
	poofed = state.get("poofed", 0.0)
