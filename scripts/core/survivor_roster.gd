class_name SurvivorRoster
extends RefCounted

const IDS: Array[String] = ["christian", "john", "max", "alex"]
const NAMES := ["CHRISTIAN", "JOHN", "MAX", "ALEX"]
const DETAILS := [
	"BAD RESEARCH: survive encounters\nto bottle creature powers.\nX FIELD TEST: use the sample.\nExperiments can hit friends too.",
	"MAKING PROGRESS: preparing an\nescape refills stamina.\nX PUSH THROUGH: defer damage 6s.\nThe full damage lands afterward.",
	"Tap X: $4 buys 1 random supply.\nHold .45s+, release: gamble.\n45% lose / 55% win 2 per $4.\nStashes earn cash. Hits spill it.",
	"TRAVEL ALONE: save light and\nrecover stamina while isolated.\nX: mark; X again: channel return.\nHits interrupt. Grabs prevent it."
]
## Dedicated camper designs follow the friends' requested clothes/features.
const ART := {"christian":"christian", "john":"john", "max":"max", "alex":"alex"}

static func valid(id: String) -> String:
	return id if id in IDS else "christian"

static func art(id: String) -> String:
	return ART[valid(id)]

static func effective(base: CampConfig, _id: String) -> CampConfig:
	return base.duplicate() as CampConfig
