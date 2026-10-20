class_name RoundPlan
extends RefCounted
## Seeded authority-side run recipe. No gameplay relies on global RNG state.

## Two region dwellers, six landmark guardians (the Rail Yard's jackals come
## as a pair), and all 22 roaming kinds: 31 creatures plus the headline Stalker.
const ROAMERS := 27
const CRYPTID_COUNT := 9 + ROAMERS
## No roaming creature starts this close to camp (the first stretch is for exploring).
const SAFE_RADIUS := 1100.0
## Every roaming kind appears once. Seeded order and placement still vary.
const ROAMER_SPECIES: Array[String] = ["werewolf", "bigfoot", "lantern_moth", "ration_moth", "briar_revenant", "switchback_hound", "lens_eater",
	"last_car_conductor", "mimic", "owl", "bog_hands", "imps", "teddy",
	"groundskeeper", "cuckoo", "banshee", "slug", "surveyor", "hitchhiker", "tollkeeper", "echo", "fortune_teller", "lifeguard", "nightlight_kid", "vulture", "nobody", "huntmaster"]
## Region guardians in zones 3..8: Mill, Orchard, Observatory, Rail Yard, Quarry, Chapel.
const GUARDIANS: Array[String] = ["boiler_saint", "bramble_seamstress", "shutter_wraith", "relay_jackal", "stoneback_ram", "candle_grazer"]
## Monster-revamp items in the woods (count each) and at camp spots.
const CREATURE_LOOT := {"garlic": 4, "wolfsbane": 3, "bug_spray": 3, "train_ticket": 3, "coffee": 2}
## Camp items wait on the porch beside a building's door (the level resolves the
## spot from tonight's layout, so it is always open ground): [kind, building].
const CAMP_CREATURE_LOOT: Array = [["air_horn", "MAINTENANCE"], ["coffee", "RANGER LODGE"], ["coffee", "MESS HALL"],
	["scissors", "FIRST AID"], ["scissors", "FERN BUNK CABIN"], ["bug_spray", "CEDAR BUNKHOUSE"]]
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
var gate_regions: Dictionary = {}
## F5c: tonight's escapes. The van always, plus one rumoured secondary chosen by seed.
const SECONDARY_ESCAPES: Array[String] = ["radio", "boat", "gate", "signal"]
const ESCAPE_NAMES := {"van": "THE CAMP VAN", "radio": "RADIO RESCUE", "boat": "THE LAKESHORE BOAT", "gate": "THE RANGER GATE", "signal": "THE SIGNAL FIRE"}
## Test fixtures set this (launch flag --all-escapes) to exercise every escape on one seed.
static var force_all_escapes := false
var escape_options: Array[String] = ["van"]
## F7: tonight's headline killer and 0–2 night modifiers (separate seeded RNGs).
## The Stalker is the game's antagonist every night (the Groundskeeper is now a
## woods creature with his own mower, not an alternative headliner).
const HEADLINES: Array[String] = ["stalker"]
const MODIFIERS: Array[String] = ["blood_moon", "dead_batteries", "fog_bank", "silent_night", "generous_woods", "lone_wolf"]
const MODIFIER_NAMES := {"blood_moon": "BLOOD MOON", "dead_batteries": "DEAD BATTERIES", "fog_bank": "FOG BANK", "silent_night": "SILENT NIGHT", "generous_woods": "GENEROUS WOODS", "lone_wolf": "LONE WOLF"}
const MODIFIER_RULES := {"blood_moon": "the moon comes out more often; the killer runs faster; every creature type remains", "dead_batteries": "spare batteries hold 40 charge", "fog_bank": "thick fog: shorter sight for everyone", "silent_night": "no music; creatures hear farther", "generous_woods": "half again as many supplies", "lone_wolf": "everyone starts in a different cabin"}
## Fixtures: null = seeded; otherwise the exact list to use (launch flag --no-modifiers sets []).
static var force_modifiers: Variant = null
static var force_headline := ""
var headline := "stalker"
var modifiers: Array[String] = []
var signal_regions: Dictionary = {}


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
	gate_regions.clear()
	signal_regions.clear()
	escape_options.assign(["van"])
	headline = "stalker"
	modifiers.clear()
	required.assign(["battery", "fuel", "key"])
	var rng := RandomNumberGenerator.new()
	rng.seed = value + 771
	if not expedition:
		for index in range(3):
			loot.append({"kind": required[index], "position": camp.remap(CampMap.PICKUP_POSITIONS[index]), "hint": CampMap.PICKUP_HINTS[index], "locked": false})
		return
	weather = ["fog", "rain", "moonless"][rng.randi_range(0, 2)]
	_choose_night_rules(value)
	if has_modifier("fog_bank"):
		weather = "fog"
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
	_add_creature_items(value)
	_add_spare_tools(value, battery_pool)
	_add_notes()
	_choose_escapes(value)
	# Separate objective/tool inventory, never a belt slot or a van component.
	# The substation fuse powers both the radio relay and the gate floodlights.
	if has_escape("radio") or has_escape("gate"):
		_add("rescue_fuse", woods.zones[3]["position"] + Vector2(76, 88), "FLOODED MILL / EMERGENCY FUSE", false)
	if has_escape("radio"):
		for index in range(3):
			_add("flare", woods.zones[8]["position"] + Vector2(-76 + index * 18, 230), "CHAPEL / RESCUE SIGNAL STASH", false)
	_add_field_escapes(value)
	_add_signal_fire(value)
	if has_modifier("generous_woods"):
		var extra := RandomNumberGenerator.new()
		extra.seed = value + 2828
		var kinds: Array[String] = ["flare", "battery_pack", "rations", "medkit", "noise_tin", "salt_ward"]
		for index in range(48):
			var cell := Vector2i(extra.randi_range(0, WoodsLayout.SIZE.x - 1), extra.randi_range(0, WoodsLayout.SIZE.y - 1))
			if woods.valid(cell) and woods.links.has(cell):
				_add(kinds[index % kinds.size()], woods.center(cell) + Vector2(-16, 12), "WOODS SUPPLIES", false)
	_schedule_night(value)
	for item in loot:
		# Keep ordinary seeded supplies off the new solid lake banks.
		var lake: Vector2 = woods.zones[12]["position"]
		if FieldEscapeArt.water_rects(lake).any(func(rect: Rect2) -> bool: return rect.grow(8).has_point(item["position"])):
			item["position"] = lake + Vector2(110 + loot.find(item) % 4 * 25, 150)
		item["position"] = camp.remap(item["position"])
	_encounter("vampire", woods.zones[2]["cell"] + Vector2i(1,1))
	_encounter("witch", woods.zones[1]["cell"] + Vector2i(1,1))
	for index in range(6):
		var zone: Dictionary = woods.zones[index + 3]
		var cell: Vector2i = zone["cell"] + Vector2i(1,1)
		_encounter(GUARDIANS[index], cell)
		encounters.back()["home"] = zone["bounds"].grow(48)
		if GUARDIANS[index] == "relay_jackal":
			# Trash Jackals come as a pair.
			_encounter("relay_jackal", cell + Vector2i(1, 0))
			encounters.back()["home"] = zone["bounds"].grow(48)
	_spread_roamers(value)


## Garlic, wolfsbane, bug spray, tickets and coffee in the woods, and the air
## horn, coffee, scissors and spray at camp (own RNG: other loot is unchanged).
func _add_creature_items(value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = value + 6363
	for kind: String in CREATURE_LOOT:
		for unit in range(CREATURE_LOOT[kind]):
			var cell := Vector2i(rng.randi_range(0, WoodsLayout.SIZE.x - 1), rng.randi_range(0, WoodsLayout.SIZE.y - 1))
			while not woods.valid(cell) or not woods.links.has(cell) or not woods.zone_at(woods.center(cell)).is_empty():
				cell = Vector2i(rng.randi_range(0, WoodsLayout.SIZE.x - 1), rng.randi_range(0, WoodsLayout.SIZE.y - 1))
			_add(kind, woods.center(cell) + Vector2(-18, 14), "WOODS SUPPLIES", false)
	# Garlic hangs in the Vampire's own region (it can't abide it).
	_add("garlic", woods.zones[2]["position"] + Vector2(60, 70), "GARLIC BRAID", false)
	for row: Array in CAMP_CREATURE_LOOT:
		loot.append({"kind": row[0], "position": Vector2.ZERO, "hint": row[1], "locked": false, "anchor": row[1]})


## Roaming creatures spread across the whole forest (seeded best-candidate
## sampling: each pick is the farthest of a dozen random clearings from every
## creature already placed), none within SAFE_RADIUS of camp, none in a region.
func _spread_roamers(value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = value + 3131
	var camp_center := CampMap.CAMP_BOUNDS.get_center()
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in woods.links:
		var at := woods.center(cell)
		if at.distance_to(camp_center) >= SAFE_RADIUS and woods.zone_at(at).is_empty():
			candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y * WoodsLayout.SIZE.x + a.x < b.y * WoodsLayout.SIZE.x + b.x)
	var placed: Array[Vector2] = []
	for encounter in encounters:
		placed.append(encounter["position"])
	var offset := posmod(value, ROAMER_SPECIES.size())
	for index in range(ROAMERS):
		var best := candidates[rng.randi_range(0, candidates.size() - 1)]
		var best_gap := -1.0
		for attempt in range(12):
			var cell := candidates[rng.randi_range(0, candidates.size() - 1)]
			var gap := INF
			for other in placed:
				gap = minf(gap, woods.center(cell).distance_to(other))
			if gap > best_gap:
				best_gap = gap
				best = cell
		_encounter(ROAMER_SPECIES[(index + offset) % ROAMER_SPECIES.size()], best)
		placed.append(woods.center(best))


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


## Parts arrive by ranger radio as the night deepens, and the night deepens as the
## team secures parts, so the chain unfolds at the team's own pace. Events are tied
## to phases (with a seeded delay into each), not to fixed clock times.
func _schedule_night(value: int) -> void:
	reveal_phase = {"battery": 0, "key": 0, "fuel": 1, required[3]: 2, required[4]: 3}
	var rng := RandomNumberGenerator.new()
	rng.seed = value + 5150
	night_events.append({"kind": "storm", "phase": 1, "delay": rng.randf_range(120.0, 360.0)})
	night_events.append({"kind": "blackout", "phase": 2, "delay": rng.randf_range(120.0, 300.0)})
	night_events.append({"kind": "storm" if rng.randf() < 0.5 else "blackout", "phase": 3, "delay": rng.randf_range(60.0, 180.0)})
	# Two of the three story events, each in a seeded phase (separate RNG).
	var story := RandomNumberGenerator.new()
	story.seed = value + 7474
	var kinds: Array[String] = ["hunt", "gift", "camper"]
	kinds.remove_at(story.randi_range(0, 2))
	for kind in kinds:
		night_events.append({"kind": kind, "phase": story.randi_range(1, 3), "delay": story.randf_range(30.0, 240.0)})
	night_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["phase"] < b["phase"] or a["phase"] == b["phase"] and a["delay"] < b["delay"])


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
			lines.append("· %s / RADIO AT %s · %s" % [kind.replace("_", " ").to_upper(), NightClock.PHASES[due], where])
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


func has_modifier(id: String) -> bool:
	return id in modifiers


func modifier_text() -> String:
	return ", ".join(modifiers.map(func(id: String) -> String: return MODIFIER_NAMES[id]))


## 0–2 modifiers (40% none, 45% one, 15% two) and the headline killer.
func _choose_night_rules(value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = value + 2727
	# The roll is kept so modifier picks for a seed stay the same as before.
	rng.randi_range(0, 1)
	headline = force_headline if force_headline in HEADLINES else HEADLINES[0]
	if force_modifiers != null:
		modifiers.assign(force_modifiers)
		return
	var roll := rng.randf()
	var count := 0 if roll < 0.4 else (1 if roll < 0.85 else 2)
	var pool: Array[String] = MODIFIERS.duplicate()
	for index in range(count):
		var pick := rng.randi_range(0, pool.size() - 1)
		modifiers.append(pool[pick])
		pool.remove_at(pick)


func has_escape(id: String) -> bool:
	return id in escape_options


## One rumoured secondary escape per night (separate RNG: other content unchanged).
func _choose_escapes(value: int) -> void:
	if force_all_escapes:
		escape_options.assign(["van"] + SECONDARY_ESCAPES)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = value + 4242
	escape_options.assign(["van", SECONDARY_ESCAPES[rng.randi_range(0, SECONDARY_ESCAPES.size() - 1)]])


func rumour_text() -> String:
	var others: Array[String] = []
	for id in escape_options:
		if id != "van":
			others.append(ESCAPE_NAMES[id])
	return " / ".join(others)


## Signal Fire: two kerosene cans and a flare gun from three directions; the pyre
## stands on the White Stone Quarry rim (zone 7).
func _add_signal_fire(value: int) -> void:
	if not has_escape("signal"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = value + 6363
	var pools := [[0, 5], [1, 6], [2, 8]]
	var kinds := ["kerosene_1", "kerosene_2", "flare_gun"]
	for index in range(3):
		var region: int = pools[index][rng.randi_range(0, 1)]
		signal_regions[kinds[index]] = region
		_add(kinds[index], woods.zones[region]["position"] + Vector2(112, -140), WoodsLayout.short_name(woods.zones[region]), false)


func _add_field_escapes(value: int) -> void:
	if not has_escape("boat") and not has_escape("gate"):
		return
	if not has_escape("boat"):
		_add_gate_codes(value)
		return
	_add("outboard_motor", woods.zones[11]["position"] + Vector2(-70,48), "WEST / LOGGING CAMP", false)
	_add("boat_fuel", woods.zones[6]["position"] + Vector2(-92,72), "EAST / RAIL YARD", false)
	_add("drain_plug", woods.zones[5]["position"] + Vector2(-96,96), "NORTH / OBSERVATORY", false)
	if has_escape("gate"):
		_add_gate_codes(value)


func _add_gate_codes(value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = value + 8181
	for index in range(3):
		var choices: Array = [[1,6],[2,8],[3,4]][index]
		var region: int = choices[rng.randi_range(0,1)]
		var kind := "gate_code_%d" % (index+1)
		gate_regions[kind] = region
		_add(kind, woods.zones[region]["position"] + Vector2(-112,152), WoodsLayout.short_name(woods.zones[region]), false)
