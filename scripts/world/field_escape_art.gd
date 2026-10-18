class_name FieldEscapeArt
extends RefCounted
## Cohesive compositions built from the project's original SpriteCook prop library.

static func water_rects(center: Vector2) -> Array[Rect2]:
	return [Rect2(center+Vector2(-300,-300),Vector2(252,270)),Rect2(center+Vector2(48,-300),Vector2(252,270)),Rect2(center+Vector2(-48,-300),Vector2(96,60))]

static func draw_site(canvas: Node2D, zone: Dictionary) -> void:
	var bounds: Rect2 = zone["bounds"]
	var center: Vector2 = zone["position"]
	var kind: String = zone["kind"]
	canvas.draw_rect(bounds,Color("354c3e") if kind=="logging" else Color("334e4b"))
	for y in range(int(bounds.position.y),int(bounds.end.y),16):
		for x in range(int(bounds.position.x),int(bounds.end.x),16):
			var at := Vector2(x,y)
			var ground := "forest_floor" if kind=="logging" else "leaf_litter"
			if not PixelArt.draw_material(canvas,ground,Rect2(at,Vector2(16,16)),Color("b3b69b") if kind=="logging" else Color(0.82,0.84,0.8)):
				PixelArt.draw_material(canvas,"road",Rect2(at,Vector2(16,16)),Color("828f7b"))
	if kind=="logging":
		for side in [-1,1]:
			for index in range(4):
				var at := center+Vector2(side*180,-180+index*115)
				PixelArt.draw_standing(canvas,"f5_logs",at,76)
				PixelArt.draw_standing(canvas,"stump",at+Vector2(side*50,28),25)
		for index in range(35):
			var at := center+Vector2(posmod(index*97,400)-200,posmod(index*61,380)-190)
			canvas.draw_line(at,at+Vector2(3,1),Color("b99d68"))
		PixelArt.draw_standing(canvas,"workbench",center+Vector2(110,60),65)
		PixelArt.draw_standing(canvas,"toolbox",center+Vector2(112,14),22)
	elif kind=="boathouse":
		# The lake itself is a LakeWater child (animated shader); here only a muddy bank.
		for rect in water_rects(center):
			canvas.draw_rect(rect.grow(5),Color("2b2a1f"))
		# Launch dock: weathered SpriteCook planks with a dark edge and drop shadow.
		var dock := Rect2(center+Vector2(-46,-238),Vector2(92,338))
		canvas.draw_rect(Rect2(dock.position+Vector2(3,4),dock.size),Color(0,0,0,0.35))
		for y in range(int(dock.position.y),int(dock.end.y),16):
			for x in range(int(dock.position.x),int(dock.end.x),16):
				if not PixelArt.draw_material(canvas,"dock_planks",Rect2(x,y,mini(16,int(dock.end.x)-x),mini(16,int(dock.end.y)-y)),Color(0.92,0.9,0.86)):
					canvas.draw_rect(Rect2(x,y,16,16),Color("9e8962"))
		canvas.draw_rect(dock,Color("2a2219"),false,2.0)
		PixelArt.draw_standing(canvas,"f5_pier",center+Vector2(0,80),90)
		for x in [-49,46]:
			for y in [-216,-120,-24,72]:
				canvas.draw_rect(Rect2(center+Vector2(x-3,y-6),Vector2(7,17)),Color("564a37"))
				canvas.draw_circle(center+Vector2(x,y-6),4,Color("b5a17b"))
		PixelArt.draw_standing(canvas,"canoe_rack",center+Vector2(-166,135),110)
		PixelArt.draw_standing(canvas,"barrel",center+Vector2(148,123),30)
		PixelArt.draw_standing(canvas,"barrel",center+Vector2(180,137),29)
	else:
		# Floodlit road and traversable wooden evacuation bridge, with clear shoulders.
		var road := Rect2(center+Vector2(-72,-650),Vector2(144,1260))
		for y in range(int(road.position.y),int(road.end.y),16):
			for x in range(int(road.position.x),int(road.end.x),16):
				if not PixelArt.draw_material(canvas,"asphalt",Rect2(x,y,mini(16,int(road.end.x)-x),16),Color(0.86,0.86,0.84)):
					canvas.draw_rect(Rect2(x,y,16,16),Color("6d6c54"))
		# Crumbling shoulders and a faded centre line.
		for side in [-1,1]:
			canvas.draw_line(center+Vector2(side*72,-650),center+Vector2(side*72,610),Color(0.1,0.12,0.1,0.8),3)
			canvas.draw_line(center+Vector2(side*64,-650),center+Vector2(side*64,610),Color(0.78,0.74,0.6,0.35),1)
		for y in range(-620,620,28):
			canvas.draw_rect(Rect2(center+Vector2(-2,y),Vector2(3,13)),Color(0.82,0.74,0.5,0.55))
		for y in range(-582,-420,7):
			canvas.draw_rect(Rect2(center+Vector2(-63,y),Vector2(126,5)),Color("9b8d6b"))
		PixelArt.draw_standing(canvas,"f5_bridge",center+Vector2(0,-460),145)
		for x in [-67,67]:
			canvas.draw_line(center+Vector2(x,-590),center+Vector2(x,-415),Color("c4b88b"),3)
			for y in range(-585,-410,28):
				canvas.draw_rect(Rect2(center+Vector2(x-2,y-10),Vector2(4,18)),Color("7e927d"))
		for index in range(5):
			PixelArt.draw_standing(canvas,"lamp_post",center+Vector2(70 if index%2==0 else -70,-500+index*200),25)
		for side in [-1,1]:
			for index in range(7):
				PixelArt.draw_standing(canvas,"shrub",center+Vector2(side*170,-560+index*170),30)
	# The region title is drawn once, by ForestSite (it used to be drawn here too, 4px off).

## `motor_waiting`: the boat route is on tonight and its motor still lies at the camp.
static func draw_structure(canvas: Node2D, zone: Dictionary, powered: bool, opened: bool, pulse: float, motor_waiting: bool = false) -> void:
	var center: Vector2 = zone["position"]
	match zone["kind"]:
		"logging":
			PixelArt.draw_standing(canvas,"f5_logging",center+Vector2(0,-65),145)
			PixelArt.draw_standing(canvas,"waterwheel",center+Vector2(130,-80),72)
			PixelArt.draw_standing(canvas,"scrap_pile",center+Vector2(-115,-70),64)
			if motor_waiting:
				canvas.draw_string(ThemeDB.fallback_font,center+Vector2(-48,78),"MOTOR / HEAVY CARRY",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("e3c993"))
		"boathouse":
			# A weathered raised timber shelter, with matching canoe racks and supply props.
			PixelArt.draw_standing(canvas,"f5_boathouse",center+Vector2(170,80),130)
			PixelArt.draw_standing(canvas,"canoe_rack",center+Vector2(184,124),85)
			PixelArt.draw_standing(canvas,"rail_signal",center+Vector2(-104,65),25)
		"ranger":
			var at := center+Vector2(0,500)
			PixelArt.draw_standing(canvas,"f5_ranger_booth",at+Vector2(180,-32),100)
			PixelArt.draw_standing(canvas,"f5_breaker",at+Vector2(-116,13),32)
			for side in [-1,1]:
				PixelArt.draw_standing(canvas,"rail_signal",at+Vector2(side*88,-24),28)
				# SpriteCook floodlight posts; the lamp glows when the circuit is live.
				if PixelArt.draw_standing(canvas,"lamp_post",at+Vector2(side*105,-20),18,80):
					if powered:
						canvas.draw_circle(at+Vector2(side*105,-86),6,Color(1.0,0.9,0.6,0.55))
				else:
					canvas.draw_line(at+Vector2(side*105,-24),at+Vector2(side*105,-93),Color("879d89"),4)
					canvas.draw_rect(Rect2(at+Vector2(side*105-12,-96),Vector2(24,9)),Color("ead8a1") if powered else Color("506b65"))
				if powered and int(pulse*3)%2==0:
					canvas.draw_circle(at+Vector2(side*88,-65),4,Color("e5ab6f"))
			if not opened:
				PixelArt.draw_standing(canvas,"f5_gate",at+Vector2(0,-12),166)
			elif PixelArt.draw_standing(canvas,"barrier_raised",at+Vector2(-62,-14),44):
				pass
			else:
				var start := at+Vector2(-78,-28)
				var end := start+Vector2(12,-120)
				canvas.draw_line(start,end,Color("273b36"),8)
				canvas.draw_line(start,end,Color("ceb67b"),5)
				for index in range(10):
					var point := start.lerp(end,float(index)/10)
					canvas.draw_line(point,point+(end-start).normalized()*7,Color("9a5d44"),5)
			canvas.draw_string(ThemeDB.fallback_font,at+Vector2(-45,64),"RANGER ROAD / NORTH",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("e3c993"))

static func draw_boat(canvas: Node2D, at: Vector2, installed: Array[String], started: bool, pulse: float) -> void:
	var hull := at+Vector2(0,-38 + sin(pulse*1.8)*1.5)
	PixelArt.draw_standing(canvas,"f5_boat" if "outboard_motor" in installed else "canoe",hull,86)
	for index in range(3):
		canvas.draw_circle(at+Vector2(-9+index*9,-12),2,Color("dfcc8d") if index<installed.size() else Color("314b44"))
	if started:
		for index in range(5):
			canvas.draw_arc(hull+Vector2(0,18),12+fmod(pulse*18+index*8,40),0,PI,20,Color("749f96"))

static func draw_lake_thing(canvas: Node2D, at: Vector2, striking: bool) -> void:
	PixelArt.draw_standing(canvas,"f5_lake_thing",at+Vector2(0,20),58 if striking else 48)
