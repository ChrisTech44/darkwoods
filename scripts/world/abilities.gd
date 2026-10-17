class_name SurvivorAbilities
extends Node2D
## F6 Roles 2.0: one active ability per survivor (X), item passing (H), team marks
## and the per-survivor stats behind end-of-night awards. Host-authoritative: the
## host validates every use; charges, cooldowns and marks replicate in snapshots.

const MARK_SECONDS := 6.0
const MARK_RANGE := 260.0
const PASS_RANGE := 26.0
## role → [name, charges (-1 = cooldown only), cooldown seconds, active seconds, refill]
## refill: "phase" restores charges each new night phase, "night" never refills.
const ABILITIES := {
	"jock": ["SECOND WIND", 1, 0.0, 2.0, "phase"],
	"mechanic": ["JURY-RIG", 2, 0.0, 8.0, "night"],
	"scout": ["MARK", -1, 30.0, 0.0, ""],
	"medic": ["PATCH", 2, 0.0, 0.0, "night"],
	"quiet": ["HOLD BREATH", -1, 45.0, 6.0, ""],
	"quartermaster": ["UNPACK", 1, 0.0, 0.0, "night"],
}
const UNPACK := ["flare", "battery_pack", "rations", "medkit"]
const SECOND_WIND_SPEED := 1.1

var level: Node2D
## Shared team marks from the Scout: {position, label, remaining}.
var marks: Array[Dictionary] = []
## Host-only award stats keyed by survivor instance id.
var stats: Dictionary = {}


static func ability_name(role: String) -> String:
	return ABILITIES.get(role, ["", 0])[0]


static func setup(actor: CampPlayer) -> void:
	var rule: Array = ABILITIES.get(actor.role, ["", 0, 0.0, 0.0, ""])
	actor.ability_charges = rule[1]
	actor.ability_cooldown = 0.0
	actor.ability_active = 0.0


func _ready() -> void:
	z_index = 4


func _physics_process(delta: float) -> void:
	var net: Node = get_node("/root/Net")
	if level.paused or level.finished or net.active and (not multiplayer.is_server() or net.waiting):
		return
	advance(delta)


func advance(delta: float) -> void:
	for mark in marks.duplicate():
		mark["remaining"] -= delta
		if mark["remaining"] <= 0.0:
			marks.erase(mark)
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		actor.ability_cooldown = maxf(0.0, actor.ability_cooldown - delta)
		actor.ability_active = maxf(0.0, actor.ability_active - delta)
		var row := stat(actor)
		if actor.hidden_spot >= 0:
			row["hidden"] += delta
		if level.night_clock.chased(actor):
			row["chased"] += delta
	queue_redraw()


func on_phase() -> void:
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		var rule: Array = ABILITIES.get(actor.role, ["", 0, 0.0, 0.0, ""])
		if rule[4] == "phase":
			actor.ability_charges = rule[1]


func status_text(actor: CampPlayer) -> String:
	var rule: Array = ABILITIES.get(actor.role, [])
	if rule.is_empty():
		return ""
	if actor.ability_active > 0.0:
		return "X %s %.1fs" % [rule[0], actor.ability_active]
	if actor.ability_cooldown > 0.0:
		return "X %s %ds" % [rule[0], ceili(actor.ability_cooldown)]
	if rule[1] >= 0:
		return "X %s ×%d" % [rule[0], actor.ability_charges] if actor.ability_charges > 0 else "X %s USED" % rule[0]
	return "X %s READY" % rule[0]


func use(actor: CampPlayer) -> bool:
	if level.paused or level.finished or actor.status != CampPlayer.Status.ALIVE or not actor.is_in_group("survivors"):
		return false
	var rule: Array = ABILITIES.get(actor.role, [])
	if rule.is_empty() or actor.ability_cooldown > 0.0 or actor.ability_active > 0.0:
		return false
	if rule[1] >= 0 and actor.ability_charges <= 0:
		level.announce("%s is spent for now." % rule[0].capitalize(), actor)
		return false
	var done := false
	match actor.role:
		"jock":
			actor.stamina = actor.config.stamina_max
			actor.exhausted = false
			actor.ability_active = rule[3]
			level.announce("Second wind! Stamina full, a burst of speed.", actor)
			done = true
		"mechanic":
			done = _jury_rig(actor, rule[3])
		"scout":
			done = _mark(actor)
		"medic":
			done = _patch(actor)
		"quiet":
			actor.ability_active = rule[3]
			level.announce("Holding your breath: silent footsteps, slow breath when hidden.", actor)
			done = true
		"quartermaster":
			for index in range(UNPACK.size()):
				level.spawn_dropped(UNPACK[index], actor.global_position + Vector2.from_angle(index * TAU / UNPACK.size()) * 18.0)
			level.announce("Stash unpacked: flare, battery, rations and a medkit for the team.", actor)
			done = true
	if not done:
		return false
	if rule[1] >= 0:
		actor.ability_charges -= 1
	actor.ability_cooldown = rule[2]
	stat(actor)["abilities"] += 1
	return true


func _jury_rig(actor: CampPlayer, seconds: float) -> bool:
	if level.near_generator(actor):
		# A quiet fix: power returns without the generator's roar.
		level.night_clock.blackout = false
		level.announce("Generator jury-rigged quietly. Lights are back.", actor)
		return true
	var props: ChaseProps = level.props
	var index: int = props.door_near(actor)
	if index >= 0:
		var door: Dictionary = props.doors[index]
		if door["broken"] > 0.0:
			level.announce("Nothing left to barricade; the door is smashed.", actor)
			return false
		if door["open"]:
			props.toggle_door(actor, index)
		door["barricade"] = seconds
		door["progress"] = 0.0
		level.announce("Door jury-rigged shut. It holds for %ds." % int(seconds), actor)
		return true
	level.announce("Jury-rig works on a cabin door or the dead generator.", actor)
	return false


## Mark what the Scout can actually see: a creature, a locked cache or a site.
func _mark(actor: CampPlayer) -> bool:
	var best_label := ""
	var best_at := Vector2.ZERO
	var best_score := INF
	var candidates: Array = []
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		var label: String = enemy.species.replace("_", " ").to_upper() if enemy is CampCryptid else "STALKER"
		candidates.append([enemy.global_position, label, 0.0])
	for pickup: CampPickup in level.pickups:
		if pickup.available and pickup.locked:
			candidates.append([pickup.global_position, "CACHE", 40.0])
	for site: ForestSite in level.camp_map.sites:
		candidates.append([site.definition["position"], WoodsLayout.short_name(site.definition) if site.definition.has("label") else "LANDMARK", 80.0])
	for candidate: Array in candidates:
		var at: Vector2 = candidate[0]
		var offset: Vector2 = at - actor.global_position
		if offset.length() > MARK_RANGE or offset.length() < 1.0 or actor.facing.dot(offset.normalized()) < 0.5 or not level.clear_path(actor.global_position, at):
			continue
		var score: float = offset.length() + candidate[2]
		if score < best_score:
			best_score = score
			best_at = at
			best_label = candidate[1]
	if best_label.is_empty():
		level.announce("Nothing in sight to mark. Face it and press X.", actor)
		return false
	marks.append({"position": best_at.round(), "label": best_label, "remaining": MARK_SECONDS})
	level.announce("Marked %s for the team." % best_label, actor)
	return true


func _patch(actor: CampPlayer) -> bool:
	var target: CampPlayer = actor if actor.health < CampPlayer.MAX_HEALTH else null
	if target == null:
		for other: CampPlayer in get_tree().get_nodes_in_group("survivors"):
			if other != actor and other.status == CampPlayer.Status.ALIVE and other.health < CampPlayer.MAX_HEALTH and actor.global_position.distance_to(other.global_position) <= level.config.interact_radius and level.clear_path(actor.global_position, other.global_position):
				target = other
				break
	if target == null:
		level.announce("Patch works on you or a wounded teammate beside you.", actor)
		return false
	target.wounded = false
	target.blood.clear()
	level.announce("Patched up without a medkit.", target)
	if target != actor:
		level.announce("You patched a teammate.", actor)
		stat(actor)["revives"] += 1
	return true


## Hand one unit of the held supply to the nearest adjacent standing teammate.
func give(actor: CampPlayer) -> bool:
	if level.paused or level.finished or actor.status != CampPlayer.Status.ALIVE:
		return false
	var kind := actor.held_item()
	if kind.is_empty() or actor.supplies.get(kind, 0) <= 0:
		level.announce("Select a supply on the belt (1-6), then H to hand it over.", actor)
		return false
	var best: CampPlayer
	for other: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if other == actor or other.status != CampPlayer.Status.ALIVE or other.hidden_spot >= 0:
			continue
		if actor.global_position.distance_to(other.global_position) <= PASS_RANGE and level.clear_path(actor.global_position, other.global_position) and other.can_pack(kind):
			if best == null or actor.global_position.distance_to(other.global_position) < actor.global_position.distance_to(best.global_position):
				best = other
	if best == null:
		level.announce("Stand right beside a teammate with room on their belt.", actor)
		return false
	actor.supplies[kind] -= 1
	actor.tidy_belt()
	best.pack(kind)
	stat(actor)["gave"] += 1
	level.announce("Handed over a %s." % kind.replace("_", " "), actor)
	level.announce("A teammate handed you a %s." % kind.replace("_", " "), best)
	return true


func stat(actor: CampPlayer) -> Dictionary:
	var key := actor.get_instance_id()
	if not stats.has(key):
		stats[key] = {"name": actor.peer_name if not actor.peer_name.is_empty() else "You", "revives": 0, "flares": 0, "hidden": 0.0, "chased": 0.0, "gave": 0, "downs": 0, "abilities": 0}
	return stats[key]


## Titles for the results screen. Only awarded when someone actually earned them.
func awards() -> Array[String]:
	var titles: Array[String] = []
	var rules := [["revives", "NEVER LEFT BEHIND", 1], ["flares", "MOST FLARES WASTED", 3], ["chased", "BAIT", 20.0], ["hidden", "HID IN A LOCKER FOR TWO MINUTES", 120.0], ["gave", "PACK MULE", 2], ["downs", "ALWAYS GETS CAUGHT", 2], ["abilities", "SHOW-OFF", 4]]
	for rule in rules:
		var top: Dictionary = {}
		for row: Dictionary in stats.values():
			if row[rule[0]] >= rule[2] and (top.is_empty() or row[rule[0]] > top[rule[0]]):
				top = row
		if not top.is_empty():
			titles.append("%s: %s" % [rule[1], str(top["name"]).to_upper()])
	return titles


func snapshot() -> Dictionary:
	return {"marks": marks}


func restore(state: Dictionary) -> void:
	marks.assign(state.get("marks", []))
	queue_redraw()


func _draw() -> void:
	for mark: Dictionary in marks:
		var at: Vector2 = mark["position"]
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
		if not PixelArt.draw_in(self, "fx_mark", Rect2(at - Vector2(12, 10), Vector2(24, 22)), Color(1, 1, 1, pulse)):
			draw_arc(at, 12.0, 0.0, TAU, 24, Color(0.62, 0.86, 0.95, pulse), 1.5)
		draw_line(at + Vector2(0, -20), at + Vector2(0, -13), Color(0.62, 0.86, 0.95, pulse), 2.0)
		draw_string(ThemeDB.fallback_font, at + Vector2(-ThemeDB.fallback_font.get_string_size(mark["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x * 0.5, -23), mark["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("bfe3f0"))
