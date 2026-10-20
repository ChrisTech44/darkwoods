extends Control
## Name, address and port are remembered between nights and launches.
const PREFS := "user://lobby.cfg"
## Tests point this elsewhere so they never touch a player's saved name.
static var prefs_path := PREFS
var net: Node
var fields := {}
var roster_label: Label
var message: Label
var ready_button: Button
var start_button: Button
var last_refresh := 0.0
var voice_meters: VoiceMeters


## Lobby voice at a glance: a mic meter for you beside the title, and a
## speaker meter at the end of each roster row that lights while they talk.
class VoiceMeters extends Control:
	var roster: Label
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var voice: Node = get_node_or_null("/root/Voice")
		var net: Node = get_node("/root/Net")
		if voice == null or roster == null:
			return
		var mine := Rect2(Vector2(282, 9), Vector2(88, 13))
		draw_rect(mine, Color(0.04, 0.08, 0.09, 0.85))
		draw_rect(mine, Color("63705b"), false, 1.0)
		var label := "MIC OFF" if voice.mode == "off" else ("RESTART FOR MIC" if not voice.mic_ready and not voice.test_input else ("HOLD B" if voice.mode == "push" else "OPEN MIC"))
		if voice.talking:
			label = "TALKING"
		draw_string(ThemeDB.fallback_font, mine.position + Vector2(4, 10), label, HORIZONTAL_ALIGNMENT_LEFT, 46, 7, Color("a9e0a0") if voice.talking else Color("a9c8d6"))
		var bar := Rect2(mine.position + Vector2(50, 4), Vector2(34, 5))
		draw_rect(bar, Color("13252a"))
		var level := clampf(voice.mic_level * 2.0, 0.0, 1.0) if voice.mode != "off" else 0.0
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * level, bar.size.y)), Color("8fd17f") if voice.talking else Color("6f8f7a"))
		if voice.mode == "open":
			var mark := bar.position.x + bar.size.x * clampf(voice.threshold * 2.0, 0.0, 1.0)
			draw_line(Vector2(mark, bar.position.y - 1), Vector2(mark, bar.end.y + 1), Color("e7c98a"))
		# One speaker meter per roster row, in the roster's order and line height.
		var ids: Array = net.roster.keys()
		ids.sort()
		var heard: Array = voice.speaking_ids()
		var row: float = roster.get_line_height() + roster.get_theme_constant("line_spacing")
		for index in range(ids.size()):
			var id: int = ids[index]
			var me: bool = id == multiplayer.get_unique_id()
			var live: bool = voice.talking if me else id in heard
			var amount: float = clampf((voice.mic_level if me else voice.output_peak(id)) * 2.0, 0.0, 1.0)
			var at := roster.position + Vector2(roster.size.x - 22, index * row + (row - 7.0) * 0.5 + 1.0)
			var tint := Color("8fd17f") if live else Color("4d5f58")
			draw_rect(Rect2(at + Vector2(0, 2), Vector2(2, 3)), tint)
			draw_colored_polygon(PackedVector2Array([at + Vector2(2, 2), at + Vector2(5, 0), at + Vector2(5, 7), at + Vector2(2, 5)]), tint)
			for bar_index in range(3):
				var height := 2.0 + bar_index * 2.0
				var lit := live and amount > bar_index * 0.25
				draw_rect(Rect2(at + Vector2(8 + bar_index * 3, 3.5 - height * 0.5), Vector2(2, height)), Color("8fd17f") if lit else Color(0.3, 0.38, 0.35, 0.5))


func _ready() -> void:
	net=get_node("/root/Net")
	theme=CampStyle.make()
	var background := ColorRect.new()
	background.color=Color("101d20")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(background)
	# SpriteCook campfire illustration, dimmed so the lobby controls read clearly.
	if ResourceLoader.exists("res://assets/sprites/sc/lobby_art.png"):
		var art := TextureRect.new()
		art.texture=load("res://assets/sprites/sc/lobby_art.png")
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.stretch_mode=TextureRect.STRETCH_SCALE
		art.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(art)
		var shade := ColorRect.new()
		shade.color=Color(0.02,0.04,0.05,0.5)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(shade)
	_label("NETWORK CAMP / 1-4 SURVIVORS",Vector2(14,7),14)
	_line("Name","Camper",Vector2(14,32),Vector2(145,23))
	var role := OptionButton.new()
	add_child(role)
	role.position=Vector2(168,32)
	role.size=Vector2(202,23)
	for label in SurvivorRoster.NAMES: role.add_item(label)
	role.select(SurvivorRoster.IDS.find(get_node("/root/Session").survivor))
	fields["Role"]=role
	role.item_selected.connect(func(index: int):
		get_node("/root/Session").select_survivor(SurvivorRoster.IDS[index])
		if net.active: net.choose(SurvivorRoster.IDS[index],false))
	_line("Address","127.0.0.1",Vector2(14,60),Vector2(170,23))
	fields["Address"].placeholder_text="Host IP / VPN address"
	_line("Port",str(net.DEFAULT_PORT),Vector2(192,60),Vector2(69,23))
	_line("Seed","",Vector2(269,60),Vector2(101,23))
	fields["Seed"].placeholder_text="Random seed"
	_button("Host","HOST",Vector2(14,88),Vector2(78,23),func():
		_save_prefs()
		var result: Error=net.host(int(fields["Port"].text),fields["Name"].text,SurvivorRoster.IDS[role.selected])
		if result!=OK and not net.active: net.status_text="Cannot host: "+error_string(result)
		if result==OK: _configure())
	_button("Join","JOIN",Vector2(100,88),Vector2(78,23),func():
		_save_prefs()
		var result: Error=net.join(fields["Address"].text,int(fields["Port"].text),fields["Name"].text,SurvivorRoster.IDS[role.selected])
		if result!=OK and not net.active: net.status_text="Cannot join: "+error_string(result))
	_button("Leave","BACK / LEAVE",Vector2(186,88),Vector2(91,23),func(): net.leave())
	_button("Settings","SETTINGS",Vector2(285,88),Vector2(85,23),_settings)
	roster_label=_label("",Vector2(14,115),8)
	roster_label.add_theme_constant_override("line_spacing",-4)
	roster_label.size=Vector2(356,30)
	var powers := CampStyle.abilities_toggle()
	powers.position=Vector2(14,145)
	powers.size=Vector2(140,16)
	powers.button_pressed=net.camper_abilities_enabled
	powers.toggled.connect(func(value: bool):
		if not net.active: net.camper_abilities_enabled=value
		else: net.configure_lobby(net.mode,net.seed_value,value))
	fields["Abilities"]=powers
	add_child(powers)
	ready_button=_button("Ready","READY",Vector2(14,164),Vector2(100,23),func():
		var mine: Dictionary=net.roster.get(multiplayer.get_unique_id(),{})
		net.choose(SurvivorRoster.IDS[role.selected],not mine.get("ready",false)))
	start_button=_button("Start","START (HOST)",Vector2(122,164),Vector2(110,23),func():
		var chosen: String="woods" if fields["Mode"].selected==1 else "camp"
		net.start_round(chosen,clampi(int(fields["Seed"].text),0,2147483646)))
	var mode := OptionButton.new()
	add_child(mode)
	mode.position=Vector2(240,164)
	mode.size=Vector2(130,23)
	mode.add_item("QUICK CAMP")
	mode.add_item("WOODS EXPEDITION")
	mode.select(1 if net.mode=="woods" else 0)
	fields["Mode"]=mode
	mode.item_selected.connect(func(_index: int): _configure())
	fields["Seed"].text_changed.connect(func(_value: String): _configure())
	if net.seed_value>0: fields["Seed"].text=str(net.seed_value)
	message=_label("",Vector2(14,191),8)
	message.size=Vector2(356,24)
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_load_prefs()
	voice_meters = VoiceMeters.new()
	voice_meters.roster = roster_label
	voice_meters.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	voice_meters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(voice_meters)
	var music: Node = load("res://scripts/ui/menu_audio.gd").new()
	add_child(music)
	fields["Name"].grab_focus()

func _label(value: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text=value
	label.position=at
	label.add_theme_font_size_override("font_size",font_size)
	add_child(label)
	return label
func _line(key: String, value: String, at: Vector2, dimensions: Vector2) -> void:
	var line := LineEdit.new()
	add_child(line)
	line.name=key
	line.text=value
	line.position=at
	line.size=dimensions
	line.max_length=253 if key=="Address" else 20
	fields[key]=line
func _button(key: String, value: String, at: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	add_child(button)
	button.name=key
	button.text=value
	button.position=at
	button.size=dimensions
	button.pressed.connect(callback)
	fields[key]=button
	return button
func _process(delta: float) -> void:
	last_refresh-=delta
	if last_refresh>0: return
	last_refresh=0.1
	message.text=net.status_text
	var online: bool=net.active and net.phase=="lobby"
	fields["Host"].disabled=net.active
	fields["Join"].disabled=net.active
	fields["Name"].editable=not net.active
	fields["Address"].editable=not net.active
	fields["Port"].editable=not net.active
	fields["Abilities"].disabled=net.active and not multiplayer.is_server()
	fields["Abilities"].set_pressed_no_signal(net.camper_abilities_enabled)
	fields["Mode"].disabled=net.active and not multiplayer.is_server()
	fields["Seed"].editable=not net.active or multiplayer.is_server()
	ready_button.disabled=not online or not net.roster.has(multiplayer.get_unique_id())
	start_button.disabled=not net.can_start()
	var lines: Array[String]=[]
	var ids: Array=net.roster.keys()
	ids.sort()
	for id: int in ids:
		var entry: Dictionary=net.roster[id]
		lines.append("%s%s / %s / %s" % [entry["name"]," (HOST)" if id==1 else "",SurvivorRoster.NAMES[SurvivorRoster.IDS.find(entry["role"])],"READY" if entry["ready"] else "CHOOSING"])
	roster_label.text="\n".join(lines) if not lines.is_empty() else "Same Wi-Fi/LAN: use host's local IP.\nInternet: reachable public UDP port or virtual LAN.\nVoice: Settings > MIC (push-to-talk B), then restart once."
	if net.active and not multiplayer.is_server():
		fields["Mode"].select(1 if net.mode=="woods" else 0)
		fields["Seed"].text=str(net.seed_value) if net.seed_value>0 else ""
	var mine: Dictionary=net.roster.get(multiplayer.get_unique_id(),{})
	ready_button.text="UNREADY" if mine.get("ready",false) else "READY"
func _load_prefs() -> void:
	var prefs := ConfigFile.new()
	if prefs.load(prefs_path) == OK:
		for key in ["Name", "Address", "Port"]:
			var stored := str(prefs.get_value("lobby", key.to_lower(), "")).strip_edges()
			if not stored.is_empty():
				fields[key].text = stored
	# Back for another night: show the name this session is already using.
	if net.active and not str(net.local_name).is_empty():
		fields["Name"].text = net.local_name

func _save_prefs() -> void:
	var prefs := ConfigFile.new()
	prefs.load(prefs_path)
	for key in ["Name", "Address", "Port"]:
		prefs.set_value("lobby", key.to_lower(), fields[key].text.strip_edges())
	prefs.save(prefs_path)

func _configure() -> void:
	if fields.has("Mode"):
		net.configure_lobby("woods" if fields["Mode"].selected==1 else "camp",int(fields["Seed"].text))

func _settings() -> void:
	if has_node("AudioSettings"):
		$AudioSettings.show()
		return
	var panel := PanelContainer.new()
	panel.name="AudioSettings"
	panel.position=Vector2(54,10)
	panel.size=Vector2(276,164)
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := Label.new()
	heading.text="SETTINGS"
	column.add_child(heading)
	column.add_child(load("res://scripts/ui/audio_controls.gd").new())
	var back := Button.new()
	back.text="BACK TO LOBBY"
	back.pressed.connect(func(): panel.hide())
	column.add_child(back)
	back.grab_focus()
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if has_node("AudioSettings") and $AudioSettings.visible: $AudioSettings.hide()
		else: net.leave()
