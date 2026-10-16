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
	elif definition["kind"] == "graveyard":
		actions = [{"kind": "crypt", "label": "SEARCH CRYPT / FLARES", "position": center + Vector2(-32, 32), "used": false}]

	else:
		actions = [{"kind":"relic", "label":"SEARCH LANDMARK / RARE TOOL (LOUD)", "position":center, "used":false}]


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
	var rewards := {"supplies":{"battery_pack":1,"rations":1,"flare":2}, "crypt":{"flare":2}, "relic":{["noise_tin","salt_ward","glow_moss"][posmod(int(center_hash()),3)]:1}}
	if rewards.has(action["kind"]):
		var needed := 0
		for kind in rewards[action["kind"]]:
			if kind not in actor.belt:
				needed += 1
		if actor.belt.count("") < needed:
			level.announce("Make room in the belt before searching. G drops a stack.")
			return false
		for kind in rewards[action["kind"]]:
			actor.pack(kind, rewards[action["kind"]][kind])
	match action["kind"]:
		"bell":
			cooldown = 12
			level.loud_noise(action["position"], 1100)
			level.announce("The village bell rings. Footsteps turn toward the square!")
		"supplies":
			action["used"] = true
			level.loud_noise(action["position"], 400)
			level.announce("Well stash: two flares, a battery and food. That lid was loud!")
		"cauldron":
			action["used"] = true
			actor.flashlight_charge = actor.config.flashlight_capacity
			actor.apply_hex(2.0)
			level.loud_noise(action["position"], 500)
			level.announce("Light recharged... but the brew hexed your legs!")
		"relic":
			action["used"] = true
			level.loud_noise(action["position"], 650)
			level.announce("Rare tool recovered. The landmark guardian heard you!")
		"crypt":
			action["used"] = true
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
		for index in range(65):
			var at := bounds.position + Vector2(24 + (index * 71) % int(bounds.size.x-48), 24 + (index * 43) % int(bounds.size.y-48))
			draw_circle(at, 22 + index % 3 * 4, Color("25443e"))
			draw_arc(at, 16, 0, PI, 12, Color("497258"))
			draw_line(at + Vector2(18, 4), at + Vector2(21, -13), Color("72825a"))
		# Planks keep the central ritual space readable.
		for y in range(-int(bounds.size.y/2)+48, int(bounds.size.y/2)-48, 9):
			draw_rect(Rect2(center + Vector2(-40, y), Vector2(80, 7)), Color("766443"))
		draw_circle(center + Vector2(0, -12), 19, Color("152c2c"))
		draw_arc(center + Vector2(0, -12), 18, PI, TAU, 18, Color("879a7a"), 3)
		draw_circle(center + Vector2(0, -15), 13, Color("6b9861"))
		for index in range(5):
			draw_circle(center + Vector2(-8 + index * 4, -17 + index % 2 * 4), 2, Color("a5c178"))
		draw_line(center + Vector2(-25, -34), center + Vector2(22, 22), Color("a18c58"), 3)
	elif definition["kind"] == "graveyard":
		# Crooked headstones, broken iron fences and a searchable stone crypt.
		for index in range(24):
			var row := index / 6
			var at := bounds.position + Vector2(64 + index % 6 * (bounds.size.x-128)/5, 64 + row * (bounds.size.y-128)/3)
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
	else:
		_draw_landmark(bounds, center)
	for action in actions:
		if action["used"]:
			draw_string(ThemeDB.fallback_font, action["position"] + Vector2(-12, 10), "EMPTY", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("8b9b80"))
	draw_string(ThemeDB.fallback_font, bounds.position + Vector2(8, bounds.size.y - 10), definition["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("cbbc8e"))


func center_hash() -> int:
	return int(definition["cell"].x + definition["cell"].y)

func _draw_landmark(bounds: Rect2, center: Vector2) -> void:
	var kind: String = definition["kind"]
	var palettes := {"mill":"4f6661", "orchard":"46583b", "observatory":"414b62", "rail":"66584c", "quarry":"68736d", "chapel":"465763"}
	draw_rect(bounds, Color(palettes[kind]))
	# Walkable dressing, no decorative prop changes collision or hides a route.
	_draw_biome_floor(kind, bounds, center)
	for index in range(170):
		var at := bounds.position + Vector2(12 + posmod(index*137, int(bounds.size.x)-24), 12 + posmod(index*83, int(bounds.size.y)-24))
		draw_rect(Rect2(at,Vector2(2+index%4,1)), Color("8a9177"))
	for index in range(16):
		var at := bounds.position + Vector2(80 + index%4 * (bounds.size.x-160)/3, 80 + index/4 * (bounds.size.y-160)/3)
		if at.distance_to(center) < 100:
			continue
		draw_circle(at + Vector2(0,9), 24, Color(0.05,0.09,0.1,0.3))
		match kind:
			"orchard":
				for side in [-1,1]:
					draw_line(at, at+Vector2(side*21,-20), Color("80654a"),3)
				draw_rect(Rect2(at+Vector2(-3,-23),Vector2(6,35)),Color("6b503b"))
				draw_circle(at+Vector2(0,-26),22,Color("304832"))
				for fruit in range(7):
					draw_circle(at+Vector2(-15+fruit*5,-23-fruit%3*5),2,Color("c39463"))
			"mill":
				draw_rect(Rect2(at-Vector2(23,12),Vector2(46,27)),Color("284445"))
				for plank in range(6):
					draw_rect(Rect2(at+Vector2(-24,-15+plank*5),Vector2(48,3)),Color("8e7958"))
				draw_line(at+Vector2(-20,-19),at+Vector2(18,-19),Color("b2996a"),4)
			"rail":
				for rail_x in [-20,20]:
					draw_line(at+Vector2(rail_x,-30),at+Vector2(rail_x,30),Color("a7a38c"),2)
				for y in range(-25,30,8):
					draw_line(at+Vector2(-25,y),at+Vector2(25,y),Color("352e2b"),3)
				draw_rect(Rect2(at+Vector2(-16,-22),Vector2(32,32)),Color("806449"))
				draw_rect(Rect2(at+Vector2(-12,-18),Vector2(24,12)),Color("26353b"))
			"observatory":
				draw_circle(at,23,Color("273846"))
				draw_arc(at,21,PI,TAU,20,Color("a0a799"),3)
				draw_line(at+Vector2(-17,-13),at+Vector2(20,-28),Color("b0af9b"),7)
				draw_circle(at+Vector2(20,-28),4,Color("3a4c59"))
			"quarry":
				for rock in range(4):
					var point := at+Vector2(rock*8-20,rock%2*8-10)
					draw_texture(preload("res://assets/sprites/boulder.png"),point)
				draw_line(at+Vector2(-20,17),at+Vector2(20,17),Color("c6b994"),2)
			"chapel":
				draw_rect(Rect2(at+Vector2(-20,-6),Vector2(40,10)),Color("756b58"))
				for x in [-16,14]:
					draw_rect(Rect2(at+Vector2(x,-21),Vector2(3,14)),Color("c2bd9e"))
					draw_circle(at+Vector2(x+1,-23),2,Color("efbf7a"))
	_draw_centerpiece(kind, center + Vector2(0,-95))
	# Central reward altar is visually distinct from surrounding dressing.
	draw_rect(Rect2(center-Vector2(16,12),Vector2(32,24)), Color("242f32"))
	draw_rect(Rect2(center-Vector2(14,10),Vector2(28,4)), Color("c5b88d"))
	draw_circle(center,4,Color("e2d4a2"))
	draw_string(ThemeDB.fallback_font, center+Vector2(-40,28), "E / RARE TOOL", HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("d9c799"))


func _draw_biome_floor(kind: String, bounds: Rect2, center: Vector2) -> void:
	# Inlaid floors and shallow channels are walkable; geometry stays truthful.
	for y in range(int(bounds.position.y)+8,int(bounds.end.y)-8,16):
		for x in range(int(bounds.position.x)+8,int(bounds.end.x)-8,16):
			var at := Vector2(x,y)
			var hash_value := posmod(x*31+y*17,71)
			if kind in ["chapel","observatory","quarry"]:
				draw_rect(Rect2(at,Vector2(14,14)),Color("556467") if hash_value<30 else Color("465659"))
				draw_line(at+Vector2(1,1),at+Vector2(12,1),Color("78807a"))
			elif kind == "orchard":
				draw_rect(Rect2(at,Vector2(13,3)),Color("36482e"))
				if hash_value<12:
					draw_line(at,at+Vector2(3,-5),Color("a0a66a"))
			elif kind == "mill":
				draw_line(at,at+Vector2(14,0),Color("617e75"))
			else:
				if hash_value<22:
					draw_rect(Rect2(at,Vector2(7,3)),Color("8b7b63"))
	if kind == "rail":
		for offset in [-105,105]:
			for y in range(int(bounds.position.y),int(bounds.end.y),12):
				draw_rect(Rect2(center.x+offset-27,y,54,5),Color("302e2b"))
			for x in [-19,19]:
				draw_line(Vector2(center.x+offset+x,bounds.position.y),Vector2(center.x+offset+x,bounds.end.y),Color("b0b4a5"),2)
	elif kind == "mill":
		for offset in [-105,105]:
			draw_rect(Rect2(center.x+offset-22,bounds.position.y,44,bounds.size.y),Color("254445"))
			for y in range(int(bounds.position.y),int(bounds.end.y),13):
				draw_line(Vector2(center.x+offset-18,y),Vector2(center.x+offset+14,y),Color("6b9186"))
		for y in [-45,65]:
			for x in range(-150,151,8):
				draw_rect(Rect2(center+Vector2(x,y),Vector2(6,36)),Color("8b7857"))
	elif kind == "orchard":
		for offset in [-160,160]:
			for y in range(int(bounds.position.y)+32,int(bounds.end.y)-32,64):
				var at := Vector2(center.x+offset,y)
				draw_line(at-Vector2(32,0),at+Vector2(32,0),Color("aa9a70"))
				for x in [-32,32]:
					draw_rect(Rect2(at+Vector2(x,-12),Vector2(3,24)),Color("6e5d42"))
	else:
		for radius in [78,82,128,132]:
			draw_arc(center,radius,0,TAU,64,Color("9d9d85"),1)
		for index in range(12):
			var ray := Vector2.from_angle(index*TAU/12)
			draw_line(center+ray*85,center+ray*127,Color("969780"))

func _draw_centerpiece(kind: String, at: Vector2) -> void:
	match kind:
		"mill":
			draw_circle(at+Vector2(0,14),52,Color("273936"))
			for radius in [38,43,47]:
				draw_arc(at,radius,0,TAU,48,Color("bba376"),3)
			for index in range(12):
				var ray := Vector2.from_angle(index*TAU/12)
				draw_line(at+ray*10,at+ray*44,Color("87714f"),4)
				draw_circle(at+ray*39,2,Color("e4c38b"))
			draw_circle(at,10,Color("4b5f59"))
			draw_rect(Rect2(at+Vector2(48,-20),Vector2(42,42)),Color("685b48"))
			for y in range(-17,20,7):
				draw_line(at+Vector2(49,y),at+Vector2(88,y),Color("b49768"),2)
			draw_circle(at+Vector2(69,-7),8,Color("ccad79"))
			draw_line(at+Vector2(69,-7),at+Vector2(73,-12),Color("4b4538"),2)
		"observatory":
			draw_circle(at+Vector2(0,8),55,Color("253440"))
			draw_circle(at,50,Color("727d83"))
			for radius in [36,43,49]:
				draw_arc(at,radius,PI,TAU,32,Color("adb5ae"),2)
			draw_rect(Rect2(at+Vector2(-6,-49),Vector2(12,91)),Color("273747"))
			for index in range(7):
				draw_line(at+Vector2(-35+index*11,-32),at+Vector2(-32+index*10,27),Color("566a78"))
			draw_line(at+Vector2(0,8),at+Vector2(63,-35),Color("313f4c"),20)
			draw_line(at+Vector2(0,4),at+Vector2(62,-39),Color("a3b1ac"),12)
			draw_circle(at+Vector2(64,-38),9,Color("203943"))
			draw_arc(at+Vector2(64,-38),9,PI,TAU,12,Color("c5c7ae"),2)
		"rail":
			for y in range(-30,35,10):
				draw_rect(Rect2(at+Vector2(-57,y),Vector2(114,5)),Color("332f2a"))
			for x in [-44,-8,8,44]:
				draw_line(at+Vector2(x,-35),at+Vector2(-x,35),Color("b0b4a2"),2)
			draw_rect(Rect2(at+Vector2(59,-25),Vector2(8,51)),Color("847354"))
			draw_circle(at+Vector2(63,-30),9,Color("c4a779"))
			draw_rect(Rect2(at+Vector2(58,-33),Vector2(10,3)),Color("5e4339"))
		"chapel":
			for y in range(-40,41,10):
				for x in range(-60,61,10):
					draw_rect(Rect2(at+Vector2(x,y),Vector2(8,8)),Color("9b9c8c") if posmod(x+y,20)==0 else Color("4a6063"))
			draw_arc(at,30,0,TAU,40,Color("d2c7a1"),3)
			draw_line(at+Vector2(0,-26),at+Vector2(0,26),Color("c6b990"),6)
			draw_line(at+Vector2(-17,-7),at+Vector2(17,-7),Color("c6b990"),6)
			for x in [-70,70]:
				for y in [-30,30]:
					draw_circle(at+Vector2(x,y),10,Color("9aab9e"))
					draw_circle(at+Vector2(x,y-4),7,Color("566969"))
		"quarry":
			for index in range(5):
				var rect := Rect2(at-Vector2(65-index*10,42-index*6),Vector2(130-index*20,84-index*12))
				draw_rect(rect,Color("76827b") if index%2==0 else Color("4c615e"),false,3)
			for x in [-55,55]:
				draw_line(at+Vector2(x,-35),at+Vector2(x,35),Color("c7b486"),2)
				for y in range(-30,36,8):
					draw_line(at+Vector2(x-6,y),at+Vector2(x+6,y),Color("c7b486"),2)
		"orchard":
			for x in [-65,65]:
				draw_rect(Rect2(at+Vector2(x,-40),Vector2(6,72)),Color("8b7352"))
			for y in range(-40,25,9):
				draw_line(at+Vector2(-65,y),at+Vector2(70,y),Color("9b9167"),2)
				for x in range(-55,65,13):
					draw_line(at+Vector2(x,y),at+Vector2(x+6,y-9),Color("526e41"),3)
					draw_circle(at+Vector2(x+4,y-4),2,Color("bd8d5c"))
