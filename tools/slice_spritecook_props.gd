extends SceneTree
## Slice the SpriteCook forest props sheet (3x3 grid) into the game's sprite files.
## Native pixels are kept; trees are bottom-anchored on 64x80 canvases.
const SHEET := "res://art_sources/spritecook/forest_props_sheet.png"
const OUT := {
	Vector2i(0, 0): ["pine_0", Vector2i(64, 80)], Vector2i(1, 0): ["pine_1", Vector2i(64, 80)], Vector2i(2, 0): ["pine_2", Vector2i(64, 80)],
	Vector2i(0, 1): ["birch", Vector2i(64, 80)], Vector2i(1, 1): ["dead_tree", Vector2i(64, 80)], Vector2i(2, 1): ["spruce", Vector2i(64, 80)],
	Vector2i(0, 2): ["shrub", Vector2i(32, 24)], Vector2i(1, 2): ["boulder", Vector2i(32, 24)], Vector2i(2, 2): ["stump", Vector2i(32, 24)],
}


func _initialize() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	sheet.convert(Image.FORMAT_RGBA8)
	var columns := _bands(sheet, true)
	var rows := _bands(sheet, false)
	print("bands ", columns, " ", rows)
	for cell: Vector2i in OUT:
		var area := Rect2i(columns[cell.x].x, rows[cell.y].x, columns[cell.x].y - columns[cell.x].x, rows[cell.y].y - rows[cell.y].x)
		var used := sheet.get_region(area).get_used_rect()
		var sprite := sheet.get_region(Rect2i(area.position + used.position, used.size))
		var target: Vector2i = OUT[cell][1]
		var canvas_size := Vector2i(maxi(target.x, used.size.x), maxi(target.y, used.size.y))
		var canvas := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
		# Bottom-centred: trunks and bases sit on the same line as the old art.
		canvas.blit_rect(sprite, Rect2i(Vector2i.ZERO, used.size), Vector2i((canvas_size.x - used.size.x) / 2, canvas_size.y - used.size.y))
		var path := "res://assets/sprites/%s.png" % OUT[cell][0]
		canvas.save_png(ProjectSettings.globalize_path(path))
		print("%s %s from %s" % [OUT[cell][0], canvas_size, used.size])
	quit()


## Contiguous runs of non-empty columns (or rows): the grid cells.
func _bands(image: Image, vertical: bool) -> Array[Vector2i]:
	var length := image.get_width() if vertical else image.get_height()
	var span := image.get_height() if vertical else image.get_width()
	var filled: Array[bool] = []
	for a in range(length):
		var any := false
		for b in range(span):
			var pixel := image.get_pixel(a, b) if vertical else image.get_pixel(b, a)
			if pixel.a > 0.1:
				any = true
				break
		filled.append(any)
	var result: Array[Vector2i] = []
	var start := -1
	for a in range(length + 1):
		var on := a < length and filled[a]
		if on and start < 0:
			start = a
		elif not on and start >= 0:
			result.append(Vector2i(start, a))
			start = -1
	return result
