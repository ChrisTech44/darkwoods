class_name ForestSite
extends Node2D
## Small finite themed sites: searchable supplies and deliberate noise distractions.

var definition: Dictionary
var actions: Array[Dictionary] = []
var cooldown: float = 0.0
var level: Node2D


func _ready() -> void:
	set_meta("stand_in_world", true)
	var center: Vector2 = definition["position"]
	if definition["kind"] == "boathouse":
		var lake := LakeWater.new()
		lake.rects = FieldEscapeArt.water_rects(center)
		for x in [-49, 46]:
			for y in [-216, -120, -24]:
				lake.pilings.append(center + Vector2(x, y + 8))
		add_child(lake)
	if definition["kind"] == "village":
		actions = [
			{"kind": "bell", "label": "RING VILLAGE BELL / DISTRACT", "position": center + Vector2(0, -24), "used": false},
			{"kind": "supplies", "label": "SEARCH OLD WELL / SUPPLIES", "position": center + Vector2(0, 48), "used": false}
		]
	elif definition["kind"] == "bog":
		actions = [{"kind": "cauldron", "label": "SIP CAULDRON / CHARGE LIGHT + HEX", "position": center, "used": false}]
	elif definition["kind"] == "graveyard":
		actions = [{"kind": "crypt", "label": "SEARCH CRYPT / FLARES", "position": center + Vector2(-32, 32), "used": false}]

	elif definition["kind"] in ["substation", "relay", "logging", "boathouse", "ranger"]:
		actions = []
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
			level.announce("Make room in the belt before searching. G drops a stack.",actor)
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
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var bounds: Rect2 = definition["bounds"]
	var center := bounds.get_center()
	if definition["kind"] in ["logging", "boathouse", "ranger"]:
		FieldEscapeArt.draw_site(self, definition)
	elif definition["kind"] in ["substation", "relay"]:
		RescueArt.draw_site(self, definition)
	elif definition["kind"] == "village":
		# Timber bell frame and a stone well, both used from the open square.
		if PixelArt.draw_standing(self, "bell_frame", center + Vector2(0, -22), 34) and PixelArt.draw_standing(self, "well", center + Vector2(0, 56), 36):
			pass
		else:
			_draw_village_fallback(center)
	elif definition["kind"] == "bog":
		# Murky pools: irregular textured water with reeds at the banks.
		var water := PixelArt.texture("water")
		for index in range(65):
			var at := bounds.position + Vector2(24 + (index * 71) % int(bounds.size.x-48), 24 + (index * 43) % int(bounds.size.y-48))
			if absf(at.x - center.x) < 52:
				continue
			var radius := 20.0 + index % 3 * 4
			var points := PackedVector2Array()
			var uvs := PackedVector2Array()
			for step in range(12):
				var corner := at + Vector2.from_angle(step * TAU / 12) * radius * (0.82 + 0.18 * sin(step * 2.3 + index))
				points.append(corner)
				uvs.append(corner / 64.0)
			draw_colored_polygon(points.duplicate(), Color("1b302d"))
			if water != null:
				var inner := PackedVector2Array()
				for corner in points:
					inner.append(at + (corner - at) * 0.88)
				draw_polygon(inner, PackedColorArray([Color(0.62, 0.78, 0.72)]), PackedVector2Array(Array(inner).map(func(point: Vector2) -> Vector2: return point / 64.0)), water)
			if index % 2 == 0:
				PixelArt.draw_in(self, "decal_weeds", Rect2(at + Vector2(radius * 0.7, -8), Vector2(14, 14)))
			else:
				PixelArt.draw_in(self, "decal_grass_tall", Rect2(at + Vector2(-radius, -6), Vector2(12, 12)))
		# A plank boardwalk keeps the central ritual space readable.
		var walk := Rect2(center + Vector2(-40, -int(bounds.size.y/2)+48), Vector2(80, bounds.size.y - 96))
		draw_rect(Rect2(walk.position + Vector2(3, 4), walk.size), Color(0, 0, 0, 0.35))
		for y in range(int(walk.position.y), int(walk.end.y), 16):
			for x in range(int(walk.position.x), int(walk.end.x), 16):
				if not PixelArt.draw_material(self, "dock_planks", Rect2(x, y, mini(16, int(walk.end.x) - x), mini(16, int(walk.end.y) - y)), Color(0.78, 0.74, 0.66)):
					draw_rect(Rect2(x, y, 16, 16), Color("766443"))
		draw_rect(walk, Color("231d15"), false, 2.0)
		for y in range(int(walk.position.y) + 20, int(walk.end.y), 96):
			for side in [walk.position.x - 1, walk.end.x - 3]:
				draw_rect(Rect2(side, y, 4, 9), Color("3a2e20"))
				draw_rect(Rect2(side, y, 4, 2), Color("8c7552"))
		if not PixelArt.draw_standing(self, "cauldron", center + Vector2(0, 8), 36):
			draw_circle(center + Vector2(0, -12), 19, Color("152c2c"))
			draw_circle(center + Vector2(0, -15), 13, Color("6b9861"))
	elif definition["kind"] == "graveyard":
		# Crooked headstones, broken iron fences and a searchable stone crypt.
		for index in range(24):
			var row := index / 6
			var at := bounds.position + Vector2(64 + index % 6 * (bounds.size.x-128)/5, 64 + row * (bounds.size.y-128)/3)
			if not PixelArt.draw_standing(self, "gravestone" if index % 3 else "grave_cross", at + Vector2(7, 23), 17):
				draw_rect(Rect2(at, Vector2(15, 23)), Color("6f8178"))
		for x in range(int(bounds.position.x) + 12, int(bounds.end.x) - 12, 12):
			draw_line(Vector2(x, bounds.position.y + 8), Vector2(x, bounds.position.y + 26 + x % 3 * 3), Color("536b68"), 2)
		if not PixelArt.draw_in(self, "crypt", Rect2(center + Vector2(-60, -30), Vector2(56, 52))):
			draw_rect(Rect2(center + Vector2(-57, -26), Vector2(51, 44)), Color("65766e"))
	else:
		_draw_landmark(bounds, center)
	for action in actions:
		if action["used"]:
			draw_string(ThemeDB.fallback_font, action["position"] + Vector2(-12, 10), "EMPTY", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("8b9b80"))
	# One owner for the region title, with a dark outline so it reads on any floor.
	draw_string_outline(ThemeDB.fallback_font, bounds.position + Vector2(8, bounds.size.y - 10), definition["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0.02, 0.03, 0.03, 0.85))
	draw_string(ThemeDB.fallback_font, bounds.position + Vector2(8, bounds.size.y - 10), definition["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("cbbc8e"))


func center_hash() -> int:
	return int(definition["cell"].x + definition["cell"].y)

## Seamless SpriteCook floor per landmark (procedural colour as fallback).
const FLOORS := {"mill": "mossy_flagstones", "orchard": "orchard_soil", "observatory": "court_tiles", "rail": "quarry_gravel", "quarry": "quarry_gravel", "chapel": "mossy_flagstones"}
## Ground dressing sprites per landmark: [sprite, width].
const DRESSING := {"orchard": [["apple_tree", 46]], "mill": [["mossy_log", 40], ["barrel", 14]], "rail": [["tire_stack", 26], ["drum_side", 26], ["crates", 30]],
	"observatory": [["glow_mushrooms", 20], ["decal_mossy_stone", 18]], "quarry": [["boulder", 30], ["decal_pebbles", 18]], "chapel": [["gravestone", 16], ["grave_cross", 16]]}

func _draw_landmark(bounds: Rect2, center: Vector2) -> void:
	var kind: String = definition["kind"]
	var palettes := {"mill":"4f6661", "orchard":"46583b", "observatory":"414b62", "rail":"66584c", "quarry":"68736d", "chapel":"465763"}
	if PixelArt.texture(FLOORS[kind]) != null:
		for y in range(int(bounds.position.y), int(bounds.end.y), 16):
			for x in range(int(bounds.position.x), int(bounds.end.x), 16):
				PixelArt.draw_material(self, FLOORS[kind], Rect2(x, y, mini(16, int(bounds.end.x) - x), mini(16, int(bounds.end.y) - y)), Color(0.86, 0.86, 0.86))
	else:
		draw_rect(bounds, Color(palettes[kind]))
	# Walkable dressing, no decorative prop changes collision or hides a route.
	_draw_biome_floor(kind, bounds, center)
	var options: Array = DRESSING[kind]
	for index in range(16):
		var at := bounds.position + Vector2(80 + index%4 * (bounds.size.x-160)/3, 80 + index/4 * (bounds.size.y-160)/3)
		if at.distance_to(center) < 100:
			continue
		var pick: Array = options[posmod(index * 7 + center_hash(), options.size())]
		draw_circle(at + Vector2(0, 8), pick[1] * 0.4, Color(0.03, 0.06, 0.06, 0.32))
		if pick[0] == "boulder":
			draw_texture(preload("res://assets/sprites/boulder.png"), at - Vector2(16, 24))
		elif not PixelArt.draw_standing(self, pick[0], at + Vector2(0, 10), pick[1]):
			draw_circle(at, 8, Color("566b58"))
	if not _draw_centerpiece_sprite(kind, center + Vector2(0,-95)):
		_draw_centerpiece(kind, center + Vector2(0,-95))
	# Central reward altar is visually distinct from surrounding dressing.
	if not PixelArt.draw_standing(self, "altar", center + Vector2(0, 12), 26):
		draw_rect(Rect2(center-Vector2(16,12),Vector2(32,24)), Color("242f32"))
		draw_circle(center,4,Color("e2d4a2"))
	# The painted hint goes once the landmark has been searched ("EMPTY" replaces it).
	if not actions.any(func(action: Dictionary) -> bool: return action["used"]):
		draw_string(ThemeDB.fallback_font, center+Vector2(-40,28), "E / RARE TOOL", HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("d9c799"))


func _draw_biome_floor(kind: String, bounds: Rect2, center: Vector2) -> void:
	# Inlaid tracks, channels and rows are walkable; geometry stays truthful.
	if kind == "rail":
		for offset in [-105,105]:
			for y in range(int(bounds.position.y),int(bounds.end.y),12):
				draw_rect(Rect2(center.x+offset-27,y,54,5),Color("2b2622"))
				draw_line(Vector2(center.x+offset-27,y),Vector2(center.x+offset+27,y),Color("4a3f35"))
			for x in [-19,19]:
				draw_line(Vector2(center.x+offset+x,bounds.position.y),Vector2(center.x+offset+x,bounds.end.y),Color("3a3a36"),3)
				draw_line(Vector2(center.x+offset+x,bounds.position.y),Vector2(center.x+offset+x,bounds.end.y),Color("b8bcae"),1)
	elif kind == "mill":
		for offset in [-105,105]:
			var channel := Rect2(center.x+offset-22,bounds.position.y,44,bounds.size.y)
			for y in range(int(channel.position.y), int(channel.end.y), 16):
				if not PixelArt.draw_material(self, "water", Rect2(channel.position.x, y, 44, mini(16, int(channel.end.y) - y))):
					draw_rect(Rect2(channel.position.x, y, 44, 16), Color("254445"))
			draw_line(Vector2(channel.position.x, channel.position.y), Vector2(channel.position.x, channel.end.y), Color("1d2a28"), 2)
			draw_line(Vector2(channel.end.x, channel.position.y), Vector2(channel.end.x, channel.end.y), Color("1d2a28"), 2)
		for y in [-45,65]:
			var deck := Rect2(center + Vector2(-150, y), Vector2(306, 36))
			for x in range(int(deck.position.x), int(deck.end.x), 16):
				if not PixelArt.draw_material(self, "dock_planks", Rect2(x, deck.position.y, mini(16, int(deck.end.x) - x), 36)):
					draw_rect(Rect2(x, deck.position.y, 16, 36), Color("8b7857"))
			draw_rect(deck, Color("2c2419"), false, 1.0)
	elif kind == "orchard":
		for offset in [-160,160]:
			for y in range(int(bounds.position.y)+32,int(bounds.end.y)-32,64):
				if not PixelArt.draw_standing(self, "trellis", Vector2(center.x+offset, y + 14), 64):
					draw_line(Vector2(center.x+offset-32, y),Vector2(center.x+offset+32, y),Color("aa9a70"))

## SpriteCook landmark pieces; false keeps the procedural centrepiece.
func _draw_centerpiece_sprite(kind: String, at: Vector2) -> bool:
	match kind:
		"mill":
			return PixelArt.draw_standing(self, "waterwheel", at + Vector2(0, 40), 84)
		"observatory":
			return PixelArt.draw_standing(self, "observatory", at + Vector2(0, 40), 64)
		"rail":
			var left := PixelArt.draw_standing(self, "rail_signal", at + Vector2(-40, 36), 22)
			return PixelArt.draw_standing(self, "rail_signal", at + Vector2(40, 36), 22) and left
		"chapel":
			PixelArt.draw_standing(self, "column", at + Vector2(-44, 36), 24)
			PixelArt.draw_standing(self, "column", at + Vector2(44, 36), 24)
			return PixelArt.draw_standing(self, "shrine", at + Vector2(0, 40), 40)
		"quarry":
			# Off to the west: the Signal Fire pyre stands on the north rim.
			PixelArt.draw_standing(self, "boulder", at + Vector2(-96, 44), 30)
			return PixelArt.draw_standing(self, "cave", at + Vector2(-140, 40), 72)
		"orchard":
			PixelArt.draw_standing(self, "apple_tree", at + Vector2(-46, 30), 56)
			PixelArt.draw_standing(self, "trellis", at + Vector2(30, 34), 70)
			return PixelArt.draw_standing(self, "apple_tree", at + Vector2(92, 30), 50)
	return false


func _draw_village_fallback(center: Vector2) -> void:
	for x in [-12, 11]:
		draw_rect(Rect2(center + Vector2(x, -63), Vector2(4, 38)), Color("887149"))
	draw_rect(Rect2(center + Vector2(-14, -64), Vector2(30, 5)), Color("b19563"))
	draw_circle(center + Vector2(0, 35), 19, Color("8c9583"))
	draw_circle(center + Vector2(0, 32), 13, Color("1a3030"))


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
