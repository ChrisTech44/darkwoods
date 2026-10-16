class_name SurvivorRoster
extends RefCounted

const IDS: Array[String] = ["jock", "mechanic", "scout", "medic", "quiet", "quartermaster"]
const NAMES := ["THE JOCK", "GREASE MONKEY", "THE SCOUT", "FIRST-AID KID", "THE QUIET KID", "OVERPREPARED"]
const DETAILS := [
	"5s sprint stamina (baseline 4s).\nSame speed and recovery. Run between cover.",
	"Engine start 1.5s (baseline 2s).\n+1 spare battery. Bring every part home.",
	"Light drain 0.8/s (baseline 1/s).\n+1 ration. Read trails before moving.",
	"Revive 2.25s (baseline 3s).\n+1 medkit, +1 flare. No self-revive.",
	"Sprint hearing reach x0.75.\nSight unchanged. Break sight, then walk.",
	"+1 flare, +1 battery, +1 ration.\nFinite supplies. Leave room for discoveries."
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
