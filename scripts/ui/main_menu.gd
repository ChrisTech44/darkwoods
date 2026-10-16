extends Control
## Boot screen. Offline gameplay is available; networking arrives in M2.

@onready var controls_button: Button = $Menu/Controls
@onready var controls_panel: PanelContainer = $ControlsPanel
@onready var back_button: Button = $ControlsPanel/Margin/Content/Back


func _ready() -> void:
	var menu_theme := Theme.new()
	menu_theme.default_font_size = 10
	menu_theme.set_color("font_color", "Label", Color("e5dfbf"))
	menu_theme.set_color("font_color", "Button", Color("e5dfbf"))
	menu_theme.set_color("font_disabled_color", "Button", Color("6c7970"))
	menu_theme.set_stylebox("normal", "Button", _box("1a2c2c", "495d50"))
	menu_theme.set_stylebox("hover", "Button", _box("304338", "a5b481"))
	menu_theme.set_stylebox("pressed", "Button", _box("3f5542", "d2cc9b"))
	menu_theme.set_stylebox("disabled", "Button", _box("111d20", "283b34"))
	menu_theme.set_stylebox("focus", "Button", _box("00000000", "d2cc9b"))
	menu_theme.set_stylebox("panel", "PanelContainer", _box("101e22", "6d8060"))
	theme = menu_theme
	controls_button.pressed.connect(_show_controls)
	$Menu/Play.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/world/forest_level.tscn"))
	back_button.pressed.connect(_hide_controls)
	$Menu/Quit.pressed.connect(get_tree().quit)
	controls_button.grab_focus()
	print(JSON.stringify({"event": "menu_ready", "milestone": "M1"}))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and controls_panel.visible:
		_hide_controls()
		get_viewport().set_input_as_handled()


func _show_controls() -> void:
	$Menu.hide()
	controls_panel.show()
	back_button.grab_focus()


func _hide_controls() -> void:
	controls_panel.hide()
	$Menu.show()
	controls_button.grab_focus()


func _box(fill: String, border: String) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(fill)
	box.border_color = Color(border)
	box.set_border_width_all(1)
	return box
