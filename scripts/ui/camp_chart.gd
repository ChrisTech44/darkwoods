extends Control
## Field notes: camp is printed, woods trails are revealed only by exploration.

var camp_map: CampMap
var player: CampPlayer
var van: CampVan
var plan: RoundPlan


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if camp_map == null or player == null or plan == null:
		return
	var in_woods := player.global_position.x >= 1536
	var bounds := Rect2(1536, 24, 1896, 1872) if in_woods else Rect2(0, 0, 1536, 960)
	var factor := Vector2(146, 91) / bounds.size
	var origin := Vector2(3, 15)
	draw_rect(Rect2(0, 0, 154, 112), Color("1c2b28"))
	draw_string(ThemeDB.fallback_font, Vector2(4, 10), "THE WOODS / N ↑" if in_woods else "FERNWOOD / N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("cfc89f"))
	if in_woods:
		for zone in plan.woods.zones:
			var known := false
			for cell: Vector2i in plan.woods.visited:
				if zone["bounds"].has_point(plan.woods.center(cell)):
					known = true
			if known:
				var rect: Rect2 = zone["bounds"]
				draw_rect(Rect2(origin + (rect.position - bounds.position) * factor, rect.size * factor), Color("b29c70"), false)
		for cell: Vector2i in plan.woods.visited:
			var at := origin + (plan.woods.center(cell) - bounds.position) * factor
			draw_circle(at, 2, Color("77805f"))
			for next: Vector2i in plan.woods.links[cell]:
				draw_line(at, origin + (plan.woods.center(next) - bounds.position) * factor, Color("68715b"))
	else:
		for road in camp_map.roads:
			draw_rect(Rect2(origin + road.position * factor, road.size * factor), Color("68715b"))
		for building in camp_map.buildings:
			draw_rect(Rect2(origin + building.bounds.position * factor, building.bounds.size * factor), Color("b39b72"))
		draw_rect(Rect2(origin + camp_map.lake.position * factor, camp_map.lake.size * factor), Color("406a70"))
		draw_string(ThemeDB.fallback_font, Vector2(110, 65), "WOODS →", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("c6bc96"))
	for item in plan.loot:
		if item["kind"] not in plan.required:
			continue
		var position: Vector2 = item["position"]
		if not bounds.has_point(position):
			continue
		if in_woods and not plan.woods.visited.has(plan.woods.cell_at(position)):
			continue
		var point := origin + (position - bounds.position) * factor
		draw_circle(point, 4, Color("243c36"))
		draw_string(ThemeDB.fallback_font, point + Vector2(-2, 3), str(plan.required.find(item["kind"]) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("f0dca3"))
	if bounds.has_point(van.global_position):
		var vehicle := origin + (van.global_position - bounds.position) * factor
		draw_rect(Rect2(vehicle - Vector2(2, 3), Vector2(4, 6)), Color("f0dca3"))
	var survivor := origin + (player.global_position - bounds.position) * factor
	draw_circle(survivor, 2, Color("9ee3d7"))
	draw_line(survivor, survivor + player.facing * 4, Color("9ee3d7"))
