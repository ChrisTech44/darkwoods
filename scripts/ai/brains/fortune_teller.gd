extends CreatureBrain
## The Fortune Teller: an old woman with a crystal ball who insists on reading
## your fortune. When she reaches you she holds you for a moment and turns a
## tarot card, and whatever it says happens: three cards help, four hurt. Then
## she vanishes and turns up elsewhere. Her shuffle is a soft chime; she drifts
## slowly, so you can usually decline by walking away.

const CARDS := {
	"THE SUN": "Light floods back: full flashlight and stamina.",
	"THE STAR": "A vision: the region of a part you haven't found.",
	"STRENGTH": "You feel stronger: +30 health.",
	"THE TOWER": "The stalker knows exactly where you are.",
	"THE MOON": "Darkness: your flashlight won't light for 20 s.",
	"THE FOOL": "Your belt spills open: supplies scatter around you.",
	"DEATH": "A cold touch: 30 damage.",
}
const READ_SECONDS := 1.6
var reading := 0.0
var client: CampPlayer
var cooldown := 6.0
var last_card := ""


func setup() -> void:
	display_name = "The Fortune Teller"
	tip = "She reads your fortune whether you like it or not: three cards help (light, a part's region, health), four hurt (the stalker finds you, darkness, spilled belt, 30 damage). Walk away to decline."
	body.config.killer_chase_speed = 40
	body.config.killer_patrol_speed = 24
	body.config.sight_radius = 180


func physics(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	if is_instance_valid(client):
		body.velocity = Vector2.ZERO
		reading -= delta
		client.velocity = Vector2.ZERO
		if reading <= 0.0:
			_deal(client)
			client = null
		body.queue_redraw()
		return true
	return false


func contact(actor: CampPlayer) -> bool:
	if cooldown > 0.0 or is_instance_valid(client):
		return true
	client = actor
	reading = READ_SECONDS
	actor.add_effect("tripped", READ_SECONDS)
	cue("bells", -2.0, 1.6)
	announce("\"Let me see your future, dear...\" She turns a card.", actor)
	return true


func _deal(actor: CampPlayer) -> void:
	var world: Node = level()
	CreatureSamples.encounter(actor,body)
	var names: Array = CARDS.keys()
	var card: String = names[randi() % names.size()]
	last_card = card
	actor.add_effect("card", 3.0)
	actor.effect_data["card"] = card
	match card:
		"THE SUN":
			actor.flashlight_charge = actor.config.flashlight_capacity
			actor.stamina = actor.config.stamina_max
			actor.exhausted = false
		"THE STAR":
			if world != null:
				for kind: String in world.clues:
					if int(world.clues[kind]) < 1 and kind not in world.van.installed:
						world.clues[kind] = 1
						announce("THE STAR: the %s waits at the %s." % [kind.replace("_", " ").to_upper(), world.plan.region_name(kind)], actor)
						break
		"STRENGTH":
			actor.heal(30.0)
		"THE TOWER":
			if world != null:
				world.killer.hear_stimulus(actor.global_position, INF)
		"THE MOON":
			actor.add_effect("dark", 20.0)
			actor.flashlight_on = false
		"THE FOOL":
			if world != null:
				var spilled := 0
				for kind: String in actor.supplies.keys():
					for unit in range(actor.supplies[kind]):
						world.spawn_dropped(kind, world._drop_position(actor.global_position, spilled))
						spilled += 1
					actor.supplies[kind] = 0
				actor.tidy_belt()
		"DEATH":
			actor.invulnerability = 0.0
			actor.receive_hit(30.0)
	if card != "THE STAR" or world == null:
		announce("%s. %s" % [card, CARDS[card]], actor)
	cooldown = 25.0
	cue("eerie", 2.0, 1.4)
	_vanish(actor)


func _vanish(actor: CampPlayer) -> void:
	var world: Node = level()
	if world == null or world.plan.woods.links.is_empty():
		return
	var cells: Array = world.plan.woods.links.keys()
	for attempt in range(20):
		var at: Vector2 = world.plan.woods.center(cells[randi() % cells.size()])
		if at.distance_to(actor.global_position) > 800.0 and not CampKiller.in_camp(at):
			body.global_position = at
			return


func fears_flare() -> bool:
	return false


func draw_over() -> void:
	if reading > 0.0:
		var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		body.draw_circle(Vector2(8, -26), 5.0 + glow * 2.0, Color(0.7, 0.5, 1.0, 0.45))


func snapshot() -> Dictionary:
	return {"reading": reading}


func restore(state: Dictionary) -> void:
	reading = state.get("reading", 0.0)
