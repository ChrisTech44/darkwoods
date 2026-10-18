extends SceneTree
## Slice SpriteCook object grids (equal cells) into trimmed native-resolution
## sprites under assets/sprites/sc/. Runtime sizing happens in PixelArt.fit().
## Run: godot --headless --path . --script res://tools/slice_spritecook_grid.gd
## then tools/slice_spritecook_components.gd, which replaces the ui_* slices.
const GRIDS := {
	"items_sheet": ["battery", "fuel", "key", "fuse", "belt", "tire", "spark_plug", "boltcutters",
		"crowbar", "flare", "battery_pack", "rations", "medkit", "noise_tin", "salt_ward", "glow_moss"],
	"camp_objects_sheet": ["van", "tent", "campfire", "cache_crate", "generator", "lamp_post", "notice_board", "picnic_table",
		"outhouse", "canoe", "woodpile", "barrel", "signpost", "fence", "gate", "toolbox"],
	"furniture_sheet": ["bunk", "desk", "locker", "crates", "workbench", "mess_table", "stove", "shower",
		"basin", "cot", "bench", "bookshelf", "canoe_rack", "rug", "chair", "nightstand"],
	"landmarks_sheet": ["bell_frame", "well", "cauldron", "crypt", "gravestone", "grave_cross", "altar", "waterwheel",
		"observatory", "rail_signal", "column", "shrine", "hunter_blind", "cave", "watchtower", "scrap_pile"],
	"night_props_sheet": ["pyre", "pyre_lit", "kerosene_1", "flare_gun", "snare", "snare_sprung", "gift_crate", "signpost_arrows",
		"helicopter", "apple_tree", "trellis", "mossy_log", "tire_stack", "drum_side", "cooler", "glow_mushrooms"],
	"ground_decals_sheet": ["decal_grass_tall", "decal_grass_short", "decal_fern", "decal_clover", "decal_rock", "decal_pebbles", "decal_mossy_stone", "decal_root",
		"decal_leaves", "decal_needles", "decal_puddle", "decal_flowers", "decal_mushrooms", "decal_dry_grass", "decal_weeds", "decal_branch"],
	"world_objects_sheet": ["fence_h", "fence_v", "gate_closed", "gate_open", "door_closed", "door_broken", "woodpile_fallen", "rail_track",
		"helipad", "barrier_raised", "abandoned_car", "scarecrow", "fire_pit", "totem", "fallen_tree", "torn_tent"],
	"forest_dressing_sheet": ["rock_formation", "ferns", "berry_bush", "fairy_ring", "hollow_log", "hunting_stand", "missing_poster", "cooking_pot",
		"broken_canoe", "old_bench", "birdhouse", "bone_pile", "standing_stones", "bicycle", "lantern_post_old", "forest_shrine"],
	"effects_sheet": ["fx_flare", "fx_blood", "fx_blood_trail", "fx_tin", "fx_hex", "fx_thorns", "fx_pin", "fx_help",
		"fx_mark", "fx_ripple", "fx_ember", "fx_footprints", "fx_stun", "fx_alert", "fx_suspicion", "fx_skull"],
	"ui_sheet": ["ui_panel", "ui_slot", "ui_slot_selected", "ui_button", "ui_button_hover", "ui_map", "ui_compass", "ui_battery",
		"sky_campfire", "sky_bell", "sky_dome", "sky_bog", "sky_mast", "sky_signal", "ui_badge", "ui_plaque"],
	"monster_items_sheet": ["garlic", "wolfsbane", "bug_spray", "scissors", "train_ticket", "air_horn", "coffee", "bigfoot_fur",
		"bear_trap", "bear_trap_sprung", "hook_post", "mud_puddle", "jackal_den", "moon_icon", "frog", "heart_patch"],
	"gateway_sheet": ["gateway_closed", "gateway_open", "trail_lantern", "rail_fence"],
	"gateway_vertical_sheet": ["fence_run_v", "gateway_v_closed", "", "fence_post"],
}
## Sprites derived from a slice: [source, first row, last row] as fractions of
## its height, cleared to leave only the ends (an open edge-on gate: two posts).
const OPENED := {"gateway_v_open": ["gateway_v_closed", 0.2, 0.8]}
## Sheets that are not 4x4 grids: cells per row (rows match).
const COLUMNS := {"gateway_sheet": 2, "gateway_vertical_sheet": 2}
## Extra copies for objective kinds that share one picture.
const ALIASES := {"kerosene_2": "kerosene_1"}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/sc"))
	for sheet_name: String in GRIDS:
		var sheet := Image.load_from_file(ProjectSettings.globalize_path("res://art_sources/spritecook/%s.png" % sheet_name))
		sheet.convert(Image.FORMAT_RGBA8)
		var columns: int = COLUMNS.get(sheet_name, 4)
		var cell := Vector2i(sheet.get_width() / columns, sheet.get_height() / columns)
		var names: Array = GRIDS[sheet_name]
		for index in range(names.size()):
			if names[index].is_empty():
				continue
			var region := sheet.get_region(Rect2i((index % columns) * cell.x, (index / columns) * cell.y, cell.x, cell.y))
			var used := region.get_used_rect()
			region.get_region(used).save_png(ProjectSettings.globalize_path("res://assets/sprites/sc/%s.png" % names[index]))
			print("%s %s" % [names[index], used.size])
	for derived: String in OPENED:
		var spec: Array = OPENED[derived]
		var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/sc/%s.png" % spec[0]))
		for y in range(int(image.get_height() * spec[1]), int(image.get_height() * spec[2])):
			for x in range(image.get_width()):
				image.set_pixel(x, y, Color(0, 0, 0, 0))
		image.save_png(ProjectSettings.globalize_path("res://assets/sprites/sc/%s.png" % derived))
		print("%s from %s" % [derived, spec[0]])
	for alias: String in ALIASES:
		DirAccess.copy_absolute(ProjectSettings.globalize_path("res://assets/sprites/sc/%s.png" % ALIASES[alias]), ProjectSettings.globalize_path("res://assets/sprites/sc/%s.png" % alias))
	quit()
