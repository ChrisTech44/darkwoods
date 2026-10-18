extends Node2D
## Upright props have visible floor anchors; actors and ground stay under sight fog.
var escapes: FieldEscapes
func _ready() -> void:
	set_meta("stand_in_world", true)
	z_index = 101
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode unshaded;"
	var surface := ShaderMaterial.new()
	surface.shader = shader
	material = surface
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	var level: Node2D = escapes.level
	if level.sight == null:
		return
	var player: CampPlayer = level.player
	for index in [11,12,13]:
		if (index in [11,12] and not escapes.boat_enabled) or (index == 13 and not escapes.gate_enabled):
			continue
		var zone: Dictionary = level.plan.woods.zones[index]
		var anchor: Vector2 = zone["position"] + Vector2(0,42)
		if index==12: anchor = zone["position"] + Vector2(0,84)
		if index==13: anchor = escapes.gate_point + Vector2(0,10)
		if not zone["bounds"].has_point(player.position) or not level.sight.can_see(anchor):
			continue
		var brightness := 0.68 if index==13 and escapes.gate_powered else 0.25
		for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
			if actor.flashlight_on and actor.status in [CampPlayer.Status.ALIVE,CampPlayer.Status.DOWNED] and actor.position.distance_to(anchor)<230 and actor.position.direction_to(anchor).dot(actor.facing)>0.4 and level.clear_path(actor.position,anchor):
				brightness = maxf(brightness,0.9)
		self_modulate = Color(brightness,brightness,brightness)
		var motor_waiting: bool = index == 11 and escapes.boat_enabled and level.pickups.any(func(pickup: CampPickup) -> bool: return pickup.available and pickup.kind == "outboard_motor" and zone["bounds"].has_point(pickup.global_position))
		FieldEscapeArt.draw_structure(self,zone,escapes.gate_powered,escapes.gate_open,escapes.pulse,motor_waiting)
