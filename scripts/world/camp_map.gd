class_name CampMap
extends Node2D
## Fixed authored camp: one obstacle list drives collision, shadows and navigation.

const WORLD_SIZE := Vector2(3456, 1920)
const PICKUP_POSITIONS: Array[Vector2] = [Vector2(228, 120), Vector2(1304, 272), Vector2(696, 680)]
const PICKUP_HINTS: Array[String] = ["Battery · west bunk cabin", "Fuel · maintenance workshop", "Key · ranger lodge office"]
const ATLAS := preload("res://assets/tiles/camp_tiles.png")
var obstacles: Array[Rect2] = []
var trees: Array[Rect2] = []
var buildings: Array[CampBuilding] = []
var navigation_region: NavigationRegion2D
var objects: Node2D
var focus: CampPlayer
var woods: WoodsLayout
var seed_value: int = 42
var roads: Array[Rect2] = [Rect2(36, 192, 1476, 48), Rect2(72, 216, 48, 696), Rect2(96, 496, 1352, 48), Rect2(784, 240, 32, 656), Rect2(96, 864, 1250, 32)]
var lake: Rect2 = Rect2(1056, 800, 448, 128)


func _ready() -> void:
	if objects == null:
		objects = Node2D.new()
		add_child(objects)
	if woods == null:
		woods = WoodsLayout.new()
		woods.generate(seed_value)
	add_wall(Rect2(0, 0, 3456, 24))
	add_wall(Rect2(0, 1896, 3456, 24))
	add_wall(Rect2(0, 0, 24, 1920))
	add_wall(Rect2(3432, 0, 24, 1920))
	add_wall(Rect2(0, 936, 1536, 984))
	add_wall(Rect2(1512, 24, 24, 464))
	add_wall(Rect2(1512, 552, 24, 384))
	add_wall(Rect2(1536, 24, 160, 464))
	add_wall(Rect2(1536, 552, 160, 1344))
	add_wall(Rect2(1696, 24, 1600, 96))
	add_wall(Rect2(1696, 1720, 1600, 176))
	add_wall(Rect2(3296, 24, 136, 1872))
	var layout := [
		[Rect2(144, 72, 144, 96), "cabin", "FERN BUNK CABIN"],
		[Rect2(480, 72, 144, 96), "cabin", "PINE BUNK CABIN"],
		[Rect2(408, 312, 120, 96), "cabin", "OLD STORAGE"],
		[Rect2(800, 64, 208, 160), "bunkhouse", "CEDAR BUNKHOUSE"],
		[Rect2(1136, 184, 240, 192), "workshop", "MAINTENANCE"],
		[Rect2(832, 320, 256, 192), "mess", "MESS HALL"],
		[Rect2(480, 600, 288, 224), "ranger", "RANGER LODGE"],
		[Rect2(256, 608, 176, 176), "bath", "BATHHOUSE"],
		[Rect2(960, 640, 176, 160), "infirmary", "FIRST AID"],
		[Rect2(1200, 624, 224, 160), "boat", "BOATHOUSE"]
	]
	for entry in layout:
		var building := CampBuilding.new()
		building.configure(entry[0], entry[1], entry[2])
		buildings.append(building)
		add_child(building)
		for wall in building.walls:
			add_wall(wall)
		for furnishing in building.furnishings:
			add_wall(furnishing["rect"].grow(-2), false)
		var roof := preload("res://scripts/world/building_roof.gd").new()
		roof.building = building
		roof.z_index = 8
		building.roof = roof
		add_child(roof)
		var end_y := 216.0 if building.bounds.end.y <= 240 else (520.0 if building.bounds.end.y <= 520 else 880.0)
		roads.append(Rect2(building.door.x - 16, building.door.y, 32, maxf(24, end_y - building.door.y)))
		var tint := Color("c2ded4") if building.kind in ["bath", "infirmary"] else Color("ffbe7c")
		CampLights.lamp(self, building.bounds.position + Vector2(42, 36), 90, tint, 1.1)
		CampLights.lamp(self, building.door + Vector2(0, -8), 60, Color("ffc57e"), 0.9)
	# Pond shore with a walkable dock down its middle.
	add_wall(Rect2(1056, 800, 240, 128), false)
	add_wall(Rect2(1344, 800, 160, 128), false)
	add_wall(Rect2(1296, 912, 48, 16), false)
	_seed_forest()
	_build_woods()
	_ground()
	_build_navigation()
	CampLights.lamp(self, Vector2(168, 336), 110, Color("ffb266"), 1.3)
	CampLights.lamp(self, Vector2(736, 528), 75, Color("d6dca3"), 0.75)


func _process(_delta: float) -> void:
	for building in buildings:
		building.roof.focus = focus


func location_label(point: Vector2) -> String:
	if point.x >= 1536:
		for landmark in woods.landmarks:
			if point.distance_to(landmark["position"]) < 90:
				return "THE WOODS / " + landmark["label"]
		return "THE WOODS / NO SAFE LIGHT"
	for building in buildings:
		if building.bounds.grow(16).has_point(point):
			return building.label
	if point.x > 1056 and point.y > 760:
		return "BLACKWATER SHORE"
	if point.y > 560:
		return "SOUTH CAMP TRAIL"
	if point.x > 760:
		return "EAST SERVICE TRAIL"
	return "FERNWOOD CAMPSITE"


func add_wall(rect: Rect2, shadow: bool = true) -> void:
	obstacles.append(rect)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.position = rect.get_center()
	body.add_child(collision)
	add_child(body)
	if shadow:
		CampLights.occluder(self, rect)


func _tree(at: Vector2, variant: int, legacy_rect: Rect2 = Rect2()) -> void:
	var rect := Rect2(at - Vector2(5, 6), Vector2(10, 12)) if legacy_rect.size == Vector2.ZERO else legacy_rect
	trees.append(rect)
	add_wall(rect)
	_canopy(at, variant)


func _canopy(at: Vector2, variant: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/sprites/" + ("birch" if variant == 3 else "pine_%d" % variant) + ".png")
	sprite.position = at
	sprite.offset = Vector2(0, -32)
	sprite.modulate = Color(0.85, 0.90, 0.83) if variant == 2 else Color.WHITE
	objects.add_child(sprite)


func _build_woods() -> void:
	for wall in woods.walls:
		add_wall(wall)
		for x in range(int(wall.position.x) + 12, int(wall.end.x), 40):
			_canopy(Vector2(x, wall.get_center().y + 8), (x / 40 + int(wall.position.y)) % 3)
	var decor := preload("res://scripts/world/woods_decor.gd").new()
	decor.woods = woods
	add_child(decor)


func _seed_forest() -> void:
	# Preserve the tested collision layout around the original campsite.
	for cell in [Vector2(2, 2), Vector2(4, 3), Vector2(15, 2), Vector2(17, 4), Vector2(28, 3), Vector2(29, 7), Vector2(3, 8), Vector2(5, 10), Vector2(9, 9), Vector2(13, 11), Vector2(23, 10), Vector2(26, 13), Vector2(28, 17), Vector2(4, 17), Vector2(10, 17), Vector2(14, 16), Vector2(30, 11)]:
		var rect := Rect2(cell * 24, Vector2(24, 24))
		_tree(rect.get_center(), int(cell.x) % 4, rect)
	var rng := RandomNumberGenerator.new()
	rng.seed = 18313
	for y in range(40, 936, 44):
		for x in range(40, 1512, 44):
			var at := Vector2(x + rng.randi_range(-7, 7), y + rng.randi_range(-7, 7))
			if at.x < 744 and at.y < 456:
				continue
			var clear := true
			for road in roads:
				if road.grow(26).has_point(at):
					clear = false
			for building in buildings:
				if building.bounds.grow(30).has_point(at):
					clear = false
			if lake.grow(24).has_point(at):
				clear = false
			if clear:
				_tree(at, rng.randi_range(0, 3))
	# Low nonblocking undergrowth along routes and around clearings.
	for index in range(180):
		var at := Vector2(rng.randf_range(32, 1504), rng.randf_range(32, 928))
		var clear := not lake.has_point(at)
		for building in buildings:
			if building.bounds.grow(12).has_point(at):
				clear = false
		if clear:
			var sprite := Sprite2D.new()
			sprite.texture = preload("res://assets/sprites/shrub.png")
			sprite.position = at
			sprite.offset.y = -8
			objects.add_child(sprite)


func _ground() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	var source := TileSetAtlasSource.new()
	source.texture = ATLAS
	source.texture_region_size = Vector2i(16, 16)
	for y in range(4):
		for x in range(8):
			source.create_tile(Vector2i(x, y))
	tile_set.add_source(source, 0)
	var layer := TileMapLayer.new()
	layer.name = "GroundTiles"
	layer.tile_set = tile_set
	layer.z_index = -20
	add_child(layer)
	for y in range(120):
		for x in range(216):
			var center := Vector2(x * 16 + 8, y * 16 + 8)
			var tile := Vector2i((x * 7 + y * 11) % 4, 0)
			for road in roads:
				if road.has_point(center):
					tile = Vector2i(4 + (x + y) % 3, 0)
			if center.x >= 1536:
				tile = Vector2i(2 + (x + y) % 2, 1) if woods.walkable(center) else Vector2i((x + y) % 2, 1)
			if lake.has_point(center):
				tile = Vector2i((x + y) % 2, 2)
			layer.set_cell(Vector2i(x, y), 0, tile)


func _build_navigation() -> void:
	var polygon := NavigationPolygon.new()
	polygon.agent_radius = 7.0
	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(_outline(Rect2(Vector2.ZERO, WORLD_SIZE)))
	for obstacle in obstacles:
		source.add_obstruction_outline(_outline(obstacle))
	source.add_obstruction_outline(_outline(Rect2(81, 278, 30, 40)))
	NavigationServer2D.bake_from_source_geometry_data(polygon, source)
	navigation_region = NavigationRegion2D.new()
	navigation_region.navigation_polygon = polygon
	add_child(navigation_region)


func _outline(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


func _draw() -> void:
	# Dock, piles and lantern posts are aligned to the world pixel grid.
	for y in range(784, 912, 8):
		draw_rect(Rect2(1296, y, 48, 7), Color("9b805a"))
		draw_line(Vector2(1300, y+2), Vector2(1340, y+2), Color("bba073"))
	for y in [792, 848, 904]:
		draw_rect(Rect2(1292, y, 5, 9), Color("4f4936"))
		draw_rect(Rect2(1343, y, 5, 9), Color("4f4936"))
	# Tent canvas, seams, guy ropes and pegs.
	draw_colored_polygon(PackedVector2Array([Vector2(132, 386), Vector2(153, 348), Vector2(184, 386)]), Color("bf9461"))
	draw_colored_polygon(PackedVector2Array([Vector2(151, 384), Vector2(162, 357), Vector2(178, 384)]), Color("584a37"))
	draw_line(Vector2(153, 348), Vector2(162, 385), Color("e0be83"), 2)
	draw_line(Vector2(153, 348), Vector2(121, 390), Color("9d9c7b"))
	draw_line(Vector2(184, 386), Vector2(198, 393), Color("9d9c7b"))
	for x in [120, 196]:
		draw_rect(Rect2(x, 390, 2, 5), Color("adbaa1"))
	for index in range(10):
		var point := Vector2(168, 336) + Vector2.from_angle(index * TAU / 10) * 11
		draw_rect(Rect2(point.round(), Vector2(4, 3)), Color("8d917b"))
	draw_line(Vector2(162, 338), Vector2(174, 334), Color("67513a"), 3)
	draw_colored_polygon(PackedVector2Array([Vector2(164, 338), Vector2(167, 328), Vector2(172, 338)]), Color("e9a65f"))
	draw_rect(Rect2(48, 340, 18, 25), Color("756349"))
	draw_rect(Rect2(50, 342, 14, 10), Color("a9976d"))
	draw_line(Vector2(51, 345), Vector2(60, 345), Color("4b573f"))
