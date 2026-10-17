extends Node2D

var woods: WoodsLayout


func _draw() -> void:
	# Warning gate, broken fencing and footprints at the east approach.
	draw_rect(Rect2(1552, 488, 7, 24), Color("70654c"))
	draw_rect(Rect2(1552, 536, 7, 42), Color("70654c"))
	draw_rect(Rect2(1544, 490, 50, 18), Color("947e53"))
	draw_line(Vector2(1545, 493), Vector2(1592, 493), Color("b9a775"))
	draw_string(ThemeDB.fallback_font, Vector2(1547, 503), "THE WOODS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("242f28"))
	for index in range(6):
		draw_rect(Rect2(1590 + index * 20, 518 + (index % 2) * 7, 3, 5), Color("4c5a43"))
	for index in range(woods.landmarks.size()):
		var landmark: Dictionary = woods.landmarks[index]
		var at: Vector2 = landmark["position"] + Vector2(0, -24)
		draw_circle(at, 20, Color(0.1, 0.15, 0.12, 0.4))
		match index:
			0:
				for root_index in range(6):
					var root := Vector2.from_angle(root_index * TAU / 6)
					draw_line(at + root * 10, at + root * 29 + Vector2(0, 9), Color("625139"), 3)
				draw_rect(Rect2(at - Vector2(18, 20), Vector2(36, 24)), Color("574c38"))
				draw_rect(Rect2(at - Vector2(14, 22), Vector2(28, 6)), Color("a08a60"))
				for ring in range(3):
					draw_arc(at - Vector2(0, 19), 4 + ring * 4, 0, PI, 12, Color("6d603f"))
				for x in range(-15, 18, 5):
					draw_line(at + Vector2(x, -12), at + Vector2(x - 1, 2), Color("8b714e"))
				draw_line(at - Vector2(2, 22), at + Vector2(1, 4), Color("222f28"), 4)
				draw_line(at + Vector2(8, -21), at + Vector2(20, -34), Color("b39a65"), 2)
				draw_rect(Rect2(at + Vector2(16, -35), Vector2(9, 5)), Color("7c8a80"))
			1:
				for x in [-23, 21]:
					draw_rect(Rect2(at + Vector2(x, -10), Vector2(4, 31)), Color("6d5d41"))
				draw_rect(Rect2(at - Vector2(26, 26), Vector2(52, 32)), Color("5f6047"))
				for y in range(-23, 6, 5):
					draw_line(at + Vector2(-25, y), at + Vector2(25, y), Color("8d8360"))
				draw_rect(Rect2(at - Vector2(20, 20), Vector2(40, 9)), Color("1c2b28"))
				draw_line(at - Vector2(3, 20), at - Vector2(3, 11), Color("6c674a"), 2)
				draw_line(at - Vector2(26, 27), at + Vector2(26, -27), Color("98a078"), 3)
				for y in range(6, 23, 5):
					draw_line(at + Vector2(-8, y), at + Vector2(6, y), Color("9b8c60"), 2)
				for x in [-9, 6]:
					draw_line(at + Vector2(x, 5), at + Vector2(x, 23), Color("61573f"), 2)
			2:
				draw_circle(at - Vector2(0, 10), 28, Color("58645b"))
				for stone in range(7):
					var angle := PI + stone * PI / 6
					var rock_at := at + Vector2.from_angle(angle) * 22 - Vector2(0, 7)
					draw_texture_rect(preload("res://assets/sprites/boulder.png"), Rect2(rock_at - Vector2(10, 7), Vector2(20, 14)), false)
				draw_circle(at - Vector2(0, 6), 20, Color("0e1b1b"))
				draw_rect(Rect2(at + Vector2(-28, 8), Vector2(56, 20)), Color("374a38"))
				for vine in range(5):
					draw_line(at + Vector2(-20 + vine * 9, -29), at + Vector2(-22 + vine * 9, -18 + vine % 3 * 4), Color("768359"))
				draw_line(at + Vector2(12, 16), at + Vector2(21, 19), Color("b3b293"), 2)
			3:
				for y in range(-20, 20, 8):
					draw_line(at + Vector2(-36, y), at + Vector2(36, y + 12), Color("85714d"), 3)
				draw_line(at - Vector2(32, 24), at + Vector2(30, 28), Color("b0a171"), 4)
				for rung in range(6):
					draw_line(at + Vector2(-29 + rung * 9, -19 + rung * 6), at + Vector2(-21 + rung * 9, -28 + rung * 6), Color("a99564"), 2)
				draw_rect(Rect2(at + Vector2(18, 17), Vector2(9, 9)), Color("a38d5b"))
				draw_rect(Rect2(at + Vector2(20, 19), Vector2(5, 4)), Color("3c4840"))
			4:
				draw_rect(Rect2(at - Vector2(9, 32), Vector2(18, 42)), Color("738174"))
				draw_rect(Rect2(at - Vector2(19, 26), Vector2(38, 7)), Color("9b9a79"))
				draw_circle(at - Vector2(0, 13), 3, Color("b4a16d"))
				draw_line(at - Vector2(6, 28), at + Vector2(2, 5), Color("455a48"))
				for stone in range(5):
					draw_rect(Rect2(at + Vector2(-18 + stone * 9, 10 + stone % 2 * 4), Vector2(7, 4)), Color("8b9277"))
				for x in [-21, 19]:
					draw_rect(Rect2(at + Vector2(x, 2), Vector2(3, 7)), Color("c3b99b"))
					draw_rect(Rect2(at + Vector2(x, 1), Vector2(3, 1)), Color("3e473b"))
			5:
				for item in range(5):
					draw_texture_rect(preload("res://assets/sprites/boulder.png"), Rect2(at + Vector2(item * 9 - 25, item % 2 * 10 - 16), Vector2(32, 24)), false, Color("92714f"))
				draw_arc(at + Vector2(-16, 10), 10, 0, TAU, 20, Color("6a7d76"), 3)
				for spoke in range(5):
					draw_line(at + Vector2(-16, 10), at + Vector2(-16, 10) + Vector2.from_angle(spoke * TAU / 5) * 9, Color("899786"))
				draw_rect(Rect2(at + Vector2(14, -18), Vector2(9, 12)), Color("9d754b"))
				draw_line(at + Vector2(15, -15), at + Vector2(21, -15), Color("c2ad78"))
		draw_string(ThemeDB.fallback_font, at + Vector2(-38, 32), landmark["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("c2b58b"))
	for post: Dictionary in woods.signposts:
		_signpost(post)
	for lamp: Vector2 in woods.lamps:
		draw_rect(Rect2(lamp + Vector2(-1, -16), Vector2(3, 18)), Color("4a4438"))
		draw_rect(Rect2(lamp + Vector2(-4, -20), Vector2(9, 5)), Color("2d2a24"))
		draw_rect(Rect2(lamp + Vector2(-2, -18), Vector2(5, 2)), Color("f6d58f"))
		draw_rect(Rect2(lamp + Vector2(-3, 2), Vector2(7, 2)), Color("2f2b23"))


func _signpost(post: Dictionary) -> void:
	var at: Vector2 = post["position"]
	draw_rect(Rect2(at + Vector2(-1, -10), Vector2(3, 30)), Color("5d4a33"))
	draw_rect(Rect2(at + Vector2(-2, 18), Vector2(5, 2)), Color("3a3326"))
	var targets: Array = post["targets"]
	for index in range(targets.size()):
		var target: Dictionary = targets[index]
		var step: Vector2i = target["step"]
		var top := at.y - 12 + index * 9
		var board := Rect2(at.x - 22, top, 45, 8)
		var face := Color("b49b69") if index == 0 else Color("8f7d57")
		draw_rect(board, face)
		draw_rect(Rect2(board.position + Vector2(0, 7), Vector2(45, 1)), Color("51432f"))
		# Painted arrow in the board's left notch: the real next trail toward that place.
		var tip := Vector2(board.position.x + 5, top + 4)
		var arrow := Vector2(step).normalized()
		var side := Vector2(-arrow.y, arrow.x)
		draw_colored_polygon(PackedVector2Array([tip + arrow * 3, tip - arrow * 2 + side * 3, tip - arrow * 2 - side * 3]), Color("2a2a22"))
		draw_string(ThemeDB.fallback_font, Vector2(board.position.x + 10, top + 7), target["short"], HORIZONTAL_ALIGNMENT_LEFT, 34, 6, Color("2a2a22"))
