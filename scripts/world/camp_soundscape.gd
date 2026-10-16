class_name CampSoundscape
extends Node
## Round-owned playback. All loops/voices are freed with the round.

const MAX_VOICES := 12
const CREATURE_CUES := {"werewolf": "werewolf_howl", "bigfoot": "bigfoot_growl", "lantern_moth": "lantern_moth_screech", "witch": "witch_cackle", "briar_revenant": "revenant_screech", "vampire": "vampire_snarl"}
var level: Node2D
var mixer: Node
var loops: Dictionary = {}
var gains: Dictionary = {}
var voices: Array[AudioStreamPlayer2D] = []
var enemy_steps: Dictionary = {}
var call_timers: Dictionary = {}
var last_position := Vector2.ZERO
var step_distance := 0.0
var threat_gain := 0.0
var rng := RandomNumberGenerator.new()
var played_counts: Dictionary = {}
var last_step_cue := ""


func _ready() -> void:
	add_to_group("round_audio")
	mixer = get_node("/root/AudioManager")
	rng.seed = level.plan.seed_value + 9051
	last_position = level.player.global_position
	var listener := AudioListener2D.new()
	level.player.add_child(listener)
	listener.make_current()
	for cue in ["woods", "swamp", "music", "heartbeat", "running_grass", "walking_indoor", "campfire"]:
		var node: Node
		if cue == "campfire":
			node = AudioStreamPlayer2D.new()
			node.position = Vector2(168, 336)
			node.max_distance = 270
			node.attenuation = 1.5
		else:
			node = AudioStreamPlayer.new()
		node.stream = mixer.stream_for(cue)
		node.bus = mixer.cues[cue]["bus"]
		node.volume_db = -80
		add_child(node)
		loops[cue] = node
		gains[cue] = 0.0
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		_track_enemy(enemy)


func _track_enemy(enemy: CampKiller) -> void:
	enemy.state_changed.connect(_enemy_state.bind(enemy))
	if enemy is CampCryptid:
		enemy.spell_started.connect(_spell_started.bind(enemy))
	enemy_steps[enemy.get_instance_id()] = {"position": enemy.global_position, "distance": 0.0}
	call_timers[enemy.get_instance_id()] = 0.0



func _physics_process(delta: float) -> void:
	var actor: CampPlayer = level.player
	var suspended: bool = level.paused or level.finished
	for node in loops.values():
		node.stream_paused = suspended
	for voice in voices:
		voice.stream_paused = suspended
	if suspended:
		last_position = actor.global_position
		return
	var alive := actor.status == CampPlayer.Status.ALIVE
	var indoor := _indoors(actor.global_position)
	var distance := last_position.distance_to(actor.global_position)
	last_position = actor.global_position
	# Teleports/fixtures never produce a burst of hundreds of footsteps.
	var moving := alive and distance > 0.05 and distance < 8.0
	var bog := level.plan.woods.zones[1]["bounds"] as Rect2
	var swamp_weight := clampf(1.0 - actor.global_position.distance_to(bog.get_center()) / (bog.size.x * 0.5 + 150.0), 0.0, 1.0)
	var spotted := false
	var active_ids := {}
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		var id := enemy.get_instance_id()
		active_ids[id] = true
		if not enemy_steps.has(id):
			_track_enemy(enemy)
		if enemy.enabled and enemy.state == CampKiller.State.CHASE and enemy.visible_target == actor:
			spotted = true
		call_timers[id] = maxf(0.0, call_timers[id] - delta)
		var data: Dictionary = enemy_steps[id]
		var travel := enemy.global_position.distance_to(data["position"])
		data["position"] = enemy.global_position
		if enemy.enabled and travel > 0.05 and travel < 8.0:
			data["distance"] += travel
			if data["distance"] >= 24.0:
				data["distance"] = 0.0
				play_cue("footstep", enemy.global_position, -12.0, 0.72)
		if enemy is CampCryptid and enemy.enabled and call_timers[id] <= 0 and enemy.global_position.distance_to(actor.global_position) < 310:
			_creature_call(enemy)
	for id in enemy_steps.keys():
		if not active_ids.has(id):
			enemy_steps.erase(id)
			call_timers.erase(id)
	threat_gain = move_toward(threat_gain, 1.0 if spotted and alive else 0.0, delta * (0.9 if spotted else 0.28))
	_mix_loop("heartbeat", threat_gain, delta)
	loops["heartbeat"].pitch_scale = lerpf(0.94, 1.12, threat_gain)
	_mix_loop("woods", (1.0 - swamp_weight * 0.85) * (0.4 if indoor else 1.0), delta)
	_mix_loop("swamp", swamp_weight * (0.4 if indoor else 1.0), delta)
	_mix_loop("campfire", 1.0, delta)
	_mix_loop("music", 1.0 - threat_gain * 0.35, delta)
	_mix_loop("running_grass", 1.0 if moving and actor.sprinting and not indoor else 0.0, delta, 10.0)
	_mix_loop("walking_indoor", 1.0 if moving and indoor else 0.0, delta, 10.0)
	loops["walking_indoor"].pitch_scale = 1.35 if actor.sprinting else 1.0
	last_step_cue = "walking_indoor" if moving and indoor else ("running_grass" if moving and actor.sprinting else ("footstep" if moving else ""))
	if moving and not indoor and not actor.sprinting:
		step_distance += distance
		if step_distance >= 24.0:
			step_distance = fmod(step_distance, 24.0)
			play_cue("footstep", actor.global_position, 0.0, rng.randf_range(0.94, 1.06))
	else:
		step_distance = 0.0


func _indoors(point: Vector2) -> bool:
	for building in level.camp_map.buildings + level.camp_map.forest_buildings:
		if building.bounds.has_point(point):
			return true
	return false


func _mix_loop(cue: String, target: float, delta: float, speed: float = 0.8) -> void:
	var node: Node = loops[cue]
	gains[cue] = move_toward(gains[cue], target, delta * speed)
	if gains[cue] <= 0.001:
		node.stop()
		return
	node.volume_db = float(mixer.cues[cue]["gain_db"]) + linear_to_db(gains[cue])
	if mixer.output_enabled and node.stream != null and not node.playing:
		node.play()


func _enemy_state(next: CampKiller.State, enemy: CampKiller) -> void:
	if next == CampKiller.State.CHASE and enemy is CampCryptid:
		_creature_call(enemy)


func _spell_started(enemy: CampCryptid) -> void:
	_creature_call(enemy)


func _creature_call(enemy: CampCryptid) -> void:
	var id := enemy.get_instance_id()
	if call_timers.get(id, 0.0) > 0:
		return
	if play_cue(CREATURE_CUES[enemy.species], enemy.global_position):
		call_timers[id] = rng.randf_range(8.0, 14.0)


func play_cue(cue: String, origin: Vector2, gain_db: float = 0.0, pitch: float = 1.0) -> bool:
	if level.paused or level.finished or not mixer.cues.has(cue) or origin.distance_to(level.player.global_position) > 430:
		return false
	# Instrument accepted local cues even with Dummy/headless output; no device needed.
	if voices.size() >= MAX_VOICES:
		return false
	var stream: AudioStream = mixer.stream_for(cue)
	if stream == null:
		return false
	played_counts[cue] = played_counts.get(cue, 0) + 1
	if not mixer.output_enabled:
		return true
	var voice := AudioStreamPlayer2D.new()
	voice.stream = stream
	voice.position = origin
	voice.bus = mixer.cues[cue]["bus"]
	voice.max_distance = 430.0 if cue != "footstep" else 230.0
	voice.attenuation = 1.5
	voice.volume_db = float(mixer.cues[cue]["gain_db"]) + gain_db
	voice.pitch_scale = pitch
	add_child(voice)
	voices.append(voice)
	voice.finished.connect(func() -> void:
		voices.erase(voice)
		voice.queue_free())
	voice.play()
	return true


func stop_round() -> void:
	set_physics_process(false)
	for node in loops.values():
		node.stop()
	for voice in voices:
		voice.queue_free()
	voices.clear()
	threat_gain = 0.0


func _exit_tree() -> void:
	stop_round()
