extends Control
## Boot screen. Offline gameplay is available; networking arrives in M2.

@onready var session: Node = get_node("/root/Session")
@onready var controls_button: Button = $Menu/Controls
@onready var controls_panel: PanelContainer = $ControlsPanel
@onready var back_button: Button = $ControlsPanel/Margin/Content/Back


func _ready() -> void:
	theme = CampStyle.make()
	$Menu/Mode.add_item("WOODS EXPEDITION")
	$Menu/Mode.add_item("QUICK CAMP")
	$Menu/Mode.select(1 if session.mode == "camp" else 0)
	controls_button.pressed.connect(_show_controls)
	$Menu/Play.pressed.connect(_play)
	back_button.pressed.connect(_hide_controls)
	$Menu/Quit.pressed.connect(get_tree().quit)
	controls_button.grab_focus()
	print(JSON.stringify({"event": "menu_ready", "milestone": "M1"}))


func _play() -> void:
	session.mode = "camp" if $Menu/Mode.selected == 1 else "woods"
	session.next_seed = clampi(int($Menu/Seed.text), 0, 2147483646)
	session.load_game()


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
