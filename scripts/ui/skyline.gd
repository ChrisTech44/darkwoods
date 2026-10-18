class_name Skyline
extends Control
## Tall landmarks and team pins drawn above the canopy. Direction only: no trails or creatures.

const RANGE := 2400.0
const MAX_LANDMARKS := 4
const EDGE := Rect2(10, 38, 364, 94)
const PIN_COLORS: Array[Color] = [Color("9ee3d7"), Color("f0c27a"), Color("d79ad6"), Color("b5dd86")]
var level: Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


## Bounded landmark list for the current player: camp plus the nearest tall regions.
static func beacons(plan: RoundPlan, from: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"kind": "camp", "label": "CAMP", "position": Vector2(168, 336)}]
	var nearby: Array[Dictionary] = []
	for zone in plan.woods.zones:
		if from.distance_to(zone["position"]) <= RANGE and not zone["bounds"].grow(32).has_point(from):
			nearby.append({"kind": zone["kind"], "label": WoodsLayout.SIGN_NAMES[zone["kind"]], "position": zone["position"]})
	nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return from.distance_to(a["position"]) < from.distance_to(b["position"]))
	result.append_array(nearby.slice(0, MAX_LANDMARKS))
	return result


## Regions the team knows hold a missing part show its name on the marker.
static func beacon_label(level: Node2D, beacon: Dictionary) -> String:
	var label: String = beacon["label"]
	if beacon["kind"] == "chapel" and level.rescue.transmitted:
		label += " · RESCUE"
	for kind: String in level.clues:
		var zone: Dictionary = level.plan.woods.zones[level.plan.cache_zone[kind]]
		if zone["kind"] == beacon["kind"] and level.clues[kind] >= 1 and kind not in level.van.installed:
			label += " · " + kind.replace("_", " ").to_upper()
	return label


## Clamp a screen point to the HUD-safe edge band along the ray from the view centre.
static func edge_point(point: Vector2, view: Vector2) -> Vector2:
	var middle := view * 0.5
	if EDGE.has_point(point):
		return point
	var offset := point - middle
	var factor := INF
	if offset.x != 0:
		factor = minf(factor, ((EDGE.end.x if offset.x > 0 else EDGE.position.x) - middle.x) / offset.x)
	if offset.y != 0:
		factor = minf(factor, ((EDGE.end.y if offset.y > 0 else EDGE.position.y) - middle.y) / offset.y)
	return middle + offset * factor


func _draw() -> void:
	if level == null or level.finished or not is_instance_valid(level.player):
		return
	# World bearings would sit under the open notebook: hide them there.
	if level.hud != null and level.hud.notebook.visible:
		return
	var to_screen := get_viewport().get_canvas_transform()
	var view := get_viewport_rect().size
	var from: Vector2 = level.player.global_position
	var markers: Array[Dictionary] = []
	for ping: Dictionary in level.help_pings:
		if int(ping["remaining"] * 4) % 2 == 0:
			markers.append({"point": to_screen * ping["position"], "kind": "help", "label": "HELP " + ping["name"], "color": Color("e0705a"), "priority": 0})
	if level.plan.expedition and CampMap.is_woods(from):
		for beacon in beacons(level.plan, from):
			var label := beacon_label(level, beacon)
			var tracked: bool = label != beacon["label"]
			markers.append({"point": to_screen * beacon["position"], "kind": beacon["kind"], "label": label, "color": Color("f0c27a") if tracked else Color("d8cfa4"), "priority": 1 if tracked else 3})
	# Building names, readable at night: anchored on the door plaque, only near a
	# door you can actually see (walls block it), never from inside.
	for building: CampBuilding in level.camp_map.buildings + level.camp_map.forest_buildings:
		var board := building.plaque_rect()
		var threshold := building.door + Vector2(0, 14)
		if from.distance_to(board.get_center()) < 130.0 and not building.bounds.grow(4).has_point(from) and level.clear_path(from, threshold):
			markers.append({"point": to_screen * board.get_center(), "kind": "plaque", "label": building.label, "color": Color("f0dca3"), "priority": 1})
	for index in range(level.pins.size() - 1, -1, -1):
		var pin: Dictionary = level.pins[index]
		markers.append({"point": to_screen * pin["position"], "kind": "pin", "label": pin["name"], "color": PIN_COLORS[int(pin["slot"]) % PIN_COLORS.size()], "priority": 2})
	var blocked: Array[Rect2] = []
	if level.hud != null and level.hud.broadcast.place_box().has_area():
		blocked.append(level.hud.broadcast.place_box())
	for marker in layout(markers, view, blocked):
		_marker(marker)


## One collision pass for every skyline marker. Higher priority first (help,
## tracked objective, pins, plain landmarks). An icon landing on a placed icon
## merges into it as "+N". Labels try below, above (never into the top HUD
## band), then further below; plain landmarks that find no room keep their icon
## only. Directions are preserved: icons stay on their bearing.
static func layout(markers: Array[Dictionary], view: Vector2, blocked: Array[Rect2] = []) -> Array[Dictionary]:
	var ordered := markers.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["priority"] < b["priority"])
	var placed: Array[Dictionary] = []
	var font := ThemeDB.fallback_font
	for marker: Dictionary in ordered:
		var at := edge_point(marker["point"], view).round()
		if marker["kind"] == "plaque":
			# Door names sit on their plaque: never clamped to an edge or merged.
			if not Rect2(Vector2.ZERO, view).has_point(marker["point"]):
				continue
			marker = marker.duplicate()
			marker["at"] = Vector2(marker["point"]).round()
			marker["extra"] = 0
			marker["onscreen"] = true
			placed.append(marker)
			continue
		var merged := false
		for other in placed:
			if other["at"].distance_to(at) < 14.0:
				other["extra"] += 1
				merged = true
				break
		if merged:
			continue
		marker = marker.duplicate()
		marker["at"] = at
		marker["extra"] = 0
		marker["onscreen"] = at == Vector2(marker["point"]).round()
		placed.append(marker)
	var labels: Array[Rect2] = []
	var icons: Array[Rect2] = []
	for marker in placed:
		if marker["kind"] != "plaque":
			icons.append(Rect2(marker["at"] - Vector2(8, 8), Vector2(16, 16)))
	for marker in placed:
		var text: String = marker["label"] + ("  +%d" % marker["extra"] if marker["extra"] > 0 else "")
		marker["text"] = text
		marker["size"] = 7 if marker["kind"] == "plaque" else 6
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, marker["size"]).x + 4.0
		var at: Vector2 = marker["at"]
		var candidates: Array[float] = [at.y + 9.0, at.y - 19.0, at.y + 17.0]
		if marker["kind"] == "plaque":
			candidates = [at.y - 4.0, at.y - 14.0, at.y + 7.0]
		marker["label_rect"] = Rect2()
		for top in candidates:
			var rect := Rect2(clampf(at.x - width * 0.5, 2.0, view.x - width - 2.0), top, width, marker["size"] + 2.0)
			if rect.position.y < EDGE.position.y - 2.0 or rect.end.y > EDGE.end.y + 22.0:
				continue
			var own := Rect2(at - Vector2(8, 8), Vector2(16, 16))
			if labels.any(func(other: Rect2) -> bool: return other.intersects(rect)) or blocked.any(func(other: Rect2) -> bool: return other.intersects(rect)) or icons.any(func(other: Rect2) -> bool: return other != own and other.intersects(rect)):
				continue
			marker["label_rect"] = rect
			break
		if not marker["label_rect"].has_area() and marker["priority"] < 3:
			# Must-read markers (help, objectives, pins) keep a label regardless.
			marker["label_rect"] = Rect2(clampf(at.x - width * 0.5, 2.0, view.x - width - 2.0), at.y + 9.0, width, 8.0)
		if marker["label_rect"].has_area():
			labels.append(marker["label_rect"])
	return placed


func _marker(marker: Dictionary) -> void:
	var color: Color = marker["color"]
	var faded := Color(color, 0.85 if marker["onscreen"] else 0.65)
	if marker["kind"] != "plaque":
		_icon(marker["at"], marker["kind"], faded)
	var rect: Rect2 = marker["label_rect"]
	if not rect.has_area():
		return
	draw_rect(rect, Color(0.03, 0.05, 0.05, 0.55))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(2, marker["size"] + 1), marker["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, marker["size"], faded)


## SpriteCook icon per marker kind (skyline sheet, effects sheet or landmark art).
const ICONS := {"camp": "sky_campfire", "help": "fx_help", "pin": "fx_pin", "village": "sky_bell", "observatory": "sky_dome",
	"bog": "sky_bog", "relay": "sky_mast", "substation": "f5_transformer", "rail": "sky_signal", "ranger": "ui_badge",
	"logging": "f5_logs", "boathouse": "f5_boathouse", "graveyard": "gravestone", "mill": "waterwheel", "orchard": "apple_tree",
	"quarry": "cave", "chapel": "shrine"}

func _icon(at: Vector2, kind: String, color: Color) -> void:
	var dark := Color(0.04, 0.06, 0.06, 0.75)
	draw_circle(at, 7, dark)
	draw_arc(at, 7, 0.0, TAU, 16, Color(color, 0.7), 1.0)
	if ICONS.has(kind) and PixelArt.draw_in(self, ICONS[kind], Rect2(at - Vector2(6, 6), Vector2(12, 12)), Color(1, 1, 1, color.a)):
		return
	match kind:
		"camp":
			draw_colored_polygon(PackedVector2Array([at + Vector2(-3, 3), at + Vector2(0, -5), at + Vector2(3, 3)]), Color("e9a65f"))
		"help":
			draw_rect(Rect2(at + Vector2(-1, -4), Vector2(3, 9)), color)
			draw_rect(Rect2(at + Vector2(-4, -1), Vector2(9, 3)), color)
		"pin":
			draw_line(at + Vector2(-2, 4), at + Vector2(-2, -5), color, 1)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-2, -5), at + Vector2(4, -3), at + Vector2(-2, -1)]), color)
		"logging":
			draw_rect(Rect2(at+Vector2(-4,-2),Vector2(8,5)),color)
			draw_line(at+Vector2(-2,-5),at+Vector2(3,4),Color("c5b68c"),2)
		"boathouse":
			draw_arc(at,4,0,PI,12,color,2)
			draw_line(at+Vector2(-4,0),at+Vector2(4,0),color)
		"ranger":
			draw_line(at+Vector2(-4,4),at+Vector2(-4,-3),color,2)
			draw_line(at+Vector2(4,4),at+Vector2(4,-3),color,2)
			draw_line(at+Vector2(-4,-3),at+Vector2(4,-3),color,2)
		"relay":
			draw_line(at + Vector2(-3, 4), at + Vector2(0, -5), color)
			draw_line(at + Vector2(3, 4), at + Vector2(0, -5), color)
			draw_arc(at + Vector2(0, -4), 4, PI, TAU, 8, color)
		"substation":
			draw_line(at + Vector2(2, -5), at + Vector2(-2, 0), color, 2)
			draw_line(at + Vector2(-2, 0), at + Vector2(2, 0), color, 2)
			draw_line(at + Vector2(2, 0), at + Vector2(-2, 5), color, 2)
		"village":
			draw_rect(Rect2(at + Vector2(-2, -1), Vector2(4, 5)), color)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-3, -1), at + Vector2(0, -5), at + Vector2(3, -1)]), color)
		"bog":
			draw_circle(at, 3, Color("a0c876"))
		"graveyard":
			draw_line(at + Vector2(0, -5), at + Vector2(0, 4), color, 2)
			draw_line(at + Vector2(-3, -2), at + Vector2(3, -2), color, 2)
		"mill":
			draw_arc(at, 4, 0, TAU, 12, color, 1)
			draw_line(at + Vector2(-4, 0), at + Vector2(4, 0), color)
			draw_line(at + Vector2(0, -4), at + Vector2(0, 4), color)
		"orchard":
			draw_circle(at + Vector2(0, -1), 3, color)
			draw_line(at + Vector2(0, 1), at + Vector2(0, 5), color, 1)
		"observatory":
			draw_arc(at + Vector2(0, 2), 4, PI, TAU, 10, color, 2)
			draw_line(at + Vector2(0, -2), at + Vector2(3, -5), color, 1)
		"rail":
			draw_line(at + Vector2(0, 5), at + Vector2(0, -3), color, 1)
			draw_circle(at + Vector2(0, -3), 2, Color("e07a5f"))
		"quarry":
			draw_colored_polygon(PackedVector2Array([at + Vector2(-4, 4), at + Vector2(-1, -4), at + Vector2(4, 4)]), color)
		"chapel":
			draw_colored_polygon(PackedVector2Array([at + Vector2(-2, 4), at + Vector2(0, -3), at + Vector2(2, 4)]), color)
			draw_line(at + Vector2(0, -5), at + Vector2(0, -2), color)
