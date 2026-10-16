class_name ForestSite
extends Node2D
## Small finite themed sites: searchable supplies and deliberate noise distractions.

var definition: Dictionary
var actions: Array[Dictionary] = []
var cooldown: float = 0.0
var level: Node2D


func _ready() -> void:
	var center: Vector2 = definition["position"]
	if definition["kind"] == "village":
		actions = [
			{"kind": "bell", "label": "RING VILLAGE BELL / DISTRACT", "position": center + Vector2(0, -24), "used": false},
			{"kind": "supplies", "label": "SEARCH OLD WELL / SUPPLIES", "position": center + Vector2(0, 48), "used": false}
		]
	elif definition["kind"] == "bog":
		actions = [{"kind": "cauldron", "label": "SIP CAULDRON / CHARGE LIGHT + HEX", "position": center, "used": false}]
	else:
		actions = [{"kind": "crypt", "label": "SEARCH CRYPT / FLARES", "position": center + Vector2(-32, 32), "used": false}]


func _physics_process(delta: float) -> void:
	if not level.paused and not level.finished:
		cooldown = maxf(0, cooldown - delta)


func nearby(actor: CampPlayer) -> Dictionary:
	for action in actions:
		if not action["used"] and actor.global_position.distance_to(action["position"]) <= actor.config.interact_radius and level.clear_path(actor.global_position, action["position"]):
			return action
	return {}


func interact(actor: CampPlayer) -> bool:
	if level.paused or level.finished or actor.status != CampPlayer.Status.ALIVE or not actor.is_in_group("survivors"):
		return false
	var action := nearby(actor)
	if action.is_empty() or cooldown > 0:
		return false
	cooldown = 3
	match action["kind"]:
		"bell":
			cooldown = 12
			level.loud_noise(action["position"], 1100)
			level.announce("The village bell rings. Footsteps turn toward the square!")
		"supplies":
			actor.supplies["battery_pack"] += 1
			actor.supplies["rations"] += 1
			actor.supplies["flare"] += 2
			action["used"] = true
			level.loud_noise(action["position"], 400)
			level.announce("Well stash: two flares, a battery and food. That lid was loud!")
		"cauldron":
			action["used"] = true
			actor.flashlight_charge = actor.config.flashlight_capacity
			actor.apply_hex(2.0)
			level.loud_noise(action["position"], 500)
			level.announce("Light recharged... but the brew hexed your legs!")
		"crypt":
			action["used"] = true
			actor.supplies["flare"] += 2
			level.loud_noise(action["position"], 550)
			level.announce("Two flares in the crypt. Something heard the stone move.")
	queue_redraw()
	return true


func _draw() -> void:
	var bounds: Rect2 = definition["bounds"]
	var center := bounds.get_center()
	if definition["kind"] == "village":
		for y in range(int(bounds.position.y), int(bounds.end.y), 16):
			for x in range(int(bounds.position.x), int(bounds.end.x), 16):
				if (x / 16 + y / 16) % 3 == 0:
					draw_rect(Rect2(x + 2, y + 2, 11, 10), Color("687263"))
		# Timber bell frame and a stone well, both used from the open square.
		for x in [-12, 11]:
			draw_rect(Rect2(center + Vector2(x, -63), Vector2(4, 38)), Color("887149"))
		draw_rect(Rect2(center + Vector2(-14, -64), Vector2(30, 5)), Color("b19563"))
		draw_circle(center + Vector2(0, -48), 7, Color("b49b60"))
		draw_line(center + Vector2(0, -40), center + Vector2(0, -24), Color("b9b18c"))
		draw_circle(center + Vector2(0, 35), 19, Color("8c9583"))
		draw_circle(center + Vector2(0, 32), 13, Color("1a3030"))
		for index in range(8):
			var stone := center + Vector2(0, 35) + Vector2.from_angle(index * TAU / 8) * 16
			draw_rect(Rect2(stone, Vector2(5, 4)), Color("b0ac8b"))
		draw_rect(Rect2(center + Vector2(-28, 65), Vector2(19, 12)), Color("866a45"))
	elif definition["kind"] == "bog":
		for index in range(9):
			var at := bounds.position + Vector2(24 + (index * 71) % 205, 24 + (index * 43) % 199)
			draw_circle(at, 22 + index % 3 * 4, Color("25443e"))
			draw_arc(at, 16, 0, PI, 12, Color("497258"))
			draw_line(at + Vector2(18, 4), at + Vector2(21, -13), Color("72825a"))
		# Planks keep the central ritual space readable.
		for y in range(-56, 78, 9):
			draw_rect(Rect2(center + Vector2(-31, y), Vector2(62, 7)), Color("766443"))
		draw_circle(center + Vector2(0, -12), 19, Color("152c2c"))
		draw_arc(center + Vector2(0, -12), 18, PI, TAU, 18, Color("879a7a"), 3)
		draw_circle(center + Vector2(0, -15), 13, Color("6b9861"))
		for index in range(5):
			draw_circle(center + Vector2(-8 + index * 4, -17 + index % 2 * 4), 2, Color("a5c178"))
		draw_line(center + Vector2(-25, -34), center + Vector2(22, 22), Color("a18c58"), 3)
	else:
		# Crooked headstones, broken iron fences and a searchable stone crypt.
		for index in range(10):
			var at := bounds.position + Vector2(28 + index % 5 * 45, 29 + index / 5 * 145)
			draw_rect(Rect2(at, Vector2(15, 23)), Color("6f8178"))
			draw_arc(at + Vector2(7, 1), 7, PI, TAU, 12, Color("a0a68a"), 2)
			draw_line(at + Vector2(3, 9), at + Vector2(12, 9), Color("c2baa0"))
			draw_rect(Rect2(at + Vector2(5, 15), Vector2(4, 3)), Color("394e43"))
		for x in range(int(bounds.position.x) + 12, int(bounds.end.x) - 12, 12):
			draw_line(Vector2(x, bounds.position.y + 8), Vector2(x, bounds.position.y + 26 + x % 3 * 3), Color("536b68"), 2)
		draw_rect(Rect2(center + Vector2(-57, -26), Vector2(51, 44)), Color("65766e"))
		draw_rect(Rect2(center + Vector2(-59, -30), Vector2(55, 8)), Color("9b9e85"))
		draw_rect(Rect2(center + Vector2(-43, -20), Vector2(22, 36)), Color("182b2a"))
		draw_line(center + Vector2(-60, 19), center + Vector2(-4, 19), Color("b2aa88"), 3)
	for action in actions:
		if action["used"]:
			draw_string(ThemeDB.fallback_font, action["position"] + Vector2(-12, 10), "EMPTY", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("8b9b80"))
	draw_string(ThemeDB.fallback_font, bounds.position + Vector2(8, bounds.size.y - 10), definition["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("cbbc8e"))
