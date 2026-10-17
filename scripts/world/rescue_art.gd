class_name RescueArt
extends RefCounted
## Original pixel geometry over the existing SpriteCook materials. No new credits.

static func draw_site(canvas: Node2D, definition: Dictionary) -> void:
	var bounds: Rect2 = definition["bounds"]
	var center: Vector2 = definition["position"]
	var power: bool = definition["kind"] == "substation"
	canvas.draw_rect(bounds, Color("374744") if power else Color("394a4d"))
	for y in range(int(bounds.position.y), int(bounds.end.y), 16):
		for x in range(int(bounds.position.x), int(bounds.end.x), 16):
			var at := Vector2(x, y)
			if not PixelArt.draw_material(canvas, "road", Rect2(at, Vector2(16,16)), Color("798b80")):
				canvas.draw_rect(Rect2(at + Vector2.ONE, Vector2(14,14)), Color("4d5b52"))
	# Border bollards with wide gaps on all four approaches; never imply a solid fence.
	for index in range(12):
		for side in [-1,1]:
			var offset := -bounds.size.x * 0.5 + 24 + index * (bounds.size.x - 48) / 11
			if absf(offset) < 90:
				continue
			var at := center + Vector2(offset, side * (bounds.size.y * 0.5 - 16))
			canvas.draw_rect(Rect2(at + Vector2(-3,-12),Vector2(6,16)),Color("927d59"))
			canvas.draw_rect(Rect2(at + Vector2(-3,-12),Vector2(6,3)),Color("d4bd82"))
	# Service walk, cable conduits and weathered drainage grates.
	for x in [-58,58]:
		canvas.draw_line(center + Vector2(x,-170),center + Vector2(x,150),Color("252f2d"),3)
		canvas.draw_line(center + Vector2(x+2,-170),center + Vector2(x+2,150),Color("a19670"))
	for side in [-1,1]:
		for index in range(5):
			var at := center + Vector2(side * 180,-180 + index*86)
			PixelArt.draw_standing(canvas, "shrub" if index % 2 else "boulder", at, 20)
	# Elevated machinery is drawn by rescue_structures above the floor sight mask.


static func draw_substation(canvas: Node2D, center: Vector2) -> void:
	for x in [-112,112]:
		var at := center + Vector2(x,-30)
		canvas.draw_rect(Rect2(at + Vector2(-35,-8),Vector2(76,61)),Color("1e302e"))
		canvas.draw_rect(Rect2(at + Vector2(-32,-48),Vector2(64,88)),Color("657c73"))
		canvas.draw_rect(Rect2(at + Vector2(-32,-48),Vector2(64,8)),Color("a5b2a0"))
		canvas.draw_rect(Rect2(at + Vector2(22,-40),Vector2(10,80)),Color("3a514d"))
		for rib in range(9):
			canvas.draw_line(at + Vector2(-28,-29+rib*7),at + Vector2(18,-29+rib*7),Color("293e39"),3)
		for terminal in [-20,0,20]:
			canvas.draw_line(at + Vector2(terminal,-48),at + Vector2(terminal,-73),Color("9f9b7f"),3)
			for y in [-69,-62,-55]:
				canvas.draw_line(at + Vector2(terminal-5,y),at + Vector2(terminal+5,y),Color("cad3bb"),2)
		canvas.draw_line(at + Vector2(-20,-73),center + Vector2(-20,-147),Color("222f2d"),2)
		canvas.draw_line(at + Vector2(20,-73),center + Vector2(20,-147),Color("222f2d"),2)
	# Overhead gantry and insulators.
	for x in [-158,158]:
		canvas.draw_rect(Rect2(center + Vector2(x,-156),Vector2(7,128)),Color("8b9c8c"))
		canvas.draw_line(center + Vector2(x+1,-153),center + Vector2(x+1,-32),Color("c1c7a5"))
	canvas.draw_rect(Rect2(center + Vector2(-158,-156),Vector2(323,8)),Color("809689"))
	for x in range(-140,150,18):
		canvas.draw_line(center + Vector2(x,-154),center + Vector2(x+12,-150),Color("d4c597"))
	# Fuse cabinet faces the unobstructed service walk.
	canvas.draw_rect(Rect2(center + Vector2(-23,-24),Vector2(46,62)),Color("233c38"))
	canvas.draw_rect(Rect2(center + Vector2(-21,-27),Vector2(42,58)),Color("8b9f8b"))
	canvas.draw_rect(Rect2(center + Vector2(-16,-21),Vector2(32,20)),Color("283d39"))
	for index in range(3):
		PixelArt.draw_in(canvas, "fuse", Rect2(center + Vector2(-13+index*9,-18),Vector2(7,14)))
	canvas.draw_rect(Rect2(center + Vector2(-9,7),Vector2(18,14)),Color("d2b56e"))
	canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(2,8),center+Vector2(-4,15),center+Vector2(1,15),center+Vector2(-1,20),center+Vector2(6,12),center+Vector2(1,12)]),Color("3a4133"))
	canvas.draw_string(ThemeDB.fallback_font,center+Vector2(-51,84),"E / EMERGENCY POWER",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("dfc99b"))


static func draw_relay(canvas: Node2D, center: Vector2) -> void:
	# Triangulated mast, guy wires and dish: the base is solid, the apron walkable.
	canvas.draw_circle(center + Vector2(0,-25),48,Color("283d3e"))
	for side in [-1,1]:
		canvas.draw_line(center + Vector2(side*25,-9),center + Vector2(side*5,-176),Color("91aaa4"),5)
		canvas.draw_line(center + Vector2(side*150,35),center + Vector2(side*4,-145),Color("7a8f88"))
		canvas.draw_rect(Rect2(center+Vector2(side*150-4,31),Vector2(8,8)),Color("b3a680"))
	for index in range(8):
		var y := -15-index*20
		var width := 24-index*2
		canvas.draw_line(center+Vector2(-width,y),center+Vector2(width,y-20),Color("6f8b86"),2)
		canvas.draw_line(center+Vector2(width,y),center+Vector2(-width,y-20),Color("a9b6a1"))
	# The ladder leads to the transmitter platform (the hold represents the climb).
	for side in [-1,1]:
		canvas.draw_line(center+Vector2(side*7,10),center+Vector2(side*4,-143),Color("c1b48b"),2)
	for y in range(-138,13,9):
		canvas.draw_line(center+Vector2(-6,y),center+Vector2(6,y),Color("d0c49a"))
	canvas.draw_rect(Rect2(center+Vector2(-25,-84),Vector2(50,7)),Color("d0c3a2"))
	canvas.draw_rect(Rect2(center+Vector2(-27,-99),Vector2(54,2)),Color("7caaa5"))
	for side in [-1,1]:
		canvas.draw_line(center+Vector2(side*26,-99),center+Vector2(side*26,-79),Color("93afa1"),2)
	canvas.draw_circle(center+Vector2(25,-124),19,Color("bcc9b7"))
	canvas.draw_arc(center+Vector2(25,-124),16,-PI/2,PI/2,20,Color("5e7b79"),3)
	canvas.draw_line(center+Vector2(27,-124),center+Vector2(48,-133),Color("9db7b1"),3)
	canvas.draw_circle(center+Vector2(49,-134),3,Color("dfc99b"))
	canvas.draw_line(center+Vector2(0,-175),center+Vector2(0,-196),Color("b9c6b0"),2)
	canvas.draw_circle(center+Vector2(0,-197),3,Color("d57557"))
	# Field radio on a solid low pedestal beside the ladder approach.
	canvas.draw_rect(Rect2(center+Vector2(-22,15),Vector2(44,25)),Color("233a37"))
	canvas.draw_rect(Rect2(center+Vector2(-19,12),Vector2(38,21)),Color("7a8c71"))
	canvas.draw_rect(Rect2(center+Vector2(-15,15),Vector2(19,8)),Color("abc8a7"))
	for x in [9,14]:
		canvas.draw_circle(center+Vector2(x,19),2,Color("203836"))
	for x in range(-14,17,4):
		canvas.draw_line(center+Vector2(x,26),center+Vector2(x,29),Color("30463d"))
	canvas.draw_string(ThemeDB.fallback_font,center+Vector2(-55,92),"E / CLIMB AND TRANSMIT",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("dfc99b"))
