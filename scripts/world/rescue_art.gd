class_name RescueArt
extends RefCounted
## Matching F5 SpriteCook props on the existing native material floors.

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


static func draw_substation(canvas: Node2D, center: Vector2, actionable: bool = true) -> void:
	for x in [-112,112]:
		PixelArt.draw_standing(canvas,"f5_transformer",center+Vector2(x,12),72)
		canvas.draw_line(center+Vector2(x,-55),center+Vector2(0,-110),Color("3f5042"),2)
	PixelArt.draw_standing(canvas,"f5_breaker",center+Vector2(0,32),46)
	if actionable:
		canvas.draw_string(ThemeDB.fallback_font,center+Vector2(-51,84),"E / EMERGENCY POWER",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("dfc99b"))


static func draw_relay(canvas: Node2D, center: Vector2, actionable: bool = true) -> void:
	PixelArt.draw_standing(canvas,"f5_relay",center+Vector2(0,34),76,218)
	PixelArt.draw_standing(canvas,"f5_breaker",center+Vector2(0,40),30)
	if actionable:
		canvas.draw_string(ThemeDB.fallback_font,center+Vector2(-55,92),"E / CLIMB AND TRANSMIT",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("dfc99b"))
