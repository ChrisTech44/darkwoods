class_name LandmarkHazard
extends Node2D
## Brief, non-solid visible hazard. Never edits navigation or blocks an exit.
var source: CampCryptid
var remaining := 2.2
var thorns := false
var affected := {}
func _ready() -> void:
	add_to_group("hazards")
func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0 or not is_instance_valid(source):
		queue_free()
		return
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		if actor.status != CampPlayer.Status.ALIVE or actor.hidden_spot >= 0 or affected.has(actor.get_instance_id()):
			continue
		if actor.global_position.distance_to(global_position) <= 23 and source.has_line_of_sight(actor.global_position):
			if thorns and not actor.sprinting:
				continue
			affected[actor.get_instance_id()] = true
			actor.apply_hex(1.2) # Bounded slowdown, no damage or route lock.
	queue_redraw()
func _draw() -> void:
	draw_circle(Vector2.ZERO,23,Color(0.6,0.65,0.4,0.25))
	if thorns and PixelArt.fit("fx_thorns", Vector2(20, 20)) != null:
		for index in range(5):
			var spot := Vector2.from_angle(index * TAU / 5) * 12
			PixelArt.draw_in(self, "fx_thorns", Rect2(spot - Vector2(9, 9), Vector2(18, 16)))
		draw_arc(Vector2.ZERO,23,0,TAU,24,Color("d6c28d"))
		return
	for index in range(9):
		var at := Vector2.from_angle(index*TAU/9)*18
		draw_line(at,at+Vector2(3,-9 if thorns else -18),Color("b4bc89") if thorns else Color("d0d4bc"),2)
	draw_arc(Vector2.ZERO,23,0,TAU,24,Color("d6c28d"))
