extends Node
## Local asset registry/mixer. No microphone, networking or AI hearing decisions.

const BUSES: Array[String] = ["Master", "Effects", "Ambience", "Music", "Voice"]
const SETTINGS_PATH := "user://audio_settings.cfg"
var cues: Dictionary = {}
var streams: Dictionary = {}
var volumes: Dictionary = {"Master": 0.8, "Effects": 0.8, "Ambience": 0.65, "Music": 0.5, "Voice": 1.0}
var output_enabled: bool = false
## Temporary dB offsets per bus (voice ducking); never saved.
var duck: Dictionary = {}
var settings_path: String = SETTINGS_PATH


func _ready() -> void:
	output_enabled = DisplayServer.get_name() != "headless"
	if "--audio-test" in OS.get_cmdline_user_args():
		settings_path = "user://audio_test_settings.cfg"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/manifest.json"))
	if parsed is Dictionary:
		cues = parsed["cues"]
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	# The supplied fire has a ~43dB crest factor: raise detail after peak compression.
	AudioServer.add_bus()
	var fire_bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(fire_bus, "Campfire")
	AudioServer.set_bus_send(fire_bus, "Ambience")
	var compressor := AudioEffectCompressor.new()
	compressor.threshold = -42.0
	compressor.ratio = 6.0
	compressor.gain = 16.0
	compressor.attack_us = 100.0
	compressor.release_ms = 150.0
	AudioServer.add_bus_effect(fire_bus, compressor)
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiter)
	# Deafened by the Banshee: a muffling low-pass on everything except voice chat.
	for bus in ["Effects", "Ambience", "Music"]:
		var muffle := AudioEffectLowPassFilter.new()
		muffle.cutoff_hz = 450.0
		AudioServer.add_bus_effect(AudioServer.get_bus_index(bus), muffle)
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(bus), AudioServer.get_bus_effect_count(AudioServer.get_bus_index(bus)) - 1, false)
	var settings := ConfigFile.new()
	if settings.load(settings_path) == OK:
		for bus in BUSES:
			var stored: Variant = settings.get_value("volume", bus, volumes[bus])
			if stored is float or stored is int:
				volumes[bus] = clampf(float(stored), 0.0, 1.0)
	for bus in BUSES:
		set_volume(bus, volumes[bus], false)


func set_volume(bus: String, value: float, persist: bool = true) -> void:
	if bus not in BUSES:
		return
	value = clampf(value, 0.0, 1.0)
	volumes[bus] = value
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index, value <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)) + float(duck.get(bus, 0.0)))
	if persist:
		var settings := ConfigFile.new()
		for name in BUSES:
			settings.set_value("volume", name, volumes[name])
		settings.save(settings_path)


func set_duck(offsets: Dictionary) -> void:
	duck = offsets
	for bus in BUSES:
		var index := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volumes[bus], 0.0001)) + float(duck.get(bus, 0.0)))


var muffled := false


## Banshee deafness for this machine's player: muffle and quieten the round.
func set_muffled(on: bool) -> void:
	if on == muffled:
		return
	muffled = on
	for bus in ["Effects", "Ambience", "Music"]:
		var index := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_effect_enabled(index, AudioServer.get_bus_effect_count(index) - 1, on)
	var quiet := {"Effects": -14.0, "Ambience": -10.0, "Music": -10.0} if on else {}
	for bus in quiet:
		duck[bus] = quiet[bus]
	if not on:
		for bus in ["Effects", "Ambience", "Music"]:
			duck.erase(bus)
	set_duck(duck)


func stream_for(cue: String) -> AudioStream:
	if not cues.has(cue):
		return null
	if not streams.has(cue):
		var path: String = cues[cue]["path"]
		if not ResourceLoader.exists(path):
			return null
		var stream := load(path) as AudioStreamMP3
		if stream == null:
			return null
		# Duplicate the imported resource; looping never mutates shared defaults.
		stream = stream.duplicate() as AudioStreamMP3
		stream.loop = cues[cue]["loop"]
		streams[cue] = stream
	return streams[cue]


func prepare_shutdown() -> void:
	get_tree().call_group("menu_audio", "stop_playback")
	get_tree().call_group("round_audio", "stop_round")
	# Allow native audio-thread stop commands to drain before engine shutdown.
	var deadline := Time.get_ticks_msec() + 180
	while output_enabled and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
