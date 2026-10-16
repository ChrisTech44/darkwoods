class_name CampPickup
extends Node2D

var kind: String = "battery"
var available: bool = true


func consume() -> void:
	available = false
	hide()


func _draw() -> void:
	var color := Color("94c9c3")
	if kind == "fuel":
		color = Color("d6a363")
	elif kind == "key":
		color = Color("e6dc8f")
	draw_circle(Vector2.ZERO, 9, Color(0.8, 0.85, 0.6, 0.1))
	if kind == "battery":
		draw_rect(Rect2(-5, -4, 10, 8), color)
		draw_rect(Rect2(-3, -6, 2, 2), color)
		draw_line(Vector2(1, -1), Vector2(3, -1), Color("253e3b"))
	elif kind == "fuel":
		draw_rect(Rect2(-4, -5, 8, 10), color)
		draw_line(Vector2(-2, -7), Vector2(3, -7), color, 2)
		draw_line(Vector2(-2, 2), Vector2(2, -2), Color("754b3c"), 2)
	else:
		draw_circle(Vector2(-3, 0), 3, color)
		draw_line(Vector2(-1, 0), Vector2(6, 0), color, 2)
		draw_line(Vector2(5, 0), Vector2(5, 3), color, 2)
	draw_string(ThemeDB.fallback_font, Vector2(-16, -12), kind.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)
