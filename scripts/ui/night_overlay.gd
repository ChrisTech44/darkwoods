extends Node2D
## Real world lighting. CanvasLayer HUD remains unaffected by world darkness.

var player: CampPlayer
var flashlight: PointLight2D
var nearby_glow: PointLight2D
var ambient: CanvasModulate
var weather: String = "clear"


func _ready() -> void:
	ambient = CanvasModulate.new()
	ambient.color = player.config.night_ambient
	add_child(ambient)
	nearby_glow = CampLights.lamp(player, Vector2(0, -10), 38, Color("b3bfba"), 0.6)
	nearby_glow.shadow_enabled = true
	flashlight = PointLight2D.new()
	flashlight.texture = CampLights.texture(true)
	flashlight.texture_scale = player.config.flashlight_range / 128.0
	flashlight.energy = 1.6
	flashlight.color = Color("fff1bf")
	flashlight.shadow_enabled = true
	flashlight.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	player.add_child(flashlight)


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var woods := CampMap.is_woods(player.global_position)
	ambient.color = player.config.night_ambient.lerp(Color(0.003, 0.008, 0.015, 1), 0.8 if woods else 0.0)
	nearby_glow.texture_scale = (25.0 if woods else 38.0) / 128.0
	flashlight.position = _safe_emitter(Vector2(0, -12) + player.facing * 8.0)
	nearby_glow.position = _safe_emitter(Vector2(0, -10))
	flashlight.rotation = player.facing.angle()
	flashlight.texture_scale = player.config.flashlight_range / 128.0 * (0.7 if woods and weather == "fog" else 1.0)
	flashlight.enabled = player.flashlight_on and player.status not in [CampPlayer.Status.BOARDED, CampPlayer.Status.ESCAPED, CampPlayer.Status.DEAD]
	nearby_glow.enabled = player.status not in [CampPlayer.Status.BOARDED, CampPlayer.Status.ESCAPED]


func _safe_emitter(offset: Vector2) -> Vector2:
	# A head-height sprite offset must not place the light beyond a nearby wall.
	var query := PhysicsRayQueryParameters2D.create(player.global_position, player.global_position + offset, 1)
	var hit := player.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return offset
	return player.to_local(hit["position"] + hit["normal"] * 1.5)
