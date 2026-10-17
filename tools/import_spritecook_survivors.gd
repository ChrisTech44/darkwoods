extends SceneTree
## Build the six survivor walk sheets (3 frames x 4 rows of 24x32) from the
## SpriteCook pose grid: area downscale to 31px, snap to each figure's own
## palette, crisp alpha, then a 1px step-bob with alternating leg shift.
## Run: godot --headless --path . --script res://tools/import_spritecook_survivors.gd
const SHEET := "res://art_sources/spritecook/survivors_sheet.png"
const ROLES: Array[String] = ["jock", "mechanic", "scout", "medic", "quiet", "quartermaster"]
const CELL := Vector2i(40, 60)
const FRAME := Vector2i(24, 32)
const HEIGHT := 31
const LEG_ROWS := 7


func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	source.convert(Image.FORMAT_RGBA8)
	for column in range(ROLES.size()):
		var sheet := Image.create(FRAME.x * 3, FRAME.y * 4, false, Image.FORMAT_RGBA8)
		for row in range(4):
			var pose := _pose(source.get_region(Rect2i(column * CELL.x, row * CELL.y, CELL.x, CELL.y)))
			for frame in range(3):
				sheet.blit_rect(_step(pose, frame), Rect2i(Vector2i.ZERO, FRAME), Vector2i(frame * FRAME.x, row * FRAME.y))
		sheet.save_png(ProjectSettings.globalize_path("res://assets/sprites/survivor_%s.png" % ROLES[column]))
		if ROLES[column] == "scout":
			# The menu backdrop's generic camper.
			sheet.save_png(ProjectSettings.globalize_path("res://assets/sprites/camper.png"))
		print("survivor_%s.png" % ROLES[column])
	quit()


func _pose(cell: Image) -> Image:
	var used := cell.get_used_rect()
	var figure := cell.get_region(used)
	var palette := _palette(figure)
	var size := Vector2i(mini(FRAME.x, maxi(1, roundi(used.size.x * float(HEIGHT) / used.size.y))), HEIGHT)
	var small := figure.duplicate()
	small.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	for y in range(size.y):
		for x in range(size.x):
			var c: Color = small.get_pixel(x, y)
			small.set_pixel(x, y, Color(0, 0, 0, 0) if c.a < 0.5 else _nearest(palette, c))
	var frame := Image.create(FRAME.x, FRAME.y, false, Image.FORMAT_RGBA8)
	frame.blit_rect(small, Rect2i(Vector2i.ZERO, size), Vector2i((FRAME.x - size.x) / 2, FRAME.y - size.y))
	return frame


## Frame 0 stands; frames 1-2 bob up 1px with the legs shifted to alternate sides.
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
