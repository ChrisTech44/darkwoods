extends Control
## Small screen-space pixel weather, below the unaffected HUD.

var level: Node2D
var elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not level.paused and not level.finished:
		elapsed += delta
	queue_redraw()


func _draw() -> void:
	if not level.plan.expedition:
		return
	if level.plan.weather == "rain":
		for index in range(90):
			var at := Vector2(fposmod(index * 73 - elapsed * 24, 384), fposmod(index * 29 + elapsed * 150, 216)).floor()
			draw_line(at, at + Vector2(-2, 6), Color(0.58, 0.70, 0.71, 0.13))
	elif level.plan.weather == "fog" and level.player.global_position.x >= 1536:
		for index in range(16):
			var at := Vector2(fposmod(index * 43 + elapsed * 5, 440) - 56, index * 15 - 5)
			draw_rect(Rect2(at, Vector2(92, 2 + index % 3)), Color(0.53, 0.63, 0.57, 0.055))
