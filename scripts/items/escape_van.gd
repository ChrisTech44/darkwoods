class_name CampVan
extends Node2D

const PARTS: Array[String] = ["battery", "fuel", "key"]
var config: CampConfig = preload("res://assets/default_config.tres")
var installed: Array[String] = []
var start_progress: float = 0.0
var running: bool = false
var remaining: float = 0.0


func interaction_point() -> Vector2:
	return global_position + Vector2(0, 30)


func in_range(actor: CampPlayer) -> bool:
	return actor.status == CampPlayer.Status.ALIVE and actor.global_position.distance_to(interaction_point()) <= config.interact_radius


func deliver(actor: CampPlayer) -> int:
	if not in_range(actor) or running:
		return 0
	var delivered := 0
	for part in PARTS:
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
	if not holding or not in_range(actor) or installed.size() != PARTS.size():
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
	draw_rect(Rect2(-9, -17, 18, 8), Color("273f45"))
	draw_rect(Rect2(-9, 5, 18, 7), Color("273f45"))
	draw_rect(Rect2(-15, -15, 3, 9), Color("0d1d22"))
	draw_rect(Rect2(12, -15, 3, 9), Color("0d1d22"))
	draw_rect(Rect2(-15, 5, 3, 9), Color("0d1d22"))
	draw_rect(Rect2(12, 5, 3, 9), Color("0d1d22"))
	for index in range(3):
		draw_rect(Rect2(-7 + index * 6, -5, 3, 3), Color("d4c27c") if index < installed.size() else Color("34493f"))
	if running:
		draw_rect(Rect2(-10, -27, 4, 4), Color("ffe8a4"))
		draw_rect(Rect2(6, -27, 4, 4), Color("ffe8a4"))
	draw_circle(Vector2(0, 30), 3, Color("c5d0a3"))
