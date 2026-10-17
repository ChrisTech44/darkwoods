extends CanvasLayer

signal menu_requested
signal restart_requested
signal retry_requested

var title: Label
var prompt: Label
var stamina: ProgressBar
## Survivor health (0–100) above stamina, and a red edge flash when hit.
var health: ProgressBar
var health_fill: StyleBoxFlat
var hurt_flash: ColorRect
var pause_panel: PanelContainer
var result_panel: PanelContainer
var inventory_label: Label
var threat_label: Label
var location_label: Label
var chart: Control
var root: Control
var belt_labels: Array[Label] = []
var belt_icons: Array[TextureRect] = []
var supplies_label: Label
## Proximity voice: who is talking nearby, and your own mic state.
var voice_label: Label
## F6 active ability state, e.g. "X MARK READY · H GIVE".
var ability_label: Label


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
	for index in range(6):
		var slot := _label(Vector2(9 + index * 61, 150), Vector2(59, 17), 7)
		slot.add_theme_stylebox_override("normal", CampStyle.art("ui_slot", 6, 3, CampStyle.box("101e22ee", "63705b", 2)))
		belt_labels.append(slot)
		var icon := TextureRect.new()
		icon.position = Vector2(44, 2)
		icon.size = Vector2(13, 13)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.add_child(icon)
		belt_icons.append(icon)
	prompt = _label(Vector2(9, 184), Vector2(366, 28), 9)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hurt_flash = ColorRect.new()
	hurt_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_flash.color = Color(0.6, 0.05, 0.04, 0.0)
	root.add_child(hurt_flash)
	root.move_child(hurt_flash, 0)
	health = ProgressBar.new()
	health.position = Vector2(9, 22)
	health.show_percentage = false
	var health_background := StyleBoxFlat.new()
	health_background.bg_color = Color("2a1416")
	health_fill = StyleBoxFlat.new()
	health_fill.bg_color = Color("c4544a")
	health.add_theme_stylebox_override("background", health_background)
	health.add_theme_stylebox_override("fill", health_fill)
	health.value = 100.0
	root.add_child(health)
	health.size = Vector2(68, 5)
	stamina = ProgressBar.new()
	stamina.position = Vector2(9, 28)
	stamina.size = Vector2(68, 3)
	supplies_label = _label(Vector2(83, 25), Vector2(107, 14), 7)
	threat_label = _label(Vector2(190, 25), Vector2(185, 14), 9)
	threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	threat_label.add_theme_color_override("font_color", Color("e7aa83"))
	ability_label = _label(Vector2(9, 33), Vector2(180, 10), 7)
	ability_label.add_theme_color_override("font_color", Color("c9d7a4"))
	voice_label = _label(Vector2(190, 37), Vector2(185, 10), 7)
	voice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	voice_label.add_theme_color_override("font_color", Color("a9c8d6"))
	stamina.show_percentage = false
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color("13252a")
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("a9af7d")
	stamina.add_theme_stylebox_override("background", bar_background)
	stamina.add_theme_stylebox_override("fill", bar_fill)
	root.add_child(stamina)
	stamina.size = Vector2(68, 3)
	inventory_label = _label(Vector2(9, 40), Vector2(366, 104), 8)
	var pack_style := style.duplicate() as StyleBoxFlat
	pack_style.bg_color = Color("101c1c")
	inventory_label.add_theme_stylebox_override("normal", CampStyle.art("ui_panel", 9, 10, pack_style))
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


func _process(_delta: float) -> void:
	var voice: Node = get_node_or_null("/root/Voice")
	if voice == null or voice_label == null:
		return
	var parts: Array[String] = []
	var heard: Array[String] = voice.speaking_names()
	if not heard.is_empty():
		parts.append("VOICE: " + ", ".join(heard).to_upper())
	if voice.capturing:
		parts.append("● TALKING" if voice.talking else ("B: TALK" if voice.mode == "push" else "MIC OPEN"))
	voice_label.text = "  ".join(parts)


func _label(at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	root.add_child(label)
	label.position = at
	label.size = dimensions
	return label


func _panel(heading: String, detail: String, replay: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = Vector2(54, 10)
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
	if not replay:
		# The mixer plus voice rows are tall: keep the pause panel compact.
		panel.position = Vector2(54, 2)
		label.add_theme_font_size_override("font_size", 13)
		description.add_theme_font_size_override("font_size", 7)
		description.custom_minimum_size = Vector2(240, 10)
		column.add_theme_constant_override("separation", 1)
		column.add_child(preload("res://scripts/ui/audio_controls.gd").new())
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


## Health bar turns from red to a pulsing deep red when wounded; a hit flashes the edges.
func set_health(value: float, wounded: bool, hurt: float) -> void:
	health.value = value
	health_fill.bg_color = Color("8f2a26").lerp(Color("e0574a"), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)) if wounded else Color("c4544a")
	hurt_flash.color.a = clampf(hurt, 0.0, 0.6) * 0.45


func show_pause(value: bool) -> void:
	pause_panel.visible = value
	if value:
		pause_panel.get_child(0).get_node("Menu").grab_focus()


func show_result(won: bool, detail: String) -> void:
	pause_panel.hide()
	result_panel.show()
	var column := result_panel.get_child(0)
	column.get_node("Heading").text = "YOU GOT OUT" if won else "LOST IN THE WOODS"
	column.get_node("Detail").text = detail
	# Scores, awards and badges make the summary long: widen and compact it.
	result_panel.position = Vector2(10, 4)
	result_panel.size = Vector2(364, 0)
	column.get_node("Heading").add_theme_font_size_override("font_size", 13)
	column.get_node("Detail").add_theme_font_size_override("font_size", 7)
	column.get_node("Detail").custom_minimum_size = Vector2(344, 25)
	column.add_theme_constant_override("separation", 2)
	if column.get_node("Restart").disabled:
		column.get_node("Menu").grab_focus()
	else:
		column.get_node("Restart").grab_focus()


func update_belt(actor: CampPlayer) -> void:
	var short := {"flare":"FLARE", "battery_pack":"CELL", "rations":"FOOD", "medkit":"MEDKIT", "noise_tin":"TIN", "salt_ward":"SALT", "glow_moss":"MOSS"}
	for index in range(6):
		var kind := actor.belt[index]
		belt_labels[index].text = "%s%d %s" % [">" if actor.selected_slot == index else "", index+1, short.get(kind, "--")]
		belt_labels[index].modulate = Color("ffe3a3") if actor.selected_slot == index else Color("a0b69e")
		var selected := actor.selected_slot == index
		if not belt_labels[index].has_meta("selected") or belt_labels[index].get_meta("selected") != selected:
			belt_labels[index].set_meta("selected", selected)
			belt_labels[index].add_theme_stylebox_override("normal", CampStyle.art("ui_slot_selected" if selected else "ui_slot", 6, 3, CampStyle.box("101e22ee", "63705b", 2)))
		belt_icons[index].texture = PixelArt.fit(kind, Vector2(13, 13)) if not kind.is_empty() else null
		belt_icons[index].self_modulate = Color.WHITE / belt_labels[index].modulate if not kind.is_empty() else Color.WHITE
