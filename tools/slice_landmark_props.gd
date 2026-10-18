extends SceneTree
## Slice the SpriteCook landmark/mower sheet (asset 906d4691) into sprites.
## The sheet is not a regular grid, so each piece has a hand-measured source
## rect; the opaque bounds inside it are trimmed. Native pixels are kept.
const SHEET := "res://art_sources/spritecook/landmarks_mower_sheet.png"
const PIECES := {
	"relic_mill": Rect2i(0, 0, 60, 66), "relic_orchard": Rect2i(62, 0, 64, 66), "relic_chapel": Rect2i(132, 0, 48, 66),
	"relic_observatory": Rect2i(0, 66, 60, 60), "relic_rail": Rect2i(64, 66, 58, 60), "relic_quarry": Rect2i(126, 66, 62, 60),
	"mower_side": Rect2i(0, 126, 116, 62), "mower_front": Rect2i(128, 126, 54, 62), "mower_back": Rect2i(190, 126, 56, 62),
}


## Region entrance markers (asset c16cb703): a regular 3x3 grid.
const ENTRANCES := "res://art_sources/spritecook/region_entrances_sheet.png"
const ENTRANCE_NAMES := ["village", "bog", "graveyard", "mill", "orchard", "chapel", "observatory", "rail", "quarry"]


func _initialize() -> void:
	var grid := Image.load_from_file(ProjectSettings.globalize_path(ENTRANCES))
	grid.convert(Image.FORMAT_RGBA8)
	var cell := Vector2i(grid.get_width() / 3, grid.get_height() / 3)
	for index in range(ENTRANCE_NAMES.size()):
		var region := grid.get_region(Rect2i(Vector2i(index % 3, index / 3) * cell, cell))
		var trimmed := region.get_region(region.get_used_rect())
		trimmed.save_png(ProjectSettings.globalize_path("res://assets/sprites/sc/entry_%s.png" % ENTRANCE_NAMES[index]))
		print("entry_%s %s" % [ENTRANCE_NAMES[index], trimmed.get_size()])
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	sheet.convert(Image.FORMAT_RGBA8)
	for name: String in PIECES:
		var area: Rect2i = PIECES[name]
		var region := sheet.get_region(area)
		var used := region.get_used_rect()
		var sprite := region.get_region(used)
		sprite.save_png(ProjectSettings.globalize_path("res://assets/sprites/sc/%s.png" % name))
		print("%s %s" % [name, used.size])
	quit()
