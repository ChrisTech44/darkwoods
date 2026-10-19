class_name SurvivorRoster
extends RefCounted

const IDS: Array[String] = ["christian", "john", "max", "alex"]
const NAMES := ["CHRISTIAN", "JOHN", "MAX", "ALEX"]
const DETAILS := [
	"BAD RESEARCH: survive encounters\nto bottle creature powers.\nX FIELD TEST: use the sample.\nExperiments can hit friends too.",
	"MAKING PROGRESS: preparing an\nescape refills stamina.\nX PUSH THROUGH: defer damage 6s.\nThe full damage lands afterward.",
	"FINDER'S FEE: searches and stolen\ngear recoveries earn cash.\nTap X: buy. Hold X: gamble more.\nGetting hit spills your money.",
	"TRAVEL ALONE: save light and\nrecover stamina while isolated.\nX: mark; X again: channel return.\nHits interrupt. Grabs prevent it."
]
## Existing artwork is a prototype stand-in, not a likeness of the four friends.
const ART := {"christian":"mechanic", "john":"jock", "max":"quartermaster", "alex":"quiet"}

static func valid(id: String) -> String:
	return id if id in IDS else "christian"

static func art(id: String) -> String:
	return ART[valid(id)]

static func effective(base: CampConfig, _id: String) -> CampConfig:
	return base.duplicate() as CampConfig
