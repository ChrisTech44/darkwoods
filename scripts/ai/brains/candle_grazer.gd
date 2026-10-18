extends CreatureBrain
## The Snuffer: eats light. It ambles after the nearest survivor wrapped in a
## bubble of darkness: flashlights inside cut out, and flares die. Harmless
## itself, but everything else hunts better in the dark. Glow moss can't be
## snuffed (you keep a glow of your own).

const DARK := 140.0
var dark_radius := 0.0


func setup() -> void:
	display_name = "The Snuffer"
	tip = "It snuffs flashlights and flares around it. Glow moss keeps you lit; otherwise walk away from it."
	body.config.sight_radius = 260


func senses(_actor: CampPlayer) -> int:
	return 0


func fears_flare() -> bool:
	return false


func physics(delta: float) -> bool:
	dark_radius = DARK
	var nearest: CampPlayer
	for actor in survivors():
		var distance := body.global_position.distance_to(actor.global_position)
		if distance <= DARK and not actor.has_effect("glowing"):
			if actor.flashlight_on:
				actor.flashlight_on = false
				actor.flicker = 0.4
				announce("Your flashlight gutters out. Something is eating the light.", actor)
		if distance < 300.0 and (nearest == null or distance < body.global_position.distance_to(nearest.global_position)):
			nearest = actor
	for flare in body.get_tree().get_nodes_in_group("flares"):
		if body.global_position.distance_to(flare.global_position) <= DARK:
			flare.queue_free()
	if nearest != null and body.global_position.distance_to(nearest.global_position) > 50.0:
		body.steer(nearest.global_position, 34.0, delta)
	else:
		wander(26.0, delta)
	return true


func contact(_actor: CampPlayer) -> bool:
	return true


func draw_over() -> void:
	# A dark halo marks the bubble.
	body.draw_circle(Vector2(0, -10), DARK, Color(0, 0, 0, 0.18))
	body.draw_arc(Vector2(0, -10), DARK, 0, TAU, 48, Color(0.3, 0.25, 0.2, 0.25), 1.0)
