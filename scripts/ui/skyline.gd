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
	var to_screen := get_viewport().get_canvas_transform()
	var view := get_viewport_rect().size
	var from: Vector2 = level.player.global_position
	if level.plan.expedition and CampMap.is_woods(from):
		for beacon in beacons(level.plan, from):
			var label := beacon_label(level, beacon)
			_marker(to_screen * beacon["position"], view, beacon["kind"], label, Color("f0c27a") if label != beacon["label"] else Color("d8cfa4"))
	for ping: Dictionary in level.help_pings:
		if int(ping["remaining"] * 4) % 2 == 0:
			_marker(to_screen * ping["position"], view, "help", "HELP " + ping["name"], Color("e0705a"))
	# Nearby pins collapse into one marker so an edge never stacks unreadable labels.
	var drawn: Array[Vector2] = []
	for index in range(level.pins.size() - 1, -1, -1):
		var pin: Dictionary = level.pins[index]
		var at := edge_point(to_screen * pin["position"], view)
		if drawn.any(func(other: Vector2) -> bool: return other.distance_to(at) < 22):
			continue
		drawn.append(at)
		_marker(to_screen * pin["position"], view, "pin", pin["name"], PIN_COLORS[int(pin["slot"]) % PIN_COLORS.size()])


func _marker(point: Vector2, view: Vector2, kind: String, label: String, color: Color) -> void:
	var at := edge_point(point, view).round()
	var faded := Color(color, 0.85 if at == point.round() else 0.65)
	_icon(at, kind, faded)
	var width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
	var text_at := Vector2(clampf(at.x - width * 0.5, 2, view.x - width - 2), at.y + 11)
	draw_string(ThemeDB.fallback_font, text_at + Vector2.ONE, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0, 0, 0, 0.7))
	draw_string(ThemeDB.fallback_font, text_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, faded)


func _icon(at: Vector2, kind: String, color: Color) -> void:
	var dark := Color(0.04, 0.06, 0.06, 0.75)
	draw_circle(at, 6, dark)
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
