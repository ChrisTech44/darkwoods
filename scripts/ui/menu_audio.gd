extends Node
## Menu-owned loops continue while browsing controls and stop on scene departure.
var mixer: Node
var channels: Array[AudioStreamPlayer] = []
var fade := 0.0

func _ready() -> void:
	add_to_group("menu_audio")
	mixer = get_node("/root/AudioManager")
	for cue in ["music", "woods"]:
		var player := AudioStreamPlayer.new()
		player.name = cue
		player.stream = mixer.stream_for(cue)
		player.bus = mixer.cues[cue]["bus"]
		player.volume_db = -80
		add_child(player)
		channels.append(player)

func _process(delta: float) -> void:
	fade = move_toward(fade, 1.0, delta * 0.7)
	for player in channels:
		var cue := String(player.name)
		player.volume_db = float(mixer.cues[cue]["gain_db"]) + linear_to_db(maxf(fade, 0.0001)) - (6.0 if cue == "woods" else 0.0)
		if mixer.output_enabled and player.stream != null and not player.playing:
			player.play()

func stop_playback() -> void:
	for player in channels:
		player.stop()
		player.stream = null
	channels.clear()
	set_process(false)

func _exit_tree() -> void:
	stop_playback()
