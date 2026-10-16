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
	if not running or actor.status != CampPlayer.Status.ALIVE or not actor.is_in_group("survivors"):
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
	passengers.append(actor)
	actor.set_status(CampPlayer.Status.BOARDED)
	actor.global_position = global_position + Vector2(0, 4)
	queue_redraw()
	return true


func interaction_point() -> Vector2:
	return global_position + Vector2(0, 30)


func in_range(actor: CampPlayer) -> bool:
	return actor.status == CampPlayer.Status.ALIVE and actor.global_position.distance_to(interaction_point()) <= config.interact_radius


func deliver(actor: CampPlayer) -> int:
	if not in_range(actor) or running:
		return 0
	var delivered := 0
	for part in required_parts:
		if part in actor.inventory and part not in installed:
			actor.inventory.erase(part)
			installed.append(part)
			delivered += 1
	queue_redraw()
	return delivered


func advance_start(actor: CampPlayer, holding: bool, delta: float) -> void:
	if running:
		remaining = maxf(0.0, remaining - delta)
		return
	if not holding or not in_range(actor) or installed.size() != required_parts.size():
		start_progress = 0.0
		return
	start_progress += delta
	if start_progress >= config.start_hold_seconds:
		running = true
		remaining = config.extraction_seconds
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-15, -24, 30, 44), Color("142628"))
	draw_rect(Rect2(-12, -23, 24, 39), Color("7e8c78"))
	draw_rect(Rect2(-11, -23, 22, 4), Color("c4b88a"))
	draw_line(Vector2(-10, -8), Vector2(-10, 13), Color("bbc4a0"))
	draw_line(Vector2(10, -8), Vector2(10, 13), Color("3d574e"))
	draw_rect(Rect2(-9, -17, 18, 8), Color("273f45"))
	draw_line(Vector2(-8, -16), Vector2(3, -16), Color("85a4a0"))
	draw_line(Vector2(-6, -11), Vector2(5, -11), Color("506f71"))
	draw_rect(Rect2(-9, 5, 18, 7), Color("273f45"))
	draw_rect(Rect2(-15, -15, 3, 9), Color("0d1d22"))
	draw_rect(Rect2(12, -15, 3, 9), Color("0d1d22"))
	draw_rect(Rect2(-15, 5, 3, 9), Color("0d1d22"))
	draw_rect(Rect2(12, 5, 3, 9), Color("0d1d22"))
	draw_rect(Rect2(-7, -6, 14, 10), Color("455b4e"))
	draw_rect(Rect2(-6, -5, 6, 8), Color("aa8d5e"))
	draw_rect(Rect2(1, -5, 5, 8), Color("64796b"))
	draw_line(Vector2(-9, -7), Vector2(9, -7), Color("c7bf97"))
	draw_line(Vector2(-9, 4), Vector2(9, 4), Color("c7bf97"))
	draw_rect(Rect2(-11, 13, 5, 2), Color("a66e4e"))
	draw_rect(Rect2(5, 13, 6, 2), Color("a66e4e"))
	draw_rect(Rect2(-5, 16, 10, 2), Color("c6c3a4"))
	for index in range(3):
		draw_rect(Rect2(-7 + index * 6, -5, 3, 3), Color("d4c27c") if index < installed.size() else Color("34493f"))
	if running:
		draw_rect(Rect2(-10, -27, 4, 4), Color("ffe8a4"))
		draw_rect(Rect2(6, -27, 4, 4), Color("ffe8a4"))
		for index in range(passengers.size()):
			draw_rect(Rect2(-7 + index * 4, 7, 2, 3), Color("e2b98c"))
		draw_circle(Vector2(-22, 2), 3, Color("dbc78a"))
		draw_circle(Vector2(22, 2), 3, Color("dbc78a"))
	draw_circle(Vector2(0, 30), 3, Color("c5d0a3"))
