class_name NoiseLure
extends Node2D
var level: Node2D
var elapsed := 0.0
var pulses := 0
func _ready() -> void:
	add_to_group("hazards")
func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 1.5 + pulses * 2.0:
		level.loud_noise(global_position, 480)
		level.soundscape.broadcast("noise_tin_rattle",global_position)
		pulses += 1
		queue_redraw()
	if pulses >= 3:
		queue_free()
func _draw() -> void:
	if not PixelArt.draw_in(self, "fx_tin", Rect2(-7, -9, 14, 12)):
		draw_rect(Rect2(-4,-6,8,10), Color("c5b49b"))
	draw_arc(Vector2.ZERO, 8 + pulses * 4, 0, TAU, 16, Color("c7b882"))
