extends CreatureBrain
## The Hitchhiker: a ghost child that wants a ride. It wanders the trails with
## its arms up; touch it (or let it reach you) and it climbs on your back. You
## walk at two-thirds speed, can't sprint, and every so often it giggles and
## switches your flashlight off. It won't let go on its own for 45 s, but it
## jumps to any teammate you walk into ("TAG!"): pass it on, then run.

const RIDE_SECONDS := 45.0
const LIGHT_PRANK_EVERY := Vector2(7.0, 12.0)
const TAG_REACH := 16.0
var rider_of: CampPlayer
var ride_clock := 0.0
var prank_clock := 8.0
var tag_lock := 0.0
var rest := 0.0
var layer := 1


func setup() -> void:
	display_name = "The Hitchhiker"
	tip = "It rides on your back: slow, no sprint, and it keeps switching your light off. Walk into a teammate to pass it on (TAG!), or wait 45 s."
	body.config.killer_chase_speed = 58
	body.config.killer_patrol_speed = 28
	body.config.sight_radius = 170


func physics(delta: float) -> bool:
	rest = maxf(0.0, rest - delta)
	tag_lock = maxf(0.0, tag_lock - delta)
	if is_instance_valid(rider_of):
		_ride(delta)
		return true
	rider_of = null
	if rest > 0.0:
		wander(24.0, delta)
		return true
	return false


func _ride(delta: float) -> void:
	var carrier := rider_of
	if carrier.status != CampPlayer.Status.ALIVE:
		_hop_off(carrier)
		return
	body.global_position = carrier.global_position + Vector2(0, 1)
	body.facing = carrier.facing
	body.velocity = Vector2.ZERO
	carrier.add_effect("piggyback", 0.5)
	ride_clock -= delta
	prank_clock -= delta
	if prank_clock <= 0.0:
		prank_clock = randf_range(LIGHT_PRANK_EVERY.x, LIGHT_PRANK_EVERY.y)
		if carrier.flashlight_on:
			carrier.flashlight_on = false
			cue("giggle", 0.0, 0.75)
			announce("A tiny hand flicks your flashlight off. Giggling.", carrier)
	if tag_lock <= 0.0:
		for other in survivors():
			if other != carrier and other.global_position.distance_to(carrier.global_position) <= TAG_REACH:
				carrier.clear_effect("piggyback")
				announce("TAG! The Hitchhiker jumps to your teammate.", carrier)
				announce("TAG, YOU'RE IT! Something climbs onto your back.", other)
				_climb(other)
				return
	if ride_clock <= 0.0:
		_hop_off(carrier)
		announce("The Hitchhiker gets bored and slides off your back.", carrier)


func _climb(actor: CampPlayer) -> void:
	if not is_instance_valid(rider_of):
		# Riding: no body of its own to bump into (restored when it hops off).
		layer = body.collision_layer
		body.collision_layer = 0
	rider_of = actor
	ride_clock = RIDE_SECONDS
	prank_clock = randf_range(3.0, 6.0)
	tag_lock = 1.5
	actor.add_effect("piggyback", 0.5)
	cue("giggle", 2.0, 0.7)


func _hop_off(actor: CampPlayer) -> void:
	if is_instance_valid(actor):
		actor.clear_effect("piggyback")
	rider_of = null
	rest = 20.0
	body.collision_layer = layer


func contact(actor: CampPlayer) -> bool:
	if rest <= 0.0 and not is_instance_valid(rider_of) and not actor.has_effect("piggyback"):
		_climb(actor)
		announce("Something small climbs onto your back. It wants a ride. (TAG a teammate to pass it on.)", actor)
	return true


func fears_flare() -> bool:
	return not is_instance_valid(rider_of)


func stunnable() -> bool:
	return not is_instance_valid(rider_of)


func draw() -> bool:
	if is_instance_valid(rider_of) or riding_drawn:
		# Perched on the carrier's shoulders.
		body.draw_sheet(Color(1, 1, 1, 0.85), 18.0)
		return true
	body.draw_sheet(Color(1, 1, 1, 0.8))
	return true


var riding_drawn := false


func snapshot() -> Dictionary:
	return {"riding": is_instance_valid(rider_of)}


func restore(state: Dictionary) -> void:
	riding_drawn = state.get("riding", false)
