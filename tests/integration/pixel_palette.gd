extends SceneTree
## Compare accelerated palette fitting with the previous exhaustive search.
func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 716
	var checks := 0
	var failures := 0
	for fixture in range(8):
		var source := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var palette: Array[Color] = []
		var seen := {}
		for y in range(32):
			for x in range(32):
				var c := Color(rng.randf(), rng.randf(), rng.randf(), 1.0 if rng.randf() > 0.2 else 0.0)
				source.set_pixel(x, y, c)
				c = source.get_pixel(x, y)
				if c.a > 0.5 and not seen.has(c.to_html(false)):
					seen[c.to_html(false)] = true
					palette.append(Color(c, 1.0))
		var actual := PixelArt._snap_resize(source, Vector2i(13, 17))
		source.resize(13, 17, Image.INTERPOLATE_LANCZOS)
		for y in range(17):
			for x in range(13):
				var c := source.get_pixel(x, y)
				var expected := Color(0, 0, 0, 0)
				var best_d := INF
				if c.a >= 0.5:
					for p in palette:
						var d: float = (p.r - c.r) * (p.r - c.r) * 0.3 + (p.g - c.g) * (p.g - c.g) * 0.59 + (p.b - c.b) * (p.b - c.b) * 0.11
						if d < best_d:
							best_d = d
							expected = p
				checks += 1
				if actual.get_pixel(x, y) != expected: failures += 1
	print(JSON.stringify({"event":"test_result", "suite":"pixel_palette", "checks":checks, "failures":failures}))
	quit(1 if failures else 0)
