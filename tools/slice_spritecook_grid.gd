extends SceneTree
## Slice SpriteCook object grids (equal cells) into trimmed native-resolution
## sprites under assets/sprites/sc/. Runtime sizing happens in PixelArt.fit().
## Run: godot --headless --path . --script res://tools/slice_spritecook_grid.gd
const GRIDS := {
	"items_sheet": ["battery", "fuel", "key", "fuse", "belt", "tire", "spark_plug", "boltcutters",
		"crowbar", "flare", "battery_pack", "rations", "medkit", "noise_tin", "salt_ward", "glow_moss"],
	"camp_objects_sheet": ["van", "tent", "campfire", "cache_crate", "generator", "lamp_post", "notice_board", "picnic_table",
		"outhouse", "canoe", "woodpile", "barrel", "signpost", "fence", "gate", "toolbox"],
	"furniture_sheet": ["bunk", "desk", "locker", "crates", "workbench", "mess_table", "stove", "shower",
		"basin", "cot", "bench", "bookshelf", "canoe_rack", "rug", "chair", "nightstand"],
	"landmarks_sheet": ["bell_frame", "well", "cauldron", "crypt", "gravestone", "grave_cross", "altar", "waterwheel",
		"observatory", "rail_signal", "column", "shrine", "hunter_blind", "cave", "watchtower", "scrap_pile"],
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/sc"))
	for sheet_name: String in GRIDS:
		var sheet := Image.load_from_file(ProjectSettings.globalize_path("res://art_sources/spritecook/%s.png" % sheet_name))
		sheet.convert(Image.FORMAT_RGBA8)
		var cell := Vector2i(sheet.get_width() / 4, sheet.get_height() / 4)
		var names: Array = GRIDS[sheet_name]
		for index in range(names.size()):
			var region := sheet.get_region(Rect2i((index % 4) * cell.x, (index / 4) * cell.y, cell.x, cell.y))
			var used := region.get_used_rect()
			region.get_region(used).save_png(ProjectSettings.globalize_path("res://assets/sprites/sc/%s.png" % names[index]))
			print("%s %s" % [names[index], used.size])
	quit()
