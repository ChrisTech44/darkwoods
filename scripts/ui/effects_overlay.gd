class_name EffectsOverlay
extends Control
## What creature effects feel like on your own screen: the Paparazzo's white
## flash, a moth on your face, the Lullaby's drowsy dim and sleep, the Vampire's
## red pull, being held (MASH E with a struggle bar) and a row of badges for
## everything else currently on you.

const MOTH := preload("res://assets/sprites/lantern_moth.png")
var player: CampPlayer
var shook := false


func _process(_delta: float) -> void:
	queue_redraw()
	# The stalker hitching you up on his shoulder shakes the view.
	if player != null and is_instance_valid(player) and player.has_node("Camera2D"):
		var camera: Camera2D = player.get_node("Camera2D")
		if player.has_effect("jolted"):
			camera.offset = Vector2(randf_range(-4, 4), randf_range(-3, 3))
			shook = true
		elif shook:
			camera.offset = Vector2.ZERO
			shook = false


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	# The moon is out: werewolves are changing (top right, under the title row).
	var world: Node = player.get_tree().get_first_node_in_group("round_world")
	if world != null and world.night_clock != null and world.night_clock.moon:
		var glow := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.004)
		PixelArt.draw_in(self, "moon_icon", Rect2(size.x - 24, 22, 14, 14), Color(1, 1, 1, glow))
	if player.status != CampPlayer.Status.ALIVE:
		return
	var screen := Rect2(Vector2.ZERO, size)
	var t := Time.get_ticks_msec() * 0.001
	var fx: Dictionary = player.effects
	if fx.get("drowsy", 0.0) > 0.0 and not player.has_effect("coffee"):
		_vignette(Color(0.02, 0.02, 0.06), 0.55)
	if fx.get("hypnotized", 0.0) > 0.0:
		_vignette(Color(0.5, 0.0, 0.05), 0.45 + 0.15 * sin(t * 6.0))
	if fx.get("asleep", 0.0) > 0.0:
		draw_rect(screen, Color(0, 0, 0.02, 0.82))
		_centered("Z z z . . .", size.y * 0.45, 12, Color(0.75, 0.8, 1.0, 0.8))
	if fx.get("face_moth", 0.0) > 0.0:
		# A moth over your eyes, wings beating.
		var beat := 0.85 + 0.15 * sin(t * 18.0)
		var box := Vector2(size.x * 0.7 * beat, size.y * 1.1)
		draw_texture_rect_region(MOTH, Rect2(size * 0.5 - box * 0.5 + Vector2(0, -10), box), Rect2(0, 0, 64, 64), Color(0.8, 0.75, 0.65))
		_centered("SPACE · SWAT IT", size.y - 70.0, 9, Color("f4d3a0"))
	if fx.get("whiteout", 0.0) > 0.0:
		draw_rect(screen, Color(1, 1, 0.97, clampf(fx["whiteout"], 0.0, 1.0)))
	if player.has_effect("held"):
		var label := "HELD BY %s" % str(player.effect_data.get("held_by", "SOMETHING")).to_upper()
		_centered(label + " · MASH E", 58.0, 10, Color("f1b08a"))
		var bar := Rect2(size.x * 0.5 - 50, 66, 100, 5)
		draw_rect(bar, Color("2a1416"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * player.struggle, bar.size.y)), Color("e0a060"))
	if player.has_effect("achoo"):
		_centered("ACHOO!", size.y * 0.42, 12, Color("f4e6b0"))
	# Badges for everything else on you.
	var badges: Array[String] = []
	for name: String in fx:
		if name in ["held", "drowsy", "asleep", "whiteout", "face_moth", "achoo"] or not CampPlayer.EFFECT_NAMES.has(name):
			continue
		badges.append("%s %ds" % [CampPlayer.EFFECT_NAMES[name], ceili(fx[name])])
	if not badges.is_empty():
		var text := "  ".join(badges)
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 9 - ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x, 144), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("d7c4f0"))


func _vignette(tint: Color, strength: float) -> void:
	for ring in range(6):
		var inset := ring * 9.0
		var alpha := strength * (1.0 - ring / 6.0) * 0.35
		var c := Color(tint, alpha)
		draw_rect(Rect2(inset, inset, size.x - inset * 2, 9), c)
		draw_rect(Rect2(inset, size.y - inset - 9, size.x - inset * 2, 9), c)
		draw_rect(Rect2(inset, inset + 9, 9, size.y - inset * 2 - 18), c)
		draw_rect(Rect2(size.x - inset - 9, inset + 9, 9, size.y - inset * 2 - 18), c)


func _centered(text: String, y: float, font_size: int, tint: Color) -> void:
	var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(ThemeDB.fallback_font, Vector2((size.x - width) * 0.5 + 1, y + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.7))
	draw_string(ThemeDB.fallback_font, Vector2((size.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
