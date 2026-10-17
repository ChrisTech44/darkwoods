class_name LakeWater
extends Node2D
## Animated lake surface for the boat landing (see lake_water.gdshader). The
## water is solid on its own collision layer, so sight, flashlights and voice
## carry across it while nobody can walk on it.

var rects: Array[Rect2] = []
var pilings: Array[Vector2] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://assets/shaders/lake_water.gdshader")
	var packed: Array[Vector4] = []
	for rect in rects:
		packed.append(Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	surface.set_shader_parameter("rects", packed)
	surface.set_shader_parameter("rect_count", mini(rects.size(), 4))
	surface.set_shader_parameter("pilings", PackedVector2Array(pilings))
	surface.set_shader_parameter("piling_count", mini(pilings.size(), 8))
	material = surface


func _draw() -> void:
	for rect in rects:
		draw_rect(rect, Color.WHITE)
