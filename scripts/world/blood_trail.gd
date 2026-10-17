extends Node2D
## Short-lived blood drops behind wounded survivors; newest drops are darkest.


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		var count := actor.blood.size()
		for index in range(count):
			var fade := float(index + 1) / float(count)
			var at := actor.blood[index] - global_position
			if not PixelArt.draw_in(self, "fx_blood_trail" if index % 2 else "fx_blood", Rect2(at + Vector2(-4, -1), Vector2(8, 7)), Color(1, 1, 1, 0.3 + fade * 0.6)):
				draw_rect(Rect2(at + Vector2(-1, 2), Vector2(3, 2)), Color(0.55, 0.12, 0.1, 0.25 + fade * 0.55))
				draw_rect(Rect2(at + Vector2(2, 4), Vector2(1, 1)), Color(0.45, 0.1, 0.08, fade * 0.6))
