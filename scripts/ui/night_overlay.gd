extends Node2D
## Real world lighting. CanvasLayer HUD remains unaffected by world darkness.

var player: CampPlayer
var flashlight: PointLight2D
var nearby_glow: PointLight2D
var ambient: CanvasModulate


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
	flashlight.position = Vector2(0, -12) + player.facing * 8.0
	flashlight.rotation = player.facing.angle()
	flashlight.enabled = player.flashlight_on and player.status not in [CampPlayer.Status.BOARDED, CampPlayer.Status.ESCAPED, CampPlayer.Status.DEAD]
	nearby_glow.enabled = player.status not in [CampPlayer.Status.BOARDED, CampPlayer.Status.ESCAPED]
