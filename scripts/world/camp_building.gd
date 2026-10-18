class_name CampBuilding
extends Node2D
## Detailed pixel floors, timber/brick walls, windows and furnished interiors.

const ATLAS := preload("res://assets/tiles/camp_tiles.png")
var bounds: Rect2
var kind: String = "cabin"
var label: String = "CABIN"
var walls: Array[Rect2] = []
var furnishings: Array[Dictionary] = []
var door: Vector2
var door_rect: Rect2
var roof: Node2D


func configure(rect: Rect2, type: String, title: String) -> void:
	bounds = rect
	kind = type
	label = title
	var thickness := 24.0 if rect.size.y <= 128 else 12.0
	var door_offset := 48.0 if rect.size.x <= 176 else 96.0
	var door_width := 24.0 if rect.size.y <= 128 else 32.0
	door = Vector2(rect.position.x + door_offset + door_width * 0.5, rect.end.y)
	door_rect = Rect2(rect.position.x + door_offset, rect.end.y - thickness, door_width, thickness)
	walls.assign([
		Rect2(rect.position, Vector2(rect.size.x, thickness)),
		Rect2(rect.position, Vector2(thickness, rect.size.y)),
		Rect2(rect.end.x - thickness, rect.position.y, thickness, rect.size.y),
		Rect2(rect.position.x, rect.end.y - thickness, door_offset, thickness),
		Rect2(rect.position.x + door_offset + door_width, rect.end.y - thickness, rect.size.x - door_offset - door_width, thickness)
	])
	if kind in ["ranger", "bunkhouse", "infirmary"]:
		walls.append(Rect2(rect.position + Vector2(rect.size.x * 0.5, thickness), Vector2(10, rect.size.y - 68)))
	if rect.size.y <= 128:
		furnishings = [
			{"type": "bed", "rect": Rect2(rect.position + Vector2(28, 30), Vector2(20, 34))},
			{"type": "desk", "rect": Rect2(rect.position + Vector2(76, 28), Vector2(36, 12))}
		]
	else:
		_furnish()


func _furnish() -> void:
	var origin := bounds.position
	if kind in ["ranger", "bunkhouse", "infirmary"]:
		for y in [28, 94]:
			furnishings.append({"type": "medical" if kind == "infirmary" else "bed", "rect": Rect2(origin + Vector2(24, y), Vector2(32, 50))})
		furnishings.append({"type": "desk", "rect": Rect2(origin + Vector2(bounds.size.x * 0.5 + 36, 28), Vector2(64, 24))})
		furnishings.append({"type": "shelf", "rect": Rect2(origin + Vector2(bounds.size.x - 26, 80), Vector2(14, 48))})
	elif kind == "workshop":
		furnishings = [
			{"type": "bench", "rect": Rect2(origin + Vector2(24, 24), Vector2(80, 24))},
			{"type": "bench", "rect": Rect2(origin + Vector2(140, 24), Vector2(72, 24))},
			{"type": "crate", "rect": Rect2(origin + Vector2(24, 112), Vector2(32, 32))},
			{"type": "shelf", "rect": Rect2(origin + Vector2(204, 88), Vector2(20, 64))}
		]
	elif kind == "mess":
		for x in [32, 148]:
			for y in [56, 120]:
				furnishings.append({"type": "table", "rect": Rect2(origin + Vector2(x, y), Vector2(56, 28))})
		furnishings.append({"type": "stove", "rect": Rect2(origin + Vector2(28, 20), Vector2(100, 24))})
	elif kind == "bath":
		for x in [24, 72, 120]:
			furnishings.append({"type": "shower", "rect": Rect2(origin + Vector2(x, 24), Vector2(28, 40))})
		furnishings.append({"type": "sink", "rect": Rect2(origin + Vector2(20, 108), Vector2(48, 24))})
		walls.append(Rect2(origin + Vector2(16, 88), Vector2(64, 8)))
	elif kind == "boat":
		for x in [24, 164]:
			furnishings.append({"type": "canoe", "rect": Rect2(origin + Vector2(x, 28), Vector2(24, 88))})
		furnishings.append({"type": "bench", "rect": Rect2(origin + Vector2(64, 20), Vector2(72, 20))})


func _draw() -> void:
	draw_rect(Rect2(bounds.position + Vector2(-4, 6), bounds.size + Vector2(8, 6)), Color(0.01, 0.02, 0.02, 0.45))
	var tile := Vector2(4, 1)
	if kind in ["bath", "infirmary"]:
		tile = Vector2(6, 1)
	var floor_material := "bath_tiles" if kind in ["bath", "infirmary"] else "floorboards"
	for y in range(int(bounds.position.y), int(bounds.end.y), 16):
		for x in range(int(bounds.position.x), int(bounds.end.x), 16):
			if not PixelArt.draw_material(self, floor_material, Rect2(x, y, 16, 16)):
				draw_texture_rect_region(ATLAS, Rect2(x, y, 16, 16), Rect2(tile * 16, Vector2(16, 16)))
	# Timber walls: warm-tinted SpriteCook planks, a lit top edge and a shaded base.
	for wall in walls:
		draw_rect(wall.grow(1), Color("1c1a14"))
		for y in range(int(wall.position.y), int(wall.end.y), 16):
			for x in range(int(wall.position.x), int(wall.end.x), 16):
				var piece := Rect2(x, y, mini(16, int(wall.end.x) - x), mini(16, int(wall.end.y) - y))
				if not PixelArt.draw_material(self, "dock_planks", piece, Color(0.82, 0.62, 0.42)):
					draw_rect(piece, Color("6b5638"))
		draw_line(wall.position, Vector2(wall.end.x, wall.position.y), Color(0.86, 0.74, 0.52, 0.8), 1.0)
		draw_line(Vector2(wall.position.x, wall.end.y), wall.end, Color(0.08, 0.08, 0.06, 0.8), 2.0)
	for x in range(int(bounds.position.x) + 32, int(bounds.end.x) - 20, 64):
		var window := Rect2(x, bounds.position.y + 3, 22, 8)
		draw_rect(window.grow(2), Color("2a231a"))
		draw_rect(window, Color("4f6f72"))
		draw_rect(Rect2(window.position + Vector2(1, 1), Vector2(9, 3)), Color(0.72, 0.84, 0.82, 0.55))
		draw_line(window.position + Vector2(11, 0), window.position + Vector2(11, 8), Color("8a7352"), 1.0)
		draw_line(window.position + Vector2(0, 4), window.position + Vector2(22, 4), Color("8a7352"), 1.0)
		draw_rect(Rect2(window.position + Vector2(-2, 9), Vector2(26, 2)), Color("a58b62"))
	for furnishing in furnishings:
		_draw_furniture(furnishing["rect"], furnishing["type"])
	# Plank threshold at the doorway.
	var step := Rect2(door - Vector2(18, 0), Vector2(36, 20))
	for x in range(int(step.position.x), int(step.end.x), 16):
		if not PixelArt.draw_material(self, "dock_planks", Rect2(x, step.position.y, mini(16, int(step.end.x) - x), 20), Color(0.86, 0.72, 0.52)):
			draw_rect(Rect2(x, step.position.y, 16, 20), Color("77684c"))
	draw_rect(step, Color("2a231a"), false, 1.0)
	_draw_plaque()


## The building's name on a post-mounted board beside the door, below the eave
## and clear of the porch awning, so it never fades with the roof or hides
## under it. (The roof and interior no longer paint the name themselves.)
func plaque_rect() -> Rect2:
	var width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 8.0
	var left := door.x + 30.0
	# Keep the board on the building's side of the door when it is near the right wall.
	if left + width > bounds.end.x + 10.0:
		left = door.x - 30.0 - width
	return Rect2(left, bounds.end.y + 11.0, width, 10.0)


func _draw_plaque() -> void:
	var board := plaque_rect()
	var post_x := board.get_center().x
	draw_rect(Rect2(post_x - 1, board.end.y, 2, 6), Color("3b2f22"))
	draw_rect(Rect2(board.position + Vector2(1, 2), board.size), Color(0, 0, 0, 0.35))
	draw_rect(board, Color("c9b07a"))
	draw_rect(board, Color("2e2619"), false, 1.0)
	draw_string(ThemeDB.fallback_font, board.position + Vector2(4, 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("251f16"))


const FURNITURE_ART := {"bed": "bunk", "medical": "cot", "desk": "desk", "crate": "crates", "bench": "workbench",
	"table": "mess_table", "stove": "stove", "shower": "shower", "sink": "basin", "canoe": "canoe_rack"}


func _draw_furniture(rect: Rect2, type: String) -> void:
	draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0, 0, 0, 0.3))
	# SpriteCook furniture fills the collision box, rising above thin footprints (3/4 view).
	var art: String = FURNITURE_ART.get(type, "")
	if type == "shelf":
		art = "bookshelf" if kind == "ranger" else "locker"
	if not art.is_empty():
		var fitted := PixelArt.fit(art, Vector2(rect.size.x, maxf(rect.size.y, rect.size.x * 1.4)))
		if fitted != null:
			var size := fitted.get_size()
			var top := rect.end.y - size.y if size.y > rect.size.y else rect.position.y + (rect.size.y - size.y) * 0.5
			draw_texture(fitted, Vector2(rect.position.x + (rect.size.x - size.x) * 0.5, top).round())
			return
	draw_rect(rect, Color("3d4037"))
	var inset := rect.grow(-2)
	if type in ["bed", "medical"]:
		draw_rect(inset, Color("bfbca0"))
		draw_rect(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 10)), Color("e0d6b6"))
		draw_rect(Rect2(rect.position + Vector2(3, 17), rect.size - Vector2(6, 20)), Color("708a79") if type == "medical" else Color("a66550"))
		for y in range(int(rect.position.y) + 20, int(rect.end.y) - 2, 6):
			draw_line(Vector2(rect.position.x + 3, y), Vector2(rect.end.x - 3, y), Color("bac19c") if type == "medical" else Color("ca9b70"))
	elif type in ["shower", "sink"]:
		draw_rect(inset, Color("a1b5ac"))
		draw_rect(inset.grow(-4), Color("657c79"))
		draw_circle(rect.get_center(), 2, Color("333e3b"))
		draw_rect(Rect2(rect.position + Vector2(4, 2), Vector2(8, 3)), Color("d5cdb1"))
	elif type == "canoe":
		draw_rect(inset, Color("bc8654"))
		draw_rect(inset.grow(-4), Color("674d3a"))
		for y in range(int(rect.position.y) + 14, int(rect.end.y) - 8, 24):
			draw_line(Vector2(rect.position.x + 3, y), Vector2(rect.end.x - 3, y), Color("dac08a"), 3)
	elif type == "shelf":
		draw_rect(inset, Color("796044"))
		for y in range(int(rect.position.y) + 5, int(rect.end.y), 10):
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("bc9c6b"), 2)
			draw_rect(Rect2(rect.position.x + 3, y - 5, 5, 4), Color("a2b6a0"))
	elif type == "crate":
		draw_rect(inset, Color("9b8055"))
		draw_line(rect.position, rect.end, Color("c6ad75"), 2)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color("6c553e"), 2)
	elif type == "stove":
		draw_rect(inset, Color("84958c"))
		for x in range(int(rect.position.x) + 10, int(rect.end.x) - 8, 20):
			draw_circle(Vector2(x, rect.get_center().y), 6, Color("344640"))
			draw_circle(Vector2(x, rect.get_center().y), 3, Color("b6aa7c"))
	else:
		draw_rect(inset, Color("9c8056"))
		draw_line(rect.position + Vector2(3, 4), Vector2(rect.end.x - 3, rect.position.y + 4), Color("c9ae7a"))
		if type == "table":
			draw_circle(rect.position + Vector2(14, 12), 5, Color("d5d0af"))
			draw_circle(rect.position + Vector2(38, 15), 4, Color("b5bca3"))
		else:
			draw_rect(Rect2(rect.position + Vector2(8, 5), Vector2(10, 7)), Color("b5c1a3"))
			draw_rect(Rect2(rect.position + Vector2(24, 6), Vector2(5, 6)), Color("6e9487"))
