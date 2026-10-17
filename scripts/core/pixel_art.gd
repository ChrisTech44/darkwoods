class_name PixelArt
extends RefCounted
## SpriteCook object art at runtime sizes: area downscale snapped back to the
## sprite's own palette with a crisp alpha cut, cached per (name, size). Never
## upscales. Sprites live in res://assets/sprites/sc/<name>.png.

static var _cache: Dictionary = {}


## Texture of `name` scaled to fit inside `box` (aspect kept). Null if missing.
static func fit(name: String, box: Vector2) -> Texture2D:
	var key := "%s@%dx%d" % [name, int(box.x), int(box.y)]
	if _cache.has(key):
		return _cache[key]
	var path := "res://assets/sprites/sc/%s.png" % name
	if not ResourceLoader.exists(path):
		_cache[key] = null
		return null
	var source: Image = (load(path) as Texture2D).get_image()
	source.convert(Image.FORMAT_RGBA8)
	var factor := minf(1.0, minf(box.x / source.get_width(), box.y / source.get_height()))
	var size := Vector2i(maxi(1, roundi(source.get_width() * factor)), maxi(1, roundi(source.get_height() * factor)))
	var result := source
	if size != source.get_size():
		result = _snap_resize(source, size)
	var texture := ImageTexture.create_from_image(result)
	_cache[key] = texture
	return texture


## Draw `name` fitted into `rect`, bottom-centred (3/4 objects stand on their base).
static func draw_in(canvas: CanvasItem, name: String, rect: Rect2, modulate := Color.WHITE) -> bool:
	var texture := fit(name, rect.size)
	if texture == null:
		return false
	var size := texture.get_size()
	canvas.draw_texture(texture, Vector2(rect.position.x + (rect.size.x - size.x) * 0.5, rect.end.y - size.y).round(), modulate)
	return true


## Draw `name` scaled to `width`, standing on `base` (centre-bottom), allowed to
## rise above a thin collision footprint like a 3/4 view object.
static func draw_standing(canvas: CanvasItem, name: String, base: Vector2, width: float, max_height: float = 999.0) -> bool:
	var texture := fit(name, Vector2(width, max_height))
	if texture == null:
		return false
	var size := texture.get_size()
	canvas.draw_texture(texture, (base - Vector2(size.x * 0.5, size.y)).round())
	return true


static func _snap_resize(source: Image, size: Vector2i) -> Image:
	var palette: Array[Color] = []
	var seen := {}
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			var c: Color = source.get_pixel(x, y)
			if c.a > 0.5 and not seen.has(c.to_html(false)):
				seen[c.to_html(false)] = true
				palette.append(Color(c, 1.0))
	var small := source.duplicate()
	small.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	for y in range(size.y):
		for x in range(size.x):
			var c: Color = small.get_pixel(x, y)
			if c.a < 0.5:
				small.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var best: Color = palette[0]
			var best_d := INF
			for p in palette:
				var d: float = (p.r - c.r) * (p.r - c.r) * 0.3 + (p.g - c.g) * (p.g - c.g) * 0.59 + (p.b - c.b) * (p.b - c.b) * 0.11
				if d < best_d:
					best_d = d
					best = p
			small.set_pixel(x, y, best)
	return small


## Seamless SpriteCook material texture (res://assets/tiles/tex_<name>.png).
static func texture(name: String) -> Texture2D:
	var key := "tex:" + name
	if not _cache.has(key):
		var path := "res://assets/tiles/tex_%s.png" % name
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


## Draw a world-aligned square of a seamless material so neighbours line up.
static func draw_material(canvas: CanvasItem, name: String, rect: Rect2, modulate := Color.WHITE) -> bool:
	var tex := texture(name)
	if tex == null:
		return false
	var size := tex.get_size()
	var source := Rect2(Vector2(fposmod(rect.position.x, size.x), fposmod(rect.position.y, size.y)), rect.size)
	# Split at the texture edge when the square straddles the wrap.
	var end := source.end
	if end.x <= size.x and end.y <= size.y:
		canvas.draw_texture_rect_region(tex, rect, source, modulate)
		return true
	for oy in [0.0, 1.0]:
		for ox in [0.0, 1.0]:
			var part := Rect2(source.position - Vector2(ox, oy) * size, source.size).intersection(Rect2(Vector2.ZERO, size))
			if part.has_area():
				var target := Rect2(rect.position + part.position - (source.position - Vector2(ox, oy) * size), part.size)
				canvas.draw_texture_rect_region(tex, target, part, modulate)
	return true
