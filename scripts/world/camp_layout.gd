class_name CampLayout
extends RefCounted
## Bounded seeded camp lots. Roads reserve space before buildings are placed.

const BASE := [
	[Rect2(144, 72, 144, 96), "cabin", "FERN BUNK CABIN"],
	[Rect2(480, 72, 144, 96), "cabin", "PINE BUNK CABIN"],
	[Rect2(408, 312, 120, 96), "cabin", "OLD STORAGE"],
	[Rect2(800, 64, 208, 160), "bunkhouse", "CEDAR BUNKHOUSE"],
	[Rect2(1136, 184, 240, 192), "workshop", "MAINTENANCE"],
	[Rect2(832, 320, 256, 160), "mess", "MESS HALL"],
	[Rect2(480, 600, 288, 224), "ranger", "RANGER LODGE"],
	[Rect2(256, 608, 176, 176), "bath", "BATHHOUSE"],
	[Rect2(960, 640, 176, 160), "infirmary", "FIRST AID"],
	[Rect2(1200, 624, 224, 160), "boat", "CAMP BOATHOUSE"]
]
const MAIN_ROADS: Array[Rect2] = [
	Rect2(36, 192, 716, 48), Rect2(736, 192, 48, 104),
	Rect2(752, 248, 352, 32), Rect2(1100, 248, 24, 296),
	Rect2(72, 216, 48, 696), Rect2(96, 496, 1352, 48),
	Rect2(784, 240, 32, 656), Rect2(96, 864, 1250, 32),
	Rect2(0,496,96,48), Rect2(1448,496,88,48),
	Rect2(656,0,32,240), Rect2(848,864,32,96)
]
const LAKE := Rect2(1056, 800, 448, 128)
var entries: Array = []
var roads: Array[Rect2] = []


func generate(seed_value: int, randomized: bool) -> void:
	entries = BASE.duplicate(true)
	roads.assign(MAIN_ROADS)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 41317
	if randomized:
		for index in range(entries.size()):
			var original: Rect2 = BASE[index][0]
			for attempt in range(48):
				var candidate := Rect2(original.position + Vector2(rng.randi_range(-6, 6), rng.randi_range(-3, 3)) * 16, original.size)
				if _fits(candidate, index):
					entries[index][0] = candidate
					break
		if rng.randi_range(0, 1) == 1:
			_swap_lots(0, 1)
		if rng.randi_range(0, 1) == 1:
			_swap_lots(7, 8)
	for entry in entries:
		var rect: Rect2 = entry[0]
		var door_x := rect.position.x + (60 if rect.size.x <= 176 else 112)
		var target_y := 264.0 if rect.end.y < 248 else (520.0 if rect.end.y < 496 else 880.0)
		roads.append(Rect2(door_x - 16, rect.end.y, 32, target_y - rect.end.y + 8))


func _swap_lots(a: int, b: int) -> void:
	var original_a: Rect2 = entries[a][0]
	var original_b: Rect2 = entries[b][0]
	var at_a := original_b.position
	var at_b := original_a.position
	if a == 7:
		at_a.y = minf(original_a.position.y, original_b.position.y)
		at_b.y = at_a.y
	entries[a][0] = Rect2(at_a, original_a.size)
	entries[b][0] = Rect2(at_b, original_b.size)
	if not _fits(entries[a][0], a) or not _fits(entries[b][0], b):
		entries[a][0] = original_a
		entries[b][0] = original_b


func _fits(candidate: Rect2, index: int) -> bool:
	if not Rect2(136, 32, 1352, 808).encloses(candidate.grow(12)) or candidate.grow(12).intersects(LAKE):
		return false
	for road in MAIN_ROADS:
		if candidate.grow(12).intersects(road):
			return false
	for other in range(entries.size()):
		if other != index and candidate.grow(32).intersects(entries[other][0]):
			return false
	# Preserve a south-facing approach all the way to its row's trail.
	var target_y := 264.0 if candidate.end.y < 248 else (520.0 if candidate.end.y < 496 else 880.0)
	var door_x := candidate.position.x + (60 if candidate.size.x <= 176 else 112)
	var approach := Rect2(door_x - 24, candidate.end.y, 48, target_y - candidate.end.y)
	for other in range(entries.size()):
		if other == index:
			continue
		var rect: Rect2 = entries[other][0]
		if approach.intersects(rect):
			return false
		var other_y := 264.0 if rect.end.y < 248 else (520.0 if rect.end.y < 496 else 880.0)
		var other_x := rect.position.x + (60 if rect.size.x <= 176 else 112)
		if candidate.grow(12).intersects(Rect2(other_x - 16, rect.end.y, 32, other_y - rect.end.y)):
			return false
	return true


func remap(point: Vector2) -> Vector2:
	for index in range(BASE.size()):
		var original: Rect2 = BASE[index][0]
		if original.has_point(point):
			return point + entries[index][0].position - original.position
	return point


func signature() -> String:
	return str(entries)
