class_name RoundPlan
extends RefCounted
## Seeded authority-side run recipe. No gameplay relies on global RNG state.

## Two region dwellers, six landmark guardians (the Rail Yard's jackals come
## as a pair), and all 29 roaming kinds: 38 creatures plus the headline Stalker.
const ROAMERS := 29
const CRYPTID_COUNT := 9 + ROAMERS
## No roaming creature starts this close to camp (the first stretch is for exploring).
const SAFE_RADIUS := 1100.0
## Split coverage between the region circuit and the whole enclosed forest.
const PERIMETER_ROAMERS := 14
const CIRCUIT_BAND := 384.0
const ROAMER_GAP := 600.0
## Every roaming kind appears once. Seeded order and placement still vary.
const ROAMER_SPECIES: Array[String] = ["werewolf", "bigfoot", "lantern_moth", "ration_moth", "briar_revenant", "switchback_hound", "lens_eater",
	"last_car_conductor", "mimic", "owl", "bog_hands", "imps", "teddy",
	"groundskeeper", "cuckoo", "banshee", "slug", "surveyor", "hitchhiker", "tollkeeper", "echo", "fortune_teller", "lifeguard", "nightlight_kid", "vulture", "nobody", "huntmaster", "magician", "shade"]
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
## Seeded objective regions and truthful clue bearings; ranger notes name
## the van-part regions without revealing undiscovered cache positions.
var objective_zone: Dictionary = {}
var objective_spread: ObjectiveSpread
var objective_anchors: Array[Vector2]=[]
var objective_excluded: Array[int]=[]
var objective_score: Array[int]=[]
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
const MODIFIER_RULES := {"blood_moon": "the moon comes out more often; the killer runs faster; every creature type remains", "dead_batteries": "spare batteries hold 80 charge", "fog_bank": "thick fog: shorter sight for everyone", "silent_night": "no music; creatures hear farther", "generous_woods": "half again as many supplies", "lone_wolf": "everyone starts in a different cabin"}
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
	objective_zone.clear()
	objective_anchors.clear();objective_excluded.clear();objective_score.clear()
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
	_choose_escapes(value)
	if has_modifier("fog_bank"):
		weather = "fog"
	var extras: Array[String] = ["fuse", "belt", "tire", "spark_plug"]
	for index in range(2):
		var chosen := rng.randi_range(0, extras.size() - 1)
		required.append(extras[chosen])
		extras.remove_at(chosen)
	var battery_pool: Array[Vector2] = [Vector2(228, 120), Vector2(564, 120), Vector2(960, 128)]
	_add("boltcutters", Vector2(1304, 272), "MAINTENANCE", false)
	objective_spread=ObjectiveSpread.new(woods)
	_prepare_objectives(value)
	var caches: Array = _rotate_caches(value)
	for index in range(caches.size() - 1, 0, -1):
		var chosen := rng.randi_range(0, index)
		var swap: Dictionary = caches[index]
		caches[index] = caches[chosen]
		caches[chosen] = swap
	for index in range(required.size()):
		var kind: String = required[index]
		_add(kind, caches[index]["position"], caches[index]["label"], kind not in ["battery","key"])
		cache_zone[kind] = caches[index]["zone"]
		cache_direction[kind] = caches[index]["direction"]
		objective_zone[kind]=caches[index]["zone"]
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
	# Separate objective/tool inventory, never a belt slot or a van component.
	# The substation fuse powers both the radio relay and the gate floodlights.
	if has_escape("radio") or has_escape("gate"):
		var fixed: Array[Vector2]=[woods.zones[9].position+Vector2(0,48)]
		var excluded: Array[int]=[9]
		if has_escape("radio"):
			fixed.append(woods.zones[10].position+Vector2(0,56));fixed.append(woods.zones[8].position+Vector2(0,230))
			excluded.append(10);excluded.append(8)
		if has_escape("gate"):
			fixed.append(woods.zones[13].position+Vector2(0,500));excluded.append(13)
		var region: int=objective_zone.get("rescue_fuse",-1)
		if region<0:region=objective_spread.choose(1,fixed,excluded,value+9191)[0]
		_add_objective("rescue_fuse",region)
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
		# Region identities now move over seeded supplies. Keep ordinary loot on
		# their clear southern edge, away from cabins and solid relay machinery.
		var region:=woods.zone_at(item.position)
		if item.hint=="WOODS SUPPLIES" and not region.is_empty():
			item.position=Vector2(clampf(item.position.x,region.bounds.position.x+48,region.bounds.end.x-48),region.bounds.end.y-48)
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


## Ring coverage prevents a vacant region-to-region lap; farthest-point filling
## spreads the other starts over the enclosed forest, excluding the quiet camp.
func _spread_roamers(value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = value + 3131
	var circuit := roaming_circuit()
	var candidates: Array[Dictionary] = []
	var perimeter: Array[Dictionary] = []
	var interior: Array[Dictionary] = []
	for cell: Vector2i in woods.links:
		var at := woods.center(cell)
		if at.distance_to(CampMap.CAMP_BOUNDS.get_center()) < SAFE_RADIUS or not woods.zone_at(at).is_empty(): continue
		var gap := circuit_distance(at,circuit)
		var candidate := {"cell":cell,"position":at,"circuit_gap":gap}
		if gap <= CIRCUIT_BAND:
			perimeter.append(candidate)
		elif Geometry2D.is_point_in_polygon(at,circuit):
			interior.append(candidate)
		else: continue
		candidates.append(candidate)
	# Stable order and seeded phase/tie breaks reproduce the same nightly recipe.
	for pool: Array in [candidates,perimeter,interior]:
		pool.sort_custom(func(a,b): return a.cell.y*WoodsLayout.SIZE.x+a.cell.x < b.cell.y*WoodsLayout.SIZE.x+b.cell.x)
	var placed: Array[Vector2] = []
	for encounter in encounters: placed.append(encounter.position)
	var length := 0.0
	for index in range(circuit.size()): length += circuit[index].distance_to(circuit[(index+1)%circuit.size()])
	var step := length/PERIMETER_ROAMERS
	var phase := rng.randf()*step
	var offset := posmod(value,ROAMER_SPECIES.size())
	for index in range(ROAMERS):
		var chosen: Dictionary
		if index < PERIMETER_ROAMERS:
			var target := circuit_point(circuit,phase+step*index)
			var score := INF
			for candidate: Dictionary in perimeter:
				if spawn_gap_squared(candidate.position,placed) < ROAMER_GAP*ROAMER_GAP: continue
				var cost: float = candidate.position.distance_squared_to(target)+candidate.circuit_gap*candidate.circuit_gap*0.2
				if cost < score:
					score = cost
					chosen = candidate
		if chosen.is_empty():
			var pool: Array = interior if index>=PERIMETER_ROAMERS else perimeter
			if pool.is_empty(): pool=candidates
			var best := -1.0
			for candidate: Dictionary in pool:
				var gap := spawn_gap_squared(candidate.position,placed)
				# Tiny seeded tie-break, rather than unconstrained random clustering.
				var score := gap+rng.randf()*0.01
				if score > best:
					best = score
					chosen = candidate
		_encounter(ROAMER_SPECIES[(index+offset)%ROAMER_SPECIES.size()],chosen.cell)
		placed.append(chosen.position)

## Geometric circuit through all region centers, sorted around camp. It is a
## placement guide, not a new road or a hard movement boundary.
func roaming_circuit() -> PackedVector2Array:
	var points: Array[Vector2] = []
	for zone: Dictionary in woods.zones: points.append(zone.position)
	var camp := CampMap.CAMP_BOUNDS.get_center()
	points.sort_custom(func(a: Vector2,b: Vector2): return (a-camp).angle() < (b-camp).angle())
	return PackedVector2Array(points)

static func circuit_distance(at: Vector2,circuit: PackedVector2Array) -> float:
	var gap := INF
	for index in range(circuit.size()):
		gap = minf(gap,at.distance_to(Geometry2D.get_closest_point_to_segment(at,circuit[index],circuit[(index+1)%circuit.size()])))
	return gap

static func circuit_point(circuit: PackedVector2Array,distance: float) -> Vector2:
	for index in range(circuit.size()):
		var a := circuit[index]
		var b := circuit[(index+1)%circuit.size()]
		var segment := a.distance_to(b)
		if distance <= segment: return a.lerp(b,distance/segment)
		distance -= segment
	return circuit[0]

static func spawn_gap_squared(at: Vector2,placed: Array[Vector2]) -> float:
	var gap := INF
	for other in placed: gap = minf(gap,at.distance_squared_to(other))
	return gap


## Optimize all unique pieces of both offered routes together, destinations included.
## Forced all-route diagnostics exceed the region budget and retain per-route spread.
func _prepare_objectives(value: int) -> void:
	if force_all_escapes:return
	var kinds: Array[String]=required.duplicate()
	var fixed: Array[Vector2]=[CampMap.CAMP_BOUNDS.get_center()]
	var excluded: Array[int]=[]
	if has_escape("boat"):
		kinds.append_array(FieldEscapes.BOAT_PARTS)
		fixed.append(woods.zones[12].position+Vector2(0,-95));excluded.append(12)
	if has_escape("signal"):
		kinds.append_array(SignalFire.PARTS)
		fixed.append(woods.zones[7].position+Vector2(0,-150));excluded.append(7)
	if has_escape("radio"):
		kinds.append("rescue_fuse")
		for row in [[9,Vector2(0,48)],[10,Vector2(0,56)],[8,Vector2(0,230)]]:
			fixed.append(woods.zones[row[0]].position+row[1]);excluded.append(row[0])
	if has_escape("gate"):
		kinds.append("rescue_fuse");kinds.append_array(FieldEscapes.GATE_CODES)
		fixed.append(woods.zones[9].position+Vector2(0,48));excluded.append(9)
		fixed.append(woods.zones[13].position+Vector2(0,500));excluded.append(13)
		fixed.append(woods.zones[13].position+Vector2(0,-500))
	objective_anchors=fixed;objective_excluded=excluded
	var selected:=objective_spread.choose(kinds.size(),fixed,excluded,value+5151)
	objective_score=objective_spread.best_score.duplicate()
	for i in range(kinds.size()):objective_zone[kinds[i]]=selected[i]

## Five distinct outer regions, maximizing separation from one another and camp.
## Unlock/phase gates and the camp -> note -> region discovery chain are retained.
func _rotate_caches(value: int) -> Array:
	var chosen: Array[int]=[]
	for kind in required:
		if objective_zone.has(kind):chosen.append(objective_zone[kind])
	if chosen.is_empty():chosen=objective_spread.choose(5,[CampMap.CAMP_BOUNDS.get_center()],[],value+4242)
	var caches: Array=[]
	for index in chosen:
		var zone: Dictionary=woods.zones[index]
		caches.append({"position":cache_spot(zone),"label":WoodsLayout.short_name(zone)+" / CACHE","zone":index,"direction":WoodsLayout.cardinal(zone.position)})
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


## Each route chooses the most separated legal pickup-region set, destination included.
func _add_objective(kind: String,region: int) -> void:
	objective_zone[kind]=region
	var at:=cache_spot(woods.zones[region])
	# Only diagnostic all-route nights exceed the fourteen-region budget. Keep
	# their reused anchors physically distinct so E does not take another part.
	if force_all_escapes:
		for offset: Vector2 in [Vector2.ZERO,Vector2(0,96),Vector2(96,96),Vector2(-96,96),Vector2(96,0),Vector2(-96,0),Vector2(0,-96)]:
			var candidate:=cache_spot(woods.zones[region])+offset
			if not woods.zones[region].bounds.grow(-24).has_point(candidate):continue
			if loot.any(func(item): return item.position.distance_to(candidate)<80 and (item.kind in required or item.kind in objective_zone)):continue
			at=candidate;break
	_add(kind,at,WoodsLayout.short_name(woods.zones[region]),false)

func _add_signal_fire(value: int) -> void:
	if not has_escape("signal"):return
	var regions: Array[int]=[]
	for kind in SignalFire.PARTS:
		if objective_zone.has(kind):regions.append(objective_zone[kind])
	if regions.is_empty():regions=objective_spread.choose(3,[woods.zones[7].position+Vector2(0,-150)],[7],value+6363)
	for i in range(SignalFire.PARTS.size()):
		var kind: String=SignalFire.PARTS[i]
		signal_regions[kind]=regions[i];_add_objective(kind,regions[i])

func _add_field_escapes(value: int) -> void:
	if has_escape("boat"):
		var regions: Array[int]=[]
		for kind in FieldEscapes.BOAT_PARTS:
			if objective_zone.has(kind):regions.append(objective_zone[kind])
		if regions.is_empty():regions=objective_spread.choose(3,[woods.zones[12].position+Vector2(0,-95)],[12],value+7171)
		for i in range(FieldEscapes.BOAT_PARTS.size()):_add_objective(FieldEscapes.BOAT_PARTS[i],regions[i])
	if has_escape("gate"):_add_gate_codes(value)

func _add_gate_codes(value: int) -> void:
	var anchors: Array[Vector2]=[woods.zones[13].position+Vector2(0,500),woods.zones[9].position+Vector2(0,48)]
	var excluded: Array[int]=[13,9]
	if objective_zone.has("rescue_fuse"):
		var region: int=objective_zone.rescue_fuse
		anchors.append(cache_spot(woods.zones[region]));excluded.append(region)
	var regions: Array[int]=[]
	for kind in FieldEscapes.GATE_CODES:
		if objective_zone.has(kind):regions.append(objective_zone[kind])
	if regions.is_empty():regions=objective_spread.choose(3,anchors,excluded,value+8181)
	for i in range(3):
		var kind: String="gate_code_%d"%(i+1)
		gate_regions[kind]=regions[i];_add_objective(kind,regions[i])
