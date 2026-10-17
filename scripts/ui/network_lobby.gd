extends Control
var net: Node
var fields := {}
var roster_label: Label
var message: Label
var ready_button: Button
var start_button: Button
var last_refresh := 0.0
func _ready() -> void:
	net=get_node("/root/Net")
	theme=CampStyle.make()
	var background := ColorRect.new()
	background.color=Color("101d20")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_label("NETWORK CAMP / 1-4 SURVIVORS",Vector2(14,6),17)
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
		var result: Error=net.host(int(fields["Port"].text),fields["Name"].text,SurvivorRoster.IDS[role.selected])
		if result!=OK and not net.active: net.status_text="Cannot host: "+error_string(result)
		if result==OK: _configure())
	_button("Join","JOIN",Vector2(100,88),Vector2(78,23),func():
		var result: Error=net.join(fields["Address"].text,int(fields["Port"].text),fields["Name"].text,SurvivorRoster.IDS[role.selected])
		if result!=OK and not net.active: net.status_text="Cannot join: "+error_string(result))
	_button("Leave","BACK / LEAVE",Vector2(186,88),Vector2(91,23),func(): net.leave())
	_button("Settings","SETTINGS",Vector2(285,88),Vector2(85,23),_settings)
	roster_label=_label("",Vector2(14,115),8)
	roster_label.add_theme_constant_override("line_spacing",-4)
	roster_label.size=Vector2(356,46)
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
	roster_label.text="\n".join(lines) if not lines.is_empty() else "Same Wi-Fi/LAN: use host's local IP.\nInternet: reachable public UDP port or virtual LAN.\nVoice chat is the next feature; no microphone is used."
	if net.active and not multiplayer.is_server():
		fields["Mode"].select(1 if net.mode=="woods" else 0)
		fields["Seed"].text=str(net.seed_value) if net.seed_value>0 else ""
	var mine: Dictionary=net.roster.get(multiplayer.get_unique_id(),{})
	ready_button.text="UNREADY" if mine.get("ready",false) else "READY"
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
