extends Node2D

const ATLAS := preload("res://assets/tiles/camp_tiles.png")
var building: CampBuilding
var focus: CampPlayer


func _process(delta: float) -> void:
	if not is_instance_valid(focus):
		return
	var interior := building.bounds.grow(5).has_point(focus.global_position)
	var entrance := Rect2(building.door - Vector2(26, 12), Vector2(52, 40)).has_point(focus.global_position)
	modulate.a = move_toward(modulate.a, 0.0 if interior or entrance else 1.0, delta * 5.0)


func _draw() -> void:
	var rect := building.bounds.grow(8)
	# Soft drop shadow, stepped so it reads as falloff rather than a block.
	for step in range(3):
		draw_rect(Rect2(rect.position + Vector2(4 + step * 2, 8 + step * 2), rect.size), Color(0, 0, 0, 0.16))
	var column := 4 + (building.kind.hash() % 4)
	var tint := Color.WHITE
	if building.kind in ["workshop", "boat"]:
		tint = Color(0.8, 1.0, 1.2)
	elif building.kind in ["ranger", "bath"]:
		tint = Color(0.7, 1.0, 0.8)
	elif building.kind in ["mess", "infirmary"]:
		tint = Color(1.1, 0.75, 0.7)
	# SpriteCook shingles: green-grey for the work/wash buildings, brown elsewhere.
	var shingles := "shingles_green" if building.kind in ["workshop", "boat", "bath", "infirmary"] else "shingles_brown"
	var soft_tint := Color.WHITE.lerp(tint, 0.25)
	# Gable roof: the ridge runs along the long side; the far slope catches the
	# moonlight (upper left), the near slope falls into shade.
	var wide := rect.size.x >= rect.size.y
	var ridge := rect.get_center()
	for y in range(int(rect.position.y), int(rect.end.y), 16):
		for x in range(int(rect.position.x), int(rect.end.x), 16):
			var piece := Rect2(x, y, mini(16, int(rect.end.x) - x), mini(16, int(rect.end.y) - y))
			var near := (piece.get_center().y > ridge.y) if wide else (piece.get_center().x > ridge.x)
			var slope := soft_tint * (Color(0.74, 0.74, 0.78) if near else Color(1.06, 1.04, 1.0))
			slope.a = 1.0
			if not PixelArt.draw_material(self, shingles, piece, slope):
				draw_texture_rect_region(ATLAS, piece, Rect2(column * 16, 32, 16, 16), tint * slope)
	# Weathering: a few seeded moss patches.
	var seed_value := absi(building.label.hash())
	for index in range(3):
		var at := rect.position + Vector2(fposmod(seed_value * (index + 3) * 0.37, rect.size.x - 16) + 8, fposmod(seed_value * (index + 7) * 0.53, rect.size.y - 16) + 8)
		for blob in range(5):
			draw_rect(Rect2((at + Vector2(blob * 2 - 4, (blob * 3) % 4 - 2)).round(), Vector2(2, 1)), Color(0.38, 0.48, 0.3, 0.45))
	# Eaves: dark fascia with a light drip edge on the lit sides.
	draw_rect(rect, Color("1d2723"), false, 2.0)
	draw_line(rect.position + Vector2(1, 1), Vector2(rect.end.x - 1, rect.position.y + 1), Color(0.86, 0.78, 0.6, 0.55), 1.0)
	draw_line(rect.position + Vector2(1, 1), Vector2(rect.position.x + 1, rect.end.y - 1), Color(0.86, 0.78, 0.6, 0.35), 1.0)
	# Ridge cap.
	if wide:
		draw_line(Vector2(rect.position.x + 2, ridge.y), Vector2(rect.end.x - 2, ridge.y), Color("2a2620"), 5)
		draw_line(Vector2(rect.position.x + 2, ridge.y - 1), Vector2(rect.end.x - 2, ridge.y - 1), Color("b8a27a"), 2)
	else:
		draw_line(Vector2(ridge.x, rect.position.y + 2), Vector2(ridge.x, rect.end.y - 2), Color("2a2620"), 5)
		draw_line(Vector2(ridge.x - 1, rect.position.y + 2), Vector2(ridge.x - 1, rect.end.y - 2), Color("b8a27a"), 2)
	# Fieldstone chimney on the lit slope.
	var chimney := Rect2(rect.end.x - 36, rect.position.y + 10, 14, 16)
	draw_rect(chimney.grow(1), Color("1d2420"))
	if not PixelArt.draw_material(self, "cobbles", chimney, Color(0.85, 0.85, 0.82)):
		draw_rect(chimney, Color("6c6a5c"))
	draw_rect(Rect2(chimney.position + Vector2(2, 2), Vector2(10, 5)), Color("141714"))
	draw_rect(Rect2(chimney.position.x - 1, chimney.position.y - 1, chimney.size.x + 2, 2), Color("8e8a76"))
	# Porch awning over the door: a small shingled overhang with its own shadow.
	var awning := Rect2(building.door - Vector2(24, -2), Vector2(48, 13))
	draw_rect(Rect2(awning.position + Vector2(2, 4), awning.size), Color(0, 0, 0, 0.3))
	if not PixelArt.draw_material(self, shingles, awning, soft_tint * Color(0.82, 0.82, 0.86)):
		draw_rect(awning, Color("6b6049"))
	draw_rect(awning, Color("1d2723"), false, 1.0)
	draw_line(Vector2(awning.position.x, awning.end.y), awning.end, Color("b8a27a"), 1.0)
	draw_string(ThemeDB.fallback_font, building.bounds.position + Vector2(14, building.bounds.size.y - 8), building.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.89, 0.8, 0.63, 0.75))
