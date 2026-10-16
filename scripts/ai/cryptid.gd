class_name CampCryptid
extends CampKiller

signal spell_started

var species: String = "werewolf"
var hunt_clock: float = 0.0
var sheet: Texture2D
var cast_cooldown: float = 1.5
var cast_remaining: float = 0.0
var cast_aim := Vector2.ZERO
var casting: bool = false


func _ready() -> void:
	super._ready()
	sheet = load("res://assets/sprites/" + species + ".png")
	add_to_group("cryptids")
	config = config.duplicate() as CampConfig
	config.killer_patrol_speed = 32
	config.search_seconds = 8
	if species == "bigfoot":
		config.killer_chase_speed = 63
		config.hearing_radius = 300
		config.sight_radius = 95
	elif species == "lantern_moth":
		config.killer_chase_speed = 68
		config.hearing_radius = 80
		config.sight_radius = 220
		CampLights.lamp(self, Vector2(0, -44), 30, Color("eab779"), 0.8)
	elif species == "vampire":
		config.killer_chase_speed = 90
		config.sight_radius = 165
		config.hearing_radius = 190
	elif species == "witch":
		config.killer_chase_speed = 52
		config.sight_radius = 190
		config.hearing_radius = 210
	elif species == "briar_revenant":
		config.killer_chase_speed = 64
		config.sight_radius = 155
		config.hearing_radius = 160
	else:
		config.sight_radius = 125
		config.hearing_radius = 210


func _physics_process(delta: float) -> void:
	if species == "witch" and not enabled:
		super._physics_process(delta)
		return
	if enabled:
		hunt_clock += delta
		if species == "werewolf":
			# A visible wind-up, brief charge, then a slow recovery to let players juke.
			var cycle := fmod(hunt_clock, 3.6)
			config.killer_chase_speed = 116.0 if cycle > 0.6 and cycle < 1.5 else 48.0
		if species == "lantern_moth" and visible_target == null:
			for flare in get_tree().get_nodes_in_group("flares"):
				if global_position.distance_to(flare.global_position) < 220 and has_line_of_sight(flare.global_position):
					# This is sensed light, independent of the moth's shorter hearing.
					last_seen = flare.global_position
					transition(State.INVESTIGATE)
		if species == "vampire":
			var sensed := sense_visible_target()
			config.killer_chase_speed = 52 if is_instance_valid(sensed) and in_beam(sensed) else 90
	super._physics_process(delta)
	if species == "witch" and enabled:
		_advance_spell(delta)


func can_sense(actor: CampPlayer) -> bool:
	if actor.global_position.x < 1540:
		return false
	if species == "briar_revenant":
		return actor.velocity.length() > 10 or global_position.distance_to(actor.global_position) < 55
	return species != "lantern_moth" or actor.flashlight_on or global_position.distance_to(actor.global_position) < 45


func in_beam(actor: CampPlayer) -> bool:
	return actor.flashlight_on and global_position.distance_to(actor.global_position) < 145 and actor.facing.dot(actor.global_position.direction_to(global_position)) > 0.88


func pursuit_goal(actor: CampPlayer) -> Vector2:
	if species == "witch":
		var distance := global_position.distance_to(actor.global_position)
		if distance < 85:
			return NavigationServer2D.map_get_closest_point(agent.get_navigation_map(), global_position + actor.global_position.direction_to(global_position) * 90)
		if distance < 175:
			return global_position
	if species == "vampire" and in_beam(actor):
		# Circle the lit approach instead of blindly running into the beam.
		var flank := actor.global_position + actor.facing.orthogonal() * 54
		return NavigationServer2D.map_get_closest_point(agent.get_navigation_map(), flank)
	return super.pursuit_goal(actor)


func _advance_spell(delta: float) -> void:
	cast_cooldown = maxf(0, cast_cooldown - delta)
	if not is_instance_valid(visible_target) or nearby_flare() != Vector2.INF:
		casting = false
		cast_remaining = 0
		return
	var distance := global_position.distance_to(visible_target.global_position)
	if distance < 60 or distance > 205:
		casting = false
		return
	if not casting and cast_cooldown <= 0:
		casting = true
		spell_started.emit()
		cast_remaining = 0.8
		# Lock the aim during the readable wind-up. No late homing.
		cast_aim = visible_target.global_position + visible_target.velocity * 0.2
	if casting:
		cast_remaining -= delta
		velocity = Vector2.ZERO
		if cast_remaining <= 0:
			casting = false
			cast_cooldown = 3.2
			if has_line_of_sight(cast_aim):
				var bolt := HexBolt.new()
				bolt.position = global_position
				bolt.direction = global_position.direction_to(cast_aim)
				get_parent().add_child(bolt)
	queue_redraw()


func fears_flare() -> bool:
	return species != "lantern_moth"


func _draw() -> void:
	var row := 0
	if absf(facing.x) > absf(facing.y):
		row = 2 if facing.x > 0 else 3
	elif facing.y < 0:
		row = 1
	var frame := 0 if velocity.length() < 1 else 1 + int(stride / 10.0) % 2
	draw_texture_rect_region(sheet, Rect2(-32, -58, 64, 64), Rect2(frame * 64, row * 64, 64, 64))
	if state == State.CHASE:
		draw_string(ThemeDB.fallback_font, Vector2(-18, -63), "HEX!" if casting else ("HOWL!" if species == "werewolf" else "!"), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("d9b581"))
	if casting:
		draw_arc(Vector2(0, -20), 22, 0, TAU * (1 - cast_remaining / 0.8), 24, Color("c4aadf"), 2)
