extends Control
## Boot screen. Offline gameplay is available; networking arrives in M2.

var quitting := false

@onready var session: Node = get_node("/root/Session")
@onready var controls_button: Button = $Menu/Controls
@onready var controls_panel: PanelContainer = $ControlsPanel
@onready var back_button: Button = $ControlsPanel/Margin/Content/Back


func _ready() -> void:
	theme = CampStyle.make()
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
	panel.position = Vector2(54, 26)
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
	$Settings.pressed.connect(_show_settings)
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
	session.load_game()


func _random_toggled(enabled: bool) -> void:
	$Menu/Seed.editable = not enabled
	$Menu/Seed.placeholder_text = "AUTO: FRESH NIGHT" if enabled else "SEED (OPTIONAL)"
	if enabled:
		$Menu/Seed.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and controls_panel.visible:
		_hide_controls()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and $SettingsPanel.visible:
		_hide_settings()
		get_viewport().set_input_as_handled()


func _show_controls() -> void:
	$Menu.hide()
	$Settings.hide()
	controls_panel.show()
	back_button.grab_focus()


func _hide_controls() -> void:
	controls_panel.hide()
	$Menu.show()
	$Settings.show()
	controls_button.grab_focus()


func _quit() -> void:
	if quitting:
		return
	quitting = true
	await get_node("/root/AudioManager").prepare_shutdown()
	get_tree().quit()


func _show_settings() -> void:
	$Menu.hide()
	$Settings.hide()
	$SettingsPanel.show()
	$SettingsPanel/Content/Back.grab_focus()

func _hide_settings() -> void:
	$SettingsPanel.hide()
	$Menu.show()
	$Settings.show()
	$Settings.grab_focus()
