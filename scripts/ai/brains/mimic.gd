extends CreatureBrain
## The Mimic: pretends to be a teammate. It wears a survivor's look and a
## teammate's name, waves, and calls out: with voice chat on it replays that
## teammate's recent words from where it stands. Up close it reveals itself and
## grabs (25 damage, a 1.5 s stumble), then hunts for a while before slipping
## back into a new disguise. Tells: no flashlight, and it isn't on the map.

const REVEAL_RANGE := 34.0
const CALL_EVERY := 11.0
var role := "christian"
var mask_name := ""
var mask_peer := 0
var revealed := 0.0
var call_clock := 4.0
var bubble := 0.0
## Bumped on every voice call so clients replay it too.
var talk_id := 0
var heard_talk := 0
var sheets: Dictionary = {}
## Teammates join after creatures spawn, so the first disguise is picked on
## the first host frame.
var masked := false


func setup() -> void:
	display_name = "The Mimic"
	tip = "It looks and sounds like a teammate. Real teammates carry a flashlight and show on the map; it doesn't."
	body.config.killer_chase_speed = 84
	body.config.sight_radius = 260
	_disguise()


func _disguise() -> void:
	var others: Array[CampPlayer] = []
	for actor: CampPlayer in body.get_tree().get_nodes_in_group("survivors"):
		others.append(actor)
	var net: Node = body.get_node_or_null("/root/Net")
	if others.size() > 1 and net != null and net.active:
		var actor: CampPlayer = others[randi() % others.size()]
		role = actor.role
		mask_name = actor.peer_name
		mask_peer = 0
		for id: int in net.actors:
			if net.actors[id] == actor:
				mask_peer = id
	else:
		role = SurvivorRoster.IDS[randi() % SurvivorRoster.IDS.size()]
		mask_name = ""
		mask_peer = 0


func physics(delta: float) -> bool:
	if not masked:
		masked = true
		_disguise()
	bubble = maxf(0.0, bubble - delta)
	if revealed > 0.0:
		revealed -= delta
		if revealed <= 0.0:
			_disguise()
			body.visible_target = null
			body.transition(CampKiller.State.PATROL)
		return false
	# Disguised: amble toward the nearest survivor like a friend would.
	var friend := nearest_seen(260.0)
	if friend == null:
		wander(40.0, delta)
		return true
	call_clock -= delta
	if call_clock <= 0.0:
		call_clock = CALL_EVERY
		_call_out()
	if body.global_position.distance_to(friend.global_position) <= REVEAL_RANGE:
		_reveal(friend)
		return true
	# Navigation can call it "arrived" a step short; close the last few px directly.
	if body.steer(friend.global_position, 40.0, delta) and body.has_line_of_sight(friend.global_position):
		body.velocity = body.global_position.direction_to(friend.global_position) * body.motion_speed(40.0)
		body.move_and_slide()
	return true


func _call_out() -> void:
	talk_id += 1
	bubble = 2.5
	_play_voice()


func _play_voice() -> void:
	heard_talk = talk_id
	var voice: Node = body.get_node_or_null("/root/Voice")
	if voice != null and mask_peer != 0 and voice.has_method("replay"):
		voice.replay(mask_peer, body.global_position)


func _reveal(victim: CampPlayer) -> void:
	revealed = 20.0
	bubble = 0.0
	cue("screech_4", 6.0, 0.8)
	victim.invulnerability = 0.0
	if body.land_hit(victim, 25.0):
		victim.add_effect("tripped", 1.5)
	announce("THAT WASN'T YOUR TEAMMATE! The Mimic shows its face.", victim)
	body.visible_target = victim
	body.transition(CampKiller.State.CHASE)


func on_stunned() -> void:
	if revealed <= 0.0:
		revealed = 20.0
		announce("Your flash shows the Mimic for what it is!")


func contact(actor: CampPlayer) -> bool:
	if revealed <= 0.0:
		_reveal(actor)
		return true
	return false


func _sheet() -> Texture2D:
	if not sheets.has(role):
		sheets[role] = load("res://assets/sprites/survivor_%s.png" % SurvivorRoster.art(role))
	return sheets[role]


func draw() -> bool:
	var row := 0
	if absf(body.facing.x) > absf(body.facing.y):
		row = 2 if body.facing.x > 0 else 3
	elif body.facing.y < 0:
		row = 1
	var moving := body.velocity.length() > 1.0
	var frame := 0 if not moving else 1 + int(body.stride / 6.0) % 2
	# Waving: it bobs a hand while it calls.
	if bubble > 0.0 and not moving:
		frame = 1 + int(Time.get_ticks_msec() / 250) % 2
	var shown := mask_name if not mask_name.is_empty() else "???"
	body.draw_string(ThemeDB.fallback_font, Vector2(-ThemeDB.fallback_font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x * 0.5, -34), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("b9d4b2"))
	body.draw_circle(Vector2(0, 1), 7, Color(0, 0, 0, 0.35))
	var tint := Color.WHITE
	if revealed > 0.0:
		tint = Color(0.55, 0.45, 0.5)
	body.draw_texture_rect_region(_sheet(), Rect2(-12, -29, 24, 32), Rect2(frame * 24, row * 32, 24, 32), tint)
	if revealed > 0.0:
		body.draw_circle(Vector2(-3, -21), 1.4, Color(1, 0.15, 0.15))
		body.draw_circle(Vector2(3, -21), 1.4, Color(1, 0.15, 0.15))
		# Too many teeth.
		body.draw_line(Vector2(-5, -15), Vector2(5, -15), Color(0.95, 0.9, 0.85), 2.0)
	if bubble > 0.0:
		var text := "HEY! OVER HERE!"
		var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		body.draw_rect(Rect2(-width * 0.5 - 3, -54, width + 6, 11), Color(0.95, 0.93, 0.85, 0.9))
		body.draw_string(ThemeDB.fallback_font, Vector2(-width * 0.5, -45), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("2a2216"))
	return true


func snapshot() -> Dictionary:
	return {"role": role, "name": mask_name, "peer": mask_peer, "revealed": revealed, "bubble": bubble, "talk": talk_id}


func restore(state: Dictionary) -> void:
	role = state.get("role", role)
	mask_name = state.get("name", mask_name)
	mask_peer = state.get("peer", mask_peer)
	revealed = state.get("revealed", 0.0)
	bubble = state.get("bubble", 0.0)
	talk_id = state.get("talk", talk_id)
	if talk_id != heard_talk:
		_play_voice()
