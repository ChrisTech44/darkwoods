class_name CampKiller
extends CharacterBody2D
## Authority-only senses and FSM. Destinations come from patrol or sensed memory.

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
@onready var agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	add_to_group("killers")


func _physics_process(delta: float) -> void:
	if not enabled:
		velocity = Vector2.ZERO
		return
	attack_remaining = maxf(0.0, attack_remaining - delta)
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
	if is_instance_valid(visible_target):
		last_seen = visible_target.global_position
		memory[visible_target.get_instance_id()] = {"position": last_seen, "remaining": config.memory_seconds}
		transition(State.CHASE)
		if global_position.distance_to(last_seen) <= config.attack_radius and attack_remaining <= 0.0:
			attack_remaining = config.attack_cooldown
			visible_target.receive_hit()
	elif state == State.CHASE:
		transition(State.SEARCH)
	var destination := patrol[patrol_index]
	if state != State.PATROL:
		destination = last_seen
	var arrived := global_position.distance_to(destination) < 9.0
	if state == State.PATROL and arrived:
		patrol_index = (patrol_index + 1) % patrol.size()
		destination = patrol[patrol_index]
	elif state == State.INVESTIGATE and arrived:
		transition(State.SEARCH)
	elif state == State.SEARCH:
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
	var previous := position
	move_and_slide()
	stride += position.distance_to(previous)
	if velocity.length() > 1.0 and position.distance_to(previous) < 0.1:
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


func sense_visible_target() -> CampPlayer:
	var nearest: CampPlayer
	var distance := config.sight_radius
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if not can_sense(actor):
			continue
		if actor.status not in [CampPlayer.Status.ALIVE, CampPlayer.Status.DOWNED]:
			continue
		var candidate_distance := global_position.distance_to(actor.global_position)
		if candidate_distance <= distance and has_line_of_sight(actor.global_position):
			distance = candidate_distance
			nearest = actor
	return nearest


func can_sense(_actor: CampPlayer) -> bool:
	return true


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
	if not enabled or state == State.CHASE or global_position.distance_to(origin) > config.hearing_radius:
		return
	last_seen = origin
	transition(State.INVESTIGATE)


func transition(next: State) -> void:
	if state == next:
		return
	state = next
	path_clock = 0.0
	if next == State.SEARCH:
		search_remaining = config.search_seconds
	queue_redraw()


func state_label() -> String:
	return State.keys()[state]


func _draw() -> void:
	draw_circle(Vector2(0, 2), 9, Color(0, 0, 0, 0.4))
	var row := 0
	if absf(facing.x) > absf(facing.y):
		row = 2 if facing.x > 0 else 3
	elif facing.y < 0:
		row = 1
	var frame := 0 if velocity.length() < 1.0 else 1 + int(stride / 9.0) % 2
	draw_texture_rect_region(preload("res://assets/sprites/stalker.png"), Rect2(-16, -36, 32, 40), Rect2(frame * 32, row * 40, 32, 40))
	var cue := "."
	var color := Color("a7b194")
	if state == State.CHASE:
		cue = "!"
		color = Color("ee947e")
	elif state in [State.INVESTIGATE, State.SEARCH]:
		cue = "?"
		color = Color("dfc18e")
	draw_string(ThemeDB.fallback_font, Vector2(-3, -40), cue, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
