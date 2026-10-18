extends CreatureBrain
## The Lullaby Saint: sings you to sleep. Within its hymn you grow DROWSY:
## slower, the screen dims. Stand still for two seconds and you fall ASLEEP for
## 6 s, snoring loudly enough for the woods to hear. Coffee keeps you awake;
## otherwise keep moving and get out of earshot.

const SONG := 170.0
const NOD_OFF := 2.0
var still: Dictionary = {}
var hymn := 0.0
var snore := 0.0


func setup() -> void:
	display_name = "The Lullaby Saint"
	tip = "Its hymn makes you drowsy; stand still and you fall asleep (snoring). Keep moving, or drink coffee."
	body.config.sight_radius = 220


func senses(_actor: CampPlayer) -> int:
	return 0


func physics(delta: float) -> bool:
	hymn -= delta
	snore -= delta
	var listening := false
	var world: Node = level()
	for actor in survivors():
		var id := actor.get_instance_id()
		if body.global_position.distance_to(actor.global_position) > SONG or actor.has_effect("coffee"):
			still.erase(id)
			continue
		listening = true
		actor.add_effect("drowsy", 0.4)
		if actor.has_effect("asleep"):
			continue
		if actor.velocity.length() < 1.0:
			still[id] = still.get(id, 0.0) + delta
			if still[id] >= NOD_OFF:
				still[id] = 0.0
				actor.add_effect("asleep", 6.0)
				announce("You nod off... (asleep for 6 s, and snoring)", actor)
		else:
			still[id] = 0.0
	for actor in survivors():
		if actor.has_effect("asleep") and snore <= 0.0 and world != null:
			snore = 1.5
			world.loud_noise(actor.global_position, 200)
	if listening and hymn <= 0.0:
		hymn = 6.0
		cue("bells", -6.0, 0.6)
	wander(20.0, delta)
	return true


func contact(_actor: CampPlayer) -> bool:
	return true


func draw_over() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for index in range(3):
		var at := Vector2(sin(t * 1.5 + index * 2.1) * 18.0, -60 - fmod(t * 10.0 + index * 9.0, 26.0))
		var tint := Color(0.9, 0.85, 0.65, 0.7)
		body.draw_circle(at, 1.8, tint)
		body.draw_line(at + Vector2(1.5, 0), at + Vector2(1.5, -6), tint, 1.0)
		body.draw_line(at + Vector2(1.5, -6), at + Vector2(4, -4.5), tint, 1.0)
