class_name CampSong
extends AudioStreamPlayer2D
## The stalker whistles the camp song ("Row, Row, Row Your Boat", traditional,
## public domain): you hear where he is, and the tune comes faster and higher
## when he's hunting. A frenzy turns it into a scream. Synthesised once in code
## (a real recording is on the audio wish list). Runs on every peer from the
## killer's synced state, so everyone hears the same thing.

const RATE := 22050
## [note (semitones above C5), seconds]
const MELODY := [[0, 0.42], [0, 0.42], [0, 0.3], [2, 0.12], [4, 0.42], [4, 0.3], [2, 0.12], [4, 0.3], [5, 0.12], [7, 0.9]]
static var _tune: AudioStreamWAV
var clock := 6.0


func _ready() -> void:
	stream = tune()
	bus = "Effects"
	max_distance = 1100.0
	attenuation = 1.2
	volume_db = -3.0


static func tune() -> AudioStreamWAV:
	if _tune != null:
		return _tune
	var data := PackedByteArray()
	var phase := 0.0
	var noise := RandomNumberGenerator.new()
	noise.seed = 77
	for note: Array in MELODY:
		var frequency := 523.25 * pow(2.0, note[0] / 12.0)
		var count := int(note[1] * RATE)
		for index in range(count):
			var t := float(index) / RATE
			var vibrato := 1.0 + 0.008 * sin(TAU * 5.5 * t)
			phase += TAU * frequency * vibrato / RATE
			# A breathy attack and a soft release on each note.
			var envelope := minf(1.0, t / 0.04) * minf(1.0, (note[1] - t) / 0.06)
			var sample := (sin(phase) * 0.8 + noise.randf_range(-0.06, 0.06)) * envelope * 0.55
			var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
			data.append(value & 0xFF)
			data.append((value >> 8) & 0xFF)
		for gap in range(int(0.03 * RATE)):
			data.append(0)
			data.append(0)
	_tune = AudioStreamWAV.new()
	_tune.format = AudioStreamWAV.FORMAT_16_BITS
	_tune.mix_rate = RATE
	_tune.stereo = false
	_tune.data = data
	return _tune


func _process(delta: float) -> void:
	var killer: CampKiller = get_parent()
	if killer == null or not killer.enabled or killer.faded or killer.stun_remaining > 0.0:
		return
	clock -= delta
	if clock > 0.0:
		return
	var hunting := killer.state == CampKiller.State.CHASE
	clock = 7.0 if hunting else (11.0 if killer.state != CampKiller.State.PATROL else 17.0)
	if killer.frenzy > 0.0:
		var level: Node = get_tree().get_first_node_in_group("round_world")
		if level != null and level.soundscape != null:
			level.soundscape.play_cue("screech_3", killer.global_position, 4.0, 0.7)
		return
	pitch_scale = 1.15 if hunting else 1.0
	play()
