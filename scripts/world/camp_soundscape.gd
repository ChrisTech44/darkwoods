class_name CampSoundscape
extends Node
## Round-owned playback. All loops/voices are freed with the round.

const MAX_VOICES := 12
const MONSTER_RANGE := 160.0
const ENEMY_STEP_RANGE := 110.0
const CREATURE_CUES := {"werewolf": "werewolf_howl", "bigfoot": "bigfoot_growl", "lantern_moth": "lantern_moth_screech", "witch": "witch_cackle", "briar_revenant": "revenant_screech", "vampire": "vampire_snarl",
	"switchback_hound": "screech_4", "relay_jackal": "screech_4", "shutter_wraith": "screech_1", "lens_eater": "screech_1",
	"bramble_seamstress": "screech_2", "candle_grazer": "screech_2", "boiler_saint": "screech_3", "last_car_conductor": "screech_3",
	"stoneback_ram": "screech_5", "ration_moth": "screech_5"}
## The second species sharing a screech is pitched lower so the two stay distinct.
const CREATURE_PITCH := {"relay_jackal": 0.8, "lens_eater": 0.78, "candle_grazer": 0.82, "last_car_conductor": 0.8, "ration_moth": 1.25}
const RADIO_TALK_SECONDS := 7.0
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
var survivor_steps := {}
var heard_phase := 0
var prop_state := {}


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
	for voice in voices.duplicate():
		voice.stream_paused = suspended
		if voice.has_meta("source"):
			var source: Node2D = voice.get_meta("source").get_ref()
			if is_instance_valid(source):
				voice.global_position = source.global_position
			else:
				voices.erase(voice)
				voice.queue_free()
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
				play_cue("footstep", enemy.global_position, -12.0, 0.72, enemy)
		if enemy is CampCryptid and enemy.enabled and call_timers[id] <= 0 and enemy.global_position.distance_to(actor.global_position) < MONSTER_RANGE:
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
	# Music swells with the night's dread; a chase still pulls it under the heartbeat.
	var dread: float = level.night_clock.dread if level.night_clock.active else 40.0
	_mix_loop("music", clampf(0.45 + dread * 0.0055, 0.0, 1.0) * (1.0 - threat_gain * 0.35), delta)
	loops["music"].pitch_scale = lerpf(1.0, 0.9, dread / 100.0)
	if level.night_clock.phase != heard_phase:
		heard_phase = level.night_clock.phase
		radio_broadcast(heard_phase)
	_prop_sounds()
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
	# Remote survivors use local positional playback from accepted host movement.
	var active_survivors := {}
	for other: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if other==actor: continue
		var id := other.get_instance_id()
		active_survivors[id]=true
		var data: Dictionary=survivor_steps.get(id,{"position":other.position,"distance":0.0})
		var traveled: float=other.position.distance_to(data["position"])
		data["position"]=other.position
		if other.status==CampPlayer.Status.ALIVE and traveled>0.05 and traveled<8:
			data["distance"]+=traveled
			if data["distance"]>=24:
				data["distance"]=0.0
				play_cue("footstep",other.position,-8.0,1.12 if other.sprinting else 1.0,other)
		survivor_steps[id]=data
	for id in survivor_steps.keys():
		if not active_survivors.has(id): survivor_steps.erase(id)


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
	if play_cue(CREATURE_CUES.get(enemy.species, "revenant_screech"), enemy.global_position, 0, CREATURE_PITCH.get(enemy.species, 1.0), enemy):
		call_timers[id] = rng.randf_range(8.0, 14.0)


func play_cue(cue: String, origin: Vector2, gain_db: float = 0.0, pitch: float = 1.0, source: Node2D = null) -> bool:
	var monster := cue in CREATURE_CUES.values()
	var radius := MONSTER_RANGE if monster else (ENEMY_STEP_RANGE if source is CampKiller else 230.0)
	if level.paused or level.finished or not mixer.cues.has(cue) or origin.distance_to(level.player.global_position) >= radius:
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
	voice.max_distance = radius
	voice.attenuation = 2.0
	voice.volume_db = float(mixer.cues[cue]["gain_db"]) + gain_db
	voice.pitch_scale = pitch
	if source != null:
		voice.set_meta("source", weakref(source))
	add_child(voice)
	voices.append(voice)
	voice.finished.connect(func() -> void:
		voices.erase(voice)
		voice.queue_free())
	# Some supplied calls open with silence; start at the sound so warnings are immediate.
	voice.play(float(mixer.cues[cue].get("start_seconds", 0.0)))
	return true


## Ranger radio at each phase change (the part reveals): a burst of static, then a
## short faded excerpt of chatter. Non-positional, like a walkie on your belt.
func radio_broadcast(phase: int) -> bool:
	if level.finished or not mixer.cues.has("radio_talk") or mixer.stream_for("radio_talk") == null:
		return false
	played_counts["phase_stinger"] = played_counts.get("phase_stinger", 0) + 1
	played_counts["radio_talk"] = played_counts.get("radio_talk", 0) + 1
	played_counts["radio_static"] = played_counts.get("radio_static", 0) + 1
	if not mixer.output_enabled:
		return true
	var static_burst := _radio_voice("radio_static", 0.0)
	get_tree().create_timer(1.1).timeout.connect(func() -> void:
		if is_instance_valid(static_burst): static_burst.queue_free())
	var talk_length: float = mixer.stream_for("radio_talk").get_length()
	var offset := fmod((phase - 1) * 9.0, maxf(1.0, talk_length - RADIO_TALK_SECONDS))
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if level.finished: return
		var talk := _radio_voice("radio_talk", offset)
		var fade := talk.create_tween()
		fade.tween_interval(RADIO_TALK_SECONDS - 1.0)
		fade.tween_property(talk, "volume_db", -60.0, 1.0)
		fade.tween_callback(talk.queue_free))
	return true


func _radio_voice(cue: String, offset: float) -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.stream = mixer.stream_for(cue)
	voice.bus = mixer.cues[cue]["bus"]
	voice.volume_db = float(mixer.cues[cue]["gain_db"])
	add_child(voice)
	voice.play(offset)
	return voice


## Door slams/breaks, gate openings, knock-overs and vault landings, inferred from
## (replicated) prop state so host and clients each hear them once, locally.
func _prop_sounds() -> void:
	var props: ChaseProps = level.props
	if props == null:
		return
	for index in range(props.doors.size()):
		var door: Dictionary = props.doors[index]
		var key := "door%d" % index
		var now := [door["open"], door["broken"] > 0.0]
		if prop_state.has(key):
			var before: Array = prop_state[key]
			if before[0] and not now[0]:
				play_cue("thud", door["rect"].get_center(), 0.0, 1.0)
			elif not before[1] and now[1]:
				play_cue("thud", door["rect"].get_center(), 6.0, 0.7)
				play_cue("wood_falling", door["rect"].get_center(), 0.0, 1.2)
		prop_state[key] = now
	for index in range(props.knocks.size()):
		var key := "knock%d" % index
		var state: int = props.knocks[index]["state"]
		if prop_state.get(key, state) == 0 and state == 1:
			play_cue("wood_falling", props.knocks[index]["position"], 2.0, 1.0)
		prop_state[key] = state
	var gates: Array[Dictionary] = level.plan.woods.gates
	for index in range(gates.size()):
		var key := "gate%d" % index
		if prop_state.has(key) and not prop_state[key] and gates[index]["open"]:
			play_cue("thud", gates[index]["position"], -2.0, 1.25)
		prop_state[key] = gates[index]["open"]
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		var key := "vault%d" % actor.get_instance_id()
		if prop_state.get(key, 0.0) > 0.0 and actor.vault_time <= 0.0:
			play_cue("thud", actor.global_position, -8.0, 1.35)
		prop_state[key] = actor.vault_time


## Non-positional phase stinger: a distant call that marks the night getting worse.
func stinger(cue: String, gain_db: float, pitch: float) -> bool:
	if level.finished or not mixer.cues.has(cue) or mixer.stream_for(cue) == null:
		return false
	played_counts["phase_stinger"] = played_counts.get("phase_stinger", 0) + 1
	if not mixer.output_enabled:
		return true
	var voice := AudioStreamPlayer.new()
	voice.stream = mixer.stream_for(cue)
	voice.bus = "Music"
	voice.volume_db = float(mixer.cues[cue]["gain_db"]) + gain_db
	voice.pitch_scale = pitch
	add_child(voice)
	voice.finished.connect(voice.queue_free)
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
