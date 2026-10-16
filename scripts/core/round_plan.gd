class_name RoundPlan
extends RefCounted
## Seeded authority-side run recipe. No gameplay relies on global RNG state.

var seed_value: int
var expedition: bool
var weather: String = "clear"
var woods := WoodsLayout.new()
var camp := CampLayout.new()
var required: Array[String] = ["battery", "fuel", "key"]
var loot: Array[Dictionary] = []
var encounters: Array[Dictionary] = []


func generate(value: int, mode: String) -> void:
	seed_value = value
	expedition = mode == "woods"
	weather = "clear"
	woods.generate(value)
	camp.generate(value, true)
	loot.clear()
	encounters.clear()
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
	var caches: Array = [
		{"position": woods.zones[0]["bounds"].position + Vector2(156, 116), "label": "VILLAGE / SURVEYOR HUT"},
		{"position": woods.zones[1]["position"] + Vector2(70, 60), "label": "WITCH'S BOG / STASH"},
		{"position": woods.zones[2]["position"] + Vector2(64, 70), "label": "OLD GRAVEYARD / CACHE"}
	]
	for index in range(caches.size() - 1, 0, -1):
		var chosen := rng.randi_range(0, index)
		var swap: Dictionary = caches[index]
		caches[index] = caches[chosen]
		caches[chosen] = swap
	for index in range(3):
		var kind := "fuel" if index == 0 else required[index + 2]
		_add(kind, caches[index]["position"], caches[index]["label"], true)
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
	_add("flare", Vector2(1304, 312), "MAINTENANCE", false)
	_add("battery_pack", Vector2(168, 356), "CAMPSITE", false)
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
	# Replace a subset of roaming duplicates, retaining a bounded 24-creature population.
	for index in range(homes.size() - 6):
		_encounter("switchback_hound" if index % 4 == 0 else species[(index + posmod(value,6)) % 6],homes[index])



func _encounter(species: String, cell: Vector2i) -> void:
	encounters.append({"species": species, "position": woods.center(cell), "cell": cell})


func _add(kind: String, at: Vector2, hint: String, locked: bool) -> void:
	loot.append({"kind": kind, "position": at, "hint": hint, "locked": locked})


func pack_description(installed: Array[String]) -> String:
	var lines: Array[String] = []
	for kind in required:
		var clue := ""
		for item in loot:
			if item["kind"] == kind:
				clue = item["hint"]
		lines.append(("✓ " if kind in installed else "· ") + kind.replace("_", " ").to_upper() + " / " + clue)
	return "\n".join(lines)
