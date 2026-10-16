class_name CampLights
extends RefCounted
## Native 2D lights and occluders: walls block the flashlight visually.

static var radial: Texture2D
static var beam: Texture2D


static func texture(cone: bool = false) -> Texture2D:
	if cone and beam != null:
		return beam
	if not cone and radial != null:
		return radial
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var offset := Vector2(x - 128, y - 128) / 128.0
			var strength := pow(maxf(0.0, 1.0 - offset.length()), 1.1)
			if cone:
				strength *= smoothstep(0.80, 0.96, offset.normalized().x)
			image.set_pixel(x, y, Color(1, 1, 1, strength))
	var result := ImageTexture.create_from_image(image)
	if cone:
		beam = result
	else:
		radial = result
	return result


static func lamp(parent: Node, at: Vector2, radius: float, tint: Color, energy: float = 1.0) -> PointLight2D:
	var light := PointLight2D.new()
	light.position = at
	light.texture = texture()
	light.texture_scale = radius / 128.0
	light.color = tint
	light.energy = energy
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	parent.add_child(light)
	return light


static func occluder(parent: Node, rect: Rect2) -> void:
	var node := LightOccluder2D.new()
	node.position = rect.position
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = PackedVector2Array([Vector2.ZERO, Vector2(rect.size.x, 0), rect.size, Vector2(0, rect.size.y)])
	node.occluder = polygon
	parent.add_child(node)


static func trunk(parent: Node, at: Vector2, radius: float = 5.0) -> void:
	var node := LightOccluder2D.new()
	node.position = at
	var polygon := OccluderPolygon2D.new()
	var points := PackedVector2Array()
	for index in range(8):
		points.append(Vector2.from_angle(index * TAU / 8) * Vector2(radius, radius * 0.7))
	polygon.polygon = points
	node.occluder = polygon
	parent.add_child(node)
