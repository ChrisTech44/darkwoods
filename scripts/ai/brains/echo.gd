extends CreatureBrain
## The Echo: a smoke-eared shadow that learned the stalker's tune. Every so
## often, near a survivor, it whistles the camp song from where it stands, so
## you hear "him" somewhere he isn't (and, on a bad night, miss where he is).
## It never attacks. Catch it in your flashlight up close and it bursts into
## smoke and re-forms somewhere far off.

const WHISTLE_EVERY := Vector2(9.0, 16.0)
const HEAR_REACH := 520.0
const POP_REACH := 110.0
var whistle_clock := 6.0
var whistles := 0
var heard := 0
var popped := 0.0
## Seconds of visible whistling (notes drift up while the tune plays).
var sing := 0.0
var song: AudioStreamPlayer2D


func setup() -> void:
	display_name = "The Echo"
	tip = "It whistles the stalker's camp song from the wrong place. It can't hurt you; put your light on it up close and it bursts."
	body.config.killer_patrol_speed = 36
	# Every peer has the same body, so the fake whistle plays locally on each.
	song = AudioStreamPlayer2D.new()
	song.stream = CampSong.tune()
	song.bus = "Effects"
	song.max_distance = 900.0
	song.attenuation = 1.2
	song.volume_db = -4.0
	body.add_child(song)


func physics(delta: float) -> bool:
	popped = maxf(0.0, popped - delta)
	sing = maxf(0.0, sing - delta)
	whistle_clock -= delta
	var near := false
	for actor in survivors():
		var distance := body.global_position.distance_to(actor.global_position)
		if distance <= HEAR_REACH:
			near = true
		if distance <= POP_REACH and in_beam(actor, body.global_position, POP_REACH):
			_pop(actor)
			return true
	if near and whistle_clock <= 0.0:
		whistle_clock = randf_range(WHISTLE_EVERY.x, WHISTLE_EVERY.y)
		whistles += 1
		sing = 3.0
		_play()
	wander(30.0, delta)
	return true


func _pop(actor: CampPlayer) -> void:
	popped = 1.0
	cue("wind", 2.0, 1.6)
	announce("The whistler bursts into smoke. It was never him.", actor)
	var world: Node = level()
	if world != null and not world.plan.woods.links.is_empty():
		var cells: Array = world.plan.woods.links.keys()
		for attempt in range(20):
			var cell: Vector2i = cells[randi() % cells.size()]
			var at: Vector2 = world.plan.woods.center(cell)
			if at.distance_to(actor.global_position) > 900.0 and not CampKiller.in_camp(at):
				body.global_position = at
				break


func _play() -> void:
	if song == null or not body.get_node("/root/AudioManager").output_enabled:
		return
	song.pitch_scale = 1.0
	song.play()


func contact(_actor: CampPlayer) -> bool:
	return true


func stunnable() -> bool:
	return false


func draw() -> bool:
	# A wavering shadow, hard to pin down.
	body.draw_sheet(Color(1, 1, 1, 0.55 + 0.25 * sin(Time.get_ticks_msec() * 0.006)))
	if sing > 0.0:
		# Notes drifting up from its tunnel mouth: the tune you thought was his.
		var t := Time.get_ticks_msec() * 0.001
		for index in range(3):
			var rise := fmod(t * 14.0 + index * 9.0, 26.0)
			var at := Vector2(6 + sin(t * 2.0 + index) * 6.0, -50.0 - rise)
			var tint := Color(0.85, 0.9, 1.0, (1.0 - rise / 26.0) * minf(1.0, sing))
			body.draw_circle(at, 1.6, tint)
			body.draw_line(at + Vector2(1.5, 0), at + Vector2(1.5, -6), tint, 1.0)
	return true


func snapshot() -> Dictionary:
	return {"whistles": whistles, "sing": sing}


func restore(state: Dictionary) -> void:
	whistles = state.get("whistles", 0)
	sing = state.get("sing", 0.0)
	# A client hears each fake whistle once, when the host's count rises.
	if whistles > heard:
		if heard > 0:
			_play()
		heard = whistles
