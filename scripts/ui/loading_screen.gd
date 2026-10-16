extends Control
## Render a loading card before synchronous scene and procedural-world preparation.

const WORLD := "res://scenes/world/forest_level.tscn"
var elapsed: float = 0.0
var preparing: bool = false


func _ready() -> void:
	print(JSON.stringify({"event": "loading_started"}))


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed > 0.35 and not preparing:
		preparing = true
		_enter_world.call_deferred()


func _enter_world() -> void:
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(true)
	var scene: PackedScene = load(WORLD)
	get_tree().change_scene_to_packed(scene)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 384, 216), Color("070f13"))
	for x in range(-16, 400, 32):
		draw_texture_rect(preload("res://assets/sprites/pine_0.png"), Rect2(x, 32 + x % 17, 48, 60), false, Color("3b5046"))
	draw_line(Vector2(35, 111), Vector2(349, 111), Color("3d5249"))
	draw_string(ThemeDB.fallback_font, Vector2(34, 101), "THE LAST SAFE LIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("e5d5af"))
	draw_string(ThemeDB.fallback_font, Vector2(35, 128), "PREPARING THE WOODS..." if preparing else "FOLLOWING THE TRAIL...", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("9aaa8d"))
	draw_rect(Rect2(35, 140, 314, 4), Color("20332e"))
	# An activity indicator, not a fabricated resource-loading percentage.
	draw_rect(Rect2(35 + fmod(elapsed * 90, 270), 140, 44, 4), Color("c6a96e"))
	var tip := "Run from the howl. Walk when it goes quiet."
	if int(elapsed) % 3 == 1:
		tip = "A flare scares teeth. It also attracts wings."
	draw_string(ThemeDB.fallback_font, Vector2(35, 174), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("c4bfa0"))
	draw_string(ThemeDB.fallback_font, Vector2(35, 197), "FERNWOOD / AFTER DARK", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("647a70"))
