class_name StalkerTraits
extends RefCounted
## What makes the headline killer the centre of the game (docs/monster_revamp.md):
## - A FAVOURITE: each phase he picks one survivor to shadow at the edge of their
##   light. Catch him in your beam and he melts back into the dark, to turn up
##   behind you later. After a while of shadowing, he lunges.
## - THE GRAB: a wounded survivor (50 health or less) isn't hit; he throws them
##   over his shoulder and walks them to his HOOK. Mash E, or a teammate's flash,
##   flare or air horn makes him drop them. Reaching the hook leaves them downed
##   there, pinned on everyone's map.
## - HE REMEMBERS hiding spots you used and checks them first.
## - RAGE: every time a victim slips away it grows; at three he FRENZIES for
##   20 s (faster, doors burst instantly, he screams instead of whistling).
## - CALLING CARDS: he scrawls your name and threats on the ground behind you.
## The whistled camp song and bear traps live in CampSong and Snares.
## Host only; the body's synced fields (faded, frenzy, carrying) drive drawing.

const SHADOW_DISTANCE := 190.0
const SHADOW_SPEED := 64.0
const LUNGE_AFTER := Vector2(35.0, 55.0)
const MELT_SECONDS := 5.0
const CARRY_SPEED := 58.0
const FRENZY_SECONDS := 20.0
const RAGE_LIMIT := 3
const CARD_EVERY := 80.0
## While carrying, he jolts his captive every SHAKE_EVERY s, knocking back
## SHAKE_LOSS of their struggle; his grip drains struggle faster than others'.
const SHAKE_EVERY := 3.0
const SHAKE_LOSS := 0.25
const GRIP_DECAY := 0.12
var shake_clock := SHAKE_EVERY
const CARDS := ["I SEE YOU", "RUN", "%s", "%s <3", "NOT YET", "YOU'RE NEXT %s"]
var body: CampKiller
var favourite: CampPlayer
var shadow_clock := 0.0
var lunge_at := 45.0
var melt := 0.0
var rage := 0
var card_clock := 40.0
var used_spots: Dictionary = {}
var checked_spot := -1


func _init(killer: CampKiller) -> void:
	body = killer


func level() -> Node:
	return body.get_tree().get_first_node_in_group("round_world")


## Returns true when the trait took this physics frame.
func physics(delta: float) -> bool:
	var world: Node = level()
	if world == null or not world.plan.expedition:
		return false
	body.frenzy = maxf(0.0, body.frenzy - delta)
	body.door_force = 40.0 if body.frenzy > 0.0 else 1.0
	melt = maxf(0.0, melt - delta)
	body.faded = melt > 0.0
	if is_instance_valid(body.held):
		_carry(world, delta)
		return true
	body.carrying = false
	if melt > 0.0:
		# Gone into the dark; he reappears behind his favourite when it ends.
		body.velocity = Vector2.ZERO
		if melt <= delta * 1.5 and is_instance_valid(favourite):
			body.global_position = _behind(favourite, SHADOW_DISTANCE + 60.0)
		return true
	_cards(world, delta)
	_check_memory()
	if body.state != CampKiller.State.PATROL or world.night_clock.phase < 1:
		return false
	if not is_instance_valid(favourite) or favourite.status != CampPlayer.Status.ALIVE:
		_pick_favourite()
	if not is_instance_valid(favourite) or not CampMap.is_woods(favourite.global_position) or (CampKiller.camp_closed and CampKiller.in_camp(favourite.global_position)):
		return false
	# Shadowing: hang back at the edge of their light.
	if CreatureBrain.in_beam(favourite, body.global_position, 240.0, 0.82) and body.has_line_of_sight(favourite.global_position):
		melt = MELT_SECONDS
		world.announce("Something in your beam... and it's gone.", favourite)
		return true
	shadow_clock += delta
	if shadow_clock >= lunge_at:
		shadow_clock = 0.0
		lunge_at = randf_range(LUNGE_AFTER.x, LUNGE_AFTER.y)
		body.last_seen = favourite.global_position
		body.visible_target = favourite
		body.transition(CampKiller.State.CHASE)
		return false
	body.steer(_behind(favourite, SHADOW_DISTANCE), SHADOW_SPEED, delta)
	return true


func _pick_favourite() -> void:
	var options: Array[CampPlayer] = []
	for actor: CampPlayer in body.get_tree().get_nodes_in_group("survivors"):
		if actor.status == CampPlayer.Status.ALIVE:
			options.append(actor)
	favourite = options[randi() % options.size()] if not options.is_empty() else null
	shadow_clock = 0.0


func _behind(actor: CampPlayer, distance: float) -> Vector2:
	var back := -actor.facing if actor.facing != Vector2.ZERO else Vector2.UP
	var point: Vector2 = actor.global_position + back * distance
	var map := body.agent.get_navigation_map()
	if NavigationServer2D.map_get_iteration_id(map) > 0:
		point = NavigationServer2D.map_get_closest_point(map, point)
	return point


## The hunter loop reached `actor`: grab the wounded, hit everyone else.
func strike(actor: CampPlayer) -> bool:
	var world: Node = level()
	if world == null or not world.plan.expedition or not actor.wounded or actor.has_effect("held"):
		return false
	body.hold(actor, body.headline.to_upper(), 1.0 / 14.0, GRIP_DECAY)
	shake_clock = SHAKE_EVERY
	body.carrying = true
	body.attack_remaining = body.hit_cooldown
	world.soundscape.play_cue("chain_rattle", body.global_position, 4.0)
	world.announce("THE %s THROWS YOU OVER HIS SHOULDER! Mash E; teammates: flash him, flare, or the air horn." % body.headline.to_upper(), actor)
	return true


func _carry(world: Node, delta: float) -> void:
	body.carrying = true
	var victim := body.held
	victim.global_position = body.global_position + Vector2(0, -6)
	shake_clock -= delta
	if shake_clock <= 0.0:
		# He hitches you up on his shoulder: you lose your grip on the struggle.
		shake_clock = SHAKE_EVERY
		victim.struggle = maxf(0.0, victim.struggle - SHAKE_LOSS)
		victim.add_effect("jolted", 0.35)
	if body.nearby_flare() != Vector2.INF:
		body.release_held()
		world.announce("The flare makes him drop you!", victim)
		return
	var hook: Vector2 = world.hook_point()
	if body.steer(hook, CARRY_SPEED * (1.25 if body.frenzy > 0.0 else 1.0), delta) or body.global_position.distance_to(hook) < 18.0:
		_hang(world, victim, hook)


func _hang(world: Node, victim: CampPlayer, hook: Vector2) -> void:
	body.held = null
	victim.holder = null
	victim.clear_effect("held")
	victim.global_position = hook + Vector2(10, 8)
	victim.health = 0.0
	victim.set_meta("hooked", true)
	victim.set_status(CampPlayer.Status.DOWNED)
	body.carrying = false
	body.visible_target = null
	body.transition(CampKiller.State.PATROL)
	body.recover_remaining = 4.0
	world.pin_hook()
	world.announce("%s IS ON THE HOOK. It's pinned on the map: go and get them!" % (victim.peer_name.to_upper() if not victim.peer_name.is_empty() else "A SURVIVOR"))


## Someone slipped away from him: a broken hold, a stun, a vanished hider.
func humiliated() -> void:
	rage += 1
	if rage < RAGE_LIMIT:
		return
	rage = 0
	body.frenzy = FRENZY_SECONDS
	var world: Node = level()
	if world != null:
		world.soundscape.play_cue("screech_3", body.global_position, 10.0, 0.6)
		world.announce("THE %s SCREAMS. HE'S IN A FRENZY!" % body.headline.to_upper())


func remember_spot(index: int) -> void:
	used_spots[index] = used_spots.get(index, 0) + 1


## Searching near a spot someone hid in before: he goes there first.
func _check_memory() -> void:
	if body.state != CampKiller.State.SEARCH or used_spots.is_empty():
		return
	var world: Node = level()
	for index: int in used_spots:
		if index == checked_spot:
			continue
		var at: Vector2 = world.props.spots[index]["position"]
		if body.global_position.distance_to(at) < 380.0:
			checked_spot = index
			body.search_points.push_front(at)
			body.search_index = 0
			return


func _cards(world: Node, delta: float) -> void:
	card_clock -= delta
	if card_clock > 0.0 or not is_instance_valid(favourite) or not CampMap.is_woods(favourite.global_position):
		return
	card_clock = CARD_EVERY
	var name := favourite.peer_name.to_upper() if not favourite.peer_name.is_empty() else "YOU"
	var text: String = CARDS[randi() % CARDS.size()]
	if "%s" in text:
		text = text % name
	world.add_card(_behind(favourite, 110.0), text)
