class_name WoodsLayout
extends RefCounted
## Finite surrounding forest. Raster occupancy drives terrain, collision and shadows.
const ORIGIN := Vector2(-4032, -4224)
const SIZE := Vector2i(50, 49)
const CELL := 192
const HALF_TRAIL := 64
const CAMP_BOUNDS := Rect2(0, 0, 1536, 960)
const CAMP_CELLS := Rect2i(21, 22, 8, 5)
const WORLD_BOUNDS := Rect2(ORIGIN, Vector2(9600, 9408))
const ENTRY := Vector2i(20, 24)
const ENTRIES: Array[Vector2i] = [ENTRY, Vector2i(29,24), Vector2i(24,21), Vector2i(25,27)]
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
var links: Dictionary = {}
var corridors: Array[Rect2] = []
var walls: Array[Rect2] = []
var landmarks: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var visited: Dictionary = {}
var landmark_distances: Dictionary = {}
var open_tiles: Dictionary = {}
var signposts: Array[Dictionary] = []
## F4a road network: a ring road through the three objective regions and four
## straight spokes from the camp exits to the map edges. The maze between them
## stays as the dark "thickets".
const ROAD_HALF := 80
const RING := Rect2i(16, 17, 17, 14)
var roads: Array[Rect2] = []
var road_cells: Dictionary = {}
var road_tiles: Dictionary = {}
var lamps: Array[Vector2] = []
const SIGN_SPACING := 640.0
const SIGN_OFFSET := Vector2(-44, -40)
const SIGN_NAMES := {"village":"VILLAGE", "bog":"BOG", "graveyard":"GRAVES", "mill":"MILL", "orchard":"ORCHARD", "observatory":"DOME", "rail":"RAILS", "quarry":"QUARRY", "chapel":"CHAPEL"}
const COMPASS := {Vector2i.UP:"N", Vector2i.DOWN:"S", Vector2i.LEFT:"W", Vector2i.RIGHT:"E"}

func generate(seed_value: int) -> void:
	links.clear()
	corridors.clear()
	walls.clear()
	landmarks.clear()
	zones.clear()
	visited.clear()
	open_tiles.clear()
	signposts.clear()
	roads.clear()
	road_cells.clear()
	road_tiles.clear()
	lamps.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var stack: Array[Vector2i] = [ENTRY]
	links[ENTRY] = []
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var choices: Array[Vector2i] = []
		for direction in DIRECTIONS:
			var neighbor := current + direction
			if valid(neighbor) and not links.has(neighbor):
				choices.append(neighbor)
		if choices.is_empty():
			stack.pop_back()
			continue
		var next := choices[rng.randi_range(0, choices.size() - 1)]
		links[current].append(next)
		links[next] = [current]
		stack.append(next)
	for index in range(600):
		var cell := Vector2i(rng.randi_range(0, SIZE.x-1), rng.randi_range(0, SIZE.y-1))
		var neighbor := cell + DIRECTIONS[rng.randi_range(0, 3)]
		if valid(cell) and valid(neighbor):
			_link(cell, neighbor)
	_make_zones(rng)
	_make_roads()
	# Traversable approach routes keep objectives reachable without flattening the outer maze.
	_connect_grid(ENTRIES[0], zones[0]["cell"] + Vector2i(2,2))
	_connect_grid(ENTRIES[1], zones[1]["cell"] + Vector2i(1,1))
	_connect_grid(ENTRIES[3], zones[2]["cell"] + Vector2i(1,1))
	for cell: Vector2i in links:
		var at := center(cell)
		_carve(Rect2(at - Vector2(HALF_TRAIL, HALF_TRAIL), Vector2.ONE * HALF_TRAIL * 2))
		for next: Vector2i in links[cell]:
			if next.y * SIZE.x + next.x < cell.y * SIZE.x + cell.x:
				continue
			var other := center(next)
			_carve(Rect2(at.min(other) - Vector2.ONE * HALF_TRAIL, (other-at).abs() + Vector2.ONE * HALF_TRAIL * 2))
	for road in roads:
		_carve(road)
	for zone in zones:
		_carve(zone["bounds"].grow(32))
	_carve(CAMP_BOUNDS)
	for entrance in [Rect2(-192,448,288,128), Rect2(1448,448,280,128), Rect2(608,-192,128,432), Rect2(800,864,128,288)]:
		_carve(entrance)
	_make_walls()
	landmark_distances = distances_from(ENTRY)
	var candidates: Array = links.keys()
	candidates.sort_custom(_farthest_first)
	var labels := ["THE SPLIT STUMP", "OLD HUNTER'S BLIND", "HOLLOW ROCK CAVE", "FALLEN WATCHTOWER", "THE CROOKED SHRINE", "RUSTED SCRAP CACHE"]
	for cell: Vector2i in candidates:
		var spaced := zone_at(center(cell)).is_empty()
		for landmark in landmarks:
			if center(cell).distance_to(landmark["position"]) < 1300:
				spaced = false
		if spaced:
			landmarks.append({"cell":cell, "position":center(cell), "label":labels[landmarks.size()]})
		if landmarks.size() == labels.size():
			break
	landmark_distances.clear()
	_make_signposts()

## Deterministic (no RNG) so roads never shift other seeded content.
func _make_roads() -> void:
	var ring: Array[Vector2i] = []
	for x in range(RING.position.x, RING.end.x):
		ring.append(Vector2i(x, RING.position.y))
	for y in range(RING.position.y, RING.end.y):
		ring.append(Vector2i(RING.end.x, y))
	for x in range(RING.end.x, RING.position.x, -1):
		ring.append(Vector2i(x, RING.end.y))
	for y in range(RING.end.y, RING.position.y - 1, -1):
		ring.append(Vector2i(RING.position.x, y))
	_road(ring, true)
	# Spokes: lit from each camp exit out to the ring, dark beyond it.
	var spokes: Array = [[ENTRIES[0], Vector2i.LEFT, 1], [ENTRIES[1], Vector2i.RIGHT, SIZE.x - 2], [ENTRIES[2], Vector2i.UP, 1], [ENTRIES[3], Vector2i.DOWN, SIZE.y - 2]]
	for spoke: Array in spokes:
		var cells: Array[Vector2i] = []
		var cell: Vector2i = spoke[0]
		var step: Vector2i = spoke[1]
		var limit: int = spoke[2]
		while valid(cell) and (cell.x if step.x != 0 else cell.y) != limit + (step.x if step.x != 0 else step.y):
			cells.append(cell)
			cell += step
		var inner: Array[Vector2i] = []
		for index in range(cells.size()):
			inner.append(cells[index])
			if ring.has(cells[index]):
				break
		_road(inner, true)
		_road(cells.slice(inner.size() - 1), false)


func _road(cells: Array[Vector2i], lit: bool) -> void:
	for index in range(cells.size()):
		var cell := cells[index]
		road_cells[cell] = true
		if index > 0:
			var previous := cells[index - 1]
			_link(previous, cell)
			var a := center(previous)
			var b := center(cell)
			# Wide across the road, but only a normal trail half-width past each end,
			# so road ends meet existing trail squares without new wall stubs.
			var along := (b - a).normalized().abs()
			var half := along * HALF_TRAIL + (Vector2.ONE - along) * ROAD_HALF
			var rect := Rect2(a.min(b) - half, (b - a).abs() + half * 2)
			roads.append(rect)
			for y in range(int(floor(rect.position.y / 32)), int(ceil(rect.end.y / 32))):
				for x in range(int(floor(rect.position.x / 32)), int(ceil(rect.end.x / 32))):
					road_tiles[Vector2i(x, y)] = true
		if lit and index % 2 == 0 and zone_at(center(cell)).is_empty():
			var along := Vector2(cells[mini(index + 1, cells.size() - 1)] - cells[maxi(index - 1, 0)]).normalized()
			var side := along.orthogonal() * (1.0 if (index / 2) % 2 == 0 else -1.0)
			var post := center(cell) + side * (ROAD_HALF - 12)
			if not lamps.has(post):
				lamps.append(post)


## True on the dirt road surface (outside region clearings, which keep their own ground).
func on_road(point: Vector2) -> bool:
	return road_tiles.has(Vector2i((point / 32).floor())) and zone_at(point).is_empty()


func _make_signposts() -> void:
	# Graph data only (no RNG), so adding signs never shifts other seeded content.
	var to_camp := distances_from_many(ENTRIES)
	var to_zone: Array[Dictionary] = []
	for zone in zones:
		to_zone.append(distances_from(zone["cell"]))
	var junctions: Array = []
	for cell: Vector2i in links:
		if links[cell].size() >= 3 and zone_at(center(cell)).is_empty():
			junctions.append(cell)
	junctions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return to_camp[a] < to_camp[b] if to_camp[a] != to_camp[b] else a.y * SIZE.x + a.x < b.y * SIZE.x + b.x)
	for cell: Vector2i in junctions:
		var spaced := true
		var at := center(cell) + SIGN_OFFSET
		for post in signposts:
			if at.distance_to(post["position"]) < SIGN_SPACING:
				spaced = false
				break
		for landmark in landmarks:
			if center(cell).distance_to(landmark["position"]) < 160:
				spaced = false
		if not spaced:
			continue
		var home := next_step(cell, to_camp)
		if home == Vector2i.ZERO:
			# Camp exits sit beside the camp block; point straight into it.
			var offset := Vector2(CAMP_CELLS.get_center()) - Vector2(cell)
			home = Vector2i(signi(int(offset.x)), 0) if absf(offset.x) > absf(offset.y) else Vector2i(0, signi(int(offset.y)))
		var targets: Array[Dictionary] = [{"label": "CAMP", "short": "CAMP", "step": home}]
		var order: Array = range(zones.size())
		order.sort_custom(func(a: int, b: int) -> bool:
			return to_zone[a][cell] < to_zone[b][cell] if to_zone[a][cell] != to_zone[b][cell] else a < b)
		for index in order.slice(0, 2):
			targets.append({"label": short_name(zones[index]), "short": SIGN_NAMES.get(zones[index]["kind"], "?"), "step": next_step(cell, to_zone[index]), "zone": index})
		signposts.append({"cell": cell, "position": at, "targets": targets})


## Neighbouring cell on a shortest trail toward the distance field's source.
func next_step(cell: Vector2i, field: Dictionary) -> Vector2i:
	var best := cell
	for next: Vector2i in links[cell]:
		if field[next] < field[best] or (field[next] == field[best] and best != cell and next.y * SIZE.x + next.x < best.y * SIZE.x + best.x):
			best = next
	return best - cell


static func short_name(zone: Dictionary) -> String:
	var label: String = zone["label"]
	for prefix in ["NORTH", "EAST", "SOUTH", "WEST"]:
		if label.begins_with(prefix):
			return label.get_slice(" / ", 1)
	return label.get_slice(" / ", 0)


static func signpost_text(post: Dictionary) -> String:
	var parts: Array[String] = []
	for target: Dictionary in post["targets"]:
		parts.append("%s %s" % [target["label"], COMPASS.get(target["step"], "?")])
	return "SIGNPOST · " + " · ".join(parts)


func signpost_near(point: Vector2, radius: float = 72.0) -> Dictionary:
	for post in signposts:
		if point.distance_to(post["position"]) <= radius:
			return post
	return {}


func _link(a: Vector2i, b: Vector2i) -> void:
	if b not in links[a]:
		links[a].append(b)
		links[b].append(a)

func _connect_grid(start: Vector2i, goal: Vector2i) -> void:
	var parents := {start: start}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size() and not parents.has(goal):
		var cell := queue[cursor]
		cursor += 1
		for direction in DIRECTIONS:
			var next := cell + direction
			if valid(next) and not parents.has(next):
				parents[next] = cell
				queue.append(next)
	var cell := goal
	while cell != start:
		var previous: Vector2i = parents[cell]
		_link(cell, previous)
		cell = previous

func _make_zones(rng: RandomNumberGenerator) -> void:
	var definitions := [
		["village", "NORTHWEST / ABANDONED VILLAGE", Vector2i(rng.randi_range(15,16), rng.randi_range(16,17)), Vector2i(5,3)],
		["bog", "EAST / WITCH'S BOG", Vector2i(rng.randi_range(31,32), rng.randi_range(20,21)), Vector2i(4,4)],
		["graveyard", "SOUTH / OLD GRAVEYARD", Vector2i(rng.randi_range(23,24), rng.randi_range(29,30)), Vector2i(4,4)],
		["mill", "FLOODED MILL / PIPE LANES", Vector2i(9,20), Vector2i(4,4)],
		["orchard", "BRAMBLE ORCHARD / THREAD ROWS", Vector2i(13,32), Vector2i(4,4)],
		["observatory", "STARLESS OBSERVATORY", Vector2i(33,11), Vector2i(4,4)],
		["rail", "LAST-CAR RAIL YARD", Vector2i(37,30), Vector2i(5,3)],
		["quarry", "WHITE STONE QUARRY", Vector2i(8,8), Vector2i(4,4)],
		["chapel", "DROWNED CHAPEL / CANDLE COURT", Vector2i(27,38), Vector2i(4,4)]
	]
	for d in definitions:
		var anchor: Vector2i = d[2]
		var size: Vector2i = d[3]
		var bounds := Rect2(ORIGIN + Vector2(anchor) * CELL, Vector2(size) * CELL)
		zones.append({"kind":d[0], "label":d[1], "cell":anchor, "bounds":bounds, "position":bounds.get_center()})
		for y in range(size.y):
			for x in range(size.x):
				var cell := anchor + Vector2i(x,y)
				for direction in [Vector2i.RIGHT,Vector2i.DOWN]:
					var next: Vector2i = cell + direction
					if Rect2i(anchor,size).has_point(next):
						_link(cell,next)

func _carve(rect: Rect2) -> void:
	corridors.append(rect)
	for y in range(int(floor(rect.position.y/32)), int(ceil(rect.end.y/32))):
		for x in range(int(floor(rect.position.x/32)), int(ceil(rect.end.x/32))):
			open_tiles[Vector2i(x,y)] = true

func _make_walls() -> void:
	var previous := {}
	var first := Vector2i(ORIGIN / 32)
	for y in range(first.y, first.y + SIZE.y * CELL / 32):
		var row := {}
		var start := first.x
		for x in range(first.x, first.x + SIZE.x * CELL / 32 + 1):
			var solid := x < first.x + SIZE.x * CELL / 32 and not open_tiles.has(Vector2i(x,y))
			if solid and start < 0x7fffffff:
				continue
			if solid:
				start = x
			elif start < 0x7fffffff:
				if x > start:
					var key := Vector2i(start,x-start)
					if previous.has(key):
						var index: int = previous[key]
						walls[index].size.y += 32
						row[key] = index
					else:
						row[key] = walls.size()
						walls.append(Rect2(start*32,y*32,(x-start)*32,32))
				start = 0x7fffffff
		previous = row

func zone_at(point: Vector2) -> Dictionary:
	for zone in zones:
		if zone["bounds"].grow(32).has_point(point):
			return zone
	return {}

func roaming_route(start: Vector2i, steps: int = 16) -> Array[Vector2]:
	var result: Array[Vector2] = [center(start)]
	var seen := {start:true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty() and result.size() < steps:
		var cell: Vector2i = queue.pop_front()
		for next: Vector2i in links[cell]:
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
				result.append(center(next))
				if result.size() >= steps:
					break
	return result

func _farthest_first(a: Vector2i, b: Vector2i) -> bool:
	return landmark_distances[a] > landmark_distances[b] if landmark_distances[a] != landmark_distances[b] else a.y * SIZE.x + a.x < b.y * SIZE.x + b.x

func valid(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO,SIZE).has_point(cell) and not CAMP_CELLS.has_point(cell)

func center(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * CELL + Vector2.ONE * CELL * 0.5

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(((point-ORIGIN)/CELL).floor())

func walkable(point: Vector2) -> bool:
	return open_tiles.has(Vector2i((point/32).floor()))

func distances_from(start: Vector2i) -> Dictionary:
	var result := {start:0}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for next: Vector2i in links[cell]:
			if not result.has(next):
				result[next] = result[cell]+1
				queue.append(next)
	return result

func distances_from_many(starts: Array[Vector2i]) -> Dictionary:
	var result := {}
	var queue: Array[Vector2i] = []
	for start in starts:
		result[start] = 0
		queue.append(start)
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for next: Vector2i in links[cell]:
			if not result.has(next):
				result[next] = result[cell]+1
				queue.append(next)
	return result

func signature() -> String:
	var result := ""
	for y in range(SIZE.y):
		for x in range(SIZE.x):
			var cell := Vector2i(x,y)
			if not valid(cell):
				continue
			for d in DIRECTIONS:
				result += "1" if cell+d in links[cell] else "0"
	return result
