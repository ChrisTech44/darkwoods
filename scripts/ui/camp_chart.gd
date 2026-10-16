extends Control
## The survivor's field map. No enemy locations are disclosed.

var camp_map: CampMap
var player: CampPlayer
var van: CampVan


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if camp_map == null or player == null:
		return
	var factor := Vector2(146, 91) / CampMap.WORLD_SIZE
	var origin := Vector2(3, 15)
	draw_rect(Rect2(0, 0, 154, 112), Color("1c2b28"))
	draw_string(ThemeDB.fallback_font, Vector2(4, 10), "FERNWOOD  /  N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("cfc89f"))
	for road in camp_map.roads:
		draw_rect(Rect2(origin + road.position * factor, road.size * factor), Color("68715b"))
	draw_rect(Rect2(origin + camp_map.lake.position * factor, camp_map.lake.size * factor), Color("406a70"))
	for building in camp_map.buildings:
		draw_rect(Rect2(origin + building.bounds.position * factor, building.bounds.size * factor), Color("b39b72"))
	for index in range(CampMap.PICKUP_POSITIONS.size()):
		var point := origin + CampMap.PICKUP_POSITIONS[index] * factor
		draw_circle(point, 5, Color("243c36"))
		draw_string(ThemeDB.fallback_font, point + Vector2(-2, 3), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("f0dca3"))
	var vehicle := origin + van.global_position * factor
	draw_rect(Rect2(vehicle - Vector2(2, 3), Vector2(4, 6)), Color("f0dca3"))
	var survivor := origin + player.global_position * factor
	draw_circle(survivor, 2, Color("9ee3d7"))
	draw_line(survivor, survivor + player.facing * 4, Color("9ee3d7"))
