class_name SurvivorRoster
extends RefCounted

const IDS: Array[String] = ["jock", "mechanic", "scout", "medic", "quiet", "quartermaster"]
const NAMES := ["THE JOCK", "GREASE MONKEY", "THE SCOUT", "FIRST-AID KID", "THE QUIET KID", "OVERPREPARED"]
const DETAILS := [
	"5s sprint stamina (baseline 4s).\nX SECOND WIND: full stamina + faster\nsprint, once each night phase.",
	"Engine start 1.5s, +1 spare battery.\nX JURY-RIG (2/night): barricade a door\n8s or restart dead power quietly.",
	"Light drain 0.8/s, +1 ration.\nX MARK: tag a creature, cache or site\nyou can see for the team (30s).",
	"Medkit revive 2.25s, +1 medkit/flare.\nX PATCH (2/night): heal a wound on\nyou or a teammate, no medkit.",
	"Sprint hearing reach x0.75.\nX HOLD BREATH: 6s silent steps and\nslow breath when hidden (45s).",
	"+1 flare, +1 battery, +1 ration.\nX UNPACK (1/night): drop a stash of\nfour supplies for the team."
]

static func valid(id: String) -> String:
	return id if id in IDS else "jock"

static func effective(base: CampConfig, id: String) -> CampConfig:
	var result := base.duplicate() as CampConfig
	match valid(id):
		"jock": result.stamina_max = 5
		"mechanic": result.start_hold_seconds = 1.5
		"medic": result.revive_seconds = 2.25
	return result
