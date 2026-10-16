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
var visited: Dictionary = {}
var landmark_distances: Dictionary = {}


func generate(seed_value: int) -> void:
	links.clear()
	corridors.clear()
	walls.clear()
	landmarks.clear()
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
	for cell: Vector2i in links:
		var at := center(cell)
		corridors.append(Rect2(at - Vector2(48, 48), Vector2(96, 96)))
		for neighbor: Vector2i in links[cell]:
			var other := center(neighbor)
			corridors.append(Rect2(Vector2(minf(at.x, other.x), minf(at.y, other.y)) - Vector2(48, 48), (other - at).abs() + Vector2(96, 96)))
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
