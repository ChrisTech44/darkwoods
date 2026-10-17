class_name WoodsVisibility
extends Node2D
## Opaque line-of-sight mask, independent of ambient light and monster AI.
const RANGE := 260.0
const RAYS := 256
## Sight reaches a little way into the forest wall and then fades out, so trail
## edges read as tree line rather than a hard black cut. Walls between corridors
## are at least 64 px thick, so PEEK + FADE (< 32) never reveals the next trail.
const PEEK := 12.0
const FADE := 18.0
var player: CampPlayer
## Woods canopy renderer; edge trees whose base is in sight draw above the mask.
var canopy: Node2D
var enabled := true
var boundary := PackedVector2Array()
var tree_line: Node2D
var depth_image: Image
var depth_texture: ImageTexture

func _ready() -> void:
	z_index = 100
	var fog := ShaderMaterial.new()
	fog.shader=preload("res://assets/shaders/forest_sight.gdshader")
	material=fog
	tree_line=preload("res://scripts/ui/forest_edge.gd").new()
	tree_line.sight=self
	var foliage := ShaderMaterial.new()
	foliage.shader=preload("res://assets/shaders/forest_edge.gdshader")
	depth_image=Image.create(RAYS,1,false,Image.FORMAT_RF)
	depth_texture=ImageTexture.create_from_image(depth_image)
	foliage.set_shader_parameter("sight_depth",depth_texture)
	tree_line.material=foliage
	add_child(tree_line)

func _physics_process(_delta: float) -> void:
	visible = enabled and CampMap.is_woods(player.global_position)
	global_position = player.global_position
	if visible and DisplayServer.get_name() != "headless":
		boundary.clear()
		for index in range(RAYS):
			var target := global_position + Vector2.from_angle(index * TAU / RAYS) * RANGE
			var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, target, 1))
			boundary.append((hit["position"] if not hit.is_empty() else target) - global_position)
		for index in range(RAYS): depth_image.set_pixel(index,0,Color(boundary[index].length()/RANGE,0,0))
		depth_texture.update(depth_image)
		material.set_shader_parameter("observer",player.global_position)
		tree_line.material.set_shader_parameter("observer",player.global_position)
		tree_line.queue_redraw()
		queue_redraw()
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		enemy.visible = not visible or can_see(enemy.global_position)

func can_see(point: Vector2) -> bool:
	if not enabled or not CampMap.is_woods(player.global_position):
		return true
	if player.global_position.distance_to(point) > RANGE:
		return false
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(player.global_position, point, 1)).is_empty()

func _draw() -> void:
	if boundary.size() != RAYS:
		return
	# Each angular strip fades out just past its first obstruction, then is black.
	var clear := Color(0, 0, 0, 0)
	for index in range(RAYS):
		var next := (index + 1) % RAYS
		var dir_a := Vector2.from_angle(index * TAU / RAYS)
		var dir_b := Vector2.from_angle(next * TAU / RAYS)
		var near_a := boundary[index] + dir_a * PEEK
		var near_b := boundary[next] + dir_b * PEEK
		var far_a := near_a + dir_a * FADE
		var far_b := near_b + dir_b * FADE
		draw_polygon(PackedVector2Array([near_a, near_b, far_b, far_a]), PackedColorArray([clear, clear, Color.BLACK, Color.BLACK]))
		draw_colored_polygon(PackedVector2Array([far_a, far_b, dir_b * 20000, dir_a * 20000]), Color.BLACK)



func visible_edge_anchor(anchors: PackedVector2Array) -> Variant:
	for point: Vector2 in anchors:
		var delta := point-global_position
		var distance := delta.length()
		if distance>RANGE-FADE: continue
		var index := posmod(roundi(delta.angle()/TAU*RAYS),RAYS)
		if distance<=boundary[index].length()+2: return point
	return null
