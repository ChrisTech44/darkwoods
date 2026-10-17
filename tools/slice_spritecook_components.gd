extends SceneTree
## Slice SpriteCook sheets whose pieces overflow their grid cells: find connected
## opaque shapes, merge specks into the nearest shape, order them row by row and
## save each under its name in assets/sprites/sc/. Overrides grid slices.
## Run: godot --headless --path . --script res://tools/slice_spritecook_components.gd
## name -> [rows, names...]; "" skips a shape.
const SHEETS := {
	"portraits_sheet": [2, "portrait_jock", "portrait_mechanic", "portrait_scout", "portrait_medic", "", "portrait_quiet", "portrait_quartermaster", ""],
	"ui_sheet": [4, "ui_panel", "ui_slot", "ui_slot_selected", "ui_button", "ui_button_hover", "ui_map", "ui_compass", "ui_battery",
		"sky_campfire", "sky_bell", "sky_dome", "sky_bog", "sky_mast", "sky_signal", "ui_badge", "ui_plaque"],
}
const MIN_AREA := 40


func _initialize() -> void:
	for sheet_name: String in SHEETS:
		var image := Image.load_from_file(ProjectSettings.globalize_path("res://art_sources/spritecook/%s.png" % sheet_name))
		image.convert(Image.FORMAT_RGBA8)
		var names: Array = SHEETS[sheet_name].slice(1)
		var rows: int = SHEETS[sheet_name][0]
		var boxes := _components(image)
		var big: Array[Rect2i] = []
		var small: Array[Rect2i] = []
		for box in boxes:
			if box.get_area() >= MIN_AREA:
				big.append(box)
			else:
				small.append(box)
		for speck in small:
			var best := -1
			var gap := INF
			for index in range(big.size()):
				var distance := Vector2(big[index].get_center()).distance_to(Vector2(speck.get_center()))
				if distance < gap:
					gap = distance
					best = index
			if best >= 0 and gap < 40:
				big[best] = big[best].merge(speck)
		var row_height := image.get_height() / rows
		big.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
			var row_a := a.get_center().y / row_height
			var row_b := b.get_center().y / row_height
			return row_a < row_b or row_a == row_b and a.get_center().x < b.get_center().x)
		if big.size() != names.size():
			push_error("%s: found %d shapes for %d names" % [sheet_name, big.size(), names.size()])
			for box in big:
				print(box)
			continue
		for index in range(names.size()):
			if names[index].is_empty():
				continue
			image.get_region(big[index]).save_png(ProjectSettings.globalize_path("res://assets/sprites/sc/%s.png" % names[index]))
			print("%s %s" % [names[index], big[index].size])
	quit()


## Bounding boxes of 8-connected opaque regions.
func _components(image: Image) -> Array[Rect2i]:
	var width := image.get_width()
	var height := image.get_height()
	var seen := PackedByteArray()
	seen.resize(width * height)
	var boxes: Array[Rect2i] = []
	for y in range(height):
		for x in range(width):
			if seen[y * width + x] or image.get_pixel(x, y).a < 0.5:
				continue
			var low := Vector2i(x, y)
			var high := Vector2i(x, y)
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			seen[y * width + x] = 1
			while not stack.is_empty():
				var point: Vector2i = stack.pop_back()
				low = Vector2i(mini(low.x, point.x), mini(low.y, point.y))
				high = Vector2i(maxi(high.x, point.x), maxi(high.y, point.y))
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var next := point + Vector2i(dx, dy)
						if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
							continue
						if seen[next.y * width + next.x] or image.get_pixel(next.x, next.y).a < 0.5:
							continue
						seen[next.y * width + next.x] = 1
						stack.append(next)
			boxes.append(Rect2i(low, high - low + Vector2i.ONE))
	return boxes
