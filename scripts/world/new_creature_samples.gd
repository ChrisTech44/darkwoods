class_name NewCreatureSamples
extends RefCounted
const SOURCES := ["lifeguard","nightlight_kid","vulture","nobody","huntmaster"]
static func fire(actor: CampPlayer, kind: String) -> void:
	var level: Node=SurvivorKits.world(actor)
	match kind:
		"huntmaster":
			level.soundscape.broadcast("huntmaster_horn",actor.position)
			for friend: CampPlayer in actor.get_tree().get_nodes_in_group("survivors"):
				if friend.status==CampPlayer.Status.ALIVE and friend.position.distance_to(actor.position)<=300: friend.add_effect("rally",10)
			for enemy: CampKiller in actor.get_tree().get_nodes_in_group("killers"):
				if enemy.enabled and enemy.position.distance_to(actor.position)<=400: enemy.haste_remaining=maxf(enemy.haste_remaining,15)
		"vulture":
			var friend:=downed_friend(actor)
			if friend!=null:
				actor.kit["vulture_guard"]=10.0
				actor.kit["guard_target"]=friend.get_instance_id()
				actor.kit["guard_touched"]=[]
				level.soundscape.broadcast("vulture_wings",actor.position)
		"nightlight_kid":
			level.soundscape.broadcast("nightlight_scream",actor.position)
			level.loud_noise(actor.position,500)
			for friend: CampPlayer in actor.get_tree().get_nodes_in_group("survivors"):
				if friend.status==CampPlayer.Status.ALIVE and friend.flashlight_charge>0 and friend.position.distance_to(actor.position)<=150 and level.clear_path(actor.position,friend.position): friend.add_effect("nightlight",15);friend.flashlight_on=true
		"lifeguard":
			level.soundscape.broadcast("lifeguard_whistle",actor.position)
			level.loud_noise(actor.position,700)
			for friend: CampPlayer in actor.get_tree().get_nodes_in_group("survivors"):
				if friend.status==CampPlayer.Status.ALIVE and friend.position.distance_to(actor.position)<=200 and level.clear_path(actor.position,friend.position): friend.stamina=0; friend.exhausted=true
			for enemy: CampKiller in actor.get_tree().get_nodes_in_group("killers"):
				if enemy.enabled and enemy.position.distance_to(actor.position)<=200 and level.clear_path(actor.position,enemy.position): enemy.recover_remaining=maxf(enemy.recover_remaining,2)

static func downed_friend(actor: CampPlayer) -> CampPlayer:
	for friend: CampPlayer in actor.get_tree().get_nodes_in_group("survivors"):
		if friend!=actor and friend.status==CampPlayer.Status.DOWNED and actor.position.distance_to(friend.position)<=150 and SurvivorKits.world(actor).clear_path(actor.position,friend.position): return friend
	return null

static func advance(actor: CampPlayer, delta: float) -> void:
	if actor.kit.get("vulture_guard",0.0)<=0: return
	actor.kit["vulture_guard"]=maxf(0,actor.kit.vulture_guard-delta)
	var friend: Object=instance_from_id(actor.kit.get("guard_target",0))
	if not is_instance_valid(friend) or not friend.is_inside_tree() or friend.status!=CampPlayer.Status.DOWNED or actor.status!=CampPlayer.Status.ALIVE:
		actor.kit.vulture_guard=0.0
		return
	for enemy: CampKiller in actor.get_tree().get_nodes_in_group("killers"):
		if enemy.enabled and enemy.position.distance_to(friend.position)<=60 and not enemy.get_instance_id() in actor.kit.guard_touched and SurvivorKits.world(actor).clear_path(enemy.position,friend.position):
			enemy.stun(1)
			actor.kit.guard_touched.append(enemy.get_instance_id())
