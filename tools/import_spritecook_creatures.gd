extends SceneTree
## Build the creature walk sheets (3 frames x 4 rows of 64x64: down, up,
## right, left) from four SpriteCook 4x4 pose grids (columns = species).
## Side views that came back facing the wrong way are fixed per species.
## Run: godot --headless --path . --script res://tools/import_spritecook_creatures.gd
const FRAME := 64
const SHEETS := {
	"creatures_A_sheet": {"species": ["werewolf", "bigfoot", "vampire", "witch"], "sides": {}},
	"creatures_B_sheet": {"species": ["briar_revenant", "lantern_moth", "switchback_hound", "relay_jackal"],
		"sides": {"briar_revenant": "mirror", "lantern_moth": "mirror", "switchback_hound": "mirror", "relay_jackal": "swap"}},
	"creatures_C_sheet": {"species": ["ration_moth", "lens_eater", "boiler_saint", "shutter_wraith"],
		"sides": {"ration_moth": "mirror", "shutter_wraith": "mirror"}},
	"creatures_D_sheet": {"species": ["bramble_seamstress", "last_car_conductor", "stoneback_ram", "candle_grazer"],
		"sides": {"last_car_conductor": "mirror", "stoneback_ram": "swap"}},
	"creatures_E_sheet": {"species": ["owl", "bog_hands", "imps", "teddy"], "sides": {}},
	"creatures_F_sheet": {"species": ["cuckoo", "banshee", "slug", "surveyor"], "sides": {"banshee": "mirror_left", "slug": "mirror_left"}},
	"creatures_G_sheet": {"species": ["hitchhiker", "tollkeeper", "echo", "fortune_teller"], "sides": {}},
}
## Flying or floating creatures bob instead of stepping.
const HOVER: Array[String] = ["lantern_moth", "ration_moth", "shutter_wraith", "owl", "bog_hands", "banshee", "slug", "hitchhiker", "fortune_teller"]


func _initialize() -> void:
	# `-- --only creatures_F_sheet` rebuilds one sheet and leaves the rest alone.
	var args := OS.get_cmdline_user_args()
	var only := args[args.find("--only") + 1] if "--only" in args and args.find("--only") + 1 < args.size() else ""
	for sheet_name: String in SHEETS:
		if not only.is_empty() and sheet_name != only:
			continue
		var path := ProjectSettings.globalize_path("res://art_sources/spritecook/%s.png" % sheet_name)
		if not FileAccess.file_exists(path):
			print("skip missing ", sheet_name)
			continue
		var source := Image.load_from_file(path)
		source.convert(Image.FORMAT_RGBA8)
		var cell := Vector2i(source.get_width() / 4, source.get_height() / 4)
		var species: Array = SHEETS[sheet_name]["species"]
		for column in range(4):
			var poses: Array[Image] = []
			for row in range(4):
				var region := source.get_region(Rect2i(column * cell.x, row * cell.y, cell.x, cell.y))
				poses.append(region.get_region(region.get_used_rect()))
			var fix: String = SHEETS[sheet_name]["sides"].get(species[column], "")
			if fix == "mirror":
				poses[3] = poses[2].duplicate()
				poses[3].flip_x()
			elif fix == "mirror_left":
				# Both side rows face left: the right-facing row is the mirror.
				poses[2] = poses[3].duplicate()
				poses[2].flip_x()
			elif fix == "swap":
				var right := poses[3]
				poses[3] = poses[2]
				poses[2] = right
			var factor := 1.0
			for pose in poses:
				factor = minf(factor, minf(float(FRAME - 2) / pose.get_height(), float(FRAME - 2) / pose.get_width()))
			var out := Image.create(FRAME * 3, FRAME * 4, false, Image.FORMAT_RGBA8)
			for row in range(4):
				var frame0 := _fit(poses[row], factor)
				for frame in range(3):
					out.blit_rect(_step(frame0, frame, species[column] in HOVER), Rect2i(0, 0, FRAME, FRAME), Vector2i(frame * FRAME, row * FRAME))
			out.save_png(ProjectSettings.globalize_path("res://assets/sprites/%s.png" % species[column]))
			print("%s scale %.2f %s" % [species[column], factor, fix])
	quit()


func _fit(figure: Image, factor: float) -> Image:
	var small := figure
	if factor < 0.999:
		var palette := _palette(figure)
		var size := Vector2i(maxi(1, roundi(figure.get_width() * factor)), maxi(1, roundi(figure.get_height() * factor)))
		small = figure.duplicate()
		small.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
		for y in range(size.y):
			for x in range(size.x):
				var c: Color = small.get_pixel(x, y)
				small.set_pixel(x, y, Color(0, 0, 0, 0) if c.a < 0.5 else _nearest(palette, c))
	var frame := Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	frame.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i((FRAME - small.get_width()) / 2, FRAME - 1 - small.get_height()))
	return frame


func _step(pose: Image, frame: int, hover: bool) -> Image:
	if frame == 0:
		return pose
	var out := Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	if hover:
		out.blit_rect(pose, Rect2i(0, 0, FRAME, FRAME), Vector2i(0, -1 if frame == 1 else -2))
		return out
	var legs_from := FRAME - 12
	var body := pose.get_region(Rect2i(0, 0, FRAME, legs_from))
	var legs := pose.get_region(Rect2i(0, legs_from, FRAME, 12))
	out.blit_rect(body, Rect2i(Vector2i.ZERO, body.get_size()), Vector2i(0, -1))
	out.blend_rect(legs, Rect2i(Vector2i.ZERO, legs.get_size()), Vector2i(-1 if frame == 1 else 1, legs_from - 1))
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
