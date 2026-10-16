class_name CampMap
extends Node2D
## Original fixed woodland layout. Collision and navigation share one obstacle list.

const WORLD_SIZE := Vector2(768, 480)
const CELL := 24
var obstacles: Array[Rect2] = []
var cabins: Array[Rect2] = [Rect2(144, 72, 144, 96), Rect2(480, 72, 144, 96), Rect2(408, 312, 120, 96)]
var trees: Array[Rect2] = []
var navigation_region: NavigationRegion2D


func _ready() -> void:
	add_wall(Rect2(0, 0, 768, 24))
	add_wall(Rect2(0, 456, 768, 24))
	add_wall(Rect2(0, 0, 24, 480))
	add_wall(Rect2(744, 0, 24, 480))
	for cabin in cabins:
		add_wall(Rect2(cabin.position, Vector2(cabin.size.x, 24)))
		add_wall(Rect2(cabin.position, Vector2(24, cabin.size.y)))
		add_wall(Rect2(cabin.end.x - 24, cabin.position.y, 24, cabin.size.y))
		var door_x := cabin.position.x + 48
		add_wall(Rect2(cabin.position.x, cabin.end.y - 24, 48, 24))
		add_wall(Rect2(door_x + 24, cabin.end.y - 24, cabin.size.x - 72, 24))
	for cell in [Vector2(2, 2), Vector2(4, 3), Vector2(15, 2), Vector2(17, 4),
		Vector2(28, 3), Vector2(29, 7), Vector2(3, 8), Vector2(5, 10), Vector2(9, 9),
		Vector2(13, 11), Vector2(23, 10), Vector2(26, 13), Vector2(28, 17),
		Vector2(4, 17), Vector2(10, 17), Vector2(14, 16), Vector2(30, 11)]:
		var tree := Rect2(cell * CELL, Vector2(CELL, CELL))
		trees.append(tree)
		add_wall(tree)
	_build_navigation()


func add_wall(rect: Rect2) -> void:
	obstacles.append(rect)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.position = rect.get_center()
	body.add_child(collision)
	add_child(body)


func _build_navigation() -> void:
	var polygon := NavigationPolygon.new()
	polygon.agent_radius = 7.0
	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(_outline(Rect2(Vector2.ZERO, WORLD_SIZE)))
	for obstacle in obstacles:
		source.add_obstruction_outline(_outline(obstacle))
	# Keep routes clear of the van's collision, which is a separate scene.
	source.add_obstruction_outline(_outline(Rect2(81, 278, 30, 40)))
	NavigationServer2D.bake_from_source_geometry_data(polygon, source)
	navigation_region = NavigationRegion2D.new()
	navigation_region.navigation_polygon = polygon
	add_child(navigation_region)


func _outline(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("233b36"))
	# Deterministic ground detail, independent of game random seed.
	for y in range(0, 480, 12):
		for x in range(0, 768, 12):
			if (x * 3 + y * 7) % 19 < 4:
				draw_rect(Rect2(x + 3, y + 6, 3, 2), Color("2b443c"))
	draw_rect(Rect2(36, 192, 696, 48), Color("405046"))
	draw_rect(Rect2(72, 216, 48, 216), Color("405046"))
	draw_rect(Rect2(192, 144, 24, 72), Color("405046"))
	draw_rect(Rect2(528, 144, 24, 72), Color("405046"))
	draw_rect(Rect2(456, 216, 24, 192), Color("405046"))
	for cabin in cabins:
		draw_rect(cabin, Color("76654b"))
		for y in range(int(cabin.position.y), int(cabin.end.y), 8):
			draw_line(Vector2(cabin.position.x, y), Vector2(cabin.end.x, y), Color("62573f"))
	for rect in obstacles:
		if rect not in trees:
			draw_rect(rect, Color("162c2b"))
	for tree in trees:
		var center := tree.get_center()
		draw_rect(tree, Color("142b2a"))
		draw_rect(Rect2(center - Vector2(10, 14), Vector2(20, 24)), Color("1b3430"))
		draw_rect(Rect2(center - Vector2(6, 20), Vector2(12, 16)), Color("274537"))
	# Original campsite props, without collisions: tent, fire ring, and sign.
	draw_colored_polygon(PackedVector2Array([Vector2(138, 378), Vector2(153, 354), Vector2(168, 378)]), Color("8b7754"))
	draw_colored_polygon(PackedVector2Array([Vector2(147, 378), Vector2(153, 364), Vector2(159, 378)]), Color("243633"))
	draw_circle(Vector2(168, 336), 9, Color("4b5045"))
	draw_rect(Rect2(164, 333, 8, 5), Color("c49052"))
