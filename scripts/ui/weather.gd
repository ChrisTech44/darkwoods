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
	# Storm fronts bring a downpour on any night; rain nights drizzle throughout.
	var storm: bool = level.night_clock != null and level.night_clock.storm_remaining > 0.0
	if level.plan.weather == "rain" or storm:
		var drops := 200 if storm else 90
		var speed := 260.0 if storm else 150.0
		for index in range(drops):
			var at := Vector2(fposmod(index * 73 - elapsed * (60 if storm else 24), 384), fposmod(index * 29 + elapsed * speed, 216)).floor()
			draw_line(at, at + (Vector2(-4, 10) if storm else Vector2(-2, 6)), Color(0.62, 0.74, 0.76, 0.22 if storm else 0.13))
		if storm and level.night_clock.lightning > 0.0:
			draw_rect(Rect2(0, 0, 384, 216), Color(0.85, 0.9, 1.0, level.night_clock.lightning * 1.2))
	elif level.plan.weather == "fog" and CampMap.is_woods(level.player.global_position):
		for index in range(6):
			var at := Vector2(fposmod(index * 91 + elapsed * 5, 560) - 176, index * 43 - 56)
			draw_texture_rect(CampLights.texture(), Rect2(at, Vector2(220, 96)), false, Color(0.53, 0.63, 0.57, 0.035))
