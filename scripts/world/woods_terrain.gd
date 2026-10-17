extends Node2D
## View-local forest scenery; the whole forest's collision/navigation stays active.
var camp_map: CampMap
var canopy_only := false
var view := Rect2()
var detail := 16
var focus_cell := Vector2i(0x7fffffff,0x7fffffff)
const ATLAS := preload("res://assets/tiles/camp_tiles.png")
## SpriteCook forest set: pines dominate, spruce adds dark mass, birch and a rare
## dead snag break up the silhouette.
## Canopy trees for the current view: [base, texture, tint, anchor], sorted by y.
## `anchor` is the nearest trail point for edge trees (null deeper in the woods).
var trees: Array = []
const SHRUB := preload("res://assets/sprites/shrub.png")
var textures: Array[Texture2D] = [preload("res://assets/sprites/pine_0.png"),preload("res://assets/sprites/pine_1.png"),preload("res://assets/sprites/pine_2.png"),preload("res://assets/sprites/birch.png"),preload("res://assets/sprites/spruce.png"),preload("res://assets/sprites/pine_0.png"),preload("res://assets/sprites/spruce.png"),preload("res://assets/sprites/dead_tree.png")]

func _process(_delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var inverse := get_canvas_transform().affine_inverse()
	var top_left := inverse * Vector2.ZERO
	var bottom_right := inverse * get_viewport_rect().size
	top_left = (top_left/32).floor()*32
	bottom_right = (bottom_right/32).ceil()*32
	var next := Rect2(top_left,bottom_right-top_left).grow(128).intersection(WoodsLayout.WORLD_BOUNDS)
	detail = 16 if camera.zoom.x >= 0.2 else 64
	var next_focus := Vector2i((camp_map.focus.global_position/8).floor()) if is_instance_valid(camp_map.focus) else Vector2i.ZERO
	if next != view or canopy_only and next_focus != focus_cell:
		focus_cell = next_focus
		if next != view:
			view = next
			if canopy_only:
				_collect_trees()
		queue_redraw()

func _draw() -> void:
	if view.size == Vector2.ZERO:
		return
	if not canopy_only:
		for y in range(int(floor(view.position.y/detail)), int(ceil(view.end.y/detail))):
			for x in range(int(floor(view.position.x/detail)), int(ceil(view.end.x/detail))):
				var at := Vector2(x,y) * detail
				if CampMap.CAMP_BOUNDS.has_point(at + Vector2.ONE * detail/2):
					continue
				var tile := Vector2i(posmod(x+y,2),1)
				var material := "forest_floor"
				var tint := Color(0.62, 0.66, 0.6)
				if camp_map.woods.walkable(at + Vector2.ONE * detail/2):
					tint = Color.WHITE
					tile.x = 2 + posmod(x+y,2)
					material = "trail"
				if camp_map.woods.on_road(at + Vector2.ONE * detail/2):
					tile = Vector2i(4 + posmod(x + y, 3), 0)
					material = "road"
				var zone := camp_map.woods.zone_at(at + Vector2.ONE*detail/2)
				if not zone.is_empty():
					tile = Vector2i(2+posmod(x+y,2),3) if zone["kind"] == "village" else Vector2i(0 if zone["kind"] == "bog" else 7,1)
					material = {"village": "cobbles", "bog": "bog_mud", "graveyard": "dead_grass"}.get(zone["kind"], "flagstones")
					tint = Color.WHITE
				# SpriteCook seamless materials, world-aligned; atlas tiles as fallback.
				if not PixelArt.draw_material(self, material, Rect2(at, Vector2.ONE * detail), tint):
					draw_texture_rect_region(ATLAS,Rect2(at,Vector2.ONE*detail),Rect2(Vector2(tile)*16,Vector2(16,16)),tint)
	if not canopy_only:
		_draw_undergrowth()
		return
	for tree in trees:
		var color: Color = tree[2]
		if is_instance_valid(camp_map.focus):
			var offset: Vector2 = tree[0] - camp_map.focus.global_position
			if absf(offset.x) < 30 and offset.y > -4 and offset.y < 70:
				color.a = 0.28
		draw_texture(tree[1], tree_origin(tree), color)


static func tree_origin(tree: Array) -> Vector2:
	return tree[0] - Vector2(32, 76)


## Trees stand on a jittered 20 px grid inside the forest walls: dense along every
## path edge so trails read as cut through woodland, sparser deeper in.
func _collect_trees() -> void:
	trees.clear()
	var step := 20
	for y in range(int(floor(view.position.y / step)) - 1, int(ceil(view.end.y / step)) + 5):
		for x in range(int(floor(view.position.x / step)), int(ceil(view.end.x / step))):
			var h := hash(Vector2i(x, y) + Vector2i(7919, 104729))
			var base := Vector2(x * step + posmod(h, 13) - 6, y * step + posmod(h >> 4, 13) - 6)
			if not _solid(base) or not _solid(base + Vector2(-7, 0)) or not _solid(base + Vector2(7, 0)) or not _solid(base + Vector2(0, 5)):
				continue
			var anchor: Variant = _path_point(base, 44)
			if anchor == null and posmod(h >> 8, 3) != 0:
				continue
			var shade := 0.82 + posmod(h >> 12, 19) * 0.01
			if anchor == null:
				shade *= 0.85
			trees.append([base, textures[posmod(h >> 16, textures.size())], Color(shade, shade, shade * 0.97), anchor])


func _solid(point: Vector2) -> bool:
	return WoodsLayout.WORLD_BOUNDS.has_point(point) and not CampMap.CAMP_BOUNDS.has_point(point) and not camp_map.woods.walkable(point)


func _near_path(point: Vector2, reach: float) -> bool:
	return _path_point(point, reach) != null


## Nearest sampled trail point within `reach`, or null.
func _path_point(point: Vector2, reach: float) -> Variant:
	for distance in [reach * 0.5, reach]:
		for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(0.7, -0.7), Vector2(-0.7, -0.7)]:
			var probe: Vector2 = point + direction * distance
			if not CampMap.CAMP_BOUNDS.has_point(probe) and camp_map.woods.walkable(probe):
				return probe
	return null


## Shrubs fill the gaps between trunks along every trail edge.
func _draw_undergrowth() -> void:
	var step := 14
	for y in range(int(floor(view.position.y / step)), int(ceil(view.end.y / step))):
		for x in range(int(floor(view.position.x / step)), int(ceil(view.end.x / step))):
			var h := hash(Vector2i(x, y) + Vector2i(31, 977))
			var base := Vector2(x * step + posmod(h, 9) - 4, y * step + posmod(h >> 4, 9) - 4)
			if not _solid(base) or not _near_path(base, 18):
				continue
			var shade := 0.7 + posmod(h >> 8, 21) * 0.01
			draw_texture(SHRUB, base - Vector2(17, 24), Color(shade, shade, shade))
