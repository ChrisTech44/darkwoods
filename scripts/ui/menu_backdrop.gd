extends Control
## Animated original pixel forest: moonlit fog, lamp, fireflies and distant eyes.

var time: float = 0.0


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _draw() -> void:
	# SpriteCook title illustration with the original fog and fireflies drifting over it.
	var art := PixelArt.fit("title_art", Vector2(384, 216))
	if art != null:
		draw_texture(art, Vector2.ZERO)
		for index in range(4):
			var y := 128.0 + index * 20 + sin(time * 0.18 + index) * 5
			draw_rect(Rect2(-20 + sin(time * 0.1 + index) * 12, y, 430, 3), Color(0.6, 0.7, 0.6, 0.03))
		for index in range(12):
			var point := Vector2(20 + index * 29, 139 + sin(index * 7.1 + time * 0.4) * 23)
			draw_rect(Rect2(point.round(), Vector2(1, 1)), Color(0.8, 0.86, 0.5, 0.35 + sin(time + index) * 0.2))
		# Translucent so the stalker still watches from behind the menu.
		draw_rect(Rect2(239, 20, 130, 166), Color(0.02, 0.06, 0.06, 0.62))
		draw_line(Vector2(239, 20), Vector2(369, 20), Color("899475"))
		return
	draw_rect(Rect2(0, 0, 384, 216), Color("081318"))
	draw_circle(Vector2(214, 33), 16, Color("798f83"))
	draw_circle(Vector2(220, 29), 15, Color("081318"))
	for index in range(18):
		var x := index * 26 - 12
		draw_texture_rect(preload("res://assets/sprites/pine_1.png"), Rect2(x, 54 + index % 4 * 7, 48, 76), false, Color("334c44"))
	for index in range(9):
		var x := index * 48 - 10
		draw_texture_rect(preload("res://assets/sprites/pine_0.png"), Rect2(x, 92 + index % 3 * 9, 64, 100), false, Color("54644a"))
	draw_colored_polygon(PackedVector2Array([Vector2(112, 216), Vector2(224, 216), Vector2(192, 128), Vector2(176, 128)]), Color("233732"))
	draw_texture_rect_region(preload("res://assets/sprites/camper.png"), Rect2(177, 153, 24, 32), Rect2(0, 32, 24, 32), Color("c6c2a0"))
	draw_colored_polygon(PackedVector2Array([Vector2(190, 165), Vector2(157, 110), Vector2(222, 110)]), Color(0.8, 0.8, 0.5, 0.07))
	for index in range(4):
		var y := 128.0 + index * 20 + sin(time * 0.18 + index) * 5
		draw_rect(Rect2(-20 + sin(time * 0.1 + index) * 12, y, 430, 3), Color(0.6, 0.7, 0.6, 0.025))
	for index in range(12):
		var point := Vector2(20 + index * 29, 139 + sin(index * 7.1 + time * 0.4) * 23)
		draw_rect(Rect2(point.round(), Vector2(1, 1)), Color(0.8, 0.86, 0.5, 0.35 + sin(time + index) * 0.2))
	draw_texture_rect(preload("res://assets/sprites/pine_2.png"), Rect2(-25, 110, 80, 125), false, Color("182b28"))
	draw_texture_rect(preload("res://assets/sprites/pine_0.png"), Rect2(340, 122, 75, 118), false, Color("182b28"))
	draw_rect(Rect2(18, 35, 3, 73), Color("bca56c"))
	draw_rect(Rect2(239, 20, 130, 166), Color(0.02, 0.06, 0.06, 0.85))
	draw_line(Vector2(239, 20), Vector2(369, 20), Color("899475"))
	draw_rect(Rect2(305, 146, 2, 1), Color("bfa27b"))
	draw_rect(Rect2(311, 146, 2, 1), Color("bfa27b"))
