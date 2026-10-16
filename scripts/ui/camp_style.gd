class_name CampStyle
extends RefCounted


static func box(fill: String, border: String, padding: int = 4) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color(fill)
	result.border_color = Color(border)
	result.set_border_width_all(1)
	result.set_content_margin_all(padding)
	return result


static func make() -> Theme:
	var result := Theme.new()
	result.default_font_size = 9
	for type in ["Label", "Button", "LineEdit", "OptionButton"]:
		result.set_color("font_color", type, Color("e7ddbb"))
	result.set_color("font_disabled_color", "Button", Color("6d7f75"))
	for type in ["Button", "OptionButton", "LineEdit"]:
		result.set_stylebox("normal", type, box("142422", "526852"))
		result.set_stylebox("hover", type, box("304637", "c7b77c"))
		result.set_stylebox("pressed", type, box("3b4d37", "e7c98d"))
		result.set_stylebox("focus", type, box("00000000", "e1c888", 0))
	result.set_stylebox("panel", "PanelContainer", box("101d1cf5", "8b9471", 10))
	return result
