class_name CreatureBrain
extends RefCounted
## One creature's verb (see docs/monster_revamp.md). CampCryptid asks its brain
## first every physics frame and falls back to the shared hunter loop (patrol,
## investigate, chase, hit) when the brain doesn't take the frame. Brains run on
## the host only; clients get `snapshot()` through WorldSync for drawing.
## A brain lives at res://scripts/ai/brains/<species>.gd.

var body: CampCryptid
## Player-facing name (journal, announcements).
var display_name := "Creature"
## One practical tip for the journal.
var tip := ""


static func for_species(species: String) -> CreatureBrain:
	var path := "res://scripts/ai/brains/%s.gd" % species
	if not ResourceLoader.exists(path):
		return null
	return load(path).new()


func level() -> Node:
	return body.get_tree().get_first_node_in_group("round_world")


## Standing, unhidden survivors.
func survivors() -> Array[CampPlayer]:
	var result: Array[CampPlayer] = []
	for actor: CampPlayer in body.get_tree().get_nodes_in_group("survivors"):
		if actor.status == CampPlayer.Status.ALIVE and actor.hidden_spot < 0:
			result.append(actor)
	return result


## Nearest standing survivor this creature can see within `reach`, or null.
func nearest_seen(reach: float) -> CampPlayer:
	var best: CampPlayer
	for actor in survivors():
		var distance := body.global_position.distance_to(actor.global_position)
		if distance <= reach and body.can_sense(actor) and body.has_line_of_sight(actor.global_position) and (best == null or distance < body.global_position.distance_to(best.global_position)):
			best = actor
	return best


## True while `actor`'s flashlight beam is on `point` (lit and roughly facing it).
static func in_beam(actor: CampPlayer, point: Vector2, reach: float = 150.0, cone: float = 0.85) -> bool:
	if not actor.flashlight_on or actor.status != CampPlayer.Status.ALIVE:
		return false
	var offset := point - actor.global_position
	return offset.length() <= reach and actor.facing.dot(offset.normalized()) >= cone


func announce(text: String, recipient: CampPlayer = null) -> void:
	if recipient != null and not text.begins_with("Something big and soft"):
		CreatureSamples.encounter(recipient,body)
	var world: Node = level()
	if world != null:
		world.announce(text, recipient)


## Host-side: every peer hears it once (see CampSoundscape.broadcast).
func cue(name: String, volume: float = 0.0, pitch: float = 1.0, length: float = 0.0) -> void:
	# Complete, observable source windups count as surviving an encounter, even
	# when the survivor correctly dodges. No hidden-source bestiary polling.
	if body.species in ["werewolf","stoneback_ram","shutter_wraith","ration_moth","bramble_seamstress","banshee"]:
		for actor in survivors():
			if actor.global_position.distance_to(body.global_position)<210 and body.has_line_of_sight(actor.global_position):
				CreatureSamples.encounter(actor,body)
	var world: Node = level()
	if world != null and world.soundscape != null:
		world.soundscape.broadcast(name, body.global_position, volume, pitch, length)


## Walk the creature's patrol circuit at `speed`.
func wander(speed: float, delta: float) -> void:
	if body.patrol.is_empty():
		body.velocity = Vector2.ZERO
		return
	if body.steer(body.patrol[body.patrol_index], speed, delta):
		body.patrol_index = (body.patrol_index + 1) % body.patrol.size()


## Run directly away from `point` (to a reachable spot about 220 px off).
func flee_from(point: Vector2, speed: float, delta: float) -> void:
	var away := body.global_position + point.direction_to(body.global_position) * 220.0
	var map := body.agent.get_navigation_map()
	if NavigationServer2D.map_get_iteration_id(map) > 0:
		away = NavigationServer2D.map_get_closest_point(map, away)
	if body.home.has_area():
		away = away.clamp(body.home.position + Vector2.ONE * 16, body.home.end - Vector2.ONE * 16)
	body.steer(away, speed, delta)


## A reachable point near `point` (navmesh), or `point` itself before baking.
func reachable(point: Vector2) -> Vector2:
	var map := body.agent.get_navigation_map()
	if NavigationServer2D.map_get_iteration_id(map) > 0:
		return NavigationServer2D.map_get_closest_point(map, point)
	return point


func setup() -> void:
	pass


## False for creatures a flash can't freeze (the Scarecrow).
func stunnable() -> bool:
	return true


## Return true to take over this frame (the shared hunter loop is skipped).
func physics(_delta: float) -> bool:
	return false


## -1: default sensing; 0: can't sense `actor`; 1: senses them.
func senses(_actor: CampPlayer) -> int:
	return -1


## The hunter loop reached `actor`. Return true when the brain handled it
## (otherwise the creature's ordinary hit lands).
func contact(_actor: CampPlayer) -> bool:
	return false


## Where to run when chasing `actor` (Vector2.INF: straight at them).
func goal(_actor: CampPlayer) -> Vector2:
	return Vector2.INF


func fears_flare() -> bool:
	return true


func on_stunned() -> void:
	pass


func on_released(_actor: CampPlayer) -> void:
	pass


## Draw the creature yourself (return true) instead of the walk sheet.
func draw() -> bool:
	return false


## Drawn after the creature (tells, rings, threads).
func draw_over() -> void:
	pass


func snapshot() -> Dictionary:
	return {}


func restore(_state: Dictionary) -> void:
	pass


## A reserved survivor remains allocated outside the scene tree. Clear direct
## references so no windup, rider or drain can keep using that absent body.
func survivor_left(actor: CampPlayer) -> void:
	if body.species == "hitchhiker" and get("rider_of") == actor:
		call("_hop_off", actor)
	if body.species == "lantern_moth" and get("riding") == actor:
		actor.clear_effect("face_moth")
		call("_let_go")
	for property: Dictionary in get_property_list():
		if property.type == TYPE_OBJECT and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			if get(property.name) == actor: set(property.name, null)
