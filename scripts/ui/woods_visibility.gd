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

func _ready() -> void:
	z_index = 100

func _physics_process(_delta: float) -> void:
	visible = enabled and CampMap.is_woods(player.global_position)
	global_position = player.global_position
	if visible and DisplayServer.get_name() != "headless":
		boundary.clear()
		for index in range(RAYS):
			var target := global_position + Vector2.from_angle(index * TAU / RAYS) * RANGE
			var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, target, 1))
			boundary.append((hit["position"] if not hit.is_empty() else target) - global_position)
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
	_draw_tree_line()


## Trees standing at the edge of sight are drawn whole over the darkness, so the
## forest rises as a silhouette instead of being clipped at the wall line.
func _draw_tree_line() -> void:
	if not is_instance_valid(canopy):
		return
	for tree: Array in canopy.trees:
		if tree[3] == null:
			continue
		# Shown when the trail patch beside it is in sight, so grazing views of
		# a wall still get their full tree line.
		var anchor: Vector2 = tree[3] - global_position
		var distance := anchor.length()
		if distance > RANGE - FADE:
			continue
		var index := posmod(roundi(anchor.angle() / TAU * RAYS), RAYS)
		if distance > boundary[index].length() + 6.0:
			continue
		var offset: Vector2 = tree[0] - global_position
		var color: Color = tree[2]
		if absf(offset.x) < 30 and offset.y > -4 and offset.y < 70:
			color.a = 0.28
		draw_texture(tree[1], canopy.tree_origin(tree) - global_position, color)
