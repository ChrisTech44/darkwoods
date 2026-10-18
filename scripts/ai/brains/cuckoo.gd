extends CreatureBrain
## The Cuckoo: a clock-headed thing on spider legs that turns back time. When it
## sees you it calls CUCKOO three times (one per second, the bird pops out of
## its clock face). If you are still in its sight on the third call you are
## snapped back to where you stood 8 seconds ago, losing the ground you gained.
## Break line of sight before the third call, or flash it to stop the count.
## Harmless to touch.

const SIGHT := 230.0
const CALLS := 3
const CALL_EVERY := 1.0
const REWIND_SECONDS := 8.0
const SAMPLE_EVERY := 0.25
const COOLDOWN := 14.0
var history: Dictionary = {}
var sample_clock := 0.0
var calls := 0
var call_clock := 0.0
var victim: CampPlayer
var cooldown := 4.0
var bird := 0.0


func setup() -> void:
	display_name = "The Cuckoo"
	tip = "It calls CUCKOO three times when it sees you. Still in its sight on the third and you're thrown back 8 seconds. Break line of sight, or flash it."
	body.config.sight_radius = SIGHT
	body.config.killer_patrol_speed = 30


func physics(delta: float) -> bool:
	bird = maxf(0.0, bird - delta)
	cooldown = maxf(0.0, cooldown - delta)
	_record(delta)
	if is_instance_valid(victim):
		body.velocity = Vector2.ZERO
		body.facing = body.global_position.direction_to(victim.global_position)
		if not _sees(victim):
			_reset()
			announce("The ticking fades. It lost sight of you.", victim)
			return true
		call_clock -= delta
		if call_clock <= 0.0:
			calls += 1
			call_clock = CALL_EVERY
			bird = 0.4
			cue("squeak", 6.0, 1.5 if calls % 2 == 1 else 1.2)
			if calls >= CALLS:
				_rewind(victim)
				_reset()
				cooldown = COOLDOWN
			else:
				announce("CUCKOO! (%d of %d) Get out of its sight!" % [calls, CALLS], victim)
		body.queue_redraw()
		return true
	if cooldown <= 0.0:
		var seen := nearest_seen(SIGHT)
		if seen != null:
			victim = seen
			calls = 0
			call_clock = 0.15
			return true
	wander(30.0, delta)
	return true


func _sees(actor: CampPlayer) -> bool:
	return actor.status == CampPlayer.Status.ALIVE and actor.hidden_spot < 0 and body.global_position.distance_to(actor.global_position) <= SIGHT * 1.15 and body.has_line_of_sight(actor.global_position)


## Where each survivor stood over the last REWIND_SECONDS.
func _record(delta: float) -> void:
	sample_clock -= delta
	if sample_clock > 0.0:
		return
	sample_clock = SAMPLE_EVERY
	for actor in survivors():
		var trail: Array = history.get(actor.get_instance_id(), [])
		trail.append(actor.global_position)
		while trail.size() > int(REWIND_SECONDS / SAMPLE_EVERY):
			trail.pop_front()
		history[actor.get_instance_id()] = trail


func _rewind(actor: CampPlayer) -> void:
	var trail: Array = history.get(actor.get_instance_id(), [])
	if trail.is_empty():
		return
	var back: Vector2 = trail[0]
	actor.global_position = reachable(back)
	actor.velocity = Vector2.ZERO
	actor.add_effect("rewound", 0.6)
	actor.add_effect("whiteout", 0.35)
	history[actor.get_instance_id()] = []
	cue("bells", 0.0, 1.8)
	announce("CUCKOO! Time lurches back eight seconds. You're where you were.", actor)


func _reset() -> void:
	victim = null
	calls = 0


func on_stunned() -> void:
	_reset()
	cooldown = COOLDOWN * 0.5


func contact(_actor: CampPlayer) -> bool:
	return true


func draw_over() -> void:
	if calls > 0 or bird > 0.0:
		# The little bird pops out of the clock face, and the count above it.
		var at := Vector2(0, -50)
		body.draw_circle(at + Vector2(0, -2) * (1.0 if bird > 0.0 else 0.0), 3.0, Color("e8c070"))
		for index in range(CALLS):
			body.draw_circle(Vector2(-6 + index * 6, -66), 2.0, Color("f0dca3") if index < calls else Color(0.3, 0.3, 0.3, 0.8))


func snapshot() -> Dictionary:
	return {"calls": calls, "bird": bird}


func restore(state: Dictionary) -> void:
	calls = state.get("calls", 0)
	bird = state.get("bird", 0.0)
