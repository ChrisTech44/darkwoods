extends CreatureBrain
## Trash Jackals: thieves. They dart in, snatch something off your belt (now
## and then a part you're carrying) and run it back to their den, where they
## drop it. The den is pinned on everyone's map after the first theft. A flash
## makes a jackal drop what it carries; thrown food distracts it.

const DASH := 120.0
const PART_CHANCE := 0.2
var den := Vector2.ZERO
var loot := ""
var snack := 0.0
var cooldown := 0.0


func setup() -> void:
	display_name = "Trash Jackals"
	tip = "They steal from your belt (sometimes a part) and run to their den. Flash one to make it drop the loot."
	body.config.killer_chase_speed = DASH
	body.config.sight_radius = 170
	var center: Vector2 = body.home.get_center() if body.home.has_area() else body.global_position
	den = center + Vector2(110, 80)


func physics(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	snack = maxf(0.0, snack - delta)
	if snack > 0.0:
		body.velocity = Vector2.ZERO
		return true
	if not loot.is_empty():
		if body.steer(den, 115.0, delta):
			_stash()
		return true
	if cooldown > 0.0:
		wander(50.0, delta)
		return true
	return false


func contact(actor: CampPlayer) -> bool:
	if not loot.is_empty() or cooldown > 0.0:
		return true
	var world: Node = level()
	var parts: Array[String] = []
	for kind: String in actor.inventory:
		if kind != "outboard_motor":
			parts.append(kind)
	if not parts.is_empty() and randf() < PART_CHANCE:
		loot = parts[randi() % parts.size()]
		actor.inventory.erase(loot)
	else:
		var options: Array[String] = []
		for kind: String in actor.belt:
			if not kind.is_empty() and actor.supplies.get(kind, 0) > 0:
				options.append(kind)
		if options.is_empty():
			cooldown = 4.0
			return true
		loot = options[randi() % options.size()]
		actor.supplies[loot] -= 1
		actor.tidy_belt()
	cue("monster_6", 4.0, 1.5)
	announce("A JACKAL SNATCHED YOUR %s! It's running for its den." % loot.replace("_", " ").to_upper(), actor)
	if world != null:
		world.pin_den(den)
	return true


func _stash() -> void:
	var world: Node = level()
	if world != null:
		world.spawn_dropped(loot, den + Vector2(randf_range(-14, 14), randf_range(4, 14))).theft_token = "theft:"+str(body.get_instance_id())
	loot = ""
	cooldown = 10.0


## Dropped on a flash: the stolen thing falls where it stands.
func on_stunned() -> void:
	if loot.is_empty():
		return
	var world: Node = level()
	if world != null:
		world.spawn_dropped(loot, body.global_position).theft_token = "theft:"+str(body.get_instance_id())
		world.announce("The jackal yelps and drops the %s!" % loot.replace("_", " "))
	loot = ""
	cooldown = 6.0


func bait(actor: CampPlayer) -> bool:
	if body.global_position.distance_to(actor.global_position) > 140.0:
		return false
	on_stunned()
	snack = 15.0
	announce("The jackal snaps up the food and forgets you for a bit.", actor)
	return true


func draw_over() -> void:
	if not loot.is_empty():
		PixelArt.draw_in(body, loot, Rect2(6, -22, 10, 10))


func snapshot() -> Dictionary:
	return {"loot": loot}


func restore(state: Dictionary) -> void:
	loot = state.get("loot", "")
