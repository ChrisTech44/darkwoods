class_name NewCreatureSamples
extends RefCounted
const SOURCES := ["lifeguard","nightlight_kid"]
static func fire(actor: CampPlayer, kind: String) -> void:
	var level: Node=SurvivorKits.world(actor)
	match kind:
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
