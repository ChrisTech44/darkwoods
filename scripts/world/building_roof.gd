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
	draw_rect(Rect2(rect.position + Vector2(5, 10), rect.size + Vector2(3, 3)), Color(0, 0, 0, 0.45))
	draw_rect(rect.grow(2), Color("283b36"))
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
	for y in range(int(rect.position.y), int(rect.end.y), 16):
		for x in range(int(rect.position.x), int(rect.end.x), 16):
			var piece := Rect2(x, y, mini(16, int(rect.end.x) - x), mini(16, int(rect.end.y) - y))
			if not PixelArt.draw_material(self, shingles, piece, soft_tint):
				draw_texture_rect_region(ATLAS, piece, Rect2(column * 16, 32, 16, 16), tint)
	draw_line(Vector2(rect.position.x, rect.get_center().y), Vector2(rect.end.x, rect.get_center().y), Color("b9a37a"), 3)
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("aa9570"), 2)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, Color("4c493b"), 3)
	draw_rect(Rect2(rect.end.x - 38, rect.position.y + 14, 16, 20), Color("4e5d55"))
	draw_rect(Rect2(rect.end.x - 40, rect.position.y + 12, 20, 5), Color("9a9a80"))
	draw_rect(Rect2(building.door - Vector2(24, -2), Vector2(48, 13)), Color("6b6049"))
	draw_string(ThemeDB.fallback_font, building.bounds.position + Vector2(14, building.bounds.size.y - 8), building.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("e3cda1"))
