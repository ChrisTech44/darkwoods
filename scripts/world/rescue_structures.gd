extends Node2D
## Only elevated machinery rises above the floor sight mask. No terrain/actors.
var rescue: RadioRescue

func _ready() -> void:
	z_index = 101
	var unshaded := Shader.new()
	unshaded.code = "shader_type canvas_item; render_mode unshaded;"
	var surface := ShaderMaterial.new()
	surface.shader = unshaded
	material = surface

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var level: Node2D = rescue.level
	if level.sight == null:
		return
	var observer: CampPlayer = level.player
	for index in [9,10]:
		var zone: Dictionary = level.plan.woods.zones[index]
		var at: Vector2 = zone["position"]
		var anchor := at + Vector2(0,44)
		# Upright structures are known silhouettes anchored to a visible front face.
		# Stay inside their own clearing; this never lifts floor or creature fog.
		if not zone["bounds"].has_point(observer.global_position) or not level.sight.can_see(anchor):
			continue
		var brightness := 0.62 if rescue.powered else 0.16
		var direction := observer.global_position.direction_to(anchor)
		if observer.flashlight_on and direction.dot(observer.facing) > 0.4:
			brightness = maxf(brightness, 0.82)
		self_modulate = Color(brightness, brightness, brightness)
		if index == 9:
			RescueArt.draw_substation(self, at)
		else:
			RescueArt.draw_relay(self, at)
