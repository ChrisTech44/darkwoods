class_name StandingProps
extends Node2D
## Depth-sorted copies of tall SpriteCook props. Canvases that opt in (meta
## "stand_in_world") call PixelArt.draw_standing as usual, but instead of
## painting flat on the ground the prop becomes a Sprite2D in the level's
## y-sorted world, so survivors and monsters pass behind it when north of its
## base and in front when south. A prop a canvas stops drawing is hidden.

var world: Node2D
## key -> {sprite, canvas, touched}
var props: Dictionary = {}
## canvas id -> process frame of its latest draw
var drawn: Dictionary = {}


static func for_canvas(canvas: CanvasItem) -> StandingProps:
	if not canvas.is_inside_tree() or not canvas.has_meta("stand_in_world"):
		return null
	var level: Node = canvas.get_tree().get_first_node_in_group("round_world")
	if level == null or not level.has_node("StandingProps"):
		return null
	return level.get_node("StandingProps")


static func begin_draw(canvas: CanvasItem) -> void:
	var layer := for_canvas(canvas)
	if layer != null:
		layer.drawn[canvas.get_instance_id()] = Engine.get_process_frames()


func place(canvas: CanvasItem, name: String, texture: Texture2D, base: Vector2, modulate_color: Color) -> void:
	var at: Vector2 = canvas.global_transform * base
	var key := "%d:%d:%d" % [canvas.get_instance_id(), roundi(at.x), roundi(at.y)]
	var frame := Engine.get_process_frames()
	drawn[canvas.get_instance_id()] = frame
	var entry: Dictionary = props.get(key, {})
	if entry.is_empty():
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		entry = {"sprite": sprite, "canvas": canvas.get_instance_id(), "touched": frame}
		props[key] = entry
		world.add_child.call_deferred(sprite)
	var node: Sprite2D = entry["sprite"]
	node.texture = texture
	var size := texture.get_size()
	node.position = at.round()
	node.offset = (-Vector2(size.x * 0.5, size.y)).round()
	# Keep the source layer's look: e.g. the escape structures are unshaded
	# night silhouettes whose brightness depends on power and flashlights.
	node.material = canvas.material
	node.modulate = modulate_color * canvas.self_modulate
	node.visible = true
	node.set_meta("prop", name)
	entry["touched"] = frame
	# Silhouette layers (z >= 100) rise above the sight mask; keep that height.
	entry["z"] = canvas.z_index


func _process(delta: float) -> void:
	var level: Node = get_parent()
	var focus: Node2D = level.player if level != null and "player" in level and is_instance_valid(level.player) else null
	for key: String in props:
		var entry: Dictionary = props[key]
		var sprite: Sprite2D = entry["sprite"]
		# Hide props whose canvas redrew without them (e.g. a gate that opened).
		if drawn.get(entry["canvas"], -1) > entry["touched"]:
			sprite.visible = false
			continue
		# A tall prop standing in front of your survivor turns see-through.
		var behind := false
		var in_front := false
		if focus != null and sprite.texture != null:
			var area := Rect2(sprite.position + sprite.offset, sprite.texture.get_size())
			var feet: Vector2 = focus.global_position
			var overlapping := area.grow(-2).has_point(feet + Vector2(0, -10)) or area.grow(-2).has_point(feet + Vector2(0, -24))
			behind = feet.y < sprite.position.y and overlapping and area.size.y > 24
			in_front = feet.y >= sprite.position.y and overlapping
		# Silhouettes stay above the sight mask unless your survivor stands in
		# front of them, when depth order puts the survivor on top.
		var layer_z: int = entry.get("z", 0)
		sprite.z_index = 0 if layer_z < 100 or in_front else layer_z
		var target := 0.42 if behind else 1.0
		sprite.self_modulate.a = move_toward(sprite.self_modulate.a, target, delta * 4.0)
