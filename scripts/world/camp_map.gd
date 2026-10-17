class_name CampMap
extends Node2D
## Seeded camp lots: one obstacle list drives collision, shadows and navigation.

const CAMP_BOUNDS := Rect2(0, 0, 1536, 960)
const WORLD_SIZE := Vector2(9600, 9408)
const WORLD_BOUNDS := WoodsLayout.WORLD_BOUNDS
const PICKUP_POSITIONS: Array[Vector2] = [Vector2(228, 120), Vector2(1304, 272), Vector2(696, 680)]
const PICKUP_HINTS: Array[String] = ["Battery · Fern bunk cabin", "Fuel · maintenance workshop", "Key · ranger lodge office"]
const ATLAS := preload("res://assets/tiles/camp_tiles.png")
## Nav chunk seams (every 1536px) run inside the camp's two main roads (x=808 in
## the 784-816 road, y=504 in the 496-544 road), which buildings and trees never
## occupy. Neither is a multiple of 32, so no woods wall (all on the 32px grid) can
## lie on a seam. Each chunk's edge is shrunk by the agent radius, leaving a 14px
## off-mesh strip on every seam, so seams also stay clear of the y=520 patrol line.
const NAV_SEAM := Vector2i(808, 504)
const NAV_CHUNK := 1536


## Nudge a point out of the 14px off-mesh strip along a nav seam, so nav queries
## to placed props (hiding spots, piles) end on the mesh.
static func off_seam(point: Vector2) -> Vector2:
	var result := point
	for axis in range(2):
		var offset := posmod(int(round(point[axis])) - NAV_SEAM[axis], NAV_CHUNK)
		if offset < 12:
			result[axis] += 12 - offset
		elif offset > NAV_CHUNK - 12:
			result[axis] -= offset - (NAV_CHUNK - 12)
	return result


static func nav_seam_start(axis: int) -> int:
	var origin := int(WORLD_BOUNDS.position[axis])
	return NAV_SEAM[axis] - NAV_CHUNK * ceili(float(NAV_SEAM[axis] - origin) / NAV_CHUNK)
var obstacles: Array[Rect2] = []
var trees: Array[Rect2] = []
var canopies: Array[Sprite2D] = []
var buildings: Array[CampBuilding] = []
var forest_buildings: Array[CampBuilding] = []
var sites: Array[ForestSite] = []
var navigation_region: NavigationRegion2D
var objects: Node2D
var focus: CampPlayer
## Woods canopy renderer; the sight mask redraws its visible tree line on top.
var woods_canopy: Node2D
var woods: WoodsLayout
var seed_value: int = 42
var layout: CampLayout
var roads: Array[Rect2] = []
var lake: Rect2 = CampLayout.LAKE
var camp_lamps: Array[PointLight2D] = []


func _ready() -> void:
	set_meta("stand_in_world", true)
	if objects == null:
		objects = Node2D.new()
		add_child(objects)
	if woods == null:
		woods = WoodsLayout.new()
		woods.generate(seed_value)
	add_wall(Rect2(WORLD_BOUNDS.position,Vector2(WORLD_SIZE.x,24)))
	add_wall(Rect2(WORLD_BOUNDS.position.x,WORLD_BOUNDS.end.y-24,WORLD_SIZE.x,24))
	add_wall(Rect2(WORLD_BOUNDS.position,Vector2(24,WORLD_SIZE.y)))
	add_wall(Rect2(WORLD_BOUNDS.end.x-24,WORLD_BOUNDS.position.y,24,WORLD_SIZE.y))
	if layout == null:
		layout = CampLayout.new()
		layout.generate(seed_value, false)
	roads.assign(layout.roads)
	for entry in layout.entries:
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
		var tint := Color("c2ded4") if building.kind in ["bath", "infirmary"] else Color("ffbe7c")
		CampLights.lamp(self, building.bounds.position + Vector2(42, 36), 90, tint, 1.1)
		CampLights.lamp(self, building.door + Vector2(0, -8), 60, Color("ffc57e"), 0.9)
	# Pond shore with a walkable dock down its middle.
	add_wall(Rect2(1056, 800, 240, 128), false)
	add_wall(Rect2(1344, 800, 160, 128), false)
	add_wall(Rect2(1296, 912, 48, 16), false)
	_seed_forest()
	_build_woods()
	_build_sites()
	_ground()
	_build_navigation()
	# Electric camp lamps fail during a blackout; the campfire (added last) keeps burning.
	for child in get_children():
		if child is PointLight2D and CAMP_BOUNDS.has_point(child.position):
			camp_lamps.append(child)
	camp_lamps.append(CampLights.lamp(self, Vector2(736, 528), 75, Color("d6dca3"), 0.75))
	CampLights.lamp(self, Vector2(168, 336), 110, Color("ffb266"), 1.3)


func _process(delta: float) -> void:
	for building in buildings:
		building.roof.focus = focus
	for building in forest_buildings:
		building.roof.focus = focus
	if is_instance_valid(focus):
		for canopy in canopies:
			var offset := canopy.global_position - focus.global_position
			var covers_player := absf(offset.x) < 30 and offset.y > -4 and offset.y < 70
			canopy.modulate.a = move_toward(canopy.modulate.a, 0.28 if covers_player else 1.0, delta * 6)


func location_label(point: Vector2) -> String:
	if is_woods(point):
		for building in forest_buildings:
			if building.bounds.grow(5).has_point(point):
				return "ABANDONED VILLAGE / " + building.label
		var zone := woods.zone_at(point)
		if not zone.is_empty():
			return zone["label"]
		for landmark in woods.landmarks:
			if point.distance_to(landmark["position"]) < 90:
				return "THE WOODS / " + landmark["label"]
		if woods.on_road(point):
			for lamp: Vector2 in woods.lamps:
				if point.distance_to(lamp) < 260:
					return "THE WOODS / LIT ROAD" if not night_dark() else "THE WOODS / ROAD (POWER OUT)"
			return "THE WOODS / LOGGING ROAD"
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


func night_dark() -> bool:
	return not camp_lamps.is_empty() and not camp_lamps[0].enabled


const CAMP_DECOR: Array = [["notice_board", Vector2(222, 344), 30.0], ["picnic_table", Vector2(236, 400), 40.0], ["outhouse", Vector2(1484, 420), 26.0], ["toolbox", Vector2(1300, 410), 18.0]]


## Decor has no collision, so only draw it where it won't sit on a tree or wall.
func _decor_clear(base: Vector2, width: float) -> bool:
	var footprint := Rect2(base - Vector2(width * 0.5, width * 0.6), Vector2(width, width * 0.6))
	for obstacle in obstacles:
		if obstacle.intersects(footprint):
			return false
	for road in roads:
		if road.intersects(footprint):
			return false
	return true


func add_wall(rect: Rect2, shadow: bool = true, layer: int = 1) -> void:
	obstacles.append(rect)
	var body := StaticBody2D.new()
	body.collision_layer = layer
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
	add_wall(rect, false)
	CampLights.trunk(self, at)
	_canopy(at, variant)


func _canopy(at: Vector2, variant: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/sprites/" + ("birch" if variant == 3 else "pine_%d" % variant) + ".png")
	sprite.position = at
	sprite.offset = Vector2(0, -32)
	sprite.modulate = Color(0.85, 0.90, 0.83) if variant == 2 else Color.WHITE
	objects.add_child(sprite)
	canopies.append(sprite)


func _build_woods() -> void:
	for wall in woods.walls:
		add_wall(wall,true)
	# Road lamps run on camp power: a blackout darkens the ring and inner spokes too.
	for post in woods.lamps:
		camp_lamps.append(CampLights.lamp(self, post + Vector2(0, -14), 120, Color("f2c47a"), 1.15))
	for canopy in [false,true]:
		var renderer := preload("res://scripts/world/woods_terrain.gd").new()
		renderer.camp_map = self
		renderer.canopy_only = canopy
		renderer.z_index = 5 if canopy else -20
		add_child(renderer)
		if canopy:
			woods_canopy = renderer
	var decor := preload("res://scripts/world/woods_decor.gd").new()
	decor.woods = woods
	add_child(decor)


func _seed_forest() -> void:
	# Preserve the tested collision layout around the original campsite.
	for cell in [Vector2(2, 2), Vector2(4, 3), Vector2(15, 2), Vector2(17, 4), Vector2(28, 3), Vector2(29, 7), Vector2(3, 8), Vector2(5, 10), Vector2(9, 9), Vector2(13, 11), Vector2(23, 10), Vector2(26, 13), Vector2(28, 17), Vector2(4, 17), Vector2(10, 17), Vector2(14, 16), Vector2(30, 11)]:
		var rect := Rect2(cell * 24, Vector2(24, 24))
		if _tree_clear(rect.get_center(), 14):
			_tree(rect.get_center(), int(cell.x) % 4, rect)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 18313
	for y in range(40, 936, 44):
		for x in range(40, 1512, 44):
			var at := Vector2(x + rng.randi_range(-7, 7), y + rng.randi_range(-7, 7))
			if at.x < 744 and at.y < 456:
				continue
			if _tree_clear(at, 30):
				_tree(at, rng.randi_range(0, 3))
	# Low nonblocking undergrowth along routes and around clearings.
	for index in range(180):
		var at := Vector2(rng.randf_range(32, 1504), rng.randf_range(32, 928))
		var clear := not lake.has_point(at)
		for road in roads:
			if road.grow(8).has_point(at):
				clear = false
		for building in buildings:
			if building.bounds.grow(12).has_point(at):
				clear = false
		if clear:
			var sprite := Sprite2D.new()
			sprite.texture = preload("res://assets/sprites/shrub.png")
			sprite.position = at
			sprite.offset.y = -8
			objects.add_child(sprite)


func _tree_clear(at: Vector2, clearance: float) -> bool:
	for road in roads:
		if road.grow(clearance).has_point(at):
			return false
	for building in buildings:
		if building.bounds.grow(clearance).has_point(at):
			return false
	return not lake.grow(clearance).has_point(at)


func _build_sites() -> void:
	for definition in woods.zones:
		var site := ForestSite.new()
		site.definition = definition
		site.level = get_parent()
		add_child(site)
		sites.append(site)
		if definition["kind"] == "village":
			var origin: Vector2 = definition["bounds"].position
			for index in range(2):
				var building := CampBuilding.new()
				building.configure(Rect2(origin + Vector2(64 if index == 0 else definition["bounds"].size.x - 208, 64), Vector2(144, 96)), "cabin", "SURVEYOR HUT" if index == 0 else "LOOTED COTTAGE")
				forest_buildings.append(building)
				add_child(building)
				for wall in building.walls:
					add_wall(wall)
				for furniture in building.furnishings:
					add_wall(furniture["rect"].grow(-2), false)
				var roof := preload("res://scripts/world/building_roof.gd").new()
				roof.building = building
				roof.z_index = 8
				building.roof = roof
				add_child(roof)
				CampLights.lamp(self, building.door - Vector2(0,4), 70, Color("bdab84"), 0.7)
			CampLights.lamp(self, site.definition["position"] + Vector2(0, 48), 88, Color("beaa78"), 0.8)
		elif definition["kind"] == "substation":
			for x in [-112,112]:
				add_wall(Rect2(definition["position"] + Vector2(x - 32, -38), Vector2(64, 50)))
			add_wall(Rect2(definition["position"] + Vector2(-22, 12), Vector2(44, 20)))
		elif definition["kind"] == "relay":
			add_wall(Rect2(definition["position"] + Vector2(-24, 12), Vector2(48, 28)))
		elif definition["kind"] == "boathouse":
			# Water blocks walking only: sight, light and voice carry across it.
			for water_rect in FieldEscapeArt.water_rects(definition["position"]):
				add_wall(water_rect, false, CampPlayer.WATER_LAYER)
			# A lantern at the end of the pier lights the water and the boat.
			CampLights.lamp(self, definition["position"] + Vector2(0, -222), 220, Color("e9c37f"), 1.25)
		elif definition["kind"] == "bog":
			CampLights.lamp(self, definition["position"] - Vector2(0, 13), 66, Color("a0b876"), 0.65)
		else:
			CampLights.lamp(self, definition["position"] + Vector2(-32, 8), 75, Color("83a9a0"), 0.75)


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
	# SpriteCook seamless materials as world-aligned 16px sub-tiles (sources 1-3).
	var materials := {1: "lawn" if PixelArt.texture("lawn") != null else "grass", 2: "road", 3: "water"}
	var spans := {}
	for id: int in materials:
		var tex := PixelArt.texture(materials[id])
		if tex == null:
			continue
		var material_source := TileSetAtlasSource.new()
		material_source.texture = tex
		material_source.texture_region_size = Vector2i(16, 16)
		var span := Vector2i(tex.get_size()) / 16
		for ty in range(span.y):
			for tx in range(span.x):
				material_source.create_tile(Vector2i(tx, ty))
		tile_set.add_source(material_source, id)
		spans[id] = span
	var layer := TileMapLayer.new()
	layer.name = "GroundTiles"
	layer.tile_set = tile_set
	layer.z_index = -20
	add_child(layer)
	for y in range(60):
		for x in range(96):
			var center := Vector2(x * 16 + 8, y * 16 + 8)
			var tile := Vector2i((x * 7 + y * 11) % 4, 0)
			var material := 1
			for road in roads:
				if road.has_point(center):
					tile = Vector2i(4 + (x + y) % 3, 0)
					material = 2
			if lake.has_point(center):
				tile = Vector2i((x + y) % 2, 2)
				material = 3
			if spans.has(material):
				layer.set_cell(Vector2i(x, y), material, Vector2i(posmod(x, spans[material].x), posmod(y, spans[material].y)))
			else:
				layer.set_cell(Vector2i(x, y), 0, tile)


func _build_navigation() -> void:
	# Bounded native bakes avoid unstable convex partitioning of one giant maze.
	NavigationServer2D.map_set_use_async_iterations(get_world_2d().navigation_map,false)
	NavigationServer2D.map_set_edge_connection_margin(get_world_2d().navigation_map,16.0)
	# A wall edge lying exactly on a chunk seam loses its path clearance, so seams
	# are shifted half a chunk away from every road edge.
	for y in range(nav_seam_start(1),int(WORLD_BOUNDS.end.y),NAV_CHUNK):
		for x in range(nav_seam_start(0),int(WORLD_BOUNDS.end.x),NAV_CHUNK):
			var bounds := Rect2(x,y,NAV_CHUNK,NAV_CHUNK).intersection(WORLD_BOUNDS)
			var polygon := NavigationPolygon.new()
			polygon.agent_radius = 7.0
			var source := NavigationMeshSourceGeometryData2D.new()
			source.add_traversable_outline(_outline(bounds))
			for obstacle in obstacles + woods.barriers():
				if bounds.grow(8).intersects(obstacle):
					source.add_obstruction_outline(_outline(obstacle))
			if bounds.intersects(Rect2(81,278,30,40)):
				source.add_obstruction_outline(_outline(Rect2(81,278,30,40)))
			NavigationServer2D.bake_from_source_geometry_data(polygon,source)
			var region := NavigationRegion2D.new()
			region.navigation_polygon = polygon
			add_child(region)
			NavigationServer2D.region_set_use_async_iterations(region.get_rid(),false)
			if navigation_region == null:
				navigation_region = region
	NavigationServer2D.map_force_update(get_world_2d().navigation_map)


func _outline(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


## Ground-cover decals: tufts break up road edges, litter breaks up the tiling.
const DECALS_GRASS: Array[String] = ["decal_grass_short", "decal_clover", "decal_grass_tall", "decal_flowers", "decal_mushrooms", "decal_mossy_stone", "decal_fern", "decal_leaves", "decal_pebbles", "decal_rock"]
const DECALS_EDGE: Array[String] = ["decal_grass_tall", "decal_grass_short", "decal_fern", "decal_weeds", "decal_dry_grass", "decal_grass_tall"]
const DECALS_ROAD: Array[String] = ["decal_pebbles", "decal_leaves", "decal_needles", "decal_puddle", "decal_branch"]


func _draw_decals() -> void:
	var local_obstacles := obstacles.filter(func(rect: Rect2) -> bool: return CAMP_BOUNDS.intersects(rect))
	var floors: Array[Rect2] = []
	for building in buildings + forest_buildings:
		if CAMP_BOUNDS.intersects(building.bounds):
			floors.append(building.bounds.grow(6))
	for y in range(8, 960, 18):
		for x in range(8, 1536, 18):
			var h := hash(Vector2i(x, y) + Vector2i(seed_value % 997, 17))
			var at := Vector2(x + posmod(h, 11) - 5, y + posmod(h >> 4, 11) - 5)
			if lake.has_point(at) or floors.any(func(rect: Rect2) -> bool: return rect.has_point(at)):
				continue
			var on_road := roads.any(func(road: Rect2) -> bool: return road.has_point(at))
			var edge := not on_road and roads.any(func(road: Rect2) -> bool: return road.grow(9).has_point(at))
			var roll := posmod(h >> 8, 100)
			var name := ""
			var size := 13.0
			if edge and roll < 75:
				name = DECALS_EDGE[posmod(h >> 12, DECALS_EDGE.size())]
				size = 12.0 + posmod(h >> 16, 5)
			elif on_road and roll < 6:
				name = DECALS_ROAD[posmod(h >> 12, DECALS_ROAD.size())]
				size = 11.0
			elif not on_road and not edge and roll < 16:
				name = DECALS_GRASS[posmod(h >> 12, DECALS_GRASS.size())]
				size = 10.0 + posmod(h >> 16, 6)
			if name.is_empty() or local_obstacles.any(func(rect: Rect2) -> bool: return rect.has_point(at)):
				continue
			PixelArt.draw_in(self, name, Rect2(at - Vector2(size * 0.5, size), Vector2(size, size)), Color(0.82, 0.84, 0.8))


func _draw() -> void:
	_draw_decals()
	# Dock, piles and lantern posts are aligned to the world pixel grid.
	var dock := Rect2(1296, 784, 48, 128)
	draw_rect(Rect2(dock.position + Vector2(3, 4), dock.size), Color(0, 0, 0, 0.35))
	for y in range(784, 912, 16):
		for x in range(1296, 1344, 16):
			if not PixelArt.draw_material(self, "dock_planks", Rect2(x, y, 16, 16), Color(0.9, 0.88, 0.84)):
				draw_rect(Rect2(x, y, 16, 16), Color("9b805a"))
	draw_rect(dock, Color("2a2219"), false, 1.0)
	for y in [792, 848, 904]:
		draw_rect(Rect2(1292, y, 5, 9), Color("4f4936"))
		draw_rect(Rect2(1343, y, 5, 9), Color("4f4936"))
	# SpriteCook campsite: tent, campfire, a barrel by the fire, and (where clear
	# of trees) the camp notice board and a picnic table.
	if PixelArt.draw_standing(self, "tent", Vector2(158, 394), 54):
		PixelArt.draw_standing(self, "campfire", Vector2(168, 346), 30)
		PixelArt.draw_standing(self, "barrel", Vector2(57, 366), 14)
		for decor: Array in CAMP_DECOR:
			if _decor_clear(decor[1], decor[2]):
				PixelArt.draw_standing(self, decor[0], decor[1], decor[2])
		return
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


static func is_woods(point: Vector2) -> bool:
	return not CAMP_BOUNDS.has_point(point)
