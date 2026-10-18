extends CreatureBrain
## The Surveyor: a faceless land surveyor who un-maps you. It shuffles toward
## anyone it sees and, at a touch, takes your bearings: you are LOST for 40 s.
## Your notebook map turns to scribble, skyline markers and signposts mean
## nothing and your location line reads "???". A teammate who stays beside you
## for 3 s (or a ranger note) sets you straight. It shies from a flashlight
## held on it, backing off with its tripod.

const LOST_SECONDS := 40.0
const GUIDE_REACH := 42.0
const GUIDE_SECONDS := 3.0
var cooldown := 0.0
var guided: Dictionary = {}


func setup() -> void:
	display_name = "The Surveyor"
	tip = "Its touch leaves you LOST: no map, no signposts, no skyline. A teammate standing beside you for 3 s, or a ranger note, sets you straight. Hold your light on it to make it back off."
	body.config.killer_chase_speed = 52
	body.config.killer_patrol_speed = 30
	body.config.sight_radius = 190


func physics(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	_guide(delta)
	for actor in survivors():
		if in_beam(actor, body.global_position, 140.0) and body.global_position.distance_to(actor.global_position) < 140.0:
			flee_from(actor.global_position, 40.0, delta)
			return true
	return false


## A teammate beside a lost survivor shows them the way.
func _guide(delta: float) -> void:
	for actor: CampPlayer in body.get_tree().get_nodes_in_group("survivors"):
		var id := actor.get_instance_id()
		if not actor.has_effect("lost"):
			guided.erase(id)
			continue
		var helped := false
		for other: CampPlayer in body.get_tree().get_nodes_in_group("survivors"):
			if other != actor and other.status == CampPlayer.Status.ALIVE and not other.has_effect("lost") and other.global_position.distance_to(actor.global_position) <= GUIDE_REACH:
				helped = true
		guided[id] = guided.get(id, 0.0) + delta if helped else 0.0
		if guided[id] >= GUIDE_SECONDS:
			actor.clear_effect("lost")
			guided.erase(id)
			announce("Your teammate points the way. You know where you are again.", actor)


func contact(actor: CampPlayer) -> bool:
	if cooldown > 0.0:
		return true
	cooldown = 6.0
	actor.add_effect("lost", LOST_SECONDS)
	body.recover_remaining = 2.0
	cue("eerie", 4.0, 0.8)
	announce("The Surveyor takes your bearings. You're LOST: no map, no signs (40 s, or stay by a teammate).", actor)
	return true


func fears_flare() -> bool:
	return true
