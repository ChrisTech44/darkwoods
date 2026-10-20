class_name CreatureSwap
extends RefCounted
## Validate both destinations before changing either body. No gear copies.
static func valid(actor: CampPlayer, other: Node2D) -> bool:
	if actor.status!=CampPlayer.Status.ALIVE or actor.hidden_spot>=0 or actor.has_effect("held") or not actor.is_inside_tree(): return false
	if not is_instance_valid(other) or not other.is_inside_tree(): return false
	if other is CampPlayer:
		if other==actor or other.status!=CampPlayer.Status.ALIVE or other.hidden_spot>=0 or other.has_effect("held"): return false
	elif other is CampKiller:
		if not other.enabled or is_instance_valid(other.held): return false
		if CampKiller.camp_closed and CampKiller.in_camp(actor.position): return false
		if other is CampCryptid and other.home.has_area() and not other.home.has_point(actor.position): return false
	else: return false
	var level: Node=SurvivorKits.world(actor)
	if other.position.distance_to(level.van.global_position)<64 or actor.position.distance_to(level.van.global_position)<64: return false
	return SurvivorKits.safe_point(actor,other.position,1|CampPlayer.BARRIER_LAYER|CampPlayer.WATER_LAYER) and SurvivorKits.safe_point(actor,actor.position,1|CampPlayer.BARRIER_LAYER|CampPlayer.WATER_LAYER)

static func creatures(actor: CampPlayer, caster: CampKiller=null, include_stalker: bool=true) -> Array[CampKiller]:
	var result: Array[CampKiller]=[]
	for enemy: CampKiller in actor.get_tree().get_nodes_in_group("killers"):
		if enemy==caster or (enemy.traits!=null and not include_stalker): continue
		if valid(actor,enemy): result.append(enemy)
	return result

static func friend(actor: CampPlayer) -> CampPlayer:
	var nearest: CampPlayer
	for other: CampPlayer in actor.get_tree().get_nodes_in_group("survivors"):
		if other.position.distance_to(actor.position)>240 or not valid(actor,other): continue
		if nearest==null or other.position.distance_to(actor.position)<nearest.position.distance_to(actor.position): nearest=other
	return nearest

static func perform(actor: CampPlayer, other: Node2D) -> bool:
	if not valid(actor,other): return false
	var old:=actor.position
	var destination:=other.position
	if other is CampPlayer:
		if not FortuneWheel.relocate(other,old): return false
	if not FortuneWheel.relocate(actor,destination): return false
	if other is CampKiller:
		other.position=old
		other.velocity=Vector2.ZERO
		other.visible_target=null
		other.recover_remaining=maxf(other.recover_remaining,1)
	actor.add_effect("whiteout",0.6)
	SurvivorKits.world(actor).soundscape.broadcast("magician_tada",actor.position)
	return true
