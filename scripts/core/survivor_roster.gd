class_name SurvivorRoster
extends RefCounted

const IDS: Array[String] = ["christian", "john", "max", "alex"]
const NAMES := ["CHRISTIAN", "JOHN", "MAX", "ALEX"]
const DETAILS := [
	"BAD RESEARCH: survive encounters\nto bottle creature powers.\nX FIELD TEST: use the sample.\nExperiments can hit friends too.",
	"MAKING PROGRESS: preparing an\nescape refills stamina.\nX PUSH THROUGH: half damage 6s.\nReduced debt lands afterward.",
	"X WHAT COULD GO WRONG?\nSpin the wheel every 60 seconds.\nTrust your luck.",
	"TRAVEL ALONE: save light and\nrecover stamina while isolated.\nX: mark; X again: 7s return.\nMonsters block. 1/3 lands randomly."
]
## Dedicated camper designs follow the friends' requested clothes/features.
const ART := {"christian":"christian", "john":"john", "max":"max", "alex":"alex"}

static func valid(id: String) -> String:
	return id if id in IDS else "christian"

static func art(id: String) -> String:
	return ART[valid(id)]

static func effective(base: CampConfig, _id: String) -> CampConfig:
	return base.duplicate() as CampConfig
