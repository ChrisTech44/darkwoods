class_name CallingCards
extends Node2D
## The stalker's scrawls on the ground (names, "I SEE YOU"), and his hook post.
var level: Node2D
## Per-card fade (0 unseen..1 read), so a scrawl only shows up in your light.
var shown: Dictionary = {}
var last_cards: Array = []
var last_hook := Vector2.INF


func _ready() -> void:
	z_index = -1
	if level != null: last_hook = level.hook_point()


func _process(delta: float) -> void:
	if level == null or level.player == null:
		return
	var changed := false
	if last_cards != level.cards:
		last_cards = level.cards.duplicate(true)
		changed = true
	var viewer: CampPlayer = level.player
	for card: Dictionary in level.cards:
		var key: Vector2 = card["position"]
		var lit := CreatureBrain.in_beam(viewer, key, 230.0, 0.8) or viewer.global_position.distance_to(key) < 60.0
		var value := move_toward(shown.get(key, 0.0), 1.0 if lit else 0.08, delta * (3.0 if lit else 0.6))
		if value != shown.get(key, 0.0): changed = true
		shown[key] = value
	if changed: queue_redraw()


func _draw() -> void:
	if level == null or not level.plan.expedition:
		return
	var hook := last_hook
	draw_circle(hook + Vector2(0, 4), 18, Color(0, 0, 0, 0.35))
	PixelArt.draw_in(self, "hook_post", Rect2(hook + Vector2(-14, -52), Vector2(28, 56)))
	for card: Dictionary in level.cards:
		var at: Vector2 = card["position"]
		var text: String = card["text"]
		var alpha: float = shown.get(at, 0.0)
		if alpha <= 0.01:
			continue
		var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_set_transform(at, -0.12, Vector2.ONE)
		draw_string(ThemeDB.fallback_font, Vector2(-width * 0.5 + 1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.6 * alpha))
		draw_string(ThemeDB.fallback_font, Vector2(-width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.78, 0.12, 0.08, 0.95 * alpha))
	draw_set_transform(Vector2.ZERO)
