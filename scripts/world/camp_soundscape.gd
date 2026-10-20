class_name CampSoundscape
extends Node
## Round-owned playback. All loops/voices are freed with the round.

const MAX_VOICES := 20
## Audio revamp (17 October): creatures carry. Calls are heard well beyond the
## screen, chases scream, footsteps are heavy, and a faint chorus of far calls
## keeps the woods alive. AI hearing is unaffected by any of this.
const MONSTER_RANGE := 560.0
const ENEMY_STEP_RANGE := 240.0
const CHORUS_RANGE := 2000.0
const CHORUS_DISTANCE := 480.0
## Headline killers vocalise on the hunt: [cue, pitch].
const KILLER_CUES := {"stalker": ["screech_3", 0.7]}
## Heavier creatures step lower and louder.
const STEP_PITCH := {"bigfoot": 0.55, "stoneback_ram": 0.6, "boiler_saint": 0.62, "werewolf": 0.7, "switchback_hound": 0.9, "relay_jackal": 1.0, "lantern_moth": 1.3, "ration_moth": 1.35, "teddy": 1.8, "imps": 1.6, "mimic": 1.0}
const CREATURE_CUES := {"huntmaster":"huntmaster_horn", "nobody":"nobody_exhale", "vulture":"vulture_squawk", "nightlight_kid":"nightlight_scream", "lifeguard":"lifeguard_whistle", "werewolf": "werewolf_howl", "bigfoot": "bigfoot_growl", "lantern_moth": "lantern_moth_screech", "witch": "witch_cackle", "briar_revenant": "revenant_screech", "vampire": "vampire_snarl",
	"switchback_hound": "dog_bark", "relay_jackal": "monster_6", "shutter_wraith": "monster_9", "lens_eater": "screech_1",
	"bramble_seamstress": "monster_7", "candle_grazer": "screech_2", "boiler_saint": "screech_3", "last_car_conductor": "train",
	"stoneback_ram": "monster_8", "ration_moth": "screech_5",
	"mimic": "screech_4", "owl": "owl", "bog_hands": "bog_gurgle", "imps": "giggle", "teddy": "squeak",
	"groundskeeper": "monster_8", "cuckoo": "squeak", "banshee": "revenant_screech", "slug": "bog_gurgle", "surveyor": "eerie",
	"hitchhiker": "giggle", "tollkeeper": "monster_8", "echo": "wind", "fortune_teller": "bells"}
## The second species sharing a screech is pitched lower so the two stay distinct.
const CREATURE_PITCH := {"relay_jackal": 0.8, "lens_eater": 0.78, "candle_grazer": 0.82, "ration_moth": 1.25,
	"mimic": 0.85, "owl": 0.7, "groundskeeper": 1.1, "cuckoo": 1.5, "banshee": 1.4, "slug": 0.6, "surveyor": 0.8,
	"hitchhiker": 0.7, "tollkeeper": 1.25, "echo": 1.3, "fortune_teller": 1.6}
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
var stopped := false
var rng := RandomNumberGenerator.new()
var played_counts: Dictionary = {}
var last_step_cue := ""
var survivor_steps := {}
var heard_phase := 0
var prop_state := {}
var chorus_clock := 20.0
var killer_call_clock := 0.0
## Ambient one-shots (owl, wind, eerie) and thunder scheduled after lightning.
var ambient_clock := 18.0
var thunder_delay := -1.0
var last_lightning := 0.0
## Positional loops placed in the world (generator, signal pyre, boat).
const WORLD_LOOPS := ["generator", "fire_loop", "boat_engine", "helicopter"]
## Alarm-like one-shots carry much farther than ordinary effects.
## Heartbeat as the only threat readout: something within NEAR_RANGE (even behind
## trees) brings a slow, quiet beat that quickens as it closes; line of sight
## (it is hunting you) brings a fast, loud one.
const NEAR_RANGE := 300.0
var near_gain := 0.0
const LOUD_CUES := {"field_whistle":900.0,"car_alarm": 1400.0, "air_horn": 1500.0, "bells": 1000.0, "car_start": 700.0, "dog_bark": 700.0, "train": 650.0, "fire_whoosh": 600.0, "thunder": 600.0,
	"metal_clang": 400.0, "chain_rattle": 400.0, "bear_trap": 450.0, "camera_charge": 420.0, "camera_shutter": 420.0, "sneeze": 320.0}
## Survivor voices (hurt/held/down) carry a little past the screen edge.
const VOICE_RANGE := 300.0
## Host-only sound events (creature attacks, items) are logged with an id and
## replayed once by each client from snapshots; entries live this long.
const SOUND_LOG_SECONDS := 2.0
var heard_sound_id := 0
var next_sound_id := 0
## Positional loops that follow sources: lullaby per Saint, croak per frog.
var follow_loops: Dictionary = {}
const LULLABY_RANGE := 300.0
const MOWER_RANGE := 650.0


func _ready() -> void:
	add_to_group("round_audio")
	mixer = get_node("/root/AudioManager")
	if ServerRuntime.requested():
		set_physics_process(false)
		return
	rng.seed = level.plan.seed_value + 9051
	last_position = level.player.global_position
	var listener := AudioListener2D.new()
	level.player.add_child(listener)
	listener.make_current()
	for cue in ["woods", "swamp", "music", "heartbeat", "running_grass", "walking_indoor", "campfire", "rain_heavy", "rain_light", "chase_music", "breathing", "gravel_steps", "wet_steps"] + WORLD_LOOPS:
		var node: Node
		if cue == "campfire":
			node = AudioStreamPlayer2D.new()
			node.position = Vector2(168, 336)
			node.max_distance = 270
			node.attenuation = 1.5
		elif cue in WORLD_LOOPS:
			node = AudioStreamPlayer2D.new()
			node.max_distance = {"generator": 220, "helicopter": 1100}.get(cue, 420)
			node.attenuation = 1.4
			match cue:
				"generator": node.position = level.night_clock.generator_point() if level.night_clock != null else Vector2(1256, 400)
				"fire_loop": node.position = level.signal_fire.pyre if level.signal_fire != null else Vector2.ZERO
				"boat_engine": node.position = level.escapes.boat_point if level.escapes != null else Vector2.ZERO
				"helicopter": node.position = level.rescue.landing + Vector2(0, -60) if level.rescue != null else Vector2.ZERO
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
	for node in follow_loops.values():
		if is_instance_valid(node):
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
	mixer.set_muffled(actor.has_effect("deaf"))
	var indoor := _indoors(actor.global_position)
	var distance := last_position.distance_to(actor.global_position)
	last_position = actor.global_position
	# Teleports/fixtures never produce a burst of hundreds of footsteps.
	var moving := alive and distance > 0.05 and distance < 8.0
	var bog := level.plan.woods.zones[1]["bounds"] as Rect2
	var swamp_weight := clampf(1.0 - actor.global_position.distance_to(bog.get_center()) / (bog.size.x * 0.5 + 150.0), 0.0, 1.0)
	var spotted := false
	var closest := INF
	var active_ids := {}
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		var id := enemy.get_instance_id()
		active_ids[id] = true
		if not enemy_steps.has(id):
			_track_enemy(enemy)
		if enemy.enabled and enemy.state == CampKiller.State.CHASE and enemy.visible_target == actor:
			spotted = true
		if enemy.enabled:
			closest = minf(closest, enemy.global_position.distance_to(actor.global_position))
		call_timers[id] = maxf(0.0, call_timers[id] - delta)
		var data: Dictionary = enemy_steps[id]
		var travel := enemy.global_position.distance_to(data["position"])
		data["position"] = enemy.global_position
		if enemy.enabled and travel > 0.05 and travel < 8.0:
			data["distance"] += travel
			if data["distance"] >= 24.0:
				data["distance"] = 0.0
				var weight: float = STEP_PITCH.get(enemy.species, 0.72) if enemy is CampCryptid else 0.66
				play_cue("footstep", enemy.global_position, -4.0 if weight < 0.8 else -7.0, weight, enemy)
		if enemy is CampCryptid and enemy.enabled and call_timers[id] <= 0 and enemy.global_position.distance_to(actor.global_position) < MONSTER_RANGE:
			_creature_call(enemy)
		elif not enemy is CampCryptid and enemy.enabled:
			_killer_voice(enemy, delta)
	for id in enemy_steps.keys():
		if not active_ids.has(id):
			enemy_steps.erase(id)
			call_timers.erase(id)
	_chorus(delta)
	_weather_and_world(actor, indoor, delta)
	_events()
	threat_gain = move_toward(threat_gain, 1.0 if spotted and alive else 0.0, delta * (0.9 if spotted else 0.28))
	var proximity := clampf(1.0 - closest / NEAR_RANGE, 0.0, 1.0) if alive else 0.0
	near_gain = move_toward(near_gain, proximity, delta * 0.6)
	# Near: 0.35–0.7 gain at 0.8–1.0 speed. Seen: full gain at 1.45 speed.
	_mix_loop("heartbeat", maxf(threat_gain, 0.35 + near_gain * 0.35 if near_gain > 0.02 else 0.0), delta)
	loops["heartbeat"].pitch_scale = lerpf(lerpf(0.8, 1.0, near_gain), 1.45, threat_gain)
	_mix_loop("woods", (1.0 - swamp_weight * 0.85) * (0.4 if indoor else 1.0), delta)
	_mix_loop("swamp", swamp_weight * (0.4 if indoor else 1.0), delta)
	_mix_loop("campfire", 1.0, delta)
	# Music swells with the night's dread; a chase still pulls it under the heartbeat.
	var dread: float = level.night_clock.dread if level.night_clock.active else 40.0
	# Silent Night modifier: no music, only the woods.
	var music_gain := 0.0 if level.plan.has_modifier("silent_night") else clampf(0.45 + dread * 0.0055, 0.0, 1.0) * (1.0 - threat_gain * 0.35)
	_mix_loop("music", music_gain * (1.0 - threat_gain * 0.8), delta)
	# Chase layer: swells in while something is actively hunting you.
	_mix_loop("chase_music", 0.0 if level.plan.has_modifier("silent_night") else threat_gain, delta, 1.2)
	# Held breath while hidden near a threat; panting when exhausted.
	var gasping: bool = alive and actor.exhausted
	var holding: bool = actor.hidden_spot >= 0 and actor.breath < 0.98
	_mix_loop("breathing", 1.0 if holding else (0.6 if gasping else 0.0), delta, 2.0)
	loops["breathing"].pitch_scale = 1.15 if holding and actor.breath < 0.4 else 1.0
	loops["music"].pitch_scale = lerpf(1.0, 0.9, dread / 100.0)
	if level.night_clock.phase != heard_phase:
		heard_phase = level.night_clock.phase
		radio_broadcast(heard_phase)
	_prop_sounds()
	# Surface footsteps: bog mud and roads have their own step loops.
	var zone: Dictionary = level.plan.woods.zone_at(actor.global_position) if level.plan.expedition else {}
	var in_bog: bool = not zone.is_empty() and zone["kind"] == "bog"
	var road: bool = not indoor and not in_bog and (level.plan.woods.on_road(actor.global_position) if CampMap.is_woods(actor.global_position) else level.camp_map.roads.any(func(rect: Rect2) -> bool: return rect.has_point(actor.global_position)))
	var surface := "wet_steps" if in_bog else ("gravel_steps" if road else "")
	var stepping: bool = moving and not indoor and not surface.is_empty()
	_mix_loop("wet_steps", 1.0 if stepping and surface == "wet_steps" else 0.0, delta, 10.0)
	_mix_loop("gravel_steps", 1.0 if stepping and surface == "gravel_steps" else 0.0, delta, 10.0)
	for cue in ["wet_steps", "gravel_steps"]:
		loops[cue].pitch_scale = 1.3 if actor.sprinting else 1.0
	if stepping:
		last_step_cue = surface
		step_distance = 0.0
		_mix_loop("running_grass", 0.0, delta, 10.0)
		_mix_loop("walking_indoor", 0.0, delta, 10.0)
		_remote_steps(actor)
		return
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
	_remote_steps(actor)


## Remote survivors use local positional playback from accepted host movement.
func _remote_steps(actor: CampPlayer) -> void:
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
	if enemy.species in NewCreatureSamples.SOURCES: return # Signature cues are authority events; loops have their own lifetime.
	var id := enemy.get_instance_id()
	if call_timers.get(id, 0.0) > 0:
		return
	if play_cue(CREATURE_CUES.get(enemy.species, "revenant_screech"), enemy.global_position, 3.0 if enemy.state == CampKiller.State.CHASE else 0.0, CREATURE_PITCH.get(enemy.species, 1.0), enemy):
		# Hunting creatures scream often; wandering ones call every so often.
		call_timers[id] = rng.randf_range(3.5, 5.0) if enemy.state == CampKiller.State.CHASE else rng.randf_range(6.0, 12.0)


## The headline killer: a scream when the chase starts and every few seconds
## during it, a low growl while investigating.
func _killer_voice(enemy: CampKiller, delta: float) -> void:
	killer_call_clock = maxf(0.0, killer_call_clock - delta)
	if killer_call_clock > 0.0 or enemy.global_position.distance_to(level.player.global_position) > MONSTER_RANGE:
		return
	var voice: Array = KILLER_CUES.get(enemy.headline, KILLER_CUES["stalker"])
	if enemy.state == CampKiller.State.CHASE:
		if play_cue(voice[0], enemy.global_position, 2.0, voice[1], enemy):
			killer_call_clock = rng.randf_range(4.0, 6.0)
	elif enemy.state == CampKiller.State.INVESTIGATE:
		if play_cue("screech_5", enemy.global_position, 6.0, 0.55, enemy):
			killer_call_clock = rng.randf_range(7.0, 11.0)


## Every 18–35 s a creature far out in the woods calls; it is placed toward
## that creature but close enough to hear, faint and slightly lowered.
func _chorus(delta: float) -> void:
	chorus_clock -= delta
	if chorus_clock > 0.0 or not level.plan.expedition:
		return
	chorus_clock = rng.randf_range(18.0, 35.0)
	var listener: Vector2 = level.player.global_position
	var options: Array = get_tree().get_nodes_in_group("cryptids").filter(func(enemy: CampCryptid) -> bool:
		var distance := enemy.global_position.distance_to(listener)
		return enemy.enabled and distance > MONSTER_RANGE and distance < CHORUS_RANGE)
	if options.is_empty():
		return
	distant_call(options[rng.randi_range(0, options.size() - 1)], -10.0)


## A creature's call from its direction, heard faintly (director build-ups too).
func distant_call(enemy: CampKiller, gain_db: float = -6.0) -> bool:
	var listener: Vector2 = level.player.global_position
	var cue: String = CREATURE_CUES.get(enemy.species, "revenant_screech") if enemy is CampCryptid else KILLER_CUES.get(enemy.headline, KILLER_CUES["stalker"])[0]
	var pitch: float = CREATURE_PITCH.get(enemy.species, 1.0) * 0.94 if enemy is CampCryptid else 0.68
	var at := listener + listener.direction_to(enemy.global_position) * minf(CHORUS_DISTANCE, listener.distance_to(enemy.global_position))
	played_counts["distant_call"] = played_counts.get("distant_call", 0) + 1
	return play_cue(cue, at, gain_db, pitch)


## The Hunt Begins: a long, low horn-like howl over the whole camp.
func hunting_horn() -> bool:
	played_counts["hunting_horn"] = played_counts.get("hunting_horn", 0) + 1
	return play_cue("hunt_horn", level.player.global_position + Vector2(0, -120), 0.0, 1.0)


## Rain, thunder, positional world loops and ambient one-shots.
func _weather_and_world(actor: CampPlayer, indoor: bool, delta: float) -> void:
	var clock: NightClock = level.night_clock
	var storm: bool = clock != null and clock.storm_remaining > 0.0
	var shelter := 0.35 if indoor else 1.0
	_mix_loop("rain_heavy", (1.0 if storm else 0.0) * shelter, delta, 0.5)
	_mix_loop("rain_light", (1.0 if level.plan.weather == "rain" and not storm else 0.0) * shelter, delta, 0.5)
	if clock != null:
		if clock.lightning > 0.0 and last_lightning <= 0.0:
			thunder_delay = rng.randf_range(0.25, 1.4)
		last_lightning = clock.lightning
	if thunder_delay >= 0.0:
		thunder_delay -= delta
		if thunder_delay < 0.0:
			played_counts["thunder"] = played_counts.get("thunder", 0) + 1
			play_cue("thunder", actor.global_position + Vector2(rng.randf_range(-120, 120), -150), 0.0, rng.randf_range(0.9, 1.05))
	_mix_loop("generator", 0.0 if clock == null or clock.blackout else 1.0, delta)
	_mix_loop("fire_loop", 1.0 if level.signal_fire != null and level.signal_fire.started else 0.0, delta)
	_mix_loop("boat_engine", 1.0 if level.escapes != null and level.escapes.boat_started else 0.0, delta)
	# Radio rescue: the helicopter is overhead for the whole landing-zone hold-out.
	_mix_loop("helicopter", 1.0 if level.rescue != null and level.rescue.started else 0.0, delta, 0.35)
	_follow_loops()
	if level.plan.expedition and CampMap.is_woods(actor.global_position):
		ambient_clock -= delta
		if ambient_clock <= 0.0:
			ambient_clock = rng.randf_range(22.0, 48.0)
			var pick: String = ["owl", "owl", "wind", "wind", "eerie"][rng.randi_range(0, 4)]
			played_counts["ambient_" + pick] = played_counts.get("ambient_" + pick, 0) + 1
			play_cue(pick, actor.global_position + Vector2.from_angle(rng.randf() * TAU) * 160.0)


## One-shots for world state changes, detected from replicated state so every
## peer hears them: van start, sabotage alarm, snares, gift bell, pyre.
func _events() -> void:
	var edges := {
		"van": level.van.running,
		"alarm": level.night_clock != null and level.night_clock.sabotage_done,
		"gift": level.events != null and level.events.gift_open,
		"pyre": level.signal_fire != null and level.signal_fire.started,
	}
	for key: String in edges:
		var before: bool = prop_state.get("event_" + key, edges[key])
		prop_state["event_" + key] = edges[key]
		if before or not edges[key]:
			continue
		played_counts["event_" + key] = played_counts.get("event_" + key, 0) + 1
		match key:
			"van": play_cue("car_start", level.van.global_position)
			"alarm": play_cue("car_alarm", level.van.global_position)
			"gift": play_cue("bells", level.events.gift_at)
			"pyre": play_cue("fire_whoosh", level.signal_fire.pyre)
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		var key := "snare%d" % actor.get_instance_id()
		var held: bool = actor.snared > 0.0
		if held and not prop_state.get(key, false):
			# One snap per trap, from replicated state (the trap code plays nothing itself).
			played_counts["snare"] = played_counts.get("snare", 0) + 1
			play_cue("bear_trap", actor.global_position)
			play_cue("chain_rattle", actor.global_position)
		prop_state[key] = held
		_survivor_voice(actor)


func play_cue(cue: String, origin: Vector2, gain_db: float = 0.0, pitch: float = 1.0, source: Node2D = null, length: float = 0.0) -> bool:
	if stopped: return false
	if ServerRuntime.requested(): return false
	var monster := cue in CREATURE_CUES.values() or cue.begins_with("screech")
	var radius: float = LOUD_CUES.get(cue, MONSTER_RANGE if monster else (VOICE_RANGE if cue in ["grunt", "gasp"] else (ENEMY_STEP_RANGE if source is CampKiller else 230.0)))
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
	# Gentler roll-off for calls so they carry; footsteps stay local.
	voice.attenuation = 1.2 if monster else 2.0
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
	if length > 0.0:
		# Cut long recordings to the event's length with a short fade.
		var cut := voice.create_tween()
		cut.tween_interval(maxf(0.0, length - 0.15))
		cut.tween_property(voice, "volume_db", -60.0, 0.15)
		cut.tween_callback(func() -> void:
			voices.erase(voice)
			voice.queue_free())
	return true


## A host-side sound event (creature attack, item use) that every peer hears
## once: played here, and logged for clients, who replay it from snapshots.
func broadcast(cue: String, origin: Vector2, gain_db: float = 0.0, pitch: float = 1.0, length: float = 0.0) -> bool:
	if stopped: return false
	var net: Node = get_node_or_null("/root/Net")
	if net != null and net.active and multiplayer.is_server():
		var now := Time.get_ticks_msec()
		next_sound_id += 1
		level.sound_log.append({"id": next_sound_id, "cue": cue, "at": origin, "gain": gain_db, "pitch": pitch, "length": length, "time": now})
		while not level.sound_log.is_empty() and now - int(level.sound_log[0]["time"]) > SOUND_LOG_SECONDS * 1000.0:
			level.sound_log.pop_front()
	played_counts["broadcast"] = played_counts.get("broadcast", 0) + 1
	return play_cue(cue, origin, gain_db, pitch, null, length)


## Client side: play each logged host event exactly once.
func replay(log: Array) -> void:
	for row: Dictionary in log:
		if int(row["id"]) <= heard_sound_id:
			continue
		heard_sound_id = int(row["id"])
		played_counts["replayed"] = played_counts.get("replayed", 0) + 1
		play_cue(row["cue"], row["at"], row["gain"], row["pitch"], null, row["length"])


## Hurt grunts, grabbed/downed gasps and sneezes, inferred from replicated
## survivor state so every peer hears each one once.
func _survivor_voice(actor: CampPlayer) -> void:
	var key := "voice%d" % actor.get_instance_id()
	var now := {"hurt": actor.hurt_time, "held": actor.has_effect("held"), "down": actor.status == CampPlayer.Status.DOWNED, "achoo": actor.has_effect("achoo")}
	if prop_state.has(key):
		var before: Dictionary = prop_state[key]
		var helium := 1.3 if actor.has_effect("helium") else 1.0
		if now["down"] and not before["down"]:
			play_cue("gasp", actor.global_position, 2.0, 0.85 * helium)
		elif now["held"] and not before["held"]:
			play_cue("gasp", actor.global_position, 0.0, rng.randf_range(0.97, 1.05) * helium)
		elif now["hurt"] > before["hurt"] + 0.1:
			play_cue("grunt", actor.global_position, 0.0, rng.randf_range(0.92, 1.08) * helium)
		if now["achoo"] and not before["achoo"]:
			play_cue("sneeze", actor.global_position, 0.0, rng.randf_range(1.15, 1.3) * helium)
	prop_state[key] = now


## Loops that follow their source: a Lullaby Saint's song while it is near, and
## the croaking of anyone under the witch's frog curse.
func _follow_loops() -> void:
	var wanted := {}
	var listener: Vector2 = level.player.global_position
	for enemy: CampCryptid in get_tree().get_nodes_in_group("cryptids"):
		if enemy.species == "boiler_saint" and enemy.enabled and enemy.global_position.distance_to(listener) < LULLABY_RANGE + 60.0:
			wanted[enemy.get_instance_id()] = ["lullaby", enemy]
		elif enemy.species=="nobody" and enemy.enabled and enemy.position.distance_to(listener)<360:
			wanted[enemy.get_instance_id()]=["nobody_breathing",enemy]
		elif enemy.species=="nightlight_kid" and enemy.enabled and enemy.brain.near_dark and enemy.position.distance_to(listener)<320:
			wanted[enemy.get_instance_id()]=["nightlight_whimper",enemy]
		# The Groundskeeper's mower engine: always audible from well off-screen.
		elif enemy.species == "groundskeeper" and enemy.enabled and enemy.brain != null and enemy.brain.riding and enemy.global_position.distance_to(listener) < MOWER_RANGE + 60.0:
			wanted[enemy.get_instance_id()] = ["boat_engine", enemy]
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status == CampPlayer.Status.ALIVE and actor.has_effect("frog"):
			wanted[actor.get_instance_id()] = ["frog_croak", actor]
		if actor.status != CampPlayer.Status.ALIVE: continue
		if actor.kit.get("cast",{}).get("kind","")=="boiler_saint" and actor.kit.get("cast",{}).get("fired",false):
			wanted["sample_song:%d" % actor.get_instance_id()] = ["lullaby",actor]
		if actor.kit.get("form","")=="nobody":
			wanted["sample_breath:%d" % actor.get_instance_id()]=["nobody_breathing",actor]
		if actor.kit.get("form","")=="groundskeeper":
			wanted["sample_mower:%d" % actor.get_instance_id()] = ["boat_engine",actor]
	for id in follow_loops.keys():
		if not wanted.has(id) or not is_instance_valid(follow_loops[id]):
			if is_instance_valid(follow_loops[id]):
				follow_loops[id].queue_free()
			follow_loops.erase(id)
	for id in wanted:
		var cue: String = wanted[id][0]
		var source: Node2D = wanted[id][1]
		if follow_loops.has(id) and follow_loops[id].stream != mixer.stream_for(cue):
			follow_loops[id].queue_free()
			follow_loops.erase(id)
		if not follow_loops.has(id):
			played_counts[cue] = played_counts.get(cue, 0) + 1
			var node := AudioStreamPlayer2D.new()
			node.stream = mixer.stream_for(cue)
			node.bus = mixer.cues[cue]["bus"]
			node.volume_db = float(mixer.cues[cue]["gain_db"])
			node.max_distance = {"lullaby": LULLABY_RANGE, "boat_engine": MOWER_RANGE}.get(cue, 260.0)
			if cue == "boat_engine":
				node.pitch_scale = 1.7
				node.volume_db -= 4.0
			node.attenuation = 1.3
			add_child(node)
			follow_loops[id] = node
			if mixer.output_enabled and node.stream != null:
				node.play()
		if cue=="nobody_breathing": follow_loops[id].volume_db=float(mixer.cues[cue]["gain_db"])-(6.0 if level.night_clock.phase>=3 else 0.0)
		follow_loops[id].global_position = source.global_position


## Ranger radio at each phase change (the part reveals): a burst of static, then a
## short faded excerpt of chatter. Non-positional, like a walkie on your belt.
func radio_broadcast(phase: int) -> bool:
	if stopped: return false
	if level.finished or not mixer.cues.has("radio_talk") or mixer.stream_for("radio_talk") == null:
		return false
	played_counts["phase_stinger"] = played_counts.get("phase_stinger", 0) + 1
	played_counts["radio_talk"] = played_counts.get("radio_talk", 0) + 1
	played_counts["radio_static"] = played_counts.get("radio_static", 0) + 1
	if not mixer.output_enabled:
		return true
	var static_burst := _radio_voice("radio_static", 0.0)
	get_tree().create_timer(1.1).timeout.connect(_finish_radio_static.bind(weakref(static_burst)))
	var talk_length: float = mixer.stream_for("radio_talk").get_length()
	var offset := fmod((phase - 1) * 9.0, maxf(1.0, talk_length - RADIO_TALK_SECONDS))
	get_tree().create_timer(0.6).timeout.connect(_start_radio_talk.bind(offset))
	return true


func _finish_radio_static(source: WeakRef) -> void:
	var voice: Node = source.get_ref()
	if is_instance_valid(voice):
		voice.queue_free()


func _start_radio_talk(offset: float) -> void:
	if stopped or level.finished:
		return
	var talk := _radio_voice("radio_talk", offset)
	var fade := talk.create_tween()
	fade.tween_interval(RADIO_TALK_SECONDS - 1.0)
	fade.tween_property(talk, "volume_db", -60.0, 1.0)
	fade.tween_callback(talk.queue_free)


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
			elif not before[0] and now[0] and not now[1]:
				play_cue("door_creak", door["rect"].get_center())
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
	if stopped: return false
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
	stopped = true
	set_physics_process(false)
	# Radio/stingers are non-positional children, outside the positional voice
	# list. Release every playback before AudioManager drains native commands.
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.stop()
			child.stream = null
	mixer.set_muffled(false)
	for node in loops.values():
		node.stop()
	for voice in voices:
		voice.queue_free()
	voices.clear()
	for node in follow_loops.values():
		if is_instance_valid(node):
			node.queue_free()
	follow_loops.clear()
	threat_gain = 0.0


func _exit_tree() -> void:
	stop_round()
