extends VBoxContainer
## Compact pause-menu mixer plus proximity-voice settings. Saved gain zero mutes a bus.

func _ready() -> void:
	var mixer: Node = get_node("/root/AudioManager")
	add_theme_constant_override("separation", 1)
	for bus in ["Master", "Effects", "Ambience", "Music", "Voice"]:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = bus.to_upper()
		label.custom_minimum_size.x = 66
		label.add_theme_font_size_override("font_size", 8)
		row.add_child(label)
		var slider := HSlider.new()
		slider.name = bus
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.value = float(mixer.volumes[bus]) * 100
		slider.custom_minimum_size = Vector2(100, 13)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.tooltip_text = bus + " volume (0 mutes)"
		slider.value_changed.connect(func(value: float) -> void: mixer.set_volume(bus, value / 100.0))
		row.add_child(slider)
		add_child(row)
	var voice: Node = get_node_or_null("/root/Voice")
	if voice == null:
		return
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "MIC"
	label.custom_minimum_size.x = 66
	label.add_theme_font_size_override("font_size", 8)
	row.add_child(label)
	var choice := OptionButton.new()
	choice.name = "VoiceMode"
	choice.add_theme_font_size_override("font_size", 8)
	for text in ["OFF", "PUSH TO TALK (B)", "OPEN MIC"]:
		choice.add_item(text)
	choice.select(VoiceChat.MODES.find(voice.mode))
	choice.disabled = not voice.available
	choice.tooltip_text = "Proximity voice in co-op. Off by default; the microphone opens only in a co-op session."
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.custom_minimum_size = Vector2(100, 14)
	var status := Label.new()
	status.name = "VoiceStatus"
	status.add_theme_font_size_override("font_size", 7)
	status.add_theme_color_override("font_color", Color("a9c8d6"))
	status.text = voice.status_text()
	choice.item_selected.connect(func(index: int) -> void:
		voice.set_mode(VoiceChat.MODES[index])
		status.text = voice.status_text())
	row.add_child(choice)
	add_child(row)
	var sense := HBoxContainer.new()
	var sense_label := Label.new()
	sense_label.text = "MIC GAIN"
	sense_label.custom_minimum_size.x = 66
	sense_label.add_theme_font_size_override("font_size", 8)
	sense.add_child(sense_label)
	var gain := HSlider.new()
	gain.name = "MicGain"
	gain.min_value = 25
	gain.max_value = 400
	gain.step = 25
	gain.value = voice.mic_gain * 100
	gain.custom_minimum_size = Vector2(100, 13)
	gain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gain.tooltip_text = "Microphone gain (open mic also uses it to decide when you are talking)"
	gain.value_changed.connect(func(value: float) -> void: voice.set_mic_gain(value / 100.0))
	sense.add_child(gain)
	add_child(sense)
	add_child(status)
