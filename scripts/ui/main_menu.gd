extends Control
## Boot screen. Offline gameplay is available; networking arrives in M2.

var quitting := false

@onready var session: Node = get_node("/root/Session")
@onready var controls_button: Button = $Menu/Controls
@onready var controls_panel: PanelContainer = $ControlsPanel
@onready var back_button: Button = $ControlsPanel/Margin/Content/Back


func _ready() -> void:
	theme = CampStyle.make()
	var online := Button.new()
	online.name="Online"
	online.text="HOST / JOIN CO-OP"
	online.add_theme_font_size_override("font_size",8)
	online.custom_minimum_size=Vector2(116,19)
	$Menu.add_child(online)
	$Menu.move_child(online,$Menu/Play.get_index()+1)
	online.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/network_lobby.tscn"))
	if not session.notice.is_empty():
		$Status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		$Status.size=Vector2(344,24)
		$Status.text=session.notice
		session.notice=""
	$Menu/Mode.add_item("WOODS EXPEDITION")
	$Menu/Mode.add_item("QUICK CAMP")
	$Menu/Mode.select(1 if session.mode == "camp" else 0)
	var audio := preload("res://scripts/ui/menu_audio.gd").new()
	audio.name = "MenuAudio"
	add_child(audio)
	var knobs := preload("res://scripts/ui/audio_controls.gd").new()
	knobs.name = "AudioControls"
	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.position = Vector2(54, 10)
	panel.size = Vector2(276, 164)
	add_child(panel)
	var content := VBoxContainer.new()
	content.name = "Content"
	panel.add_child(content)
	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.add_theme_font_size_override("font_size", 18)
	content.add_child(heading)
	content.add_child(knobs)
	var back := Button.new()
	back.name = "Back"
	back.text = "BACK TO CAMP"
	back.pressed.connect(_hide_settings)
	content.add_child(back)
	panel.hide()
	$Menu/Settings.pressed.connect(_show_settings)
	$Menu/RandomNight.toggled.connect(_random_toggled)
	_random_toggled(true)
	controls_button.pressed.connect(_show_controls)
	$Menu/Play.pressed.connect(_play)
	back_button.pressed.connect(_hide_controls)
	$Menu/Quit.pressed.connect(_quit)
	controls_button.grab_focus()
	print(JSON.stringify({"event": "menu_ready", "milestone": "M1"}))


func _play() -> void:
	session.mode = "camp" if $Menu/Mode.selected == 1 else "woods"
	session.next_seed = 0 if $Menu/RandomNight.button_pressed else clampi(int($Menu/Seed.text), 0, 2147483646)
	_show_survivors()


func _random_toggled(enabled: bool) -> void:
	$Menu/Seed.editable = not enabled
	$Menu/Seed.placeholder_text = "AUTO: FRESH NIGHT" if enabled else "SEED (OPTIONAL)"
	if enabled:
		$Menu/Seed.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and controls_panel.visible:
		_hide_controls()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and has_node("SurvivorSelection") and $SurvivorSelection.visible:
		$SurvivorSelection/Back.pressed.emit()
	elif event.is_action_pressed("pause") and $SettingsPanel.visible:
		_hide_settings()
		get_viewport().set_input_as_handled()


func _show_controls() -> void:
	$Menu/Online.hide()
	$Menu.hide()
	$Menu/Settings.hide()
	controls_panel.show()
	back_button.grab_focus()


func _hide_controls() -> void:
	controls_panel.hide()
	$Menu/Online.show()
	$Menu.show()
	$Menu/Settings.show()
	controls_button.grab_focus()


func _quit() -> void:
	if quitting:
		return
	quitting = true
	await get_node("/root/AudioManager").prepare_shutdown()
	get_tree().quit()


func _show_settings() -> void:
	$Menu/Online.hide()
	$Menu.hide()
	$Menu/Settings.hide()
	$SettingsPanel.show()
	$SettingsPanel/Content/Back.grab_focus()

func _hide_settings() -> void:
	$SettingsPanel.hide()
	$Menu/Online.show()
	$Menu.show()
	$Menu/Settings.show()
	$Menu/Settings.grab_focus()
	if has_node("SurvivorSelection"):
		$Menu/Online.hide()
		$Menu.hide()
		$Menu/Settings.hide()
		$SurvivorSelection.show()
		$SurvivorSelection/Settings.grab_focus()


func _show_survivors() -> void:
	$Menu/Online.hide()
	$Menu.hide()
	$Menu/Settings.hide()
	if has_node("SurvivorSelection"):
		$SurvivorSelection.show()
		$SurvivorSelection/Start.grab_focus()
		return
	var selection := Control.new()
	selection.name = "SurvivorSelection"
	selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(selection)
	var background := ColorRect.new()
	background.color = Color("101d20")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection.add_child(background)
	var heading := Label.new()
	heading.text = "CHOOSE YOUR SURVIVOR"
	heading.position = Vector2(14, 8)
	heading.add_theme_font_size_override("font_size", 17)
	selection.add_child(heading)
	var detail := Label.new()
	detail.name = "Detail"
	detail.position = Vector2(155, 70)
	detail.size = Vector2(218, 84)
	detail.add_theme_font_size_override("font_size", 10)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection.add_child(detail)
	var preview := TextureRect.new()
	preview.name = "Preview"
	preview.position = Vector2(243, 31)
	preview.size = Vector2(24, 32)
	preview.scale = Vector2(1.5, 1.5)
	selection.add_child(preview)
	for index in range(6):
		var button := Button.new()
		button.name = SurvivorRoster.IDS[index]
		button.text = SurvivorRoster.NAMES[index]
		selection.add_child(button)
		button.add_theme_font_size_override("font_size",10)
		button.position = Vector2(14, 34 + index * 24)
		button.size = Vector2(132, 23)
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(_select_survivor.bind(index))
	var labels := ["BACK", "RANDOM SURVIVOR", "START NIGHT", "SETTINGS"]
	for index in range(4):
		var button := Button.new()
		button.name = ["Back", "Random", "Start", "Settings"][index]
		button.text = labels[index]
		selection.add_child(button)
		button.add_theme_font_size_override("font_size",10)
		button.position = [Vector2(14,184), Vector2(155,157), Vector2(155,184), Vector2(285,184)][index]
		button.size = Vector2(126 if index < 3 else 88, 23)
		button.add_theme_font_size_override("font_size", 10)
	selection.get_node("Back").pressed.connect(func():
		selection.hide()
		$Menu/Online.show()
		$Menu.show()
		$Menu/Settings.show()
		$Menu/Play.grab_focus())
	selection.get_node("Random").pressed.connect(func(): _select_survivor(randi_range(0,5)))
	selection.get_node("Start").pressed.connect(func(): session.load_game())
	selection.get_node("Settings").pressed.connect(func():
		selection.hide()
		_show_settings())
	_select_survivor(SurvivorRoster.IDS.find(session.survivor))
	selection.get_node(session.survivor).grab_focus()

func _select_survivor(index: int) -> void:
	session.select_survivor(SurvivorRoster.IDS[index])
	$SurvivorSelection/Detail.text = SurvivorRoster.NAMES[index] + "\n" + SurvivorRoster.DETAILS[index]
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/survivor_" + session.survivor + ".png")
	atlas.region = Rect2(0, 0, 24, 32)
	$SurvivorSelection/Preview.texture = atlas
	for id in SurvivorRoster.IDS:
		$SurvivorSelection.get_node(id).modulate = Color("e7c98a") if id == session.survivor else Color.WHITE


func _process(_delta: float) -> void:
	if has_node("SurvivorSelection") and $SurvivorSelection.visible:
		var atlas: AtlasTexture = $SurvivorSelection/Preview.texture
		atlas.region.position.x = int(Time.get_ticks_msec()/350) % 3 * 24
