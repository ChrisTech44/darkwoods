extends Node2D
## Only elevated machinery rises above the floor sight mask. No terrain/actors.
var rescue: RadioRescue

func _ready() -> void:
	set_meta("stand_in_world", true)
	z_index = 101
	var unshaded := Shader.new()
	unshaded.code = "shader_type canvas_item; render_mode unshaded;"
	var surface := ShaderMaterial.new()
	surface.shader = unshaded
	material = surface

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	StandingProps.begin_draw(self)
	var level: Node2D = rescue.level
	if level.sight == null:
		return
	var observer: CampPlayer = level.player
	for index in [9,10]:
		var zone: Dictionary = level.plan.woods.zones[index]
		var at: Vector2 = zone["position"]
		var anchor := at + Vector2(0,44)
		# Either exposed cabinet face can anchor the known static silhouette.
		# The north face is just outside the solid cabinet footprint.
		# Stay inside their own clearing; this never lifts floor or creature fog.
		if not level.sight.can_see(anchor):
			anchor = at + Vector2(0,8)
		if not zone["bounds"].has_point(observer.global_position) or not level.sight.can_see(anchor):
			continue
		var powered: bool = rescue.active and rescue.powered and (index == 9 or rescue.relay_enabled)
		var brightness := 0.62 if powered else 0.16
		for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
			if actor.flashlight_on and actor.status in [CampPlayer.Status.ALIVE,CampPlayer.Status.DOWNED] and actor.position.distance_to(anchor)<230 and actor.position.direction_to(anchor).dot(actor.facing)>0.4 and level.clear_path(actor.position,anchor):
				brightness = maxf(brightness,0.9)
		self_modulate = Color(brightness, brightness, brightness)
		if index == 9:
			RescueArt.draw_substation(self, at, rescue.active)
		else:
			RescueArt.draw_relay(self, at, rescue.relay_enabled)
