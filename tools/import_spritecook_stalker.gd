extends SceneTree
## Build the stalker walk sheet (3 frames x 4 rows of 40x48) from the SpriteCook
## 2x2 pose grid (down, up / right, left), one shared scale for all directions.
## Run: godot --headless --path . --script res://tools/import_spritecook_stalker.gd
const SHEET := "res://art_sources/spritecook/stalker_sheet.png"
const CELLS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
const CELL := 100
const FRAME := Vector2i(40, 48)
const LEG_ROWS := 9


func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	source.convert(Image.FORMAT_RGBA8)
	var figures: Array[Image] = []
	var factor := INF
	for cell in CELLS:
		var region := source.get_region(Rect2i(cell * CELL, Vector2i(CELL, CELL)))
		var used := region.get_used_rect()
		figures.append(region.get_region(used))
		factor = minf(factor, minf(float(FRAME.y - 1) / used.size.y, float(FRAME.x - 1) / used.size.x))
	var sheet := Image.create(FRAME.x * 3, FRAME.y * 4, false, Image.FORMAT_RGBA8)
	for row in range(4):
		var pose := _pose(figures[row], factor)
		for frame in range(3):
			sheet.blit_rect(_step(pose, frame), Rect2i(Vector2i.ZERO, FRAME), Vector2i(frame * FRAME.x, row * FRAME.y))
	sheet.save_png(ProjectSettings.globalize_path("res://assets/sprites/stalker.png"))
	print("stalker.png scale %.3f" % factor)
	quit()


func _pose(figure: Image, factor: float) -> Image:
	var palette := _palette(figure)
	var size := Vector2i(maxi(1, roundi(figure.get_width() * factor)), maxi(1, roundi(figure.get_height() * factor)))
	var small := figure.duplicate()
	small.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	for y in range(size.y):
		for x in range(size.x):
			var c: Color = small.get_pixel(x, y)
			small.set_pixel(x, y, Color(0, 0, 0, 0) if c.a < 0.5 else _nearest(palette, c))
	var frame := Image.create(FRAME.x, FRAME.y, false, Image.FORMAT_RGBA8)
	frame.blit_rect(small, Rect2i(Vector2i.ZERO, size), Vector2i((FRAME.x - size.x) / 2, FRAME.y - size.y))
	return frame


func _step(pose: Image, frame: int) -> Image:
	if frame == 0:
		return pose
	var out := Image.create(FRAME.x, FRAME.y, false, Image.FORMAT_RGBA8)
	var body := pose.get_region(Rect2i(0, 0, FRAME.x, FRAME.y - LEG_ROWS))
	var legs := pose.get_region(Rect2i(0, FRAME.y - LEG_ROWS, FRAME.x, LEG_ROWS))
	out.blit_rect(body, Rect2i(Vector2i.ZERO, body.get_size()), Vector2i(0, -1))
	out.blend_rect(legs, Rect2i(Vector2i.ZERO, legs.get_size()), Vector2i(-1 if frame == 1 else 1, FRAME.y - LEG_ROWS - 1))
	return out


func _palette(image: Image) -> Array[Color]:
	var seen := {}
	var result: Array[Color] = []
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.5 and not seen.has(c.to_html(false)):
				seen[c.to_html(false)] = true
				result.append(Color(c, 1.0))
	return result


func _nearest(palette: Array[Color], c: Color) -> Color:
	var best: Color = palette[0]
	var best_d := INF
	for p in palette:
		var d: float = (p.r - c.r) * (p.r - c.r) * 0.3 + (p.g - c.g) * (p.g - c.g) * 0.59 + (p.b - c.b) * (p.b - c.b) * 0.11
		if d < best_d:
			best_d = d
			best = p
	return best
