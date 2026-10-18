class_name ObjectiveState
extends RefCounted
## Presentation queries over authoritative state. No new inventory or knowledge.

static func installed(level: Node, kind: String) -> bool:
	return kind in level.van.installed or kind in level.escapes.boat_installed or kind in level.escapes.gate_installed or kind in level.signal_fire.installed or (kind == "rescue_fuse" and level.rescue.powered)

static func on_ground(level: Node, kind: String) -> bool:
	if installed(level, kind):
		return false
	for actor: CampPlayer in level.get_tree().get_nodes_in_group("survivors"):
		if kind in actor.inventory:
			return false
	return level.pickups.any(func(pickup: CampPickup) -> bool: return pickup.available and pickup.kind == kind)
