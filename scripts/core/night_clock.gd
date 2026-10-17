class_name NightClock
extends Node
## Host-owned 60-minute expedition night: phases, dread, ranger-radio part reveals,
## a bounded encounter director, phase supply drops, seeded storm/blackout events and dawn.

const PHASES: Array[String] = ["DUSK", "NIGHTFALL", "DEEP NIGHT", "WITCHING HOUR"]
const PHASE_STARTS: Array[float] = [0.0, 600.0, 1500.0, 2400.0]
const PHASE_DREAD: Array[float] = [5.0, 25.0, 45.0, 65.0]
const DAWN := 3600.0
const RELIEF_SECONDS := 45.0
const STORM_SECONDS := 90.0
const STORM_HEARING := 0.6
const NUDGE_MIN := 700.0
const NUDGE_MAX := 1800.0
const NO_SPAWN_RADIUS := 400.0
const SUPPLY_DROP := {"battery_pack": 2, "flare": 1, "rations": 1}
var level: Node2D
var active := false
var elapsed := 0.0
var phase := 0
var dread := 0.0
var heat := 0.0
var storm_remaining := 0.0
var blackout := false
var lightning := 0.0
var lightning_clock := 6.0
var director_enabled := true
var director_clock := 60.0
var relief: Dictionary = {}
var nudges := 0
var next_event := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	active = level.plan.expedition
	rng.seed = level.plan.seed_value + 6061
	if active:
		_reveal(0)


func _physics_process(delta: float) -> void:
	if not active or level.paused or level.finished:
		return
	var net: Node = get_node("/root/Net")
	if net.active and (not multiplayer.is_server() or net.waiting):
		return
	advance(delta)


func advance(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	while phase < phase_at(elapsed):
		phase += 1
		_enter_phase(phase)
	var events: Array[Dictionary] = level.plan.night_events
	while next_event < events.size() and elapsed >= events[next_event]["time"]:
		_start_event(events[next_event]["kind"])
		next_event += 1
	_weather(delta)
	heat = maxf(0.0, heat - delta * 0.5)
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		var id := actor.get_instance_id()
		relief[id] = RELIEF_SECONDS if chased(actor) else maxf(0.0, relief.get(id, 0.0) - delta)
	var span := (PHASE_STARTS[phase + 1] if phase < 3 else DAWN) - PHASE_STARTS[phase]
	var through := clampf((elapsed - PHASE_STARTS[phase]) / span, 0.0, 1.0)
	dread = clampf(PHASE_DREAD[phase] + through * 20.0 + heat + level.van.installed.size() * 3.0, 0.0, 100.0)
	director_clock -= delta
	if director_clock <= 0.0:
		director_clock = lerpf(75.0, 25.0, dread / 100.0)
		if director_enabled:
			direct()
	if elapsed >= DAWN:
		level.dawn()


static func phase_at(seconds: float) -> int:
	for index in range(PHASE_STARTS.size() - 1, -1, -1):
		if seconds >= PHASE_STARTS[index]:
			return index
	return 0


static func clock_text(seconds: float) -> String:
	var whole := int(maxf(0.0, seconds))
	return "%02d:%02d" % [whole / 60, whole % 60]


## Jump the authoritative clock (tests and host tools). Applies every skipped phase once.
func skip_to(seconds: float) -> void:
	advance(maxf(0.0, seconds - elapsed))


## Reveal every staged part without advancing time (route-regression fixtures only).
func reveal_all() -> void:
	_reveal(PHASES.size() - 1)


func hearing_scale() -> float:
	return STORM_HEARING if storm_remaining > 0.0 else 1.0


func note_noise() -> void:
	heat = minf(30.0, heat + 3.0)


func chased(actor: CampPlayer) -> bool:
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		if enemy.enabled and enemy.state == CampKiller.State.CHASE and enemy.visible_target == actor:
			return true
	return false


func generator_point() -> Vector2:
	for building: CampBuilding in level.camp_map.buildings:
		if building.kind == "workshop":
			return building.door + Vector2(0, 14)
	return Vector2(1256, 400)


func restart_generator(actor: CampPlayer) -> bool:
	if not blackout:
		return false
	blackout = false
	level.loud_noise(generator_point(), 450)
	level.announce("Generator roars back to life. Camp lights are on, and the woods heard it.")
	print(JSON.stringify({"event": "night_generator", "time": int(elapsed), "actor": actor.peer_name}))
	return true


## Steer existing roamers toward a survivor's general area. Never spawns, never
## targets camp, skips survivors inside their post-chase relief window.
func direct() -> int:
	var survivors: Array[CampPlayer] = []
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status == CampPlayer.Status.ALIVE and CampMap.is_woods(actor.global_position) and relief.get(actor.get_instance_id(), 0.0) <= 0.0:
			survivors.append(actor)
	if survivors.is_empty():
		return 0
	var focus := survivors[rng.randi_range(0, survivors.size() - 1)]
	var options: Array[CampCryptid] = []
	for enemy: CampCryptid in get_tree().get_nodes_in_group("cryptids"):
		var distance := enemy.global_position.distance_to(focus.global_position)
		if enemy.enabled and enemy.state == CampKiller.State.PATROL and not enemy.home.has_area() and distance >= NUDGE_MIN and distance <= NUDGE_MAX and not _seen(enemy.global_position):
			options.append(enemy)
	options.sort_custom(func(a: CampCryptid, b: CampCryptid) -> bool: return a.global_position.distance_to(focus.global_position) < b.global_position.distance_to(focus.global_position))
	var sent := 0
	for enemy in options.slice(0, 1 if dread < 50.0 else 2):
		var area := focus.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(150.0, 300.0)
		var map := level.get_world_2d().navigation_map
		if NavigationServer2D.map_get_iteration_id(map) > 0:
			area = NavigationServer2D.map_get_closest_point(map, area)
		if not CampMap.is_woods(area):
			continue
		enemy.hear_stimulus(area, INF)
		sent += 1
	nudges += sent
	return sent


func _seen(point: Vector2) -> bool:
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.global_position.distance_to(point) < NO_SPAWN_RADIUS:
			return true
	return false


func _reveal(up_to: int) -> Array[String]:
	var revealed: Array[String] = []
	for pickup: CampPickup in level.pickups:
		var due: int = level.plan.reveal_phase.get(pickup.kind, 0) if pickup.kind in level.plan.required else 0
		if pickup.has_meta("dropped_unit"):
			continue
		if due > up_to and not pickup.has_meta("sealed") and pickup.available:
			pickup.set_meta("sealed", true)
			pickup.available = false
			pickup.hide()
		elif due <= up_to and pickup.has_meta("sealed"):
			pickup.remove_meta("sealed")
			pickup.available = true
			pickup.show()
			pickup.queue_redraw()
			revealed.append(pickup.kind)
	return revealed


func _enter_phase(next: int) -> void:
	var revealed := _reveal(next)
	var drop: Vector2 = level.plan.camp.remap(Vector2(1304, 312))
	var index := 0
	for kind: String in SUPPLY_DROP:
		for unit in range(SUPPLY_DROP[kind]):
			level.spawn_dropped(kind, drop + Vector2(-18 + index * 9, 10))
			index += 1
	# The stalker grows bolder as the night deepens.
	if next >= 2:
		level.killer.config.hearing_radius *= 1.1
	if next == 3:
		level.killer.config.killer_chase_speed *= 1.08
	var clue := ""
	for kind in revealed:
		var known: int = level.clues.get(kind, 2)
		var where: String = level.plan.region_name(kind) if known >= 1 else "the %s woods (find a ranger note)" % level.plan.cache_direction.get(kind, "")
		clue += " %s stashed at %s." % [kind.replace("_", " ").to_upper(), where if not where.is_empty() else "camp"]
	level.announce("%s. Ranger radio:%s Supply drop at Maintenance." % [PHASES[next], clue if not clue.is_empty() else " stay together."])
	print(JSON.stringify({"event": "night_phase", "phase": PHASES[next], "time": int(elapsed), "revealed": revealed}))


func _start_event(kind: String) -> void:
	if kind == "storm":
		storm_remaining = STORM_SECONDS
		lightning_clock = 2.0
		level.announce("STORM FRONT. Thunder masks footsteps for 90s; lightning lights the trees.")
	elif kind == "blackout" and not blackout:
		blackout = true
		level.announce("BLACKOUT. The camp generator died. Restart it at Maintenance (E, loud).")
	print(JSON.stringify({"event": "night_event", "kind": kind, "time": int(elapsed)}))


func _weather(delta: float) -> void:
	lightning = maxf(0.0, lightning - delta)
	if storm_remaining <= 0.0:
		return
	storm_remaining = maxf(0.0, storm_remaining - delta)
	lightning_clock -= delta
	if lightning_clock <= 0.0:
		lightning_clock = rng.randf_range(5.0, 12.0)
		lightning = 0.18


func snapshot() -> Dictionary:
	return {"elapsed": elapsed, "phase": phase, "dread": dread, "storm": storm_remaining, "blackout": blackout, "lightning": lightning}


func restore(state: Dictionary) -> void:
	elapsed = state["elapsed"]
	phase = state["phase"]
	dread = state["dread"]
	storm_remaining = state["storm"]
	blackout = state["blackout"]
	lightning = state["lightning"]
