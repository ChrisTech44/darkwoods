extends Control
## Notebook field map. One uniform world-to-map scale (no stretching), a local
## view around you or the whole woods (Z), and live markers: known objective
## items where they actually are now, teammates (downed ones crossed), the van,
## tonight's selected escape destination, pins and help calls. Camp buildings
## and region outlines are printed from the start (Lodge wall map); woods
## trails, and the caches on them, appear only once explored or revealed.

var camp_map: CampMap
var player: CampPlayer
var van: CampVan
var plan: RoundPlan
var level: Node2D
## false: around you (camp map while in camp). true: the whole woods.
var overview := false
## World pixels per map pixel in the local woods view.
const LOCAL_SCALE := 16.0
const TEAM_COLORS: Array[Color] = [Color("f2c46d"), Color("c99cf0"), Color("8fd3a5"), Color("f08f7a")]
const INK := Color("e8dcb2")
const DIM := Color("8f866a")
var window := Rect2()
var factor := 1.0
var offset := Vector2.ZERO
## Region index -> true once the team has walked into it.
var known_zones := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func to_map(point: Vector2) -> Vector2:
	return offset + (point - window.position) * factor


func _fit(view: Rect2) -> void:
	window = view
	factor = minf(size.x / view.size.x, size.y / view.size.y)
	offset = (size - view.size * factor) * 0.5


func _draw() -> void:
	if camp_map == null or player == null or plan == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("17231f"))
	var in_woods := plan.expedition and CampMap.is_woods(player.global_position)
	if overview and plan.expedition:
		_fit(CampMap.WORLD_BOUNDS)
	elif in_woods:
		_fit(Rect2(player.global_position - size * LOCAL_SCALE * 0.5, size * LOCAL_SCALE))
	else:
		_fit(CampMap.CAMP_BOUNDS)
	draw_rect(Rect2(to_map(window.position), window.size * factor), Color("1d2b26"))
	if plan.expedition:
		_draw_woods()
	_draw_camp()
	_draw_markers()
	_draw_labels()


func _draw_woods() -> void:
	for road: Rect2 in plan.woods.roads:
		if road.intersects(window):
			draw_rect(Rect2(to_map(road.position), (road.size * factor).max(Vector2.ONE)), Color("6f6449"))
	for zone in plan.woods.zones:
		var rect: Rect2 = zone["bounds"]
		if rect.intersects(window):
			var area := Rect2(to_map(rect.position), rect.size * factor)
			draw_rect(area, Color("2a3a2e") if _zone_known(zone) else Color("222d26"))
			draw_rect(area, Color("b29c70") if _zone_known(zone) else Color("5d5745"), false)
	var dot := maxf(1.0, factor * 18.0)
	for cell: Vector2i in plan.woods.visited:
		var at: Vector2 = plan.woods.center(cell)
		if not window.grow(200).has_point(at):
			continue
		for next: Vector2i in plan.woods.links[cell]:
			if plan.woods.visited.has(next):
				draw_line(to_map(at), to_map(plan.woods.center(next)), Color("7b8461"), maxf(1.0, factor * 10.0))
		draw_rect(Rect2(to_map(at) - Vector2.ONE * dot * 0.5, Vector2.ONE * dot), Color("8d9670"))


## A region the team has walked into (remembered once true).
func _zone_known(zone: Dictionary) -> bool:
	var index := plan.woods.zones.find(zone)
	if known_zones.has(index):
		return true
	for cell: Vector2i in plan.woods.visited:
		if zone["bounds"].has_point(plan.woods.center(cell)):
			known_zones[index] = true
			return true
	return false


func _draw_camp() -> void:
	if not CampMap.CAMP_BOUNDS.intersects(window):
		return
	draw_rect(Rect2(to_map(CampMap.CAMP_BOUNDS.position), CampMap.CAMP_BOUNDS.size * factor), Color("26342b"))
	for road in camp_map.roads:
		draw_rect(Rect2(to_map(road.position), (road.size * factor).max(Vector2.ONE)), Color("68715b"))
	draw_rect(Rect2(to_map(camp_map.lake.position), camp_map.lake.size * factor), Color("355d63"))
	for building in camp_map.buildings:
		draw_rect(Rect2(to_map(building.bounds.position), (building.bounds.size * factor).max(Vector2.ONE * 2)), Color("a68f68"))
	draw_rect(Rect2(to_map(CampMap.CAMP_BOUNDS.position), CampMap.CAMP_BOUNDS.size * factor), Color("b3b792"), false)


## Route parts for the selected escape page.
func route_parts() -> Array:
	if level == null:
		return plan.required
	match level.current_page():
		"radio": return ["rescue_fuse"]
		"boat": return FieldEscapes.BOAT_PARTS
		"gate": return FieldEscapes.GATE_CODES
		"signal": return SignalFire.PARTS
	return plan.required


## Known, still-lying objective items for the selected route at their live
## positions: {kind, position, dropped}. Hidden caches stay hidden.
func objective_items() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if level == null:
		return found
	var parts := route_parts()
	for index in range(level.pickups.size()):
		var pickup: CampPickup = level.pickups[index]
		if not pickup.available or pickup.kind not in parts:
			continue
		if level.current_page() == "van" and pickup.kind in van.installed:
			continue
		var dropped := index >= plan.loot.size()
		var at := pickup.global_position
		var known := dropped or not CampMap.is_woods(at) or plan.woods.visited.has(plan.woods.cell_at(at)) or int(level.clues.get(pickup.kind, 0)) >= 2
		if known:
			found.append({"kind": pickup.kind, "position": at, "dropped": dropped})
	return found


## Tonight's selected escape destination (printed in the plan already).
func destination() -> Dictionary:
	if level == null or not plan.expedition:
		return {"position": van.global_position, "name": "VAN"}
	match level.current_page():
		"radio": return {"position": level.rescue.landing, "name": "LANDING ZONE"}
		"boat": return {"position": level.escapes.boat_point, "name": "BOAT"}
		"gate": return {"position": level.escapes.gate_point, "name": "RANGER GATE"}
		"signal": return {"position": level.signal_fire.pyre, "name": "SIGNAL PYRE"}
	return {"position": van.global_position, "name": "VAN"}


func teammates() -> Array:
	var others: Array = []
	if player == null:
		return others
	var all: Array = player.get_tree().get_nodes_in_group("survivors")
	all.sort_custom(func(a: CampPlayer, b: CampPlayer) -> bool: return a.name < b.name)
	for index in range(all.size()):
		if all[index] != player and all[index].status in [CampPlayer.Status.ALIVE, CampPlayer.Status.DOWNED]:
			others.append([all[index], TEAM_COLORS[index % TEAM_COLORS.size()]])
	return others


func _draw_markers() -> void:
	var area := Rect2(Vector2.ZERO, size).grow(-3)
	# Escape destination: a diamond, held at the edge when off the map.
	var goal: Dictionary = destination()
	_marker(goal["position"], area, func(at: Vector2) -> void:
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -4), at + Vector2(4, 0), at + Vector2(0, 4), at + Vector2(-4, 0)]), Color("f0dca3"))
		draw_polyline(PackedVector2Array([at + Vector2(0, -4), at + Vector2(4, 0), at + Vector2(0, 4), at + Vector2(-4, 0), at + Vector2(0, -4)]), Color("1a1a12"), 1.0))
	if level != null and level.current_page() != "van":
		var vehicle := to_map(van.global_position)
		if area.has_point(vehicle):
			draw_rect(Rect2(vehicle - Vector2(2, 3), Vector2(4, 6)), Color("cfc6a0"))
	for item in objective_items():
		_marker(item["position"], area, func(at: Vector2) -> void:
			draw_circle(at, 3.0, Color("1b2a26"))
			draw_circle(at, 2.0, Color("f0b85a") if item["dropped"] else Color("f0dca3")))
	if level != null:
		for pin: Dictionary in level.pins:
			var tint: Color = Skyline.PIN_COLORS[int(pin["slot"]) % Skyline.PIN_COLORS.size()]
			var mark := to_map(pin["position"])
			if area.has_point(mark):
				draw_line(mark + Vector2(0, 2), mark + Vector2(0, -5), tint)
				draw_colored_polygon(PackedVector2Array([mark + Vector2(0, -5), mark + Vector2(4, -4), mark + Vector2(0, -2)]), tint)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
		for ping: Dictionary in level.help_pings:
			_marker(ping["position"], area, func(at: Vector2) -> void:
				draw_arc(at, 4.0 + pulse * 2.0, 0, TAU, 12, Color(0.95, 0.35, 0.3), 1.0))
	for row in teammates():
		var mate: CampPlayer = row[0]
		var tint: Color = row[1]
		_marker(mate.global_position, area, func(at: Vector2) -> void:
			if mate.status == CampPlayer.Status.DOWNED:
				draw_line(at + Vector2(-3, -3), at + Vector2(3, 3), Color("f06a55"), 2.0)
				draw_line(at + Vector2(-3, 3), at + Vector2(3, -3), Color("f06a55"), 2.0)
			else:
				draw_circle(at, 2.5, tint)
				draw_arc(at, 3.5, 0, TAU, 10, Color("101814"), 1.0))
	var you := to_map(player.global_position)
	var tip := you + player.facing * 5.0
	var side := player.facing.orthogonal() * 3.0
	draw_colored_polygon(PackedVector2Array([tip, you - player.facing * 2.0 + side, you - player.facing * 2.0 - side]), Color("9ee3d7"))


## Draw at the marker position, or as a clipped arrow on the edge of the map.
func _marker(world: Vector2, area: Rect2, paint: Callable) -> void:
	var at := to_map(world)
	if area.has_point(at):
		paint.call(at)
		return
	var middle := area.get_center()
	var direction := (at - middle).normalized()
	var reach := minf(absf((area.size.x * 0.5) / direction.x) if absf(direction.x) > 0.001 else INF, absf((area.size.y * 0.5) / direction.y) if absf(direction.y) > 0.001 else INF)
	var edge := middle + direction * reach
	draw_colored_polygon(PackedVector2Array([edge, edge - direction * 5 + direction.orthogonal() * 3, edge - direction * 5 - direction.orthogonal() * 3]), Color("e8dcb2"))


## Region and destination names last, so nothing paints over them; only when
## the name fits inside its region, measured with the real font.
func _draw_labels() -> void:
	var font := ThemeDB.fallback_font
	if plan.expedition and not overview:
		for zone in plan.woods.zones:
			var rect: Rect2 = zone["bounds"]
			if not rect.intersects(window):
				continue
			var area := Rect2(to_map(rect.position), rect.size * factor)
			var name: String = WoodsLayout.SIGN_NAMES[zone["kind"]]
			var width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
			if width <= area.size.x + 8.0:
				var at := Vector2(area.get_center().x - width * 0.5, area.position.y + 8.0)
				draw_string_outline(font, at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, 2, Color("101814"))
				draw_string(font, at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, INK if _zone_known(zone) else DIM)
	# North marker in the corner (the view title lives in the notebook column).
	draw_string_outline(font, Vector2(size.x - 9, 9), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, 2, Color("101814"))
	draw_string(font, Vector2(size.x - 9, 9), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("cfc89f"))


func title() -> String:
	if overview and plan.expedition:
		return "WHOLE WOODS"
	return "AROUND YOU" if plan.expedition and CampMap.is_woods(player.global_position) else "FERNWOOD CAMP"
