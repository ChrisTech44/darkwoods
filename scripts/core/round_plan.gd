class_name RoundPlan
extends RefCounted
## Seeded authority-side run recipe. No gameplay relies on global RNG state.

const CRYPTID_COUNT := 48
var seed_value: int
var expedition: bool
var weather: String = "clear"
var woods := WoodsLayout.new()
var camp := CampLayout.new()
var required: Array[String] = ["battery", "fuel", "key"]
var loot: Array[Dictionary] = []
var encounters: Array[Dictionary] = []
var toolbox_hint: String = ""
## Expedition night schedule: phase that reveals each required part, and seeded events.
var reveal_phase: Dictionary = {}
var night_events: Array[Dictionary] = []
## F4b rotation: which region holds each locked-cache part tonight, and the
## ranger notes on the roads that name those regions.
const REGION_POOL := {"NORTH": [0, 5], "EAST": [1, 6], "SOUTH": [2, 8], "WEST": [3, 4]}
var cache_zone: Dictionary = {}
var cache_direction: Dictionary = {}


func generate(value: int, mode: String) -> void:
	seed_value = value
	expedition = mode == "woods"
	weather = "clear"
	woods.generate(value)
	camp.generate(value, true)
	loot.clear()
	encounters.clear()
	reveal_phase.clear()
	night_events.clear()
	cache_zone.clear()
	cache_direction.clear()
	required.assign(["battery", "fuel", "key"])
	var rng := RandomNumberGenerator.new()
	rng.seed = value + 771
	if not expedition:
		for index in range(3):
			loot.append({"kind": required[index], "position": camp.remap(CampMap.PICKUP_POSITIONS[index]), "hint": CampMap.PICKUP_HINTS[index], "locked": false})
		return
	weather = ["fog", "rain", "moonless"][rng.randi_range(0, 2)]
	var extras: Array[String] = ["fuse", "belt", "tire", "spark_plug"]
	for index in range(2):
		var chosen := rng.randi_range(0, extras.size() - 1)
		required.append(extras[chosen])
		extras.remove_at(chosen)
	var battery_pool: Array[Vector2] = [Vector2(228, 120), Vector2(564, 120), Vector2(960, 128)]
	var key_pool: Array[Vector2] = [Vector2(696, 680), Vector2(1096, 704)]
	_add("battery", battery_pool[rng.randi_range(0, 2)], "BUNK CABINS", false)
	_add("key", key_pool[rng.randi_range(0, 1)], "LODGE / FIRST AID", false)
	_add("boltcutters", Vector2(1304, 272), "MAINTENANCE", false)
	var caches: Array = _rotate_caches(value)
	for index in range(caches.size() - 1, 0, -1):
		var chosen := rng.randi_range(0, index)
		var swap: Dictionary = caches[index]
		caches[index] = caches[chosen]
		caches[chosen] = swap
	for index in range(3):
		var kind := "fuel" if index == 0 else required[index + 2]
		_add(kind, caches[index]["position"], caches[index]["label"], true)
		cache_zone[kind] = caches[index]["zone"]
		cache_direction[kind] = caches[index]["direction"]
	var supply_types: Array[String] = ["flare", "battery_pack", "rations", "medkit", "noise_tin", "salt_ward", "glow_moss"]
	for index in range(96):
		var cell := Vector2i(rng.randi_range(0, WoodsLayout.SIZE.x-1), rng.randi_range(0, WoodsLayout.SIZE.y-1))
		while not woods.valid(cell):
			cell = Vector2i(rng.randi_range(0, WoodsLayout.SIZE.x-1), rng.randi_range(0, WoodsLayout.SIZE.y-1))
		var at := woods.center(cell) + Vector2(16, 12)
		var zone := woods.zone_at(at)
		if not zone.is_empty() and zone["kind"] == "village":
			at.y = zone["bounds"].end.y - 48
		_add(supply_types[index % supply_types.size()], at, "WOODS SUPPLIES", false)
	for index in range(3):
		_add("flare", Vector2(1304, 312), "MAINTENANCE FLARE STASH", false)
	_add("battery_pack", Vector2(168, 356), "CAMPSITE", false)
	_add_spare_tools(value, battery_pool)
	_add_notes()
	_schedule_night(value)
	for item in loot:
		item["position"] = camp.remap(item["position"])
	_encounter("vampire", woods.zones[2]["cell"] + Vector2i(1,1))
	_encounter("witch", woods.zones[1]["cell"] + Vector2i(1,1))
	_encounter("werewolf", Vector2i(24,18))
	_encounter("bigfoot", Vector2i(18,24))
	_encounter("lantern_moth", Vector2i(25,30))
	_encounter("briar_revenant", Vector2i(32,26))
	var species: Array[String] = ["werewolf","bigfoot","lantern_moth","vampire","witch","briar_revenant"]
	var homes: Array[Vector2i] = [Vector2i(19,19),Vector2i(30,19),Vector2i(32,28),Vector2i(28,29),Vector2i(20,28),Vector2i(18,22),Vector2i(6,10),Vector2i(17,6),Vector2i(32,6),Vector2i(44,12),Vector2i(44,25),Vector2i(42,40),Vector2i(32,42),Vector2i(20,42),Vector2i(6,38),Vector2i(6,25),Vector2i(10,16),Vector2i(35,36)]
	var guardians := ["boiler_saint", "bramble_seamstress", "shutter_wraith", "last_car_conductor", "stoneback_ram", "candle_grazer"]
	for index in range(6):
		var zone: Dictionary = woods.zones[index + 3]
		var cell: Vector2i = zone["cell"] + Vector2i(1,1)
		_encounter(guardians[index], cell)
		encounters.back()["home"] = zone["bounds"].grow(48)
	# Preserve the original core encounters before adding the denser roaming ring.
	for index in range(homes.size() - 6):
		_encounter("switchback_hound" if index % 4 == 0 else species[(index + posmod(value,6)) % 6],homes[index])
	# Denser, seeded roaming encounters around the approaches, never inside camp or a landmark.
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in woods.links:
		var at := woods.center(cell)
		var distance := at.distance_to(CampMap.CAMP_BOUNDS.get_center())
		if distance > 850 and distance < 2400 and woods.zone_at(at).is_empty():
			candidates.append(cell)
	for index in range(candidates.size()-1,0,-1):
		var swap := rng.randi_range(0,index)
		var cell := candidates[index]
		candidates[index] = candidates[swap]
		candidates[swap] = cell
	var added: Array[Vector2] = []
	for cell in candidates:
		var at := woods.center(cell)
		var clear := true
		for existing: Vector2 in added:
			if at.distance_to(existing)<220: clear=false
		if not clear: continue
		_encounter(["relay_jackal","ration_moth","lens_eater","switchback_hound"][added.size()%4],cell)
		added.append(at)
		if encounters.size()==CRYPTID_COUNT: break


## Three regions in three different directions from camp, rotating every night.
## A separate RNG keeps the rest of the seeded recipe unchanged.
func _rotate_caches(value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = value + 4242
	var directions: Array = REGION_POOL.keys()
	for index in range(directions.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var held: String = directions[index]
		directions[index] = directions[swap]
		directions[swap] = held
	var caches: Array = []
	for direction: String in directions.slice(0, 3):
		var choices: Array = REGION_POOL[direction]
		var zone_index: int = choices[0] if rng.randf() < 0.5 else choices[1]
		var zone: Dictionary = woods.zones[zone_index]
		caches.append({"position": cache_spot(zone), "label": WoodsLayout.short_name(zone) + " / CACHE", "zone": zone_index, "direction": direction})
	return caches


static func cache_spot(zone: Dictionary) -> Vector2:
	match zone["kind"]:
		"village":
			return zone["bounds"].position + Vector2(156, 116)
		"bog":
			return zone["position"] + Vector2(70, 60)
		"graveyard":
			return zone["position"] + Vector2(64, 70)
	return zone["position"] + Vector2(-80, 80)


## Two ranger notes for each part the camp corkboard doesn't name, on road cells
## nearest that part's region, so finding one means you're heading the right way.
func _add_notes() -> void:
	for kind: String in cache_zone:
		if kind == "fuel":
			continue
		var target: Vector2 = woods.zones[cache_zone[kind]]["position"]
		var cells: Array = woods.road_cells.keys().filter(func(cell: Vector2i) -> bool: return woods.zone_at(woods.center(cell)).is_empty() and woods.center(cell).distance_to(CampMap.CAMP_BOUNDS.get_center()) > 700)
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da := woods.center(a).distance_to(target)
			var db := woods.center(b).distance_to(target)
			return da < db if da != db else a.y * WoodsLayout.SIZE.x + a.x < b.y * WoodsLayout.SIZE.x + b.x)
		var placed := 0
		for cell: Vector2i in cells:
			var at := woods.center(cell) + Vector2(-34, 46)
			if placed == 2:
				break
			if loot.any(func(item: Dictionary) -> bool: return item["kind"] == "ranger_note" and item["position"].distance_to(at) < 300):
				continue
			loot.append({"kind": "ranger_note", "position": at, "hint": "RANGER NOTE", "locked": false, "part": kind})
			placed += 1


## Parts arrive by ranger radio across the night so escapes land in the 40-60 minute window.
func _schedule_night(value: int) -> void:
	reveal_phase = {"battery": 0, "key": 0, "fuel": 1, required[3]: 2, required[4]: 3}
	var rng := RandomNumberGenerator.new()
	rng.seed = value + 5150
	var starts: Array[float] = NightClock.PHASE_STARTS
	night_events.append({"kind": "storm", "time": rng.randf_range(starts[1] + 120, starts[2] - 240)})
	night_events.append({"kind": "blackout", "time": rng.randf_range(starts[2] + 120, starts[3] - 240)})
	night_events.append({"kind": "storm" if rng.randf() < 0.5 else "blackout", "time": rng.randf_range(starts[3] + 180, NightClock.DAWN - 600)})


## Extra lock tools so a team can split up. A separate RNG keeps older seeded content unchanged.
func _add_spare_tools(value: int, battery_pool: Array[Vector2]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = value + 9091
	var free_bunks: Array[Vector2] = []
	for at in battery_pool:
		if not loot.any(func(item: Dictionary) -> bool: return item["kind"] == "battery" and item["position"] == at):
			free_bunks.append(at)
	_add("crowbar", free_bunks[rng.randi_range(0, free_bunks.size() - 1)], "BUNK CABINS", false)
	var camp_center := CampMap.CAMP_BOUNDS.get_center()
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in woods.links:
		var at := woods.center(cell)
		var distance := at.distance_to(camp_center)
		if distance > 1000 and distance < 1600 and woods.zone_at(at).is_empty() and woods.signpost_near(at - Vector2(20, -14), 48).is_empty():
			candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y * WoodsLayout.SIZE.x + a.x < b.y * WoodsLayout.SIZE.x + b.x)
	var chosen := woods.center(candidates[rng.randi_range(0, candidates.size() - 1)]) + Vector2(-20, 14)
	var bearing := chosen - camp_center
	toolbox_hint = ("N" if bearing.y < -absf(bearing.x) * 0.4 else ("S" if bearing.y > absf(bearing.x) * 0.4 else "")) + ("E" if bearing.x > absf(bearing.y) * 0.4 else ("W" if bearing.x < -absf(bearing.y) * 0.4 else ""))
	_add("boltcutters", chosen, "WOODS TOOLBOX / %s OF CAMP" % toolbox_hint, false)


func _encounter(species: String, cell: Vector2i) -> void:
	encounters.append({"species": species, "position": woods.center(cell), "cell": cell})


func _add(kind: String, at: Vector2, hint: String, locked: bool) -> void:
	loot.append({"kind": kind, "position": at, "hint": hint, "locked": locked})


func pack_description(installed: Array[String], phase: int = 3, clues: Dictionary = {}) -> String:
	var lines: Array[String] = []
	for kind in required:
		var where := clue_text(kind, clues.get(kind, 2))
		if reveal_phase.get(kind, 0) > phase:
			var due: int = reveal_phase[kind]
			lines.append("· %s / RADIO %s · %s" % [kind.replace("_", " ").to_upper(), NightClock.clock_text(NightClock.PHASE_STARTS[due]), where])
			continue
		lines.append(("✓ " if kind in installed else "· ") + kind.replace("_", " ").to_upper() + " / " + where)
	return "\n".join(lines)


## What the team knows about a part's location: 0 direction, 1 region, 2 cache found.
func clue_text(kind: String, level: int) -> String:
	if not cache_zone.has(kind):
		for item in loot:
			if item["kind"] == kind:
				return item["hint"]
		return ""
	# Short sign names match the signposts and skyline markers.
	var region: String = WoodsLayout.SIGN_NAMES[woods.zones[cache_zone[kind]]["kind"]]
	match level:
		0:
			return cache_direction[kind] + " WOODS? FIND A NOTE"
		1:
			return region
	return region + " (CACHE MAPPED)"


func region_name(kind: String) -> String:
	return WoodsLayout.short_name(woods.zones[cache_zone[kind]]) if cache_zone.has(kind) else ""
