class_name SurvivorKits
extends RefCounted
## All outcomes are authority-owned; only the actor's plain-data kit replicates.
const JOHN_WINDOW := 6.0
const JOHN_COOLDOWN := 45.0
const ALONE_ENTER := 190.0
const ALONE_EXIT := 150.0
const ALONE_DELAY := 4.0
const MARK_LIFE := 75.0
const RETURN_CHANNEL := 2.0
const RETURN_COOLDOWN := 40.0
const CASH_PRICE := 4
const CASH_CAP := 100
const PAYOUTS := ["flare", "battery_pack", "rations", "medkit", "noise_tin", "salt_ward", "glow_moss"]

static func world(actor: CampPlayer) -> Node:
	return actor.get_tree().get_first_node_in_group("round_world")

static func enabled(actor: CampPlayer) -> bool:
	var level: Node = world(actor)
	if level != null and is_instance_valid(level.abilities): return level.abilities.enabled
	return actor.get_node("/root/Session").camper_abilities_enabled

static func setup(actor: CampPlayer) -> void:
	actor.kit = {"owner":actor.get_instance_id(), "debt":0.0, "alone":0.0,
		"isolated":false, "marker":Vector2.ZERO, "marker_life":0.0, "channel":0.0,
		"cash":6 if actor.role == "max" and enabled(actor) else 0, "stake_time":-1.0,
		"sample":"shutter_wraith" if actor.role == "christian" and not actor.expedition and enabled(actor) else "",
		"subtype":"frog", "form":"", "form_time":0.0, "action_cd":0.0}

static func able(actor: CampPlayer) -> bool:
	return actor.status == CampPlayer.Status.ALIVE and actor.hidden_spot < 0 and not actor.has_effect("held") and not actor.has_effect("asleep") and not actor.has_effect("tripped") and not actor.has_effect("frog")

static func use(actor: CampPlayer) -> bool:
	var level: Node = world(actor)
	if level == null or not enabled(actor) or level.paused or level.finished: return false
	var committed_cancel: bool=actor.role=="christian" and actor.kit.get("cast",{}).get("kind","") in ["owl","teddy","lens_eater","vampire","boiler_saint"] and actor.status==CampPlayer.Status.ALIVE and actor.hidden_spot<0 and not actor.has_effect("held") and not actor.has_effect("asleep") and not actor.has_effect("frog")
	if not able(actor) and not committed_cancel: return false
	if actor.ability_cooldown > 0.0: return false
	match actor.role:
		"christian": return CreatureSamples.use(actor)
		"john":
			if actor.ability_active > 0.0: return false
			actor.ability_active = JOHN_WINDOW
			actor.ability_cooldown = JOHN_COOLDOWN
			level.announce("Push Through: damage is deferred, not forgiven.", actor)
			return true
		"max":
			if actor.kit["stake_time"] >= 0.0: return false
			if actor.kit["cash"] < CASH_PRICE:
				level.announce("Need $%d. Search optional stashes or recover stolen gear." % CASH_PRICE, actor)
				return false
			actor.kit["stake_time"] = 0.0
			return true
		"alex":
			if actor.kit["marker_life"] <= 0.0:
				if not safe_point(actor, actor.position): return false
				actor.kit["marker"] = actor.position
				actor.kit["marker_life"] = MARK_LIFE
				level.announce("Return marker placed for 75s. Alone: X to channel back.", actor)
				return true
			if not actor.kit["isolated"] or actor.has_effect("tethered"):
				level.announce("Return needs isolation and freedom to move. No breakout from a grab.", actor)
				return false
			if actor.kit["channel"] > 0.0: return false
			actor.kit["channel"] = RETURN_CHANNEL
			return true
	return false

static func cancel_stake(actor: CampPlayer) -> void:
	if actor.role=="max": actor.kit["stake_time"]=-1.0

static func stake(actor: CampPlayer) -> int:
	return stake_for_cash(actor,float(actor.kit.get("stake_time",0.0)))

static func stake_for_cash(actor: CampPlayer, held: float) -> int:
	return CASH_PRICE * mini(int(actor.kit.get("cash",0)) / CASH_PRICE,1+mini(2,int(held/0.65)))

static func release(actor: CampPlayer) -> bool:
	if actor.role != "max" or actor.kit.get("stake_time", -1.0) < 0.0: return false
	var held: float = actor.kit["stake_time"]
	actor.kit["stake_time"] = -1.0
	var level: Node = world(actor)
	if level == null or not enabled(actor) or level.paused or level.finished or not able(actor): return false
	var cost := stake_for_cash(actor,held)
	if cost < CASH_PRICE: return false
	actor.kit["cash"] -= cost
	actor.ability_cooldown = 1.0
	var count := 1
	if held >= 0.45:
		count = 0 if randf() < 0.45 else 2 * (cost / CASH_PRICE)
	for i in range(count):
		var kind: String = PAYOUTS[randi() % PAYOUTS.size()]
		if not actor.pack(kind): level.spawn_dropped(kind, level._drop_position(actor.position, i))
	level.announce("Cash Out: $%d → %d supplies%s" % [cost,count,". Bust!" if count == 0 else "."],actor)
	return true

static func advance(actor: CampPlayer, delta: float) -> void:
	if actor.kit.is_empty(): return
	if not enabled(actor):
		settle(actor)
		cleanup(actor)
		actor.kit["isolated"] = false
		return
	if actor.role == "john" and actor.ability_active <= 0.0: settle(actor)
	if actor.role == "max" and actor.kit["stake_time"] >= 0.0:
		actor.kit["stake_time"] = minf(2.0, actor.kit["stake_time"] + delta)
		if not able(actor): actor.kit["stake_time"] = -1.0
	if actor.role == "alex":
		var distance := INF
		for other: CampPlayer in actor.get_tree().get_nodes_in_group("survivors"):
			if other != actor and other.status == CampPlayer.Status.ALIVE:
				distance = minf(distance, actor.global_position.distance_to(other.global_position))
		var threshold := ALONE_EXIT if actor.kit["isolated"] else ALONE_ENTER
		if actor.status == CampPlayer.Status.ALIVE and distance > threshold:
			actor.kit["alone"] = minf(ALONE_DELAY, actor.kit["alone"] + delta)
			actor.kit["isolated"] = actor.kit["alone"] >= ALONE_DELAY
		else:
			actor.kit["alone"] = 0.0
			actor.kit["isolated"] = false
		actor.kit["marker_life"] = maxf(0.0,actor.kit["marker_life"]-delta)
		if actor.kit["channel"] > 0.0:
			if not able(actor) or not actor.kit["isolated"] or actor.kit["marker_life"] <= 0.0 or actor.has_effect("tethered"):
				cancel_return(actor)
			else:
				actor.kit["channel"] = maxf(0.0,actor.kit["channel"]-delta)
				if actor.kit["channel"] <= 0.0:
					if safe_point(actor,actor.kit["marker"]):
						actor.position = actor.kit["marker"]
						actor.kit["marker_life"] = 0.0
						actor.ability_cooldown = RETURN_COOLDOWN
						world(actor).announce("Your own way back. Your injuries came too.",actor)
					else:
						actor.ability_cooldown = 2.0
						world(actor).announce("Return blocked. Marker remains until expiry.",actor)
	if actor.role == "christian": CreatureSamples.advance(actor,delta)

static func safe_point(actor: CampPlayer, point: Vector2) -> bool:
	if not point.is_finite() or not CampMap.WORLD_BOUNDS.has_point(point): return false
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0,point)
	query.collision_mask = actor.collision_mask
	query.exclude = [actor.get_rid()]
	return actor.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

static func cancel_return(actor: CampPlayer) -> void:
	if actor.kit.get("channel",0.0) > 0.0:
		actor.kit["channel"] = 0.0
		actor.ability_cooldown = maxf(actor.ability_cooldown,2.0)

static func hit(actor: CampPlayer, damage: float) -> void:
	cancel_return(actor)
	actor.kit["stake_time"] = -1.0
	if actor.role == "max" and enabled(actor): spill(actor,mini(int(actor.kit["cash"]),maxi(1,int(actor.kit["cash"]) / 3)))

static func settle(actor: CampPlayer) -> void:
	var debt: float = actor.kit.get("debt",0.0)
	actor.kit["debt"] = 0.0
	actor.ability_active = 0.0
	if debt > 0.0 and actor.status == CampPlayer.Status.ALIVE:
		actor.health = maxf(0.0,actor.health-debt)
		actor.hurt_time = 0.6
		if actor.health <= 0.0: actor.set_status(CampPlayer.Status.DOWNED)

static func cleanup(actor: CampPlayer) -> void:
	cancel_return(actor)
	actor.kit["stake_time"] = -1.0
	actor.kit["marker_life"] = 0.0
	CreatureSamples.finish_cast(actor)
	actor.kit["research"] = {}
	actor.kit["sample"] = ""
	actor.kit["form"] = ""
	actor.kit["form_time"] = 0.0
	actor.kit["debt"] = 0.0
	actor.ability_active = 0.0

static func progress(actor: CampPlayer, key: String) -> void:
	var level: Node = world(actor)
	if level == null or not is_instance_valid(level.abilities) or not enabled(actor): return
	if level.abilities.completed.has(key): return
	level.abilities.completed[key] = true
	if actor.role != "john": return
	actor.stamina = actor.config.stamina_max
	actor.exhausted = false

static func earn(actor: CampPlayer, key: String, amount: int) -> void:
	if actor.role != "max" or not enabled(actor): return
	var level: Node = world(actor)
	if level == null or not is_instance_valid(level.abilities) or level.abilities.receipts.has(key): return
	level.abilities.receipts[key] = true
	actor.kit["cash"] = mini(CASH_CAP,int(actor.kit["cash"])+amount)
	level.announce("Finder's Fee +$%d / $%d" % [amount,actor.kit["cash"]],actor)

static func spill(actor: CampPlayer, amount: int) -> void:
	var level: Node = world(actor)
	if amount <= 0 or level == null: return
	actor.kit["cash"] -= amount
	var pickup: CampPickup = level.spawn_dropped("cash",level._drop_position(actor.position,0))
	pickup.cash_owner = actor.kit["owner"]
	pickup.cash_amount = amount

static func status(actor: CampPlayer) -> String:
	if not enabled(actor): return "CAMPER ABILITIES OFF"
	match actor.role:
		"christian": return CreatureSamples.status(actor)
		"john":
			if actor.ability_active > 0.0: return "DEBT %d / AFTER %d / %.1fs" % [actor.kit["debt"],maxf(0,actor.health-actor.kit["debt"]),actor.ability_active]
		"max":
			if actor.kit.get("stake_time",-1.0) >= 0.0: return ("BUY 1 / $4" if actor.kit["stake_time"]<0.45 else "GAMBLE $%d / RELEASE X" % stake(actor))
			return "X BUY $4 / HOLD GAMBLE / $%d" % actor.kit.get("cash",0)
		"alex":
			if actor.kit["channel"] > 0.0: return "RETURN %.1fs / HIT CANCELS" % actor.kit["channel"]
			if actor.kit["marker_life"] > 0.0: return "X RETURN %ds / %s" % [actor.kit["marker_life"],"ALONE" if actor.kit["isolated"] else "NEED ISOLATION"]
	if actor.ability_cooldown > 0: return "X %s %ds" % [SurvivorAbilities.ability_name(actor.role),ceili(actor.ability_cooldown)]
	return "X " + SurvivorAbilities.ability_name(actor.role) + (" / SOLO" if actor.kit.get("isolated",false) else "")
