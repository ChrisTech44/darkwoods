extends Node2D

var remaining: float = 9.0
var time: float = 0.0


func _ready() -> void:
	add_to_group("flares")
	CampLights.lamp(self, Vector2(0, -4), 145, Color("ff9962"), 2.0)


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0:
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-3, -3, 7, 3), Color("b9ad87"))
	for index in range(8):
		var phase := fmod(time * 10 + index * 1.7, 12)
		draw_rect(Rect2(sin(index + time) * 5, -phase - 4, 1, 2), Color("f7c37f"))
