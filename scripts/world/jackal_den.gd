class_name JackalDen
extends Node2D
## The Trash Jackals' junk pile, where stolen things are dropped. The level
## places one per den position after spawning creatures.


func _draw() -> void:
	draw_circle(Vector2(0, 2), 16, Color(0, 0, 0, 0.3))
	PixelArt.draw_standing(self, "jackal_den", Vector2(0, 6), 40)
