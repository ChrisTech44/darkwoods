extends VBoxContainer
## Compact pause-menu mixer. Saved gain zero also mutes the bus.

func _ready() -> void:
	var mixer: Node = get_node("/root/AudioManager")
	add_theme_constant_override("separation", 1)
	for bus in ["Master", "Effects", "Ambience", "Music"]:
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
