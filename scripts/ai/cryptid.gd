class_name CampCryptid
extends CampKiller

signal spell_started

var home := Rect2()
var power_clock := 0.0
var power_aim := Vector2.ZERO
var power_tell := 0.0
var dash_remaining := 0.0
var dash_direction := Vector2.ZERO
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
	elif species in ["boiler_saint", "bramble_seamstress", "shutter_wraith", "last_car_conductor", "stoneback_ram", "candle_grazer", "switchback_hound", "relay_jackal", "ration_moth", "lens_eater"]:
		config.sight_radius = 190
		config.hearing_radius = 320 if species == "switchback_hound" else 220
		config.killer_chase_speed = 62
		config.attack_radius = 12
		config.search_seconds = 12 if species in ["switchback_hound","relay_jackal"] else 6
		if species == "ration_moth": config.sight_radius = 70
	else:
		config.sight_radius = 125
		config.hearing_radius = 210


func _physics_process(delta: float) -> void:
	if species == "witch" and not enabled:
		super._physics_process(delta)
		return
	if enabled and tick_stun(delta):
		dash_remaining = 0
		power_tell = 0
		casting = false
		return
	if enabled:
		if nearby_flare() != Vector2.INF:
			dash_remaining = 0
			power_tell = 0
		if home.has_area() and not home.has_point(global_position + dash_direction * 10):
			dash_remaining = 0
		if camp_closed and dash_remaining > 0 and in_camp(global_position + dash_direction * 14):
			dash_remaining = 0
		if dash_remaining > 0:
			dash_remaining -= delta
			velocity = dash_direction * 150
			move_and_slide()
			# Charge follows the locked visible lane, collides with ordinary walls.
			for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
				if actor.status == CampPlayer.Status.ALIVE and actor.hidden_spot < 0 and global_position.distance_to(actor.global_position) < 14 and has_line_of_sight(actor.global_position):
					# A telegraphed charge hits at least as hard as a swipe.
					land_hit(actor, maxf(hit_damage, 40.0))
					dash_remaining = 0
			queue_redraw()
			return
		_advance_power(delta)
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
		if species == "shutter_wraith":
			var observer := sense_visible_target()
			config.killer_chase_speed = 0 if is_instance_valid(observer) and in_beam(observer) else 74
		if species == "candle_grazer":
			for flare in get_tree().get_nodes_in_group("flares"):
				if global_position.distance_to(flare.global_position) < 180 and has_line_of_sight(flare.global_position):
					last_seen = flare.global_position
					transition(State.INVESTIGATE)
					if global_position.distance_to(flare.global_position) < 22:
						flare.queue_free()
		if species == "vampire":
			var sensed := sense_visible_target()
			config.killer_chase_speed = 52 if is_instance_valid(sensed) and in_beam(sensed) else 90
	super._physics_process(delta)
	if species == "witch" and enabled:
		_advance_spell(delta)


func threat_key() -> String:
	return species


func can_sense(actor: CampPlayer) -> bool:
	if home.has_area() and not home.has_point(actor.global_position):
		return false
	if species == "briar_revenant":
		return actor.velocity.length() > 10 or global_position.distance_to(actor.global_position) < 55
	return species not in ["lantern_moth", "candle_grazer"] or actor.flashlight_on or global_position.distance_to(actor.global_position) < 45


func in_beam(actor: CampPlayer) -> bool:
	return actor.flashlight_on and global_position.distance_to(actor.global_position) < 145 and actor.facing.dot(actor.global_position.direction_to(global_position)) > 0.88


func pursuit_goal(actor: CampPlayer) -> Vector2:
	if species == "relay_jackal":
		var flank := actor.global_position + actor.velocity.limit_length(1) * 50 + actor.facing.orthogonal() * 25
		return flank if has_line_of_sight(flank) else actor.global_position
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
	if not is_instance_valid(visible_target) or visible_target.status != CampPlayer.Status.ALIVE or nearby_flare() != Vector2.INF:
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
	return species not in ["lantern_moth", "candle_grazer"]


func is_class_cryptid() -> bool:
	return true


func _draw() -> void:
	_draw_power()
	var row := 0
	if absf(facing.x) > absf(facing.y):
		row = 2 if facing.x > 0 else 3
	elif facing.y < 0:
		row = 1
	var frame := 0 if velocity.length() < 1 else 1 + int(stride / 10.0) % 2
	# SpriteCook creature art (64x64 frames); the old procedural overlays are gone.
	draw_texture_rect_region(sheet, Rect2(-32, -58, 64, 64), Rect2(frame * 64, row * 64, 64, 64))
	if casting:
		draw_arc(Vector2(0, -20), 22, 0, TAU * (1 - cast_remaining / 0.8), 24, Color("c4aadf"), 2)
	draw_stun(-66)


func constrain_destination(point: Vector2) -> Vector2:
	if not home.has_area():
		return point
	if not home.has_point(global_position):
		transition(State.PATROL)
	return point.clamp(home.position + Vector2.ONE * 16, home.end - Vector2.ONE * 16)

func hear_stimulus(origin: Vector2, radius: float) -> void:
	if home.has_area() and not home.has_point(origin):
		return
	super.hear_stimulus(origin, radius)

func _advance_power(delta: float) -> void:
	power_clock = maxf(0, power_clock - delta)
	if power_tell > 0:
		power_tell -= delta
		if power_tell <= 0:
			if species == "lens_eater":
				if is_instance_valid(visible_target) and has_line_of_sight(visible_target.global_position) and in_beam(visible_target):
					visible_target.flashlight_charge=maxf(0,visible_target.flashlight_charge-8)
				return
			if species in ["switchback_hound", "stoneback_ram"]:
				dash_direction = global_position.direction_to(power_aim)
				dash_remaining = 0.55
			else:
				var hazard := LandmarkHazard.new()
				hazard.position = power_aim
				hazard.source = self
				hazard.thorns = species == "bramble_seamstress"
				get_parent().add_child(hazard)
		return
	if power_clock > 0 or not is_instance_valid(visible_target):
		return
	if species not in ["switchback_hound", "stoneback_ram", "boiler_saint", "bramble_seamstress", "last_car_conductor", "lens_eater"]:
		return
	if not has_line_of_sight(visible_target.global_position):
		return
	power_clock = 6.5
	power_aim = visible_target.global_position
	power_tell = 1.2

func _draw_power() -> void:
	if power_tell > 0:
		var at := to_local(power_aim)
		draw_arc(at, 23, 0, TAU, 24, Color("f1c27d"), 2)
		draw_line(Vector2.ZERO, at, Color("b99a72"), 1)
		draw_string(ThemeDB.fallback_font, Vector2(-28,-72), "CHARGE" if species in ["switchback_hound","stoneback_ram"] else "DANGER", HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("f4d3a0"))
