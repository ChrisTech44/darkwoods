class_name SurvivorAbilities
extends Node2D
## Four personal kits; shared handoffs/awards remain available to every survivor.
const PASS_RANGE := 26.0
var level: Node2D
var marks: Array[Dictionary] = []
var stats: Dictionary = {}
var completed: Dictionary = {}
var receipts: Dictionary = {}
var enabled := true

static func ability_name(role: String) -> String:
	return {"christian":"FIELD TEST", "john":"PUSH THROUGH", "max":"WHAT COULD GO WRONG?", "alex":"MY OWN WAY BACK"}.get(role, "")

static func setup(actor: CampPlayer) -> void:
	actor.ability_charges = 0
	actor.ability_cooldown = 0.0
	actor.ability_active = 0.0
	SurvivorKits.setup(actor)

func _ready() -> void:
	enabled = get_node("/root/Session").camper_abilities_enabled
	CreatureSamples.reset()
	z_index = 4
	var ink := CanvasItemMaterial.new()
	ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material=ink

func _physics_process(delta: float) -> void:
	var net: Node = get_node("/root/Net")
	if level.paused or level.finished or net.active and (not multiplayer.is_server() or net.waiting): return
	advance(delta)

func advance(delta: float) -> void:
	CreatureSamples.record_history(level,delta)
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		actor.ability_cooldown = maxf(0.0,actor.ability_cooldown-delta)
		actor.ability_active = maxf(0.0,actor.ability_active-delta)
		SurvivorKits.advance(actor,delta)
		var row := stat(actor)
		if actor.hidden_spot >= 0: row["hidden"] += delta
		if level.night_clock.chased(actor): row["chased"] += delta
	queue_redraw()

func on_phase() -> void:
	pass

func status_text(actor: CampPlayer) -> String:
	return SurvivorKits.status(actor)

func use(actor: CampPlayer) -> bool:
	var net: Node = get_node("/root/Net")
	if net.active and (not multiplayer.is_server() or net.waiting): return false
	var used := SurvivorKits.use(actor)
	if used: stat(actor)["abilities"] += 1
	return used

func release(actor: CampPlayer) -> bool:
	var net: Node = get_node("/root/Net")
	if net.active and (not multiplayer.is_server() or net.waiting): return false
	return SurvivorKits.release(actor)

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
	return {"marks":[], "visuals":CreatureSamples.visuals(level)}

func restore(state: Dictionary) -> void:
	marks.assign(state.get("marks", []))
	set_meta("visuals",state.get("visuals",[]))
	queue_redraw()

func _draw() -> void:
	CreatureSamples.draw_world(self,level)
