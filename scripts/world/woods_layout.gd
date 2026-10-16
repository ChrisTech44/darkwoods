class_name WoodsLayout
extends RefCounted
## A finite seeded trail maze, with loops. Every clearing is reachable by design.

const ORIGIN := Vector2(1696, 120)
const SIZE := Vector2i(10, 10)
const CELL := 160
const ENTRY := Vector2i(0, 2)
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
var links: Dictionary = {}
var corridors: Array[Rect2] = []
var walls: Array[Rect2] = []
var landmarks: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var visited: Dictionary = {}
var landmark_distances: Dictionary = {}


func generate(seed_value: int) -> void:
	links.clear()
	corridors.clear()
	walls.clear()
	landmarks.clear()
	zones.clear()
	visited.clear()
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
	# Alternate connections prevent a single corridor from being the only escape.
	for index in range(22):
		var cell := Vector2i(rng.randi_range(0, 9), rng.randi_range(0, 9))
		var neighbor := cell + DIRECTIONS[rng.randi_range(0, 3)]
		if valid(neighbor) and neighbor not in links[cell]:
			links[cell].append(neighbor)
			links[neighbor].append(cell)
	_make_zones(rng)
	for cell: Vector2i in links:
		var at := center(cell)
		corridors.append(Rect2(at - Vector2(48, 48), Vector2(96, 96)))
		for neighbor: Vector2i in links[cell]:
			var other := center(neighbor)
			corridors.append(Rect2(Vector2(minf(at.x, other.x), minf(at.y, other.y)) - Vector2(48, 48), (other - at).abs() + Vector2(96, 96)))
	for zone in zones:
		corridors.append(zone["bounds"])
	corridors.append(Rect2(1512, 488, 296, 64))
	# Merge solid 32px cells into row spans for efficient physics/navigation.
	for y in range(50):
		var run_start := -1
		for x in range(51):
			var solid := x < 50 and not walkable(ORIGIN + Vector2(x * 32 + 16, y * 32 + 16))
			if solid and run_start < 0:
				run_start = x
			if not solid and run_start >= 0:
				walls.append(Rect2(ORIGIN + Vector2(run_start * 32, y * 32), Vector2((x - run_start) * 32, 32)))
				run_start = -1
	landmark_distances = distances_from(ENTRY)
	var candidates: Array = links.keys()
	candidates.sort_custom(_farthest_first)
	var labels := ["THE SPLIT STUMP", "OLD HUNTER'S BLIND", "HOLLOW ROCK CAVE", "FALLEN WATCHTOWER", "THE CROOKED SHRINE", "RUSTED SCRAP CACHE"]
	for cell: Vector2i in candidates:
		var spaced := true
		for landmark in landmarks:
			if center(cell).distance_to(landmark["position"]) < 310:
				spaced = false
		if spaced:
			landmarks.append({"cell": cell, "position": center(cell), "label": labels[landmarks.size()]})
		if landmarks.size() == labels.size():
			break
	landmark_distances.clear()


func _make_zones(rng: RandomNumberGenerator) -> void:
	var definitions := [
		["village", "ABANDONED VILLAGE", Vector2i(rng.randi_range(1, 2), 1), Vector2i(3, 2)],
		["bog", "WITCH'S BOG", Vector2i(rng.randi_range(4, 5), 5), Vector2i(2, 2)],
		["graveyard", "OLD GRAVEYARD", Vector2i(7, rng.randi_range(1, 2)), Vector2i(2, 2)]
	]
	for definition in definitions:
		var anchor: Vector2i = definition[2]
		var dimensions: Vector2i = definition[3]
		var bounds := Rect2(center(anchor) - Vector2(48, 48), Vector2(dimensions - Vector2i.ONE) * CELL + Vector2(96, 96))
		zones.append({"kind": definition[0], "label": definition[1], "cell": anchor, "bounds": bounds, "position": bounds.get_center()})
		for y in range(dimensions.y):
			for x in range(dimensions.x):
				var cell := anchor + Vector2i(x, y)
				for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
					var next: Vector2i = cell + direction
					if Rect2i(anchor, dimensions).has_point(next) and next not in links[cell]:
						links[cell].append(next)
						links[next].append(cell)


func zone_at(point: Vector2) -> Dictionary:
	for zone in zones:
		if zone["bounds"].has_point(point):
			return zone
	return {}


func roaming_route(start: Vector2i, steps: int = 8) -> Array[Vector2]:
	# Explore branching trails around a home area instead of pacing one doorway.
	var result: Array[Vector2] = [center(start)]
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty() and result.size() < steps:
		var cell: Vector2i = queue.pop_front()
		for neighbor: Vector2i in links[cell]:
			if not seen.has(neighbor):
				seen[neighbor] = true
				queue.append(neighbor)
				result.append(center(neighbor))
				if result.size() >= steps:
					break
	return result


func _farthest_first(a: Vector2i, b: Vector2i) -> bool:
	if landmark_distances[a] == landmark_distances[b]:
		return a.y * SIZE.x + a.x < b.y * SIZE.x + b.x
	return landmark_distances[a] > landmark_distances[b]


func valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y


func center(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * CELL + Vector2(80, 80)


func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(((point - ORIGIN) / CELL).floor())


func walkable(point: Vector2) -> bool:
	for corridor in corridors:
		if corridor.has_point(point):
			return true
	return false


func distances_from(start: Vector2i) -> Dictionary:
	var result := {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for next: Vector2i in links[current]:
			if not result.has(next):
				result[next] = result[current] + 1
				queue.append(next)
	return result


func signature() -> String:
	var result := ""
	for y in range(10):
		for x in range(10):
			var cell := Vector2i(x, y)
			for direction in DIRECTIONS:
				result += "1" if cell + direction in links[cell] else "0"
	return result
