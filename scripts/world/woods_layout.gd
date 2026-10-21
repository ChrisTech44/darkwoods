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
var received_exploration := PackedByteArray()
const EXPLORATION_BYTES := (SIZE.x * SIZE.y + 7) / 8
var landmark_distances: Dictionary = {}
var open_tiles: Dictionary = {}
var signposts: Array[Dictionary] = []
## A seeded bending distribution loop and winding spokes connect fixed camp
## exits to the outer forest. The maze between them stays dark.
const ROAD_HALF := 80
const RING := Rect2i(16, 17, 17, 14)
## Region approaches branch from the inner roads to the outer destinations.
var approaches: Array[Dictionary] = []
var ring_bounds := RING
var ring_cells: Array[Vector2i]=[]
var roads: Array[Rect2] = []
var road_cells: Dictionary = {}
var road_tiles: Dictionary = {}
var lamps: Array[Vector2] = []
## F4b-2 barriers (physics layer 8: blocks bodies, never sight or light).
## Gates close new shortcut trails from optional regions to the roads and open
## only from the region side; fences cross maze links that have a real detour.
const SHORTCUT_ZONES: Array[int] = [3, 4, 5, 6, 8]
const FENCE_LIMIT := 40
const FENCE_DETOUR := 8
var gates: Array[Dictionary] = []
var fences: Array[Dictionary] = []
## Links closed by barriers. Every new barrier must keep its two sides connected
## with all earlier ones closed, so the woods as a whole always stays connected.
var blocked: Dictionary = {}
const SIGN_SPACING := 640.0
const SIGN_OFFSET := Vector2(-44, -40)
## Short names for signboards, skyline markers and the map: each is a word (or
## two) taken from the region's full name, so they can be matched to it, and the
## woods boathouse never reads like the camp's (CAMP BOATHOUSE vs LAKESHORE).
const SIGN_NAMES := {"village":"VILLAGE", "bog":"BOG", "graveyard":"GRAVEYARD", "mill":"MILL", "orchard":"ORCHARD", "observatory":"OBSERVATORY", "rail":"RAIL YARD", "quarry":"QUARRY", "chapel":"CHAPEL", "substation":"SUBSTATION", "relay":"RADIO RELAY", "logging":"LOGGING CAMP", "boathouse":"LAKESHORE", "ranger":"RANGER GATE"}
const COMPASS := {Vector2i.UP:"N", Vector2i.DOWN:"S", Vector2i.LEFT:"W", Vector2i.RIGHT:"E"}

func generate(seed_value: int) -> void:
	links.clear()
	corridors.clear()
	walls.clear()
	landmarks.clear()
	zones.clear()
	visited.clear()
	received_exploration.clear()
	open_tiles.clear()
	signposts.clear()
	roads.clear()
	ring_cells.clear()
	approaches.clear()
	gates.clear()
	fences.clear()
	blocked.clear()
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
	_make_roads(rng)
	_make_shortcuts()
	_make_approaches(rng)
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
	_measure_gates()
	_make_fences(seed_value)

## Seeded distribution loop and bending spokes; camp exits remain fixed.
func _make_roads(rng: RandomNumberGenerator) -> void:
	ring_bounds=Rect2i(Vector2i(rng.randi_range(14,18),rng.randi_range(15,19)),Vector2i.ZERO)
	ring_bounds.size=Vector2i(rng.randi_range(31,35),rng.randi_range(30,34))-ring_bounds.position
	var middle:=ring_bounds.position+ring_bounds.size/2
	var anchors: Array[Vector2i]=[
		ring_bounds.position,
		Vector2i(middle.x+rng.randi_range(-2,2),ring_bounds.position.y+rng.randi_range(-2,2)),
		Vector2i(ring_bounds.end.x,ring_bounds.position.y),
		Vector2i(ring_bounds.end.x+rng.randi_range(-2,2),middle.y+rng.randi_range(-2,2)),
		ring_bounds.end,
		Vector2i(middle.x+rng.randi_range(-2,2),ring_bounds.end.y+rng.randi_range(-2,2)),
		Vector2i(ring_bounds.position.x,ring_bounds.end.y),
		Vector2i(ring_bounds.position.x+rng.randi_range(-2,2),middle.y+rng.randi_range(-2,2))]
	for i in range(anchors.size()):
		var segment:=_connect_grid(anchors[i],anchors[(i+1)%anchors.size()],rng)
		ring_cells.append_array(segment if ring_cells.is_empty() else segment.slice(1))
	_road(ring_cells,true)
	var desires: Array[Vector2i]=[
		Vector2i(ring_bounds.position.x,rng.randi_range(22,26)),
		Vector2i(ring_bounds.end.x,rng.randi_range(22,26)),
		Vector2i(rng.randi_range(22,27),ring_bounds.position.y),
		Vector2i(rng.randi_range(22,27),ring_bounds.end.y)]
	var targets: Array[Vector2i]=[]
	for desired in desires:
		var closest: Vector2i=ring_cells[0]
		for cell in ring_cells:
			if Vector2(cell-desired).length_squared()<Vector2(closest-desired).length_squared():closest=cell
		targets.append(closest)
	var edges: Array[Vector2i]=[
		Vector2i(1,rng.randi_range(7,41)),Vector2i(SIZE.x-2,rng.randi_range(7,41)),
		Vector2i(rng.randi_range(7,42),1),Vector2i(rng.randi_range(7,42),SIZE.y-2)]
	for index in range(ENTRIES.size()):
		_road(_connect_grid(ENTRIES[index],targets[index],rng),true)
		_road(_connect_grid(targets[index],edges[index],rng),false)


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


## Straight trail from an outer optional region to the nearest road (up to 20
## cells, matching the longer journey). The gate sits on the last link, next to the road.
func _make_shortcuts() -> void:
	for zone_index in SHORTCUT_ZONES:
		var zone: Dictionary = zones[zone_index]
		var area := Rect2i(zone["cell"], Vector2i(zone["bounds"].size / CELL))
		var best: Array = []
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				for direction in DIRECTIONS:
					var start := Vector2i(x, y)
					if area.has_point(start + direction):
						continue
					for step in range(1, 21):
						var next := start + direction * step
						if not valid(next) or not zone_at(center(next)).is_empty():
							break
						if road_cells.has(next):
							if best.is_empty() or step < best[2]:
								best = [start, direction, step]
							break
		if best.is_empty():
			continue
		var cells: Array[Vector2i] = []
		for step in range(best[2] + 1):
			cells.append(best[0] + best[1] * step)
		for index in range(1, cells.size()):
			_link(cells[index - 1], cells[index])
		gates.append({"zone": zone_index, "inner": cells[-2], "road": cells[-1], "toward_zone": -Vector2(best[1]), "open": false,"path":cells})


## Gate rectangles need the carved trail, so they are measured after walls.
func _measure_gates() -> void:
	var kept: Array[Dictionary]=[]
	for gate in gates:
		var route: Array[Vector2i]=[];route.assign(gate.path)
		# A winding road can make its immediate junction too wide for a gate.
		# Try earlier links on this same shortcut, retaining region-side latching.
		for i in range(route.size()-1,0,-1):
			var inner: Vector2i=route[i-1]
			var road: Vector2i=route[i]
			if not zone_at(center(inner)).is_empty():continue
			var at: Vector2=(center(inner)+center(road))*.5
			var across:=Vector2(gate.toward_zone).orthogonal().abs()
			var rect:=barrier_rect(at,across)
			if rect.has_area() and _connected_without(inner,road):
				gate.inner=inner;gate.road=road;gate.position=at;gate.rect=rect
				kept.append(gate);_block(inner,road);break
	gates=kept


## Fences on maze links (not roads, regions or gates) where going around costs
## at least FENCE_DETOUR cells, so vaulting is a real escape.
func _make_fences(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 9393
	var pairs: Array = []
	for cell: Vector2i in links:
		for next: Vector2i in links[cell]:
			if next.y * SIZE.x + next.x > cell.y * SIZE.x + cell.x and not road_cells.has(cell) and not road_cells.has(next):
				if zone_at(center(cell)).is_empty() and zone_at(center(next)).is_empty():
					pairs.append([cell, next])
	for index in range(pairs.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var held: Array = pairs[index]
		pairs[index] = pairs[swap]
		pairs[swap] = held
	var placed: Array[Vector2] = []
	for pair: Array in pairs:
		if fences.size() >= FENCE_LIMIT:
			break
		var at := (center(pair[0]) + center(pair[1])) * 0.5
		if placed.any(func(other: Vector2) -> bool: return other.distance_to(at) < 900) or at.distance_to(CAMP_BOUNDS.get_center()) < 900:
			continue
		if gates.any(func(gate: Dictionary) -> bool: return gate["position"].distance_to(at) < 300) or not signpost_near(at, 140).is_empty():
			continue
		var detour := _detour(pair[0], pair[1])
		if detour < FENCE_DETOUR:
			continue
		var rect := barrier_rect(at, Vector2(pair[1] - pair[0]).orthogonal().abs())
		if not rect.has_area():
			continue
		fences.append({"cells": pair, "position": at, "rect": rect, "travel": Vector2(pair[1] - pair[0]), "detour": detour})
		placed.append(at)
		_block(pair[0], pair[1])


## Wall-to-wall bar across the open trail at `at`, or an empty rect if too wide.
func barrier_rect(at: Vector2, across: Vector2) -> Rect2:
	var reach: Array[float] = [0.0, 0.0]
	for side in range(2):
		var direction := across * (1.0 if side == 0 else -1.0)
		while reach[side] < 100.0 and walkable(at + direction * (reach[side] + 4.0)):
			reach[side] += 4.0
	if reach[0] + reach[1] > 180.0 or reach[0] < 24.0 or reach[1] < 24.0:
		return Rect2()
	var start: Vector2 = at - across * (reach[1] + 8.0)
	var finish: Vector2 = at + across * (reach[0] + 8.0)
	var thickness := Vector2.ONE * 8.0 - across * 8.0
	return Rect2(start.min(finish) - thickness * 0.5, (finish - start).abs() + thickness)


func barriers() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for gate in gates:
		result.append(gate["rect"])
	for fence in fences:
		result.append(fence["rect"])
	return result


func _block(a: Vector2i, b: Vector2i) -> void:
	blocked[[a, b]] = true
	blocked[[b, a]] = true


## Graph steps from a to b without the direct a-b link or any barrier-closed link
## (-1 if that would cut them apart).
func _detour(a: Vector2i, b: Vector2i) -> int:
	var seen := {a: 0}
	var queue: Array[Vector2i] = [a]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for next: Vector2i in links[cell]:
			if (cell == a and next == b) or (cell == b and next == a) or seen.has(next) or blocked.has([cell, next]):
				continue
			seen[next] = seen[cell] + 1
			if next == b:
				return seen[next]
			queue.append(next)
	return -1


func _connected_without(a: Vector2i, b: Vector2i) -> bool:
	return _detour(a, b) > 0


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

## Each destination gets a traversable approach from the closest inner road.
## Roads retain their existing lighting; these are ordinary unlit forest trails.
func _make_approaches(rng: RandomNumberGenerator) -> void:
	for index in range(zones.size()):
		var zone: Dictionary = zones[index]
		var goal := cell_at(zone["position"])
		var start := ENTRY
		var gap := INF
		for cell: Vector2i in road_cells:
			if not ring_bounds.grow(1).has_point(cell): continue
			var distance := Vector2(cell-goal).length_squared()
			if distance < gap:
				gap = distance
				start = cell
		approaches.append({"zone":index,"cells":_connect_grid(start,goal,rng)})

func _connect_grid(start: Vector2i, goal: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var parents := {start: start}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size() and not parents.has(goal):
		var cell := queue[cursor]
		cursor += 1
		var directions:=DIRECTIONS.duplicate()
		for i in range(directions.size()-1,0,-1):
			var j:=rng.randi_range(0,i)
			var held: Vector2i=directions[i];directions[i]=directions[j];directions[j]=held
		for direction in directions:
			var next: Vector2i = cell + direction
			if valid(next) and not parents.has(next):
				parents[next] = cell
				queue.append(next)
	var route: Array[Vector2i] = [goal]
	var cell := goal
	while cell != start:
		var previous: Vector2i = parents[cell]
		_link(cell, previous)
		cell = previous
		route.append(cell)
	route.reverse()
	return route

func _make_zones(rng: RandomNumberGenerator,attempt: int=0) -> void:
	var definitions := [
		["village","ABANDONED VILLAGE",Vector2i(5,3)],
		["bog","WITCH'S BOG",Vector2i(4,4)],
		["graveyard","OLD GRAVEYARD",Vector2i(4,4)],
		["mill","FLOODED MILL / PIPE LANES",Vector2i(4,4)],
		["orchard","BRAMBLE ORCHARD / THREAD ROWS",Vector2i(4,4)],
		["observatory","STARLESS OBSERVATORY",Vector2i(4,4)],
		["rail","LAST-CAR RAIL YARD",Vector2i(5,3)],
		["quarry","WHITE STONE QUARRY",Vector2i(4,4)],
		["chapel","DROWNED CHAPEL / CANDLE COURT",Vector2i(4,4)],
		["substation","POWER SUBSTATION",Vector2i(3,3)],
		["relay","RADIO RELAY STATION",Vector2i(3,3)],
		["logging","LOGGING CAMP",Vector2i(3,3)],
		["boathouse","LAKESHORE BOATHOUSE",Vector2i(4,4)],
		["ranger","RANGER ROAD AND BRIDGE",Vector2i(3,7)]]
	var slots: Array[Vector2]=[]
	var phase:=rng.randf()*8.0
	for index in range(definitions.size()):
		var t:=fposmod(phase+8.0*index/definitions.size()+rng.randf_range(-.06,.06),8.0)
		var edge: Vector2
		if t<2:edge=Vector2(-1+t,-1)
		elif t<4:edge=Vector2(1,t-3)
		elif t<6:edge=Vector2(5-t,1)
		else:edge=Vector2(-1,7-t)
		slots.append(WORLD_BOUNDS.get_center()+edge*WORLD_BOUNDS.size*.5*rng.randf_range(.825,.845))
	# Rare corner/large-footprint conflicts retry before mutating the trail graph.
	# A roomy perimeter fallback bounds work even for an adversarial RNG sequence.
	if attempt>=32:
		slots.clear()
		for cell: Vector2 in [Vector2(5,4.5),Vector2(14,4.5),Vector2(24,4.5),Vector2(34,4.5),Vector2(44,4.5),Vector2(46,18),Vector2(46,32),Vector2(44,44.5),Vector2(34,44.5),Vector2(24,44.5),Vector2(14,44.5),Vector2(5,44.5),Vector2(4,32),Vector2(4,18)]:
			slots.append(ORIGIN+cell*CELL)
	var assignment: Array=range(definitions.size())
	for i in range(assignment.size()-1,0,-1):
		var j:=rng.randi_range(0,i)
		var held: int=assignment[i];assignment[i]=assignment[j];assignment[j]=held
	# The radio's three fixed sites form a spread triangle, rotated by the seed.
	# The fuse and every movable objective are optimized after trails/barriers exist.
	for row in [[9,0],[10,5],[8,9]]:
		var previous: int=assignment[row[0]]
		var other:=assignment.find(row[1])
		assignment[row[0]]=row[1];assignment[other]=previous
	var pending: Array[Dictionary]=[]
	for index in range(definitions.size()):
		var d: Array=definitions[index]
		var size: Vector2i=d[2]
		var anchor:=Vector2i(((slots[assignment[index]]-ORIGIN)/CELL-Vector2(size)*.5).round())
		anchor=anchor.clamp(Vector2i.ONE,SIZE-size-Vector2i.ONE)
		var bounds:=Rect2(ORIGIN+Vector2(anchor)*CELL,Vector2(size)*CELL)
		pending.append({"kind":d[0],"label":bearing(bounds.get_center())+" / "+d[1],"cell":anchor,"bounds":bounds,"position":bounds.get_center()})
	for i in range(pending.size()):
		for j in range(i):
			if pending[i].bounds.grow(48).intersects(pending[j].bounds.grow(48)):
				assert(attempt<32,"Roomy region fallback must remain separated")
				_make_zones(rng,attempt+1);return
	zones.assign(pending)
	for zone in zones:
		var anchor: Vector2i=zone.cell
		var size:=Vector2i(zone.bounds.size/CELL)
		for y in range(size.y):
			for x in range(size.x):
				var cell:=anchor+Vector2i(x,y)
				for direction in [Vector2i.RIGHT,Vector2i.DOWN]:
					var next: Vector2i=cell+direction
					if Rect2i(anchor,size).has_point(next):_link(cell,next)

static func cardinal(point: Vector2) -> String:
	var diff:=point-CAMP_BOUNDS.get_center()
	return ("EAST" if diff.x>0 else "WEST") if absf(diff.x)>absf(diff.y) else ("SOUTH" if diff.y>0 else "NORTH")

static func bearing(point: Vector2) -> String:
	var diff:=point-CAMP_BOUNDS.get_center()
	var vertical: String="NORTH" if diff.y<0 else "SOUTH"
	var horizontal: String="EAST" if diff.x>0 else "WEST"
	if absf(diff.x)<absf(diff.y)*.45:return vertical
	if absf(diff.y)<absf(diff.x)*.45:return horizontal
	return vertical+horizontal

## Trail-distance fields with every optional shortcut and fence still closed.
func closed_distances(starts: Array[Vector2i]) -> Dictionary:
	var result: Dictionary={}
	var queue: Array[Vector2i]=[]
	for cell in starts:
		if links.has(cell):result[cell]=0;queue.append(cell)
	var cursor:=0
	while cursor<queue.size():
		var cell:=queue[cursor];cursor+=1
		for next: Vector2i in links[cell]:
			if not result.has(next) and not blocked.has([cell,next]):
				result[next]=result[cell]+1;queue.append(next)
	return result


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


## Full team coverage costs at most 307 bytes before normal snapshot compression.
func exploration_snapshot() -> PackedByteArray:
	var bits := PackedByteArray()
	bits.resize(EXPLORATION_BYTES)
	for cell: Vector2i in visited:
		if not valid(cell): continue
		var index := cell.y * SIZE.x + cell.x
		bits[index >> 3] |= 1 << (index & 7)
	return bits


## Complete authority snapshots recover missed visits without a reliable stream.
func restore_exploration(bits: PackedByteArray) -> void:
	if bits.size() != EXPLORATION_BYTES or bits == received_exploration: return
	var accepted := {}
	for byte in range(bits.size()):
		if bits[byte] == 0: continue
		for bit in range(8):
			if (bits[byte] & (1 << bit)) == 0: continue
			var index := byte * 8 + bit
			var cell := Vector2i(index % SIZE.x, index / SIZE.x)
			if valid(cell): accepted[cell] = true
	visited = accepted
	received_exploration = bits.duplicate()
