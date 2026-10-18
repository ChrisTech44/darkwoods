extends CreatureBrain
## The Conductor: "Tickets, please." He strolls toward anyone he sees, ringing
## his lantern bell. Caught without a ticket, you're whisked away to the Rail
## Yard. Carry a TRAIN TICKET and he punches it and gives you a free ride back
## to camp instead. Either way he rides on and turns up somewhere else.

const CAMP_STOP := Vector2(150, 420)
var bell := 0.0


func setup() -> void:
	display_name = "The Conductor"
	tip = "No ticket? He sends you to the Rail Yard. Carry a train ticket and he gives you a free ride to camp."
	body.config.killer_chase_speed = 58
	body.config.sight_radius = 170


func fears_flare() -> bool:
	return false


func physics(delta: float) -> bool:
	bell -= delta
	if body.state == CampKiller.State.CHASE and bell <= 0.0:
		bell = 4.0
		cue("train", -4.0)
	return false


func contact(actor: CampPlayer) -> bool:
	var world: Node = level()
	if world == null:
		return true
	var whoosh := actor.global_position
	if actor.supplies.get("train_ticket", 0) > 0:
		actor.supplies["train_ticket"] -= 1
		actor.tidy_belt()
		actor.global_position = reachable(CAMP_STOP)
		world.announce("The Conductor punches your ticket: ALL ABOARD for camp! (free ride)", actor)
	else:
		var yard := _rail_yard(world)
		actor.global_position = reachable(yard + Vector2(randf_range(-60, 60), randf_range(-40, 40)))
		world.announce("NO TICKET! The Conductor sends you packing to the Rail Yard.", actor)
	actor.add_effect("whiteout", 0.6)
	world.soundscape.broadcast("train", whoosh, 2.0, 1.1)
	# He rides on and alights at the far end of his line.
	body.global_position = body.patrol[(body.patrol_index + body.patrol.size() / 2) % maxi(1, body.patrol.size())] if not body.patrol.is_empty() else body.global_position
	body.visible_target = null
	body.transition(CampKiller.State.PATROL)
	body.recover_remaining = 3.0
	return true


static func _rail_yard(world: Node) -> Vector2:
	for zone: Dictionary in world.plan.woods.zones:
		if zone["kind"] == "rail":
			return zone["position"]
	return world.plan.woods.zones[0]["position"]
