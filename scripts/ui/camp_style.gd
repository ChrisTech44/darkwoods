class_name CampStyle
extends RefCounted


static func box(fill: String, border: String, padding: int = 4) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color(fill)
	result.border_color = Color(border)
	result.set_border_width_all(1)
	result.set_content_margin_all(padding)
	return result


## Nine-slice SpriteCook UI art (assets/sprites/sc/<name>.png); flat box fallback.
static func art(name: String, margin: int, padding: int, fallback: StyleBox) -> StyleBox:
	var path := "res://assets/sprites/sc/%s.png" % name
	if not ResourceLoader.exists(path):
		return fallback
	var result := StyleBoxTexture.new()
	result.texture = load(path)
	result.set_texture_margin_all(margin)
	result.set_content_margin_all(padding)
	return result


## Compact checkbox: inherited Button art would turn this rule into a full-width
## gold action bar. Keep a native check mark, keyboard focus and readable label.
static func abilities_toggle() -> CheckBox:
	var control := CheckBox.new()
	control.name = "CamperAbilities"
	control.text = "CAMPER ABILITIES"
	control.tooltip_text = "Passive + active powers. Host controls online."
	control.add_theme_font_size_override("font_size", 8)
	control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		control.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	control.add_theme_stylebox_override("focus", box("00000000", "e1c888", 0))
	return control


static func make() -> Theme:
	var result := Theme.new()
	result.default_font_size = 9
	for type in ["Label", "Button", "LineEdit", "OptionButton"]:
		result.set_color("font_color", type, Color("e7ddbb"))
	result.set_color("font_disabled_color", "Button", Color("6d7f75"))
	for type in ["Button", "OptionButton"]:
		result.set_stylebox("normal", type, art("ui_button", 7, 4, box("142422", "526852")))
		result.set_stylebox("hover", type, art("ui_button_hover", 7, 4, box("304637", "c7b77c")))
		result.set_stylebox("pressed", type, art("ui_button_hover", 7, 4, box("3b4d37", "e7c98d")))
		result.set_stylebox("disabled", type, art("ui_button", 7, 4, box("142422", "3a4a3a")))
		result.set_stylebox("focus", type, box("00000000", "e1c888", 0))
	result.set_stylebox("normal", "LineEdit", box("142422", "526852"))
	result.set_stylebox("focus", "LineEdit", box("00000000", "e1c888", 0))
	result.set_stylebox("panel", "PanelContainer", art("ui_panel", 9, 12, box("101d1cf5", "8b9471", 10)))
	return result
