extends SceneTree
## Cut SpriteCook seamless-texture grids into assets/tiles/tex_<name>.png, clear of
## the 1-2px divider lines, resampled (palette-snapped) to a 16px multiple so
## renderers can sample world-aligned 16px tiles without visible seams.
## Run: godot --headless --path . --script res://tools/import_spritecook_textures.gd
const SHEETS := {
	"ground_textures_sheet": {"grid": 2, "size": 96, "names": ["grass", "forest_floor", "trail", "road"]},
	"material_textures_sheet": {"grid": 3, "size": 64, "names": ["floorboards", "bath_tiles", "shingles_brown",
		"shingles_green", "water", "cobbles", "bog_mud", "dead_grass", "flagstones"]},
	"surface_textures_sheet": {"grid": 3, "size": 64, "names": ["asphalt", "quarry_gravel", "mossy_flagstones",
		"court_tiles", "orchard_soil", "dock_planks", "lawn", "leaf_litter", "mossy_floor"]},
}


func _initialize() -> void:
	for sheet_name: String in SHEETS:
		var spec: Dictionary = SHEETS[sheet_name]
		var image := Image.load_from_file(ProjectSettings.globalize_path("res://art_sources/spritecook/%s.png" % sheet_name))
		image.convert(Image.FORMAT_RGBA8)
		var grid: int = spec["grid"]
		var columns := _cuts(image, grid, true)
		var rows := _cuts(image, grid, false)
		var names: Array = spec["names"]
		for index in range(names.size()):
			var cx := index % grid
			var cy := index / grid
			# Two pixels inside each divider so no line survives into the tile.
			var rect := Rect2i(columns[cx] + 2, rows[cy] + 2, columns[cx + 1] - columns[cx] - 4, rows[cy + 1] - rows[cy] - 4)
			var tile := image.get_region(rect)
			var size: int = spec["size"]
			tile = _snap_resize(tile, Vector2i(size, size))
			tile.save_png(ProjectSettings.globalize_path("res://assets/tiles/tex_%s.png" % names[index]))
			print("tex_%s from %s" % [names[index], rect])
	quit()


## Cell boundaries: 0, the darkest line near each expected divider, and the edge.
func _cuts(image: Image, grid: int, vertical: bool) -> Array[int]:
	var length := image.get_width() if vertical else image.get_height()
	var span := image.get_height() if vertical else image.get_width()
	var result: Array[int] = [-2]
	for divider in range(1, grid):
		var expected := length * divider / grid
		var best := expected
		var low := INF
		for at in range(expected - 5, expected + 6):
			var sum := 0.0
			for b in range(span):
				sum += (image.get_pixel(at, b) if vertical else image.get_pixel(b, at)).v
			if sum < low:
				low = sum
				best = at
		result.append(best)
	result.append(length + 1)
	return result


func _snap_resize(source: Image, size: Vector2i) -> Image:
	var palette: Array[Color] = []
	var seen := {}
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			var c: Color = source.get_pixel(x, y)
			if not seen.has(c.to_html(false)):
				seen[c.to_html(false)] = true
				palette.append(Color(c, 1.0))
	var small := source.duplicate()
	small.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	for y in range(size.y):
		for x in range(size.x):
			var c: Color = small.get_pixel(x, y)
			var best: Color = palette[0]
			var best_d := INF
			for p in palette:
				var d: float = (p.r - c.r) * (p.r - c.r) * 0.3 + (p.g - c.g) * (p.g - c.g) * 0.59 + (p.b - c.b) * (p.b - c.b) * 0.11
				if d < best_d:
					best_d = d
					best = p
			small.set_pixel(x, y, best)
	return small
