extends CreatureBrain
## The Werewolf: moon-bound. Most of the night it's a lost hiker, harmless and
## friendly. While the moon is out it transforms and rampages: pounces knock
## survivors flying and doors burst as it passes. Wolfsbane turns it back and
## sends it running for 90 s; so does the moon going behind the clouds.

const HIKER_SHEET := preload("res://assets/sprites/survivor_quartermaster.png")
const POUNCE := 35.0
var wolf := false
var bane := 0.0
var greeted := false


func setup() -> void:
	display_name = "The Werewolf"
	tip = "Harmless as a hiker. When the moon comes out, hide or throw wolfsbane; its pounce knocks you flying."
	body.config.killer_chase_speed = 104
	body.config.sight_radius = 170


func moon_out() -> bool:
	var world: Node = level()
	return world != null and world.night_clock != null and world.night_clock.moon


func senses(_actor: CampPlayer) -> int:
	return 1 if wolf else 0


func physics(delta: float) -> bool:
	bane = maxf(0.0, bane - delta)
	var should := moon_out() and bane <= 0.0
	if should != wolf:
		wolf = should
		if wolf:
			cue("werewolf_howl", 8.0)
			body.transition(CampKiller.State.PATROL)
		else:
			body.visible_target = null
			body.transition(CampKiller.State.PATROL)
	body.door_force = 40.0 if wolf else 1.0
	if wolf:
		return false
	# The hiker: ambles along, says hello, never hurts anyone.
	var near: CampPlayer
	for actor in survivors():
		if body.global_position.distance_to(actor.global_position) < 60.0:
			near = actor
	if near != null and not greeted:
		greeted = true
		announce("A lost hiker mutters: 'Don't let me see the moon tonight...'", near)
	wander(30.0, delta)
	return true


func contact(actor: CampPlayer) -> bool:
	if not wolf:
		return true
	if body.land_hit(actor, POUNCE):
		actor.shove(body.global_position.direction_to(actor.global_position) * 430.0)
		cue("werewolf_howl", 2.0, 1.3)
	return true


## Thrown wolfsbane: back to the hiker, and away from the thrower.
func repel(seconds: float) -> void:
	bane = seconds
	if wolf:
		wolf = false
		body.visible_target = null
		body.transition(CampKiller.State.PATROL)
		cue("werewolf_howl", 0.0, 0.7)


func draw() -> bool:
	if wolf:
		return false
	var row := 0
	if absf(body.facing.x) > absf(body.facing.y):
		row = 2 if body.facing.x > 0 else 3
	elif body.facing.y < 0:
		row = 1
	var frame := 0 if body.velocity.length() < 1 else 1 + int(body.stride / 6.0) % 2
	body.draw_circle(Vector2(0, 1), 7, Color(0, 0, 0, 0.35))
	body.draw_texture_rect_region(HIKER_SHEET, Rect2(-12, -29, 24, 32), Rect2(frame * 24, row * 32, 24, 32), Color(0.82, 0.78, 0.7))
	return true


func snapshot() -> Dictionary:
	return {"wolf": wolf}


func restore(state: Dictionary) -> void:
	wolf = state.get("wolf", false)
