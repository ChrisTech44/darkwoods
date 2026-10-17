class_name CampProfile
extends RefCounted
## F8 meta progress, saved locally per player: nights, escapes, best score per
## seed and per daily night, the camp journal (bestiary sightings and escapes)
## and merit badges. Never synced; automated test runs use a separate file.

const PATH := "user://profile.cfg"
const TEST_PATH := "user://profile_test.cfg"
const GRADES := [["S", 1800], ["A", 1400], ["B", 1000], ["C", 600], ["D", 0]]
const BADGES := {
	"first_light": ["FIRST LIGHT", "Escape a night for the first time."],
	"route_master": ["ROUTE MASTER", "Escape by three different routes."],
	"pyromaniac": ["PYROMANIAC", "Escape by the Signal Fire."],
	"lake_legend": ["LAKE LEGEND", "Escape by boat."],
	"radio_ham": ["RADIO HAM", "Escape by Radio Rescue."],
	"gatecrasher": ["GATECRASHER", "Escape through the Ranger Gate."],
	"snare_dancer": ["SNARE DANCER", "Escape a Groundskeeper night."],
	"red_sky": ["RED SKY", "Escape under a Blood Moon."],
	"daily_dose": ["DAILY DOSE", "Escape a Daily Night."],
	"field_guide": ["FIELD GUIDE", "Sight ten different creatures."],
	"top_marks": ["TOP MARKS", "Earn an S grade."],
	"team_player": ["TEAM PLAYER", "Revive or patch a teammate and escape."],
}
## One practical tip per creature, revealed in the journal after a sighting.
const TIPS := {
	"stalker": "Flares and doors buy seconds. He hunts noise; at Dusk he stays near camp.",
	"groundskeeper": "Sets snares on trails you walked. Watch for the glint; disarm with E.",
	"werewolf": "Fast in the open. Break line of sight in thick trees; flares scare it.",
	"bigfoot": "Long reach, slow turns. Circle obstacles and keep moving.",
	"lantern_moth": "Drawn to your light. Switch the flashlight off when it's near.",
	"vampire": "Holds back from a steady beam. Keep your light on it while you back away.",
	"witch": "Hexes slow you. Glow moss clears a hex; dodge the bolt's line.",
	"briar_revenant": "Thorns linger where it walks. Go around the patches.",
	"switchback_hound": "Doubles back on your trail. Change direction twice.",
	"boiler_saint": "Guards the Flooded Mill. Loud and slow; flank it.",
	"bramble_seamstress": "Guards the Orchard rows. Cut across rows, not along them.",
	"shutter_wraith": "Guards the Observatory. It sees your light; go dark to slip by.",
	"last_car_conductor": "Guards the Rail Yard. Stay off the tracks it patrols.",
	"stoneback_ram": "Guards the Quarry. Charges in straight lines; step aside.",
	"candle_grazer": "Guards the Chapel. Its candles light you up; keep your distance.",
	"relay_jackal": "Calls others to you. Silence it by breaking sight quickly.",
	"ration_moth": "Smells your rations. Eat away from it, or not at all.",
	"lens_eater": "Feeds on flashlight beams. Turn the light off as it closes.",
}

var path := PATH
var data := ConfigFile.new()


func _init() -> void:
	var testing := "--script" in OS.get_cmdline_args()
	path = TEST_PATH if testing else PATH
	data.load(path)


func save() -> void:
	data.save(path)


func reset() -> void:
	data = ConfigFile.new()
	save()


func get_count(key: String) -> int:
	return int(data.get_value("stats", key, 0))


func seen(species: String) -> bool:
	return bool(data.get_value("seen", species, false))


func record_sighting(species: String) -> bool:
	if species.is_empty() or seen(species):
		return false
	data.set_value("seen", species, true)
	save()
	return true


func seen_count() -> int:
	return data.get_section_keys("seen").size() if data.has_section("seen") else 0


func has_badge(id: String) -> bool:
	return data.has_section_key("badges", id)


func best(seed_value: int) -> int:
	return int(data.get_value("best", str(seed_value), 0))


static func grade(score: int) -> String:
	for row in GRADES:
		if score >= row[1]:
			return row[0]
	return "D"


static func daily_seed(date: Dictionary) -> int:
	return int(date["year"]) * 10000 + int(date["month"]) * 100 + int(date["day"])


## Score for a finished night (host-computed, replicated as plain numbers).
static func score_night(won: bool, route: String, relics: int, notes: int, revives: int, escapes_seen: int, modifiers: int, rumoured: bool) -> Dictionary:
	var lines: Array[String] = []
	var total := 0
	if won:
		total += 1000
		lines.append("ESCAPE +1000")
		if rumoured:
			total += 200
			lines.append("RUMOURED ROUTE +200")
	total += relics * 150
	if relics > 0:
		lines.append("RELICS ×%d +%d" % [relics, relics * 150])
	total += notes * 25
	if notes > 0:
		lines.append("NOTES ×%d +%d" % [notes, notes * 25])
	total += revives * 100
	if revives > 0:
		lines.append("RESCUES ×%d +%d" % [revives, revives * 100])
	total += escapes_seen * 10
	var multiplier := 1.0 + 0.15 * modifiers
	if modifiers > 0:
		lines.append("MODIFIERS ×%.2f" % multiplier)
	total = int(round(total * multiplier))
	return {"score": total, "grade": grade(total), "lines": lines, "route": route}


## Record a finished night; returns newly earned badge ids.
func record_night(seed_value: int, card: Dictionary, won: bool, route: String, headline: String, modifiers: Array, daily: bool, helped: bool) -> Array[String]:
	data.set_value("stats", "nights", get_count("nights") + 1)
	if won:
		data.set_value("stats", "escapes", get_count("escapes") + 1)
		data.set_value("routes", route, true)
	var score: int = card.get("score", 0)
	if score > best(seed_value):
		data.set_value("best", str(seed_value), score)
	if daily:
		data.set_value("daily", str(seed_value), maxi(score, int(data.get_value("daily", str(seed_value), 0))))
	var earned: Array[String] = []
	var award := func(id: String, condition: bool) -> void:
		if condition and not has_badge(id):
			data.set_value("badges", id, true)
			earned.append(id)
	award.call("first_light", won)
	award.call("route_master", data.has_section("routes") and data.get_section_keys("routes").size() >= 3)
	award.call("pyromaniac", won and route == "SIGNAL FIRE")
	award.call("lake_legend", won and route == "BOAT")
	award.call("radio_ham", won and route == "RADIO RESCUE")
	award.call("gatecrasher", won and route == "RANGER GATE")
	award.call("snare_dancer", won and headline == "groundskeeper")
	award.call("red_sky", won and "blood_moon" in modifiers)
	award.call("daily_dose", won and daily)
	award.call("field_guide", seen_count() >= 10)
	award.call("top_marks", card.get("grade", "D") == "S")
	award.call("team_player", won and helped)
	save()
	return earned


## Journal text: bestiary (name + tip once sighted) and badges.
func journal_text() -> String:
	var lines: Array[String] = ["NIGHTS %d · ESCAPES %d · CREATURES SEEN %d/%d" % [get_count("nights"), get_count("escapes"), seen_count(), TIPS.size()], ""]
	for species: String in TIPS:
		var name := species.replace("_", " ").to_upper()
		lines.append(("%s: %s" % [name, TIPS[species]]) if seen(species) else "??? (not yet sighted)")
	lines.append("")
	var badge_names: Array[String] = []
	for id: String in BADGES:
		badge_names.append(("★ " if has_badge(id) else "· ") + BADGES[id][0])
	lines.append("BADGES  " + "  ".join(badge_names))
	return "\n".join(lines)
