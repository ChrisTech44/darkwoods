class_name CallingCards
extends Node2D
## The stalker's scrawls on the ground (names, "I SEE YOU"), and his hook post.
var level: Node2D


func _ready() -> void:
	z_index = -1


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if level == null or not level.plan.expedition:
		return
	var hook: Vector2 = level.hook_point()
	draw_circle(hook + Vector2(0, 4), 18, Color(0, 0, 0, 0.35))
	PixelArt.draw_in(self, "hook_post", Rect2(hook + Vector2(-14, -52), Vector2(28, 56)))
	for card: Dictionary in level.cards:
		var at: Vector2 = card["position"]
		var text: String = card["text"]
		var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_set_transform(at, -0.12, Vector2.ONE)
		draw_string(ThemeDB.fallback_font, Vector2(-width * 0.5 + 1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.6))
		draw_string(ThemeDB.fallback_font, Vector2(-width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.78, 0.12, 0.08, 0.95))
	draw_set_transform(Vector2.ZERO)
