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
		view = next
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
				if camp_map.woods.walkable(at + Vector2.ONE * detail/2):
					tile.x = 2 + posmod(x+y,2)
					material = "trail"
				if camp_map.woods.on_road(at + Vector2.ONE * detail/2):
					tile = Vector2i(4 + posmod(x + y, 3), 0)
					material = "road"
				var zone := camp_map.woods.zone_at(at + Vector2.ONE*detail/2)
				if not zone.is_empty():
					tile = Vector2i(2+posmod(x+y,2),3) if zone["kind"] == "village" else Vector2i(0 if zone["kind"] == "bog" else 7,1)
					material = {"village": "cobbles", "bog": "bog_mud", "graveyard": "dead_grass"}.get(zone["kind"], "flagstones")
				# SpriteCook seamless materials, world-aligned; atlas tiles as fallback.
				if not PixelArt.draw_material(self, material, Rect2(at, Vector2.ONE * detail)):
					draw_texture_rect_region(ATLAS,Rect2(at,Vector2.ONE*detail),Rect2(Vector2(tile)*16,Vector2(16,16)))
	else:
		for y in range(int(floor(view.position.y/32)),int(ceil(view.end.y/32))):
			for x in range(int(floor(view.position.x/32)),int(ceil(view.end.x/32))):
				var at := Vector2(x*32+16,y*32+16)
				if CampMap.CAMP_BOUNDS.has_point(at) or camp_map.woods.walkable(at) or posmod(x+y,2) != 0:
					continue
				var texture := textures[posmod(x*3+y*7,textures.size())]
				var color := Color.WHITE
				if is_instance_valid(camp_map.focus):
					var offset := at-camp_map.focus.global_position
					if absf(offset.x)<30 and offset.y>-4 and offset.y<70:
						color.a = 0.28
				draw_texture(texture,at-texture.get_size()*0.5-Vector2(0,32),color)
