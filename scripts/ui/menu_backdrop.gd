extends Control
## Original geometric placeholder artwork, drawn in the 384 x 216 viewport.
## This is scenery only; world collision and navigation belong to M1.


func _draw() -> void:
	draw_rect(Rect2(0, 0, 384, 216), Color("0c171e"))
	draw_rect(Rect2(0, 122, 384, 94), Color("13272a"))
	for x in range(8, 384, 29):
		_tree(Vector2(x, 167 + (x % 13)), 34, Color("1b3434"))
	for x in range(-10, 394, 47):
		_tree(Vector2(x, 195 + (x % 9)), 48, Color("102426"))
	# Moon and a few deliberately placed stars.
	draw_rect(Rect2(323, 20, 13, 13), Color("9eaa8a"))
	draw_rect(Rect2(319, 17, 13, 13), Color("0c171e"))
	for point in [Vector2(245, 22), Vector2(288, 39), Vector2(358, 29)]:
		draw_rect(Rect2(point, Vector2(1, 1)), Color("7c9386"))
	# Cabin, warm window, and a path disappearing into the trees.
	draw_colored_polygon(PackedVector2Array([
		Vector2(99, 216), Vector2(150, 216), Vector2(116, 169), Vector2(107, 169)
	]), Color("263837"))
	draw_rect(Rect2(84, 145, 54, 29), Color("303e36"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(78, 147), Vector2(111, 130), Vector2(145, 147)
	]), Color("09191d"))
	draw_rect(Rect2(106, 154, 10, 20), Color("101f22"))
	draw_rect(Rect2(91, 153, 9, 8), Color("b59757"))
	draw_rect(Rect2(95, 153, 1, 8), Color("394037"))
	draw_rect(Rect2(91, 156, 9, 1), Color("394037"))
	_tree(Vector2(26, 224), 70, Color("08171b"))
	_tree(Vector2(355, 228), 67, Color("08171b"))


func _tree(base: Vector2, height: float, color: Color) -> void:
	draw_rect(Rect2(base.x - 2, base.y - 12, 4, 16), color)
	for tier in range(3):
		var top := base + Vector2(0, -height + tier * height * 0.21)
		var width := 9.0 + tier * 5.0
		draw_colored_polygon(PackedVector2Array([
			top, top + Vector2(-width, height * 0.48),
			top + Vector2(width, height * 0.48)
		]), color)
