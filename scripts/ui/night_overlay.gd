extends CanvasLayer
## Local visual only. Darkness never controls authority-side sight checks.

var player: CampPlayer
var shade: ColorRect


func _ready() -> void:
	layer = 3
	shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://assets/night.gdshader")
	shade.material = shader_material
	add_child(shade)


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var screen := player.get_global_transform_with_canvas().origin
	shade.material.set_shader_parameter("survivor_uv", screen / get_viewport().get_visible_rect().size)
	shade.material.set_shader_parameter("facing", player.facing)
	shade.material.set_shader_parameter("flashlight_on", player.flashlight_on)
