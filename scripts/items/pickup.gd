class_name CampPickup
extends Node2D

var kind: String = "battery"
var locked: bool = false
var available: bool = true:
	set(value):
		if value == available:
			return
		available = value
		# Neighbours re-title their pile ("FLARE ×3") when one appears or goes.
		if is_inside_tree():
			for other: CampPickup in get_parent().get_children().filter(func(node: Node) -> bool: return node is CampPickup and node != self and node.position.distance_to(position) < 40.0):
				other.queue_redraw()


func consume() -> void:
	available = false
	hide()


func _draw() -> void:
	# SpriteCook icons (padlocked crate for caches); procedural fallback below.
	if locked and PixelArt.draw_in(self, "cache_crate", Rect2(-12, -12, 24, 22)):
		draw_string(ThemeDB.fallback_font, Vector2(-21, -15), "LOCKED CACHE", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("c4b58e"))
		return
	var icon_name: String = {"rescue_fuse":"fuse", "outboard_motor":"outboard_motor", "boat_fuel":"boat_fuel", "drain_plug":"spark_plug", "gate_code_1":"f5_codes", "gate_code_2":"f5_codes", "gate_code_3":"f5_codes"}.get(kind,kind)
	var icon := PixelArt.fit(icon_name, Vector2(16, 16)) if not locked else null
	if icon != null:
		draw_circle(Vector2(0, 1), 9, Color(0.8, 0.85, 0.6, 0.1))
		draw_texture(icon, (-icon.get_size() * 0.5).round())
		if _labelled():
			var title := "EMERGENCY FUSE" if kind == "rescue_fuse" else kind.trim_suffix("_1").trim_suffix("_2").replace("_", " ").to_upper()
			draw_string(ThemeDB.fallback_font, Vector2(-16, -12), _pile_title(title), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("d8d0a8"))
		return
	if locked:
		draw_rect(Rect2(-10, -9, 20, 16), Color("947b51"))
		draw_line(Vector2(-9, -8), Vector2(9, 6), Color("c0a672"), 2)
		draw_rect(Rect2(-3, -5, 6, 7), Color("d1c19a"))
		draw_circle(Vector2(0, -2), 1, Color("494d3b"))
		draw_string(ThemeDB.fallback_font, Vector2(-21, -14), "LOCKED CACHE", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("c4b58e"))
		return
	var color := Color("94c9c3")
	if kind == "fuel":
		color = Color("d6a363")
	elif kind == "key":
		color = Color("e6dc8f")
	draw_circle(Vector2.ZERO, 9, Color(0.8, 0.85, 0.6, 0.1))
	if kind == "battery":
		draw_rect(Rect2(-5, -4, 10, 8), color)
		draw_rect(Rect2(-3, -6, 2, 2), color)
		draw_line(Vector2(1, -1), Vector2(3, -1), Color("253e3b"))
	elif kind == "fuel":
		draw_rect(Rect2(-4, -5, 8, 10), color)
		draw_line(Vector2(-2, -7), Vector2(3, -7), color, 2)
		draw_line(Vector2(-2, 2), Vector2(2, -2), Color("754b3c"), 2)
	elif kind == "noise_tin":
		draw_rect(Rect2(-5,-6,10,12),Color("a6b8b2"))
		for y in [-5,0,4]:
			draw_line(Vector2(-5,y),Vector2(5,y),Color("e3c9a1"))
		draw_line(Vector2(-4,-8),Vector2(4,-8),Color("ac8060"),2)
	elif kind == "salt_ward":
		draw_circle(Vector2.ZERO,6,Color("aa9277"))
		draw_rect(Rect2(-4,-4,8,7),Color("e2ddc2"))
		draw_line(Vector2(-3,-7),Vector2(3,-7),Color("645540"),2)
	elif kind == "glow_moss":
		for index in range(6):
			draw_line(Vector2(index*2-6,5),Vector2(index*2-7,-4-index%2*3),Color("95bd86"),2)
			draw_circle(Vector2(index*2-7,-4-index%2*3),2,Color("d5e7a9"))
	elif kind == "flare":
		draw_rect(Rect2(-2,-7,4,13),Color("bf7455"))
		draw_rect(Rect2(-3,-7,6,3),Color("e2c185"))
	elif kind == "battery_pack":
		draw_rect(Rect2(-5,-5,10,10),Color("849995"))
		draw_rect(Rect2(-3,-7,6,2),Color("d4c7a0"))
		draw_line(Vector2(-2,0),Vector2(2,0),Color("e9dca9"))
	elif kind == "rations":
		draw_rect(Rect2(-5,-5,10,10),Color("a58b61"))
		draw_rect(Rect2(-4,-2,8,4),Color("d3c29a"))
	elif kind == "ranger_note":
		draw_rect(Rect2(-5, -6, 10, 12), Color("e8dfc0"))
		draw_rect(Rect2(-5, -6, 10, 2), Color("b55b45"))
		for y in [-2, 1, 4]:
			draw_line(Vector2(-3, y), Vector2(3, y), Color("7a705a"))
		draw_string(ThemeDB.fallback_font, Vector2(-22, -12), "RANGER NOTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("e8dfc0"))
		return
	elif kind == "boltcutters":
		draw_line(Vector2(-6, 5), Vector2(1, -2), Color("c7744f"), 2)
		draw_line(Vector2(6, 5), Vector2(-1, -2), Color("c7744f"), 2)
		draw_line(Vector2(-1, -2), Vector2(2, -7), Color("b8c0b4"), 2)
		draw_line(Vector2(1, -2), Vector2(-2, -7), Color("b8c0b4"), 2)
	elif kind == "crowbar":
		draw_line(Vector2(-6, 6), Vector2(4, -5), Color("b2463c"), 2)
		draw_line(Vector2(4, -5), Vector2(7, -3), Color("b2463c"), 2)
	elif kind not in ["battery", "fuel", "key"]:
		draw_rect(Rect2(-5, -5, 10, 10), Color("a4b49b"))
		draw_line(Vector2(-3, 0), Vector2(3, 0), Color("485c51"), 2)
		draw_line(Vector2(0, -3), Vector2(0, 3), Color("485c51"), 2)
	else:
		draw_circle(Vector2(-3, 0), 3, color)
		draw_line(Vector2(-1, 0), Vector2(6, 0), color, 2)
		draw_line(Vector2(5, 0), Vector2(5, 3), color, 2)
	if _labelled():
		draw_string(ThemeDB.fallback_font, Vector2(-16, -12), _pile_title(kind.to_upper()), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)


## Unlocked items lying within 40 px of this one (any kind).
func _pile() -> Array:
	return get_parent().get_children().filter(func(other: Node) -> bool:
		return other != self and other is CampPickup and other.available and not other.locked and other.position.distance_to(position) < 40.0)


## One label per pile, owned by its top-left item (ties broken by instance id),
## so stacked or mixed supplies never print a word for every unit.
func _labelled() -> bool:
	for other: CampPickup in _pile():
		if other.position.x < position.x or (other.position.x == position.x and (other.position.y < position.y or (other.position.y == position.y and other.get_instance_id() < get_instance_id()))):
			return false
	return true


## "FLARE", "FLARE ×3" or, for a mixed pile, "SUPPLIES ×5".
func _pile_title(title: String) -> String:
	var pile := _pile()
	if pile.is_empty():
		return title
	var same := pile.all(func(other: CampPickup) -> bool: return other.kind == kind)
	return "%s ×%d" % [title if same else "SUPPLIES", pile.size() + 1]
