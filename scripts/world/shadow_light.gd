class_name ShadowLight
extends RefCounted
## Host gameplay threshold within native lights, with collision line of sight.
## Uses the bright inner 70% of radial lights, not GPU pixel readback.
static func lit(level: Node, at: Vector2) -> bool:
	for actor: CampPlayer in level.get_tree().get_nodes_in_group("survivors"):
		var reach: float=actor.config.flashlight_range*(0.7 if CampMap.is_woods(actor.position) and level.plan.weather=="fog" else 1.0)
		if actor.flashlight_charge>0 and CreatureBrain.in_beam(actor,at,reach,0.8) and level.clear_path(actor.position,at): return true
	for lamp: PointLight2D in level.get_tree().get_nodes_in_group("shadow_lamps"):
		if lamp.enabled and lamp.energy>0 and at.distance_to(lamp.global_position)<lamp.texture_scale*128*0.7 and level.clear_path(lamp.global_position,at): return true
	return false
static func dark_path(level: Node, from: Vector2, to: Vector2) -> bool:
	var steps:=maxi(1,ceili(from.distance_to(to)/6))
	for i in range(steps+1):
		if lit(level,from.lerp(to,float(i)/steps)): return false
	return true
