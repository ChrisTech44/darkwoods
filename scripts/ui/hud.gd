extends CanvasLayer

signal menu_requested
signal restart_requested
signal retry_requested

var title: Label
var prompt: Label
var stamina: ProgressBar
var pause_panel: PanelContainer
var result_panel: PanelContainer
var inventory_label: Label
var threat_label: Label
var location_label: Label
var chart: Control
var root: Control
var supplies_label: Label


func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_theme := CampStyle.make()
	ui_theme.set_color("font_color", "Label", Color("efe3ba"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101e22")
	style.border_color = Color("87946f")
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	ui_theme.set_stylebox("panel", "PanelContainer", style)
	root.theme = ui_theme
	add_child(root)
	title = _label(Vector2(9, 6), Vector2(366, 15), 10)
	prompt = _label(Vector2(9, 184), Vector2(366, 28), 9)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stamina = ProgressBar.new()
	stamina.position = Vector2(9, 25)
	stamina.size = Vector2(68, 6)
	supplies_label = _label(Vector2(83, 25), Vector2(107, 14), 7)
	threat_label = _label(Vector2(190, 25), Vector2(185, 14), 9)
	threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	threat_label.add_theme_color_override("font_color", Color("e7aa83"))
	stamina.show_percentage = false
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color("13252a")
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("a9af7d")
	stamina.add_theme_stylebox_override("background", bar_background)
	stamina.add_theme_stylebox_override("fill", bar_fill)
	root.add_child(stamina)
	stamina.size = Vector2(68, 6)
	inventory_label = _label(Vector2(9, 40), Vector2(366, 124), 8)
	var pack_style := style.duplicate() as StyleBoxFlat
	pack_style.bg_color = Color("101c1c")
	inventory_label.add_theme_stylebox_override("normal", pack_style)
	location_label = _label(Vector2(9, 169), Vector2(366, 12), 8)
	location_label.add_theme_color_override("font_color", Color("c3c6a1"))
	inventory_label.hide()
	chart = preload("res://scripts/ui/camp_chart.gd").new()
	chart.position = Vector2(216, 46)
	chart.size = Vector2(154, 112)
	root.add_child(chart)
	pause_panel = _panel("PAUSED", "Esc to resume", false)
	pause_panel.hide()
	result_panel = _panel("ROUND OVER", "", true)
	result_panel.hide()


func _label(at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	root.add_child(label)
	return label


func _panel(heading: String, detail: String, replay: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = Vector2(54, 26)
	panel.size = Vector2(276, 164)
	root.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var label := Label.new()
	label.name = "Heading"
	label.text = heading
	label.add_theme_font_size_override("font_size", 18)
	column.add_child(label)
	var description := Label.new()
	description.name = "Detail"
	description.text = detail
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(240, 25)
	column.add_child(description)
	if replay:
		var restart := Button.new()
		restart.name = "Restart"
		restart.text = "TRY ANOTHER NIGHT"
		restart.pressed.connect(_restart)
		column.add_child(restart)
		var retry := Button.new()
		retry.name = "Retry"
		retry.text = "RETRY THIS SEED"
		retry.pressed.connect(_retry)
		column.add_child(retry)
	var menu := Button.new()
	menu.name = "Menu"
	menu.text = "MAIN MENU"
	menu.pressed.connect(_menu)
	column.add_child(menu)
	return panel


func _restart() -> void:
	restart_requested.emit()


func _retry() -> void:
	retry_requested.emit()


func _menu() -> void:
	menu_requested.emit()


func set_status(heading: String, detail: String, energy: float) -> void:
	title.text = heading
	prompt.text = detail
	stamina.value = energy * 100.0


func show_pause(value: bool) -> void:
	pause_panel.visible = value
	if value:
		pause_panel.get_child(0).get_node("Menu").grab_focus()


func show_result(won: bool, detail: String) -> void:
	pause_panel.hide()
	result_panel.show()
	var column := result_panel.get_child(0)
	column.get_node("Heading").text = "DAWN AWAITS" if won else "LOST IN THE WOODS"
	column.get_node("Detail").text = detail
	column.get_node("Restart").grab_focus()
