class_name HexBolt
extends Node2D
## Fixed trajectory, swept wall/player collision. No homing or hidden-target query.

var direction := Vector2.RIGHT
var speed: float = 104
var remaining: float = 2.5
var travel: float = 0.0


func _ready() -> void:
	add_to_group("hazards")
	CampLights.lamp(self, Vector2.ZERO, 26, Color("b9a4ed"), 0.8)


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from + direction * speed * delta
	remaining -= delta
	if remaining <= 0:
		queue_free()
		return
	var ray := PhysicsRayQueryParameters2D.create(from, to, 1)
	if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		queue_free()
		return
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status == CampPlayer.Status.ALIVE and Geometry2D.get_closest_point_to_segment(actor.global_position, from, to).distance_to(actor.global_position) <= 9:
			actor.apply_hex(1.6)
			queue_free()
			return
	global_position = to
	travel += delta
	queue_redraw()


func _draw() -> void:
	for index in range(5):
		draw_circle(-direction * index * 4, 3 - index * 0.4, Color(0.62, 0.5, 0.8, 0.8 - index * 0.14))
	draw_rect(Rect2(-2, -2, 4, 4), Color("e2d3f3"))
