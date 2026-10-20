class_name FieldGuide
extends RefCounted
## One source for the title-screen and in-game field guides. Key names come
## from the InputMap where an action exists; the rest are the fixed keys the
## round reads directly. Rules here must match the implementation (see
## docs/graphics_readability_plan.md, defect G07).

const TOPICS: Array[String] = ["CONTROLS", "SURVIVAL", "THE KILLER", "ESCAPES", "SURVIVORS", "CREATURES"]


## Display name of the first key bound to an action, e.g. "E" or "Tab".
static func key(action: String, fallback: String = "?") -> String:
	if not InputMap.has_action(action):
		return fallback
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			return OS.get_keycode_string(code)
	return fallback


## Lines for one topic. `level` is the running round (null on the title screen).
static func lines(topic: String, level: Node = null) -> Array[String]:
	var out: Array[String] = []
	match topic:
		"CONTROLS":
			out.append("%s/Arrows move · %s sprint (noisy) · %s flashlight" % [key("move_up", "W") + key("move_left", "A") + key("move_down", "S") + key("move_right", "D"), key("sprint", "Shift"), key("flashlight", "F")])
			out.append("%s use, take, hide; hold to revive or start the van" % key("interact", "E"))
			out.append("%s flash: short stun in front of you, costs light" % key("flash_burst", "Space"))
			out.append("%s flare · %s battery · %s food · 1-6 pick belt slot" % [key("use_flare", "Q"), key("recharge", "R"), key("eat", "C")])
			out.append("V use selected · G drop stack · H hand it to a teammate")
			out.append("X role ability · %s drop a map pin for the team" % key("map_pin", "M"))
			out.append("%s notebook: map, plan, guide, log · T next escape plan" % key("inventory", "Tab"))
			out.append("%s talk (if voice is on) · %s pause offline / menu online" % [key("push_to_talk", "B"), key("pause", "Esc")])
		"SURVIVAL":
			out.append("Noise (sprinting, prying, flares, the horn) draws creatures;")
			out.append("a noise tin lures them away. Camp is safe until DEEP NIGHT.")
			out.append("The night deepens as your escape gets ready (and slowly")
			out.append("on its own). There is no dawn deadline.")
			out.append("Downed: teammates hold E to revive (a medkit is faster);")
			out.append("press E to call for help. Alone, you get one slow get-up.")
			out.append("Moon dial (top right) fills toward the next full moon;")
			out.append("werewolves change while it is out. Red: Blood Moon.")
			out.append("Full flashlight: 7 minutes of ordinary woods use; flashes")
			out.append("and creature drains spend extra. Isolated Alex: 9m20s.")
		"THE KILLER":
			var who := "THE STALKER"
			if level != null and level.plan.expedition:
				who = "TONIGHT: THE " + level.plan.headline.to_upper()
			out.append(who)
			out.append("He whistles the camp song: listen for where it comes from.")
			out.append("From Nightfall he may shadow one survivor at the edge of")
			out.append("their light; catch him in your beam and he fades back.")
			out.append("At 50 health or less he carries you to his hook: mash E;")
			out.append("teammates flash him, throw a flare, or blow the air horn.")
			out.append("He remembers hiding spots you used. He lays traps on")
			out.append("trails you walk (E disarms). Humiliate him and he frenzies.")
		"ESCAPES":
			out.append("VAN: find and install every part, then hold E to start;")
			out.append("everyone boards before it leaves.")
			out.append("Woods nights add one more route (T in the notebook):")
			out.append("radio rescue, lakeshore boat, ranger gate or signal fire.")
			out.append("Ranger notes, regions you walk into and the phase radio")
			out.append("reveal where parts are. Locked caches need boltcutters")
			out.append("(Maintenance or a woods toolbox) or a loud crowbar.")
		"SURVIVORS":
			if level != null and not level.abilities.enabled: out.append("HOST RULE: ALL CAMPER POWERS ARE OFF THIS ROUND.")
			out.append("CHRISTIAN: survive signatures to collect one sample.")
			out.append("X borrows powers; can hit friends. Wolf needs moon.")
			out.append("Mimic needs a camper; forms show timers and aim guides.")
			out.append("JOHN: X halves damage 6s; 60s cooldown. Prep refills stamina.")
			out.append("MAX: X spins every 120s; discover the named results.")
			out.append("ALEX: 4s alone boosts light/stamina. Mark 60s; return 7s/120s CD.")
			out.append("Hits cancel; heartbeat blocks/cancels. 1/3 random, marker spent.")
		"CREATURES":
			var seen: Array = []
			if level != null:
				seen = level.tonight_seen.keys()
			if seen.is_empty():
				out.append("Creatures you see tonight are listed here with a tip.")
				out.append("Listen for calls and your heartbeat: it quickens as")
				out.append("something closes in, and pounds when it sees you.")
			for species: String in seen:
				out.append(CampProfile.display_name(species) + ": " + str(CampProfile.TIPS.get(species, "")))
	return out


static func text(topic: String, level: Node = null) -> String:
	return "\n".join(lines(topic, level))
