class_name HexBolt
extends Node2D
## Fixed trajectory, swept wall/player collision. No homing or hidden-target query.

var direction := Vector2.RIGHT
var speed: float = 104
var remaining: float = 2.5
var travel: float = 0.0
## Host only: the witch who cast it (her brain decides the curse).
var source: Node = null
var curse_kind := ""


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
		if actor.status == CampPlayer.Status.ALIVE and actor.hidden_spot < 0 and Geometry2D.get_closest_point_to_segment(actor.global_position, from, to).distance_to(actor.global_position) <= 9:
			if is_instance_valid(source) and source.brain != null and source.brain.has_method("curse"):
				source.brain.curse(actor, curse_kind)
			else:
				actor.apply_hex(1.6)
			queue_free()
			return
	global_position = to
	travel += delta
	queue_redraw()


func _draw() -> void:
	var tint: Color = preload("res://scripts/ai/brains/witch.gd").COLORS.get(curse_kind, Color("b6a0df"))
	for index in range(5):
		draw_circle(-direction * index * 4, 3 - index * 0.4, Color(tint, 0.8 - index * 0.14))
	if not PixelArt.draw_in(self, "fx_hex", Rect2(-6, -6, 12, 12)):
		draw_rect(Rect2(-2, -2, 4, 4), Color("e2d3f3"))
