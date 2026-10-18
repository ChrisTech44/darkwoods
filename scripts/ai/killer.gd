class_name CampKiller
extends CharacterBody2D
## Authority-only senses and FSM. Destinations come from patrol or sensed memory.

signal state_changed(next: State)

enum State { PATROL, INVESTIGATE, CHASE, SEARCH }

var config: CampConfig = preload("res://assets/default_config.tres")
var state: State = State.PATROL
var patrol: Array[Vector2] = [Vector2(684, 336), Vector2(684, 216), Vector2(360, 216), Vector2(360, 432), Vector2(240, 312)]
var patrol_index: int = 0
var last_seen := Vector2.ZERO
var memory: Dictionary = {}
var search_remaining: float = 0.0
var attack_remaining: float = 0.0
var path_clock: float = 0.0
var stuck_clock: float = 0.0
var enabled: bool = true
var visible_target: CampPlayer
var facing := Vector2.DOWN
var stride: float = 0.0
var search_points: Array[Vector2] = []
var search_index: int = 0
var retreat_remaining: float = 0.0
var stun_remaining: float = 0.0
var stun_immunity: float = 0.0
## F7 headline killer: "stalker" or "groundskeeper" (cryptids ignore it).
var headline := "stalker"
## Escalation tier = night phase + 1 (1 Dusk … 4 Witching Hour), set by NightClock.
var tier := 1
const INNER_RING := 1600.0
## Per-creature hit as [damage, cooldown seconds]. Slow or telegraphed creatures
## that are easy to evade hit hard and need a long recovery; quick ones hit
## lightly and more often but each has a simple counter (darkness, the beam,
## standing still, a flare). After a hit the attacker pauses for half its
## cooldown (at most 2 s), so a survivor always gets a head start.
const THREATS := {
	"stalker": [50.0, 4.0], "groundskeeper": [40.0, 3.5],
	"bigfoot": [60.0, 5.0], "werewolf": [40.0, 4.0], "witch": [35.0, 4.0],
	"vampire": [25.0, 2.5], "lantern_moth": [15.0, 1.0], "briar_revenant": [20.0, 1.5],
	"boiler_saint": [45.0, 4.0], "bramble_seamstress": [30.0, 3.0], "shutter_wraith": [15.0, 1.0],
	"last_car_conductor": [35.0, 3.5], "stoneback_ram": [55.0, 5.0], "candle_grazer": [20.0, 1.5],
	"switchback_hound": [30.0, 2.5], "relay_jackal": [15.0, 1.2], "ration_moth": [15.0, 1.0],
	"lens_eater": [20.0, 2.0], "mimic": [25.0, 3.0], "owl": [10.0, 4.0], "bog_hands": [0.0, 4.0],
	"imps": [0.0, 4.0], "teddy": [5.0, 3.0],
}
## Expedition nights keep every creature out of camp until Deep Night (the
## second half): camp neither shows nor sounds to them, and they never path
## in. The level sets this at start and NightClock lifts it.
static var camp_closed := false
const CAMP_MARGIN := 40.0
## Host only: the survivor this creature is holding (carried, hugged, latched…).
var held: CampPlayer = null
## Door-breaking speed multiplier (rampaging creatures burst doors instantly).
var door_force := 1.0
## The headline killer's own traits (StalkerTraits); null for woods creatures.
var traits: StalkerTraits
## Synced for drawing: melted into the dark, frenzy seconds left, carrying a victim.
var faded := false
var frenzy := 0.0
var carrying := false
var hit_damage := 45.0
var hit_cooldown := 4.0
var recover_remaining := 0.0
const STALKER_SHEET := preload("res://assets/sprites/stalker.png")
const GROUNDSKEEPER_SHEET := preload("res://assets/sprites/groundskeeper.png")
@onready var agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	add_to_group("killers")
	if not is_class_cryptid():
		traits = StalkerTraits.new(self)
		var song := CampSong.new()
		song.name = "CampSong"
		add_child(song)
	var threat: Array = THREATS.get(threat_key(), [45.0, 3.0])
	hit_damage = threat[0]
	hit_cooldown = threat[1]
	# Fences and closed gates (layer 8) stop creatures too; they never vault.
	collision_mask |= CampPlayer.BARRIER_LAYER | CampPlayer.WATER_LAYER


func _physics_process(delta: float) -> void:
	if not enabled:
		velocity = Vector2.ZERO
		return
	if tick_stun(delta):
		return
	attack_remaining = maxf(0.0, attack_remaining - delta)
	if recover_remaining > 0.0 and not is_instance_valid(held):
		# Catching its breath after a hit: the survivor's head start.
		recover_remaining = maxf(0.0, recover_remaining - delta)
		velocity = Vector2.ZERO
		queue_redraw()
		return
	if traits != null and traits.physics(delta):
		queue_redraw()
		return
	retreat_remaining = maxf(0.0, retreat_remaining - delta)
	for target_id: int in memory.keys():
		memory[target_id]["remaining"] -= delta
		if memory[target_id]["remaining"] <= 0.0:
			memory.erase(target_id)
	visible_target = sense_visible_target()
	var danger := nearby_flare()
	if danger != Vector2.INF:
		visible_target = null
		last_seen = global_position + danger.direction_to(global_position) * 100.0
		transition(State.SEARCH)
		retreat_remaining = 0.8
	if is_instance_valid(visible_target):
		last_seen = visible_target.global_position
		memory[visible_target.get_instance_id()] = {"position": last_seen, "remaining": config.memory_seconds}
		transition(State.CHASE)
		if global_position.distance_to(last_seen) <= config.attack_radius and attack_remaining <= 0.0:
			strike(visible_target)
			if visible_target.status != CampPlayer.Status.ALIVE:
				visible_target = null
				transition(State.SEARCH)
	elif state == State.CHASE:
		transition(State.SEARCH)
	# Tier 1 (Dusk): the headline killer sweeps camp and the inner ring only.
	if tier == 1 and not is_class_cryptid() and state == State.CHASE and last_seen.distance_to(CampMap.CAMP_BOUNDS.get_center()) > INNER_RING:
		visible_target = null
		transition(State.SEARCH)
	var destination := patrol[patrol_index]
	if state != State.PATROL:
		destination = last_seen
	if state == State.CHASE and is_instance_valid(visible_target):
		destination = pursuit_goal(visible_target)
	elif state == State.SEARCH and not search_points.is_empty() and retreat_remaining <= 0:
		destination = search_points[search_index]
	if NavigationServer2D.map_get_iteration_id(agent.get_navigation_map()) > 0:
		destination = NavigationServer2D.map_get_closest_point(agent.get_navigation_map(), destination)
	destination = constrain_destination(destination)
	if camp_closed:
		destination = outside_camp(destination)
	var arrived := global_position.distance_to(destination) < 9.0
	if state == State.PATROL and arrived:
		patrol_index = (patrol_index + 1) % patrol.size()
		destination = patrol[patrol_index]
	elif state == State.INVESTIGATE and arrived:
		transition(State.SEARCH)
	elif state == State.SEARCH:
		if arrived and retreat_remaining <= 0 and not search_points.is_empty():
			search_index = (search_index + 1) % search_points.size()
			destination = search_points[search_index]
			path_clock = 0
		search_remaining -= delta
		if search_remaining <= 0.0:
			transition(State.PATROL)
			destination = patrol[patrol_index]
	path_clock -= delta
	if NavigationServer2D.map_get_iteration_id(agent.get_navigation_map()) == 0:
		return
	if path_clock <= 0.0:
		path_clock = 0.25
		agent.target_position = destination
	velocity = Vector2.ZERO
	if not agent.is_navigation_finished() and not (state == State.SEARCH and arrived):
		var next := agent.get_next_path_position()
		var direction := global_position.direction_to(next)
		facing = direction
		velocity = direction * (config.killer_chase_speed if state == State.CHASE else config.killer_patrol_speed)
		if frenzy > 0.0:
			velocity *= 1.25
		if retreat_remaining > 0:
			velocity = direction * maxf(config.killer_patrol_speed, 82)
	if camp_closed and velocity != Vector2.ZERO and not in_camp(global_position) and in_camp(global_position + velocity.normalized() * 12.0):
		# A route that cuts through camp is refused: turn back to the woods.
		velocity = Vector2.ZERO
		if state != State.PATROL:
			visible_target = null
			transition(State.PATROL)
		patrol_index = (patrol_index + 1) % patrol.size()
		path_clock = 0.0
	var previous := position
	move_and_slide()
	stride += position.distance_to(previous)
	if not arrived and position.distance_to(previous) < 0.1:
		stuck_clock += delta
		if stuck_clock > 1.5:
			# Recompute a reachable route; never teleport through collision.
			path_clock = 0.0
			if state == State.PATROL:
				patrol_index = (patrol_index + 1) % patrol.size()
			else:
				transition(State.SEARCH if state != State.SEARCH else State.PATROL)
			stuck_clock = 0.0
	else:
		stuck_clock = 0.0
	queue_redraw()


func threat_key() -> String:
	return headline


static func in_camp(point: Vector2) -> bool:
	return CampMap.CAMP_BOUNDS.grow(CAMP_MARGIN).has_point(point)


## The nearest point just outside the closed camp.
static func outside_camp(point: Vector2) -> Vector2:
	var rect := CampMap.CAMP_BOUNDS.grow(CAMP_MARGIN + 1.0)
	if not rect.has_point(point):
		return point
	var gaps := [point.x - rect.position.x, rect.end.x - point.x, point.y - rect.position.y, rect.end.y - point.y]
	match gaps.find(gaps.min()):
		0: return Vector2(rect.position.x, point.y)
		1: return Vector2(rect.end.x, point.y)
		2: return Vector2(point.x, rect.position.y)
	return Vector2(point.x, rect.end.y)


## The hunter loop reached `actor` (cryptid brains may replace the hit).
func strike(actor: CampPlayer) -> void:
	if traits != null and traits.strike(actor):
		return
	land_hit(actor, hit_damage)


## Brains: walk toward `point` on the navmesh at `speed`. True once arrived.
func steer(point: Vector2, speed: float, delta: float) -> bool:
	var map := agent.get_navigation_map()
	if NavigationServer2D.map_get_iteration_id(map) == 0:
		velocity = Vector2.ZERO
		return false
	if camp_closed:
		point = outside_camp(point)
	path_clock -= delta
	if path_clock <= 0.0 or agent.target_position.distance_to(point) > 24.0:
		path_clock = 0.25
		agent.target_position = point
	if global_position.distance_to(point) < 8.0 or agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return true
	var direction := global_position.direction_to(agent.get_next_path_position())
	facing = direction
	velocity = direction * speed
	if camp_closed and not in_camp(global_position) and in_camp(global_position + direction * 12.0):
		velocity = Vector2.ZERO
		return true
	var previous := position
	move_and_slide()
	stride += position.distance_to(previous)
	queue_redraw()
	return false


## Strike once; a landed hit starts the cooldown and the recovery pause.
func land_hit(actor: CampPlayer, damage: float) -> bool:
	if not actor.receive_hit(damage):
		attack_remaining = 0.3
		return false
	attack_remaining = hit_cooldown
	recover_remaining = minf(hit_cooldown * 0.5, 2.0)
	return true


## Grab `actor`: they can't move until released or they wriggle free (E).
## Every grab by the same kind of creature is harder than the last: it takes
## GRAB_ESCALATION more presses each time (14, 22, 30… for the stalker).
const GRAB_ESCALATION := 8


func hold(actor: CampPlayer, label: String, per_press: float, decay: float = 0.1) -> void:
	if is_instance_valid(held) and held != actor:
		release_held()
	held = actor
	var times: int = actor.grab_counts.get(label, 0)
	actor.grab_counts[label] = times + 1
	var presses := 1.0 / per_press + GRAB_ESCALATION * times
	actor.grab(self, label, 1.0 / presses, decay)


func release_held() -> void:
	var victim := held
	held = null
	if is_instance_valid(victim) and victim.holder == self:
		victim.release()


## Called by the survivor when they break free or the hold ends.
func on_released(actor: CampPlayer) -> void:
	if held == actor:
		held = null
		carrying = false
		if traits != null:
			traits.humiliated()
		# A struggle that worked leaves the creature reeling for a moment.
		recover_remaining = maxf(recover_remaining, 1.2)


## A flash-stunned creature freezes briefly, then cannot be re-stunned for a while.
func stun(seconds: float) -> bool:
	if stun_immunity > 0.0 or stun_remaining > 0.0:
		return false
	var was_holding := is_instance_valid(held)
	release_held()
	if traits != null and not was_holding:
		traits.humiliated()
	stun_remaining = seconds
	stun_immunity = seconds + 6.0
	velocity = Vector2.ZERO
	visible_target = null
	return true


func draw_stun(top: float) -> void:
	if stun_remaining <= 0.0:
		return
	if PixelArt.fit("fx_stun", Vector2(16, 12)) != null:
		var wobble := Vector2(sin(stun_remaining * 9.0) * 3.0, 0)
		PixelArt.draw_in(self, "fx_stun", Rect2(Vector2(-8, top - 8) + wobble, Vector2(16, 12)))
		return
	for index in range(3):
		var at := Vector2.from_angle(index * TAU / 3 + stun_remaining * 6) * 7 + Vector2(0, top)
		draw_rect(Rect2(at - Vector2.ONE, Vector2(3, 3)), Color("f3e7a8"))


func tick_stun(delta: float) -> bool:
	stun_immunity = maxf(0.0, stun_immunity - delta)
	if stun_remaining <= 0.0:
		return false
	stun_remaining = maxf(0.0, stun_remaining - delta)
	velocity = Vector2.ZERO
	queue_redraw()
	return true


func sense_visible_target() -> CampPlayer:
	var nearest: CampPlayer
	var distance := config.sight_radius
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if not can_sense(actor):
			continue
		if actor.status != CampPlayer.Status.ALIVE or actor.hidden_spot >= 0:
			continue
		if camp_closed and in_camp(actor.global_position):
			continue
		var candidate_distance := global_position.distance_to(actor.global_position)
		if candidate_distance <= distance and has_line_of_sight(actor.global_position):
			distance = candidate_distance
			nearest = actor
	return nearest


func can_sense(_actor: CampPlayer) -> bool:
	return true


func is_class_cryptid() -> bool:
	return false


func fears_flare() -> bool:
	return true


func nearby_flare() -> Vector2:
	if fears_flare():
		for flare in get_tree().get_nodes_in_group("flares"):
			if global_position.distance_to(flare.global_position) < 95 and has_line_of_sight(flare.global_position):
				return flare.global_position
	return Vector2.INF


func has_line_of_sight(point: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, point, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func hear_noise(origin: Vector2) -> void:
	hear_stimulus(origin, config.hearing_radius)


func hear_stimulus(origin: Vector2, radius: float) -> void:
	if not enabled or state == State.CHASE or global_position.distance_to(origin) > radius:
		return
	if camp_closed and in_camp(origin):
		return
	last_seen = origin
	transition(State.INVESTIGATE)
	path_clock = 0


func constrain_destination(point: Vector2) -> Vector2:
	return point


func pursuit_goal(actor: CampPlayer) -> Vector2:
	# Brief prediction uses only an actually visible actor's current movement.
	var lead := actor.global_position + actor.velocity * 0.3
	return lead if has_line_of_sight(lead) else actor.global_position


func transition(next: State) -> void:
	if state == next:
		return
	state = next
	state_changed.emit(next)
	path_clock = 0.0
	if next == State.SEARCH:
		search_remaining = config.search_seconds
		search_index = 0
		search_points.assign([last_seen])
		if is_inside_tree() and NavigationServer2D.map_get_iteration_id(agent.get_navigation_map()) > 0:
			for offset in [Vector2(64, 0), Vector2(0, 64), Vector2(-64, 0), Vector2(0, -64)]:
				search_points.append(NavigationServer2D.map_get_closest_point(agent.get_navigation_map(), last_seen + offset))
	queue_redraw()


func state_label() -> String:
	return State.keys()[state]


func _draw() -> void:
	# The ground shadow fades with the body (it used to stay dark during a fade).
	draw_circle(Vector2(0, 2), 9, Color(0, 0, 0, 0.05 if faded else 0.4))
	draw_stun(-50)
	var row := 0
	if absf(facing.x) > absf(facing.y):
		row = 2 if facing.x > 0 else 3
	elif facing.y < 0:
		row = 1
	var frame := 0 if velocity.length() < 1.0 else 1 + int(stride / 9.0) % 2
	# SpriteCook stalker: 40x48 frames, feet at the body origin like the old 32x40 art.
	var sheet: Texture2D = GROUNDSKEEPER_SHEET if headline == "groundskeeper" else STALKER_SHEET
	var tint := Color.WHITE
	if frenzy > 0.0 and not faded:
		# A pulsing red aura while he's in a frenzy.
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.015)
		draw_circle(Vector2(0, -18), 22.0 + pulse * 4.0, Color(0.9, 0.1, 0.05, 0.18 + pulse * 0.12))
	if faded:
		tint = Color(1, 1, 1, 0.12)
	elif frenzy > 0.0:
		tint = Color(1.0, 0.55 + 0.25 * sin(Time.get_ticks_msec() * 0.02), 0.5)
	draw_texture_rect_region(sheet, Rect2(-20, -44, 40, 48), Rect2(frame * 40, row * 48, 40, 48), tint)
	# No "!"/"?" markers: whether it is hunting you is told by your heartbeat.
