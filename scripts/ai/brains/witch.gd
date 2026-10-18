extends CreatureBrain
## The Witch: curses. She keeps her distance and, after a readable wind-up,
## fires a hex bolt on a fixed line. A hit lays a random curse: FROG (a hopping
## frog that can't carry parts or use items), BACKWARDS (inverted controls),
## SWAP (trade places with a random teammate) or FLOAT (drift like a balloon).
## A survivor under a salt ward bounces the curse back: she becomes the frog.

const CURSES: Array[String] = ["frog", "backwards", "swap", "float"]
var cast_cooldown := 1.5
var frogged := 0.0


func setup() -> void:
	display_name = "The Witch"
	tip = "Her bolt curses: frog, backwards, swap or float. Sidestep its line, or wear a salt ward to bounce it back."
	body.config.killer_chase_speed = 52
	body.config.sight_radius = 190
	body.config.hearing_radius = 210


func senses(_actor: CampPlayer) -> int:
	return 0 if frogged > 0.0 else -1


func physics(delta: float) -> bool:
	frogged = maxf(0.0, frogged - delta)
	if frogged > 0.0:
		# A frog for a while: hops about harmlessly.
		body.casting = false
		wander(18.0, delta)
		return true
	cast_cooldown = maxf(0.0, cast_cooldown - delta)
	var target := body.visible_target
	if not is_instance_valid(target) or target.status != CampPlayer.Status.ALIVE or body.nearby_flare() != Vector2.INF:
		body.casting = false
		body.cast_remaining = 0.0
		return false
	var distance := body.global_position.distance_to(target.global_position)
	if body.casting:
		body.cast_remaining -= delta
		body.velocity = Vector2.ZERO
		body.queue_redraw()
		if body.cast_remaining <= 0.0:
			body.casting = false
			cast_cooldown = 3.2
			if body.has_line_of_sight(body.cast_aim):
				var bolt := HexBolt.new()
				bolt.position = body.global_position
				bolt.direction = body.global_position.direction_to(body.cast_aim)
				bolt.source = body
				body.get_parent().add_child(bolt)
				cue("witch_cackle", 2.0)
		return true
	if distance >= 60.0 and distance <= 205.0 and cast_cooldown <= 0.0 and body.has_line_of_sight(target.global_position):
		body.casting = true
		body.spell_started.emit()
		body.cast_remaining = 0.8
		# The aim locks for the wind-up: no late homing.
		body.cast_aim = target.global_position + target.velocity * 0.2
		return true
	return false


func goal(actor: CampPlayer) -> Vector2:
	var distance := body.global_position.distance_to(actor.global_position)
	if distance < 85.0:
		return reachable(body.global_position + actor.global_position.direction_to(body.global_position) * 90.0)
	if distance < 175.0:
		return body.global_position
	return Vector2.INF


func contact(_actor: CampPlayer) -> bool:
	# She never claws; her magic does the work.
	return true


## `kind` picks a curse (tests); empty draws one at random.
func curse(actor: CampPlayer, kind: String = "") -> void:
	if actor.ward_remaining > 0.0:
		frogged = 10.0
		announce("Your salt ward bounces the curse back. THE WITCH IS A FROG!", actor)
		cue("witch_cackle", 2.0, 1.6)
		return
	if kind.is_empty():
		kind = CURSES[randi() % CURSES.size()]
	var world: Node = level()
	match kind:
		"frog":
			actor.add_effect("frog", 12.0)
			announce("CURSED: you're a FROG for 12 s. Frogs can't carry parts or use items.", actor)
			if world != null:
				for part: String in actor.inventory.duplicate():
					if part in world.plan.required or part in FieldEscapes.BOAT_PARTS or part in SignalFire.PARTS or part.begins_with("gate_code_") or part == "rescue_fuse":
						actor.inventory.erase(part)
						world.spawn_dropped(part, actor.global_position + Vector2(8, 6))
		"backwards":
			actor.add_effect("backwards", 10.0)
			announce("CURSED: your legs go BACKWARDS for 10 s!", actor)
		"swap":
			var others: Array[CampPlayer] = []
			for other in survivors():
				if other != actor:
					others.append(other)
			if others.is_empty():
				# Alone: she flings you somewhere else nearby instead.
				actor.global_position = reachable(actor.global_position + Vector2.from_angle(randf() * TAU) * 220.0)
				announce("CURSED: the woods spin and you're somewhere else!", actor)
			else:
				var partner: CampPlayer = others[randi() % others.size()]
				var here := actor.global_position
				actor.global_position = partner.global_position
				partner.global_position = here
				announce("CURSED: you SWAPPED PLACES with %s!" % (partner.peer_name if not partner.peer_name.is_empty() else "a teammate"))
		"float":
			actor.add_effect("float", 8.0)
			actor.effect_data["drift"] = Vector2.from_angle(randf() * TAU)
			announce("CURSED: you FLOAT like a balloon for 8 s!", actor)
	cue("witch_cackle", 4.0, 1.2)


func draw() -> bool:
	if frogged <= 0.0:
		return false
	var hop := absf(sin(Time.get_ticks_msec() * 0.008)) * 5.0
	if not PixelArt.draw_in(body, "frog", Rect2(-12, -24 - hop, 24, 24)):
		body.draw_circle(Vector2(0, -8 - hop), 9, Color("5f8f43"))
	# Her hat stays on.
	body.draw_colored_polygon(PackedVector2Array([Vector2(-7, -22 - hop), Vector2(7, -22 - hop), Vector2(0, -36 - hop)]), Color("3d2b4f"))
	return true


func snapshot() -> Dictionary:
	return {"frogged": frogged}


func restore(state: Dictionary) -> void:
	frogged = state.get("frogged", 0.0)
