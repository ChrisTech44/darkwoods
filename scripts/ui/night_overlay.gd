extends Node2D
## Real world lighting. CanvasLayer HUD remains unaffected by world darkness.

var player: CampPlayer
var flashlight: PointLight2D
var nearby_glow: PointLight2D
var survivor_lights := {}
var ambient: CanvasModulate
var weather: String = "clear"
var level: Node2D


func _ready() -> void:
	ambient = CanvasModulate.new()
	ambient.color = player.config.night_ambient
	add_child(ambient)
	var pair := _lights_for(player)
	nearby_glow=pair[0]
	flashlight=pair[1]


func _lights_for(actor: CampPlayer) -> Array:
	if survivor_lights.has(actor): return survivor_lights[actor]
	var glow := CampLights.lamp(actor,Vector2(0,-10),38,Color("b3bfba"),0.6)
	var beam := PointLight2D.new()
	beam.texture=CampLights.texture(true)
	beam.energy=1.6
	beam.color=Color("fff1bf")
	beam.shadow_enabled=true
	beam.shadow_filter=Light2D.SHADOW_FILTER_PCF5
	actor.add_child(beam)
	survivor_lights[actor]=[glow,beam]
	return [glow,beam]


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	# Make room for upright north-side crowns without putting the survivor under HUD.
	var camera := get_viewport().get_camera_2d()
	if camera==player.get_node("Camera2D") and (player.is_physics_processing() or (get_node("/root/Net").active and player.controls_enabled)):
		var look := player.facing*Vector2(24,24)
		if player.facing.y<0: look.y=player.facing.y*32
		camera.offset=camera.offset.lerp(look if CampMap.is_woods(player.global_position) else Vector2.ZERO,1-exp(-_delta*5))
	var woods := CampMap.is_woods(player.global_position)
	ambient.color = player.config.night_ambient.lerp(Color(0.003, 0.008, 0.015, 1), 0.8 if woods else 0.0)
	if level != null and level.night_clock != null and level.night_clock.lightning > 0.0:
		# Lightning brightens the world briefly; the sight mask still hides what trees block.
		ambient.color = ambient.color.lerp(Color(0.42, 0.47, 0.58), 0.55)
	for old in survivor_lights.keys():
		if not is_instance_valid(old): survivor_lights.erase(old)
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		var pair := _lights_for(actor)
		var glow: PointLight2D=pair[0]
		var beam: PointLight2D=pair[1]
		var in_woods := CampMap.is_woods(actor.global_position)
		# A tiny local body light cannot reach across a forest wall. Keep the
		# observer readable when the head sprite projects beyond its foot collider.
		glow.shadow_enabled=not (actor==player and in_woods)
		glow.texture_scale=(25.0 if in_woods else 38.0)/128.0
		beam.position=_safe_emitter(Vector2(0,-12)+actor.facing*8,actor)
		glow.position=_safe_emitter(Vector2(0,-10),actor)
		beam.rotation=actor.facing.angle()
		beam.texture_scale=actor.config.flashlight_range/128.0*(0.7 if in_woods and weather=="fog" else 1.0)
		beam.enabled=actor.flashlight_on and actor.status in [CampPlayer.Status.ALIVE,CampPlayer.Status.DOWNED]
		# Build-up tell: the beam stutters before something is sent your way.
		beam.energy=1.6 if actor.flicker<=0.0 else (0.35 if int(actor.flicker*14.0)%2==0 else 1.4)
		glow.enabled=actor.status not in [CampPlayer.Status.BOARDED,CampPlayer.Status.ESCAPED]


func _safe_emitter(offset: Vector2, source: CampPlayer = null) -> Vector2:
	if source == null: source=player
	# A head-height sprite offset must not place the light beyond a nearby wall.
	var query := PhysicsRayQueryParameters2D.create(source.global_position, source.global_position + offset, 1)
	var hit := player.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return offset
	return source.to_local(hit["position"] + hit["normal"] * 1.5)
