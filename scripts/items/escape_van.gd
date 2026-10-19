class_name CampVan
extends Node2D

const PARTS: Array[String] = ["battery", "fuel", "key"]
var required_parts: Array[String] = ["battery", "fuel", "key"]
var config: CampConfig = preload("res://assets/default_config.tres")
var installed: Array[String] = []
var start_progress: float = 0.0
var running: bool = false
var remaining: float = 0.0
var passengers: Array[CampPlayer] = []
var headlights: Array[PointLight2D] = []
var start_actor: CampPlayer
var engine_clock: float = 0.0


func _ready() -> void:
	for x in [-8, 8]:
		var light := PointLight2D.new()
		light.position = Vector2(x, -25)
		light.rotation = -PI * 0.5
		light.texture = CampLights.texture(true)
		light.texture_scale = 1.8
		light.color = Color("ffe8a9")
		light.energy = 2.0
		light.shadow_enabled = true
		light.enabled = false
		headlights.append(light)
		add_child(light)


func _process(delta: float) -> void:
	engine_clock += delta
	for light in headlights:
		light.enabled = running
	if running:
		queue_redraw()


func boarding_points() -> Array[Vector2]:
	return [global_position + Vector2(-22, 2), global_position + Vector2(22, 2), interaction_point()]


func can_board(actor: CampPlayer) -> bool:
	if not running or actor.status != CampPlayer.Status.ALIVE or not actor.is_in_group("survivors") or not CreatureSamples.can_interact(actor):
		return false
	for point in boarding_points():
		if actor.global_position.distance_to(point) <= config.boarding_radius:
			var query := PhysicsRayQueryParameters2D.create(actor.global_position, point, 1)
			if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
				return true
	return false


func board(actor: CampPlayer) -> bool:
	if not can_board(actor) or actor in passengers:
		return false
	SurvivorKits.settle(actor)
	if actor.status != CampPlayer.Status.ALIVE: return false
	passengers.append(actor)
	actor.set_status(CampPlayer.Status.BOARDED)
	actor.global_position = global_position + Vector2(0, 4)
	queue_redraw()
	return true


func interaction_point() -> Vector2:
	return global_position + Vector2(0, 30)


func in_range(actor: CampPlayer) -> bool:
	return actor.status == CampPlayer.Status.ALIVE and CreatureSamples.can_interact(actor) and actor.global_position.distance_to(interaction_point()) <= config.interact_radius


func deliver(actor: CampPlayer) -> int:
	if not in_range(actor) or running:
		return 0
	var delivered := 0
	for part in required_parts:
		if part in actor.inventory and part not in installed:
			actor.inventory.erase(part)
			installed.append(part)
			SurvivorKits.progress(actor,"van:"+part)
			delivered += 1
	queue_redraw()
	return delivered


func advance_start(actor: CampPlayer, holding: bool, delta: float) -> void:
	if running:
		remaining = maxf(0.0, remaining - delta)
		return
	if not holding or not in_range(actor) or installed.size() != required_parts.size():
		start_progress = 0.0
		start_actor = null
		return
	if start_actor != actor:
		start_progress = 0
		start_actor = actor
	start_progress += delta
	if start_progress >= actor.config.start_hold_seconds:
		running = true
		remaining = config.extraction_seconds
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, 8), 22, Color(0, 0, 0, 0.25))
	# SpriteCook camp van; the procedural body remains only as a fallback.
	if not PixelArt.draw_in(self, "van", Rect2(-27, -32, 54, 52)):
		draw_rect(Rect2(-15, -24, 30, 44), Color("142628"))
		draw_rect(Rect2(-12, -23, 24, 39), Color("7e8c78"))
	# Installed-part lamps on a dashboard plate under the van.
	draw_rect(Rect2(-3.5 * required_parts.size() - 2, 21, required_parts.size() * 7 + 3, 6), Color("1d2723"))
	for index in range(required_parts.size()):
		draw_rect(Rect2(-3.5 * required_parts.size() + index * 7, 22, 4, 4), Color("e6cf7c") if index < installed.size() else Color("3b4a42"))
	if running:
		draw_rect(Rect2(-10, -27, 4, 4), Color("ffe8a4"))
		draw_rect(Rect2(6, -27, 4, 4), Color("ffe8a4"))
		for index in range(passengers.size()):
			draw_rect(Rect2(-7 + index * 4, 7, 2, 3), Color("e2b98c"))
		draw_circle(Vector2(-22, 2), 3, Color("dbc78a"))
		draw_circle(Vector2(22, 2), 3, Color("dbc78a"))
	draw_circle(Vector2(0, 30), 3, Color("c5d0a3"))
