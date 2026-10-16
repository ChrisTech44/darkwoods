class_name WoodsVisibility
extends Node2D
## Opaque line-of-sight mask, independent of ambient light and monster AI.
const RANGE := 260.0
const RAYS := 256
var player: CampPlayer
var enabled := true
var boundary := PackedVector2Array()

func _ready() -> void:
	z_index = 100

func _physics_process(_delta: float) -> void:
	visible = enabled and CampMap.is_woods(player.global_position)
	global_position = player.global_position
	if visible:
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
	# Each angular strip fills the space beyond its first obstruction with black.
	for index in range(RAYS):
		var next := (index + 1) % RAYS
		var outer_a := Vector2.from_angle(index * TAU / RAYS) * 20000
		var outer_b := Vector2.from_angle(next * TAU / RAYS) * 20000
		draw_colored_polygon(PackedVector2Array([boundary[index], boundary[next], outer_b, outer_a]), Color.BLACK)
