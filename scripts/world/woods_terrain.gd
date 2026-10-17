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
## Canopy trees: [base, texture, tint, trail anchors, scale], ordered by trunk y.
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
			var body := Rect2(camp_map.focus.global_position-Vector2(12,29),Vector2(24,32))
			if tree_rect(tree).intersects(body):
				# The surface pass supplies this crown with a per-pixel body opening.
				# Do not leave an opaque duplicate underneath it, including north trees.
				color.a = 0.0 if CampMap.is_woods(camp_map.focus.global_position) else 0.28
		draw_texture_rect(tree[1],tree_rect(tree),false,color)


static func tree_origin(tree: Array) -> Vector2:
	return tree[0] - Vector2(32, 76)*tree[4]


static func tree_rect(tree: Array) -> Rect2:
	return Rect2(tree_origin(tree),Vector2(64,80)*tree[4])


## Staggered trunks and differing crown heights avoid a fence of identical tips.
func _collect_trees() -> void:
	trees.clear()
	var step := 32
	for y in range(int(floor(view.position.y/step))-1,int(ceil(view.end.y/step))+4):
		for x in range(int(floor(view.position.x/step))-1,int(ceil(view.end.x/step))+1):
			var h := hash(Vector3i(x,y,camp_map.seed_value))
			var base := Vector2(x*step+posmod(y,2)*16+posmod(h,19)-9,y*step+posmod(h>>4,19)-9)
			if not _solid(base) or not _solid(base+Vector2(-7,0)) or not _solid(base+Vector2(7,0)) or not _solid(base+Vector2(0,5)): continue
			var anchors := _path_points(base)
			if anchors.is_empty() and posmod(h>>8,3)!=0: continue
			var shade := 0.82+posmod(h>>12,19)*0.01
			if anchors.is_empty(): shade*=0.85
			var crown_scale: float = [0.6,0.75,0.9][posmod(h>>20,3)]
			var variant: int=[0,1,2,4,6,0,1,2,4,6,0,1,2,4,6,3,3,0,2,7][posmod(h>>16,20)]
			trees.append([base,textures[variant],Color(shade,shade,shade*0.97),anchors,crown_scale])
	trees.sort_custom(func(a,b): return a[0].y<b[0].y)


func _path_points(point: Vector2) -> PackedVector2Array:
	var anchors := PackedVector2Array()
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(0.7,0.7),Vector2(-0.7,0.7),Vector2(0.7,-0.7),Vector2(-0.7,-0.7)]:
		for distance in [16,32,48]:
			var probe: Vector2=point+direction*distance
			if not CampMap.CAMP_BOUNDS.has_point(probe) and camp_map.woods.walkable(probe):
				anchors.append(probe)
				break
	return anchors


func draw_edge(canvas: Node2D, sight: WoodsVisibility) -> void:
	if sight.boundary.size()!=sight.RAYS: return
	var lights: Array=get_tree().get_nodes_in_group("survivors")
	var flares: Array=get_tree().get_nodes_in_group("flares")
	for tree: Array in trees:
		var anchor: Variant=sight.visible_edge_anchor(tree[3])
		if anchor==null: continue
		var strength := 0.22
		for actor: CampPlayer in lights:
			if not actor.flashlight_on or actor.status in [CampPlayer.Status.BOARDED,CampPlayer.Status.ESCAPED]: continue
			var offset: Vector2=anchor-actor.global_position
			var reach: float=actor.config.flashlight_range
			if CampMap.is_woods(actor.global_position) and sight.get_parent().plan.weather=="fog": reach*=0.7
			if offset.length()>reach: continue
			if not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(actor.global_position,anchor,1)).is_empty(): continue
			var beam := smoothstep(0.78,0.96,actor.facing.dot(offset.normalized()))
			strength=maxf(strength,0.2+beam*0.85*pow(1-offset.length()/reach,0.55))
		for flare: Node2D in flares:
			var distance: float=flare.global_position.distance_to(anchor)
			if distance<145 and get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(flare.global_position,anchor,1)).is_empty(): strength=maxf(strength,0.2+(1-distance/145)*0.9)
		var color: Color=tree[2]*Color(strength*0.87,strength,strength*1.04,1)
		color.a=1
		# Front-edge bracken breaks the straight ground-mask lip, especially to the north.
		var brush: Vector2=tree[0]
		for fraction in [0.75,0.5,0.25]:
			var candidate: Vector2=tree[0].lerp(anchor,fraction)
			if _solid(candidate):
				brush=candidate
				break
		canvas.draw_texture(SHRUB,brush-Vector2(17,24)-sight.global_position,color*Color(0.9,0.96,0.86,1))
		var rect := tree_rect(tree)
		rect.position-=sight.global_position
		canvas.draw_texture_rect(tree[1],rect,false,color)


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


## Decals soften trail edges (tufts, ferns) and break up tiling (litter).
const EDGE_DECALS: Array[String] = ["decal_grass_tall", "decal_fern", "decal_weeds", "decal_dry_grass", "decal_grass_short", "decal_root"]
const TRAIL_DECALS: Array[String] = ["decal_pebbles", "decal_leaves", "decal_needles", "decal_branch", "decal_puddle", "decal_rock", "decal_mushrooms"]


func _draw_decals() -> void:
	var step := 20
	for y in range(int(floor(view.position.y / step)), int(ceil(view.end.y / step))):
		for x in range(int(floor(view.position.x / step)), int(ceil(view.end.x / step))):
			var h := hash(Vector2i(x, y) + Vector2i(4441, 87))
			var at := Vector2(x * step + posmod(h, 13) - 6, y * step + posmod(h >> 4, 13) - 6)
			if CampMap.CAMP_BOUNDS.has_point(at) or not camp_map.woods.walkable(at) or not camp_map.woods.zone_at(at).is_empty():
				continue
			var roll := posmod(h >> 8, 100)
			var near_wall := _solid(at + Vector2(0, 10)) or _solid(at + Vector2(0, -10)) or _solid(at + Vector2(10, 0)) or _solid(at + Vector2(-10, 0))
			var name := ""
			var size := 12.0
			if near_wall and roll < 70:
				name = EDGE_DECALS[posmod(h >> 12, EDGE_DECALS.size())]
				size = 12.0 + posmod(h >> 16, 6)
			elif roll < 9:
				name = TRAIL_DECALS[posmod(h >> 12, TRAIL_DECALS.size())]
				size = 10.0 + posmod(h >> 16, 4)
			if not name.is_empty():
				PixelArt.draw_in(self, name, Rect2(at - Vector2(size * 0.5, size), Vector2(size, size)), Color(0.8, 0.82, 0.78))


## Shrubs fill the gaps between trunks along every trail edge.
func _draw_undergrowth() -> void:
	_draw_decals()
	var step := 14
	for y in range(int(floor(view.position.y / step)), int(ceil(view.end.y / step))):
		for x in range(int(floor(view.position.x / step)), int(ceil(view.end.x / step))):
			var h := hash(Vector2i(x, y) + Vector2i(31, 977))
			var base := Vector2(x * step + posmod(h, 9) - 4, y * step + posmod(h >> 4, 9) - 4)
			if not _solid(base) or not _near_path(base, 18):
				continue
			var shade := 0.7 + posmod(h >> 8, 21) * 0.01
			draw_texture(SHRUB, base - Vector2(17, 24), Color(shade, shade, shade))
