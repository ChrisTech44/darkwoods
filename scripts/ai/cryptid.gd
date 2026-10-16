class_name CampCryptid
extends CampKiller

var species: String = "werewolf"
var hunt_clock: float = 0.0
var base_range: float = 100.0
var sheet: Texture2D


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
	else:
		config.sight_radius = 125
		config.hearing_radius = 210
	base_range = config.sight_radius


func _physics_process(delta: float) -> void:
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
	super._physics_process(delta)


func can_sense(actor: CampPlayer) -> bool:
	if actor.global_position.x < 1540:
		return false
	return species != "lantern_moth" or actor.flashlight_on or global_position.distance_to(actor.global_position) < 45


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
		draw_string(ThemeDB.fallback_font, Vector2(-18, -63), "HOWL!" if species == "werewolf" else "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("d9b581"))
