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
	"snare_dancer": ["MOWER MECHANIC", "Pull the Groundskeeper's spark plug, then escape."],
	"red_sky": ["RED SKY", "Escape under a Blood Moon."],
	"daily_dose": ["DAILY DOSE", "Escape a Daily Night."],
	"field_guide": ["FIELD GUIDE", "Sight ten different creatures."],
	"top_marks": ["TOP MARKS", "Earn an S grade."],
	"team_player": ["TEAM PLAYER", "Revive or patch a teammate and escape."],
}
## One practical tip per creature, revealed in the journal after a sighting
## (docs/monster_revamp.md). Keys are species ids; NAMES are what players see.
const TIPS := {
	"magician":"Leave the glowing ring before the drumroll ends. Flash interrupts the swap; someone else arrives where you stood.",
	"huntmaster":"Its horn hastens creatures. Flash during the raised-horn warning; leave the crowd if it sounds.",
	"nobody":"Its breathing and prints betray it. Sweep your beam for a shimmer; flash reveals it briefly.",
	"vulture":"Flash it away before reviving. Its wing-flap warns of a peck; solo recovery slows while it perches.",
	"nightlight_kid":"Keep your light on near it. Its touch jams your flashlight on and doubles passive drain.",
	"lifeguard":"Walk in its sight; stop sprinting when its whistle rises. Flash interrupts it.",
	"stalker": "He whistles the camp song. Wounded, he carries you to his hook; an air horn or a teammate's flash makes him drop you.",
	"groundskeeper": "Rides a mower that runs you down on open ground but turns wide: sidestep late, or duck into trees or a cabin. When he walks off to rake for you, pull its spark plug (hold E).",
	"vampire": "Its gaze draws you in and its bite drains you. Garlic keeps it away; hold your beam on it; mash E if it bites.",
	"werewolf": "A harmless hiker until the moon comes out. Then hide, or throw wolfsbane; its pounce knocks you flying.",
	"bigfoot": "Shy. Light it up from far away and it runs (and drops fur). Sneak up on it and it throws you.",
	"witch": "Her bolt curses: frog, backwards, swap or float. Sidestep its line, or wear a salt ward to bounce it back.",
	"lantern_moth": "Drawn to your light; it lands on your face and drinks the battery. Swat it with a flash, or switch off.",
	"ration_moth": "Its spores give you a squeaky helium voice and loud sneezes. Walk around it, or stand still to hold your breath.",
	"briar_revenant": "It only moves when no one is watching. Keep a light on it and back away; take turns as a team.",
	"switchback_hound": "It barks to call the stalker and drags the downed to his hook. Throw it rations and it's your friend for a minute.",
	"relay_jackal": "They steal from your belt (sometimes a part) and run to their den. Flash one to make it drop the loot.",
	"lens_eater": "Don't put your light on it or face it up close, or it locks you in a stare. A teammate stepping between you breaks it.",
	"shutter_wraith": "Its flash blinds anyone facing it and sends your picture to the stalker. Turn away and break line of sight.",
	"last_car_conductor": "No ticket? He sends you to the Rail Yard. Carry a train ticket and he gives you a free ride to camp.",
	"stoneback_ram": "A CHARGE ring warns you. Step out of its line: anyone in the path is launched like a bowling pin.",
	"candle_grazer": "It snuffs flashlights and flares around it. Glow moss keeps you lit; otherwise walk away from it.",
	"bramble_seamstress": "Her thread stitches you to a teammate (or the ground) for 25 s. Scissors cut it.",
	"boiler_saint": "Its hymn makes you drowsy; stand still and you fall asleep (snoring). Keep moving, or drink coffee.",
	"mimic": "It looks and sounds like a teammate. Real teammates carry a flashlight and show on the map; it doesn't.",
	"owl": "It snatches survivors who wander alone and drops them far away. Stay together; a flare makes it let go.",
	"bog_hands": "They hide in mud puddles on the trail. Walk around puddles; if they grab you, mash E or get a teammate to pull.",
	"imps": "They trip you and hide what you drop. A flash poofs them; bug spray keeps them off.",
	"teddy": "Once it sees you it follows forever, slowly. If it hugs you, mash E or get a teammate to flash it.",
	"cuckoo": "It calls CUCKOO three times when it sees you. Still in its sight on the third and you're thrown back 8 seconds. Break line of sight, or flash it.",
	"banshee": "A swelling ring means she's drawing breath: get out of it or behind cover, or her scream leaves you deaf for 25 s.",
	"slug": "Its slime trail makes you skate. Walk around the shine; a salt ward makes it shrivel and dissolves the slime.",
	"surveyor": "Its touch leaves you LOST: no map, signposts or skyline. Stand beside a teammate for 3 s or read a ranger note.",
	"hitchhiker": "It rides on your back (slow, no sprint, lights off). Walk into a teammate to pass it on, or wait it out.",
	"tollkeeper": "He blocks a trail. E pays one supply and he lets you by for a minute; no supplies costs 15 health.",
	"echo": "It whistles the stalker's tune from the wrong place. Harmless; your light bursts it up close.",
	"fortune_teller": "She turns a tarot card when she reaches you: three help, four hurt. Walk away to decline.",
}
const NAMES := {"magician":"THE SHELL GAME MAGICIAN", "huntmaster":"THE HUNTMASTER", "nobody":"NOBODY", "vulture":"THE VULTURE", "nightlight_kid":"THE NIGHT-LIGHT KID", "lifeguard":"THE LIFEGUARD", "stalker": "THE STALKER", "groundskeeper": "THE GROUNDSKEEPER", "vampire": "THE VAMPIRE", "werewolf": "THE WEREWOLF", "bigfoot": "BIGFOOT",
	"witch": "THE WITCH", "lantern_moth": "THE LANTERN MOTH", "ration_moth": "THE PUFFBALL", "briar_revenant": "THE SCARECROW",
	"switchback_hound": "BUSTER, THE STALKER'S HOUND", "relay_jackal": "TRASH JACKALS", "lens_eater": "THE PEEPER", "shutter_wraith": "THE PAPARAZZO",
	"last_car_conductor": "THE CONDUCTOR", "stoneback_ram": "THE RAM", "candle_grazer": "THE SNUFFER", "bramble_seamstress": "THE SEAMSTRESS",
	"boiler_saint": "THE LULLABY SAINT", "mimic": "THE MIMIC", "owl": "THE NIGHT OWL", "bog_hands": "THE BOG HANDS", "imps": "THE TOADSTOOL IMPS", "teddy": "BEAR HUG",
	"cuckoo": "THE CUCKOO", "banshee": "THE BANSHEE", "slug": "THE SLUG", "surveyor": "THE SURVEYOR", "hitchhiker": "THE HITCHHIKER",
	"tollkeeper": "THE TOLLKEEPER", "echo": "THE ECHO", "fortune_teller": "THE FORTUNE TELLER"}


static func display_name(species: String) -> String:
	return NAMES.get(species, species.replace("_", " ").to_upper())

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
func record_night(seed_value: int, card: Dictionary, won: bool, route: String, _headline: String, modifiers: Array, daily: bool, helped: bool, feats: Array = []) -> Array[String]:
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
	award.call("snare_dancer", won and "mower" in feats)
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
		var name := display_name(species)
		lines.append(("%s: %s" % [name, TIPS[species]]) if seen(species) else "??? (not yet sighted)")
	lines.append("")
	var badge_names: Array[String] = []
	for id: String in BADGES:
		badge_names.append(("★ " if has_badge(id) else "· ") + BADGES[id][0])
	lines.append("BADGES  " + "  ".join(badge_names))
	return "\n".join(lines)
