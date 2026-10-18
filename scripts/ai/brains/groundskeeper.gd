extends CreatureBrain
## The Groundskeeper: keeps the grounds from a ride-on mower.
## - RIDING: you always hear the engine. He sees only what his headlight shows
##   (a forward cone) plus anything right beside him. On open trail he is faster
##   than a sprint, but the mower has momentum and turns wide: sidestep late and
##   he overshoots. Driving into you runs you over (35 damage and a launch).
## - ON FOOT: lose him behind trees, in a cabin or in a hiding spot and he parks
##   and walks with his rake: slow and quiet, raking every hiding spot near him
##   (anyone inside is dragged out). After a while he walks back to the mower.
## - SABOTAGE: while he is away, hold E at the parked mower for 3 s to pull the
##   spark plug. He is stuck on foot for 90 s, and he heard that.
## Host only; snapshot() carries what clients need to draw.

const DRIVE_SPEED := 125.0
const CRUISE_SPEED := 62.0
const FOOT_PATROL := 34.0
const FOOT_CHASE := 64.0
const ACCELERATION := 150.0
const TURN_RATE := 1.9
const SIGHT_RANGE := 270.0
const SIGHT_CONE := 0.78
const NEAR_SENSE := 46.0
const LOSE_AFTER := 2.4
const RUN_OVER_DAMAGE := 35.0
const RUN_OVER_LAUNCH := 430.0
const RAKE_EVERY := 1.4
const RAKE_REACH := 70.0
const FOOT_SECONDS := 22.0
const PLUG_SECONDS := 3.0
const PLUG_REACH := 30.0
const DEAD_SECONDS := 90.0
const GROUNDSKEEPER_SHEET := preload("res://assets/sprites/groundskeeper.png")
var riding := true
var heading := Vector2.RIGHT
var speed := 0.0
var mower_at := Vector2.ZERO
var mower_heading := Vector2.RIGHT
var target: CampPlayer
var lost_clock := 0.0
var foot_clock := 0.0
var rake_clock := 0.0
var dead := 0.0
var plug: Dictionary = {}
var run_over: Dictionary = {}
var stuck := 0.0
var headlight: PointLight2D


func setup() -> void:
	display_name = "The Groundskeeper"
	tip = "Rides a mower that runs you down on open ground but turns wide: sidestep late, or duck into trees or a cabin. When he walks off to rake for you, pull its spark plug (hold E)."
	body.config.sight_radius = SIGHT_RANGE
	body.config.killer_patrol_speed = FOOT_PATROL
	body.config.killer_chase_speed = FOOT_CHASE
	body.config.search_seconds = 10.0
	mower_at = body.global_position
	headlight = PointLight2D.new()
	headlight.texture = CampLights.texture(true)
	headlight.color = Color("fff0c0")
	headlight.energy = 1.3
	headlight.texture_scale = 200.0 / 128.0
	headlight.shadow_enabled = true
	headlight.position = Vector2(0, -10)
	body.add_child(headlight)


func physics(delta: float) -> bool:
	dead = maxf(0.0, dead - delta)
	for id in run_over.keys():
		run_over[id] -= delta
		if run_over[id] <= 0.0:
			run_over.erase(id)
	_sabotage(delta)
	if riding:
		_ride(delta)
		return true
	# On foot: the ordinary hunter loop does the walking and chasing; the rake
	# checks hiding spots, and in time he goes back for the mower.
	rake_clock -= delta
	if rake_clock <= 0.0:
		rake_clock = RAKE_EVERY
		_rake()
	foot_clock -= delta
	if foot_clock <= 0.0 and dead <= 0.0 and body.state != CampKiller.State.CHASE:
		if body.steer(mower_at, FOOT_CHASE, delta) or body.global_position.distance_to(mower_at) < 14.0:
			_mount()
		return true
	return false


func senses(actor: CampPlayer) -> int:
	if not riding:
		return -1
	return 1 if _in_headlight(actor) else 0


func _in_headlight(actor: CampPlayer) -> bool:
	var offset := actor.global_position - body.global_position
	if offset.length() <= NEAR_SENSE:
		return true
	return offset.length() <= SIGHT_RANGE and heading.dot(offset.normalized()) >= SIGHT_CONE


func _ride(delta: float) -> void:
	var seen := _spot()
	if seen != null:
		target = seen
		lost_clock = 0.0
		body.last_seen = seen.global_position
		body.visible_target = seen
		body.transition(CampKiller.State.CHASE)
	elif is_instance_valid(target):
		lost_clock += delta
		body.visible_target = null
		if lost_clock > LOSE_AFTER or target.hidden_spot >= 0 or _indoors(target.global_position):
			_dismount()
			return
	var goal: Vector2
	var top := CRUISE_SPEED
	if is_instance_valid(target):
		goal = body.last_seen + (target.velocity * 0.25 if seen != null else Vector2.ZERO)
		top = DRIVE_SPEED
	else:
		target = null
		body.transition(CampKiller.State.PATROL)
		if body.patrol.is_empty():
			body.velocity = Vector2.ZERO
			return
		goal = body.patrol[body.patrol_index]
		if body.global_position.distance_to(goal) < 32.0:
			body.patrol_index = (body.patrol_index + 1) % body.patrol.size()
			goal = body.patrol[body.patrol_index]
	_drive(goal, top, delta)
	_run_over()
	mower_at = body.global_position
	mower_heading = heading


## Headlight cone plus right beside him; never into a closed camp.
func _spot() -> CampPlayer:
	var best: CampPlayer
	for actor in survivors():
		if CampKiller.camp_closed and CampKiller.in_camp(actor.global_position):
			continue
		if _in_headlight(actor) and body.has_line_of_sight(actor.global_position):
			if best == null or body.global_position.distance_to(actor.global_position) < body.global_position.distance_to(best.global_position):
				best = actor
	return best


## Momentum steering: the heading turns at TURN_RATE toward the next path
## point; a sharp turn brakes first. Walls bleed speed.
func _drive(goal: Vector2, top: float, delta: float) -> void:
	var map := body.agent.get_navigation_map()
	if NavigationServer2D.map_get_iteration_id(map) == 0:
		body.velocity = Vector2.ZERO
		return
	if CampKiller.camp_closed:
		goal = CampKiller.outside_camp(goal)
	body.path_clock -= delta
	if body.path_clock <= 0.0:
		body.path_clock = 0.3
		body.agent.target_position = goal
	var next := body.agent.get_next_path_position()
	var desired := body.global_position.direction_to(next) if body.global_position.distance_to(next) > 1.0 else heading
	var turn := heading.angle_to(desired)
	var step := TURN_RATE * delta * (2.5 if stuck > 0.8 else 1.0)
	heading = heading.rotated(clampf(turn, -step, step)).normalized()
	var wanted := top * (0.35 if absf(turn) > 1.6 else 1.0)
	speed = move_toward(speed, wanted, ACCELERATION * delta)
	if CampKiller.camp_closed and not CampKiller.in_camp(body.global_position) and CampKiller.in_camp(body.global_position + heading * 16.0):
		speed = 0.0
		heading = -heading
	body.velocity = heading * speed
	body.facing = heading
	var before := body.global_position
	body.move_and_slide()
	body.stride += body.global_position.distance_to(before)
	if body.get_slide_collision_count() > 0:
		speed *= 0.5
	stuck = stuck + delta if body.global_position.distance_to(before) < speed * delta * 0.3 and speed > 10.0 else 0.0
	if stuck > 2.0:
		# Wedged: back off and re-plan.
		heading = desired
		speed = 0.0
		stuck = 0.0
		body.path_clock = 0.0
	headlight.rotation = heading.angle()
	body.queue_redraw()


func _run_over() -> void:
	if speed < 50.0:
		return
	for actor in survivors():
		var id := actor.get_instance_id()
		var offset := actor.global_position - body.global_position
		if run_over.has(id) or offset.length() > 18.0 or heading.dot(offset.normalized()) < -0.2:
			continue
		run_over[id] = 2.0
		actor.invulnerability = 0.0
		actor.receive_hit(RUN_OVER_DAMAGE)
		var side := heading.orthogonal()
		if side.dot(offset) < 0.0:
			side = -side
		actor.shove((heading + side).normalized() * RUN_OVER_LAUNCH)
		speed *= 0.6
		cue("thud", 4.0, 0.8)
		announce("RUN OVER BY THE GROUNDSKEEPER'S MOWER!", actor)


func _dismount() -> void:
	riding = false
	speed = 0.0
	mower_at = body.global_position
	mower_heading = heading
	foot_clock = FOOT_SECONDS
	rake_clock = 0.5
	body.velocity = Vector2.ZERO
	body.visible_target = null
	if is_instance_valid(target):
		body.last_seen = target.global_position
	target = null
	body.transition(CampKiller.State.SEARCH)
	headlight.enabled = false
	cue("monster_8", 0.0, 1.1)


func _mount() -> void:
	riding = true
	body.global_position = mower_at
	heading = mower_heading
	speed = 0.0
	headlight.enabled = true
	body.transition(CampKiller.State.PATROL)
	cue("car_start", -4.0, 1.6)


## The rake: anyone hiding within reach is dragged out.
func _rake() -> void:
	var world: Node = level()
	if world == null or world.props == null:
		return
	for actor: CampPlayer in body.get_tree().get_nodes_in_group("survivors"):
		if actor.hidden_spot < 0 or actor.hidden_spot >= world.props.spots.size():
			continue
		var at: Vector2 = world.props.spots[actor.hidden_spot]["position"]
		if body.global_position.distance_to(at) <= RAKE_REACH and body.has_line_of_sight(at):
			world.props.leave(actor)
			body.last_seen = actor.global_position
			body.transition(CampKiller.State.CHASE)
			cue("wood_falling", 0.0, 1.5)
			announce("THE GROUNDSKEEPER'S RAKE FINDS YOU! Out you come.", actor)


func _indoors(point: Vector2) -> bool:
	var world: Node = level()
	if world == null:
		return false
	for building: CampBuilding in world.camp_map.buildings + world.camp_map.forest_buildings:
		if building.bounds.has_point(point):
			return true
	return false


## The E prompt beside a parked, working mower ("" otherwise).
func prompt(actor: CampPlayer) -> String:
	if riding or dead > 0.0 or actor.global_position.distance_to(mower_at) > PLUG_REACH:
		return ""
	return "HOLD E · PULL THE MOWER'S SPARK PLUG %d%%" % int(plug.get(actor.get_instance_id(), 0.0) / PLUG_SECONDS * 100.0)


func interact(_actor: CampPlayer) -> bool:
	return true


func _sabotage(delta: float) -> void:
	var world: Node = level()
	if world == null:
		return
	for actor in survivors():
		var id := actor.get_instance_id()
		if prompt(actor).is_empty() or not world.holding(actor):
			plug.erase(id)
			continue
		plug[id] = plug.get(id, 0.0) + delta
		if plug[id] >= PLUG_SECONDS:
			plug.clear()
			dead = DEAD_SECONDS
			foot_clock = DEAD_SECONDS
			if "mower" not in world.feats:
				world.feats.append("mower")
			world.loud_noise(mower_at, 380.0)
			cue("metal_clang", 2.0, 1.4)
			world.announce("SPARK PLUG PULLED! The mower is dead for 90 s, and the Groundskeeper heard it.")
			return


func contact(actor: CampPlayer) -> bool:
	# On foot: a swing of the rake.
	if not riding and body.land_hit(actor, 25.0):
		actor.shove(body.global_position.direction_to(actor.global_position) * 260.0)
	return true


func fears_flare() -> bool:
	return not riding


func draw() -> bool:
	var row := 0
	var look := heading if riding else body.facing
	if absf(look.x) > absf(look.y):
		row = 2 if look.x > 0 else 3
	elif look.y < 0:
		row = 1
	if riding:
		_draw_mower(Vector2.ZERO, heading)
		# He sits on it: just the upper body shows above the seat.
		body.draw_texture_rect_region(GROUNDSKEEPER_SHEET, Rect2(-20, -44, 40, 28), Rect2(0, row * 48, 40, 28))
		return true
	_draw_mower(body.to_local(mower_at), mower_heading, Color(0.7, 0.7, 0.7) if dead > 0.0 else Color.WHITE)
	var frame := 0 if body.velocity.length() < 1.0 else 1 + int(body.stride / 9.0) % 2
	body.draw_circle(Vector2(0, 2), 9, Color(0, 0, 0, 0.35))
	body.draw_texture_rect_region(GROUNDSKEEPER_SHEET, Rect2(-20, -44, 40, 48), Rect2(frame * 40, row * 48, 40, 48))
	# The rake over his shoulder.
	body.draw_line(Vector2(8, -30), Vector2(18, 0), Color("8a6a44"), 2.0)
	body.draw_line(Vector2(13, 0), Vector2(23, 0), Color("9aa0a0"), 2.0)
	return true


func _draw_mower(at: Vector2, toward: Vector2, tint := Color.WHITE) -> void:
	var name := "mower_front" if toward.y > 0.6 else ("mower_back" if toward.y < -0.6 else "mower_side")
	var texture: Texture2D = PixelArt.fit(name, Vector2(48, 40) if name == "mower_side" else Vector2(30, 36))
	if texture == null:
		body.draw_rect(Rect2(at + Vector2(-16, -16), Vector2(32, 18)), Color("4b6a3c"))
		return
	var size := texture.get_size()
	var rect := Rect2(Vector2(-size.x * 0.5, -size.y + 4), size)
	# The side view faces right; mirror it when he drives left.
	body.draw_set_transform(at, 0.0, Vector2(-1, 1) if name == "mower_side" and toward.x < 0.0 else Vector2.ONE)
	body.draw_texture_rect(texture, rect, false, tint)
	body.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if dead > 0.0 and at != Vector2.ZERO:
		body.draw_string(ThemeDB.fallback_font, at + Vector2(-12, -size.y - 2), "DEAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("c9b07a"))


func snapshot() -> Dictionary:
	return {"riding": riding, "heading": heading, "mower_at": mower_at, "mower_heading": mower_heading, "dead": dead}


func restore(state: Dictionary) -> void:
	riding = state.get("riding", riding)
	heading = state.get("heading", heading)
	mower_at = state.get("mower_at", mower_at)
	mower_heading = state.get("mower_heading", mower_heading)
	dead = state.get("dead", dead)
	if headlight != null:
		headlight.enabled = riding
		headlight.rotation = heading.angle()
