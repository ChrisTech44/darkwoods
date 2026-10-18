class_name CampNotebook
extends Control
## Tab notebook: MAP (field map + where you are and what to do next), PLAN
## (tonight's escape routes, T cycles), GUIDE (field guide topics) and LOG
## (recent announcements and radio). Tab pages forward and closes after LOG;
## Shift+Tab pages back; Esc closes; Z zooms the map or turns the guide page;
## the mouse can click any tab, route or topic. Each view has its own space,
## clear of the belt, location line and prompt. Offline the world keeps
## running, as before; online it always does.

const VIEWS: Array[String] = ["map", "plan", "guide", "log"]
const VIEW_NAMES := {"map": "MAP", "plan": "ESCAPE PLAN", "guide": "FIELD GUIDE", "log": "LOG"}
const ROUTE_NAMES := {"van": "VAN", "radio": "RADIO", "boat": "BOAT", "gate": "GATE", "signal": "SIGNAL FIRE"}
const HEADER := 12.0
const BODY_TOP := 14.0
const MAX_LOG := 14
var view := "map"
var topic := 0
var level: Node2D
var chart: Control
var plan_label: Label
var side_label: Label
var routes_label: Label
var topics_label: Label
var guide_label: Label
var log_label: Label
var tab_rects: Array[Rect2] = []
var log_lines: Array[String] = []
var last_message := ""
var last_notice := ""
var online := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	side_label = _text(Vector2(158, BODY_TOP), Vector2(214, 89))
	routes_label = _text(Vector2(4, BODY_TOP + 2), Vector2(72, 87))
	topics_label = _text(Vector2(4, BODY_TOP + 2), Vector2(72, 87))
	guide_label = _text(Vector2(80, BODY_TOP), Vector2(292, 89))
	log_label = _text(Vector2(4, BODY_TOP), Vector2(368, 89))
	hide()


func _text(at: Vector2, dimensions: Vector2) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_constant_override("line_spacing", -2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


## Attach the HUD's map and plan text into their notebook slots.
func adopt(map: Control, plan_text: Label) -> void:
	chart = map
	plan_label = plan_text
	for node: Control in [map, plan_text]:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		add_child(node)
	chart.position = Vector2(3, BODY_TOP)
	chart.size = Vector2(150, 89)
	plan_label.position = Vector2(80, BODY_TOP)
	plan_label.size = Vector2(292, 89)
	plan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plan_label.clip_text = true
	plan_label.add_theme_font_size_override("font_size", 8)
	plan_label.add_theme_constant_override("line_spacing", -2)
	plan_label.remove_theme_stylebox_override("normal")
	_apply_view()


func open_view(next: String) -> void:
	view = next
	show()
	_apply_view()


func close() -> void:
	hide()


## Tab: next page, closing after the last. Shift+Tab: previous page.
func cycle(backwards: bool = false) -> void:
	if not visible:
		open_view(view if backwards else "map")
		return
	var index := VIEWS.find(view) + (-1 if backwards else 1)
	if index >= VIEWS.size() or index < 0:
		close()
		return
	open_view(VIEWS[index])


## Z: zoom the map, or turn the guide to its next topic.
func secondary() -> void:
	if view == "map" and chart != null:
		chart.overview = not chart.overview
	elif view == "guide":
		topic = (topic + 1) % FieldGuide.TOPICS.size()


func _apply_view() -> void:
	if chart == null:
		return
	chart.visible = view == "map"
	side_label.visible = view == "map"
	plan_label.visible = view == "plan"
	routes_label.visible = view == "plan"
	topics_label.visible = view == "guide"
	guide_label.visible = view == "guide"
	log_label.visible = view == "log"
	queue_redraw()


func _process(_delta: float) -> void:
	if level == null:
		return
	_capture_log()
	if not visible:
		return
	match view:
		"map": side_label.text = _map_side()
		"plan": routes_label.text = _route_list()
		"guide":
			var names: Array[String] = []
			for index in range(FieldGuide.TOPICS.size()):
				names.append(("▸ " if index == topic else "  ") + FieldGuide.TOPICS[index])
			topics_label.text = "\n".join(names)
			guide_label.text = FieldGuide.text(FieldGuide.TOPICS[topic], level)
		"log":
			var shown: Array[String] = log_lines.duplicate()
			shown.reverse()
			log_label.text = "\n".join(shown) if not shown.is_empty() else "Nothing yet. Announcements and ranger radio land here."
	queue_redraw()


## Keep announcements after their banner fades, newest last.
func _capture_log() -> void:
	var clock := ""
	if level.plan.expedition and level.night_clock != null:
		clock = "%s %s · " % [NightClock.PHASES[level.night_clock.phase], NightClock.clock_text(level.night_clock.elapsed)]
	if level.message != last_message and level.message_time > 0.0:
		last_message = level.message
		_log(clock + level.message)
	var notice: String = level.player.notice
	if notice != last_notice and level.player.notice_time > 0.0:
		last_notice = notice
		_log(clock + notice)
	elif level.player.notice_time <= 0.0:
		last_notice = ""


func _log(line: String) -> void:
	if not log_lines.is_empty() and log_lines.back() == line:
		return
	log_lines.append(line)
	while log_lines.size() > MAX_LOG:
		log_lines.pop_front()


func _route_list() -> String:
	var rows: Array[String] = []
	var options: Array = level.plan.escape_options if level.plan.expedition else ["van"]
	for index in range(options.size()):
		var selected: bool = level.current_page() == options[index]
		rows.append(("▸ " if selected else "  ") + ROUTE_NAMES.get(options[index], str(options[index]).to_upper()))
	if level.plan.expedition and options.size() > 1:
		rows.append("")
		rows.append("T: NEXT ROUTE")
	return "\n".join(rows)


## The first open step of the selected plan, where you are, and the legend.
func _map_side() -> String:
	var lines: Array[String] = []
	lines.append("MAP: " + chart.title() + " · NORTH UP")
	lines.append("YOU: " + level.hud.location_label.text)
	var route: String = ROUTE_NAMES.get(level.current_page(), "VAN")
	lines.append("ROUTE: " + route + (" (T: NEXT)" if level.plan.expedition and level.plan.escape_options.size() > 1 else ""))
	lines.append("NEXT: " + next_step())
	var carried := _carried()
	if not carried.is_empty():
		lines.append("CARRYING: " + carried)
	lines.append("◆ ESCAPE  ● PART (ORANGE: DROPPED)  ▲ PIN")
	lines.append("● TEAMMATE  ✖ DOWNED  ▸ YOU" + ("  · Z: WHOLE WOODS" if level.plan.expedition and not chart.overview else ("  · Z: AROUND YOU" if level.plan.expedition else "")))
	return "\n".join(lines)


## First unfinished line of the selected plan (same text as the PLAN view).
func next_step() -> String:
	for line: String in plan_label.text.split("\n"):
		if line.begins_with("· "):
			return line.substr(2)
	var lines := plan_label.text.split("\n")
	return lines[lines.size() - 1] if not lines.is_empty() else ""


func _carried() -> String:
	var held: Array[String] = []
	var parts: Array = chart.route_parts()
	for actor: CampPlayer in get_tree().get_nodes_in_group("survivors"):
		for kind: String in actor.inventory:
			if kind in parts:
				var who := "YOU" if actor == level.player else (actor.peer_name if not actor.peer_name.is_empty() else "TEAMMATE")
				held.append("%s (%s)" % [kind.replace("_", " ").to_upper(), who.to_upper()])
	return ", ".join(held)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.08, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color("8b9471"), false)
	tab_rects.clear()
	var x := 2.0
	for name in VIEWS:
		var label: String = VIEW_NAMES[name]
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 10.0
		var rect := Rect2(x, 1, width, HEADER)
		tab_rects.append(rect)
		var selected := name == view
		draw_rect(rect, Color("2d4136") if selected else Color("15201d"))
		if selected:
			draw_line(rect.position + Vector2(0, rect.size.y), rect.end, Color("e1c888"), 1.0)
		draw_string(font, rect.position + Vector2(5, 9), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("f0dca3") if selected else Color("8f9a84"))
		x += width + 2.0
	var next_index := VIEWS.find(view) + 1
	var hint := "TAB: %s · ESC: CLOSE" % (VIEW_NAMES[VIEWS[next_index]] if next_index < VIEWS.size() else "CLOSE")
	if online:
		hint = "WORLD KEEPS MOVING · " + hint
	draw_string(font, Vector2(0, 10), hint, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4.0, 7, Color("a9b391"))
	draw_line(Vector2(0, HEADER + 1), Vector2(size.x, HEADER + 1), Color("4a5a48"), 1.0)
	if view in ["plan", "guide"]:
		draw_line(Vector2(77, BODY_TOP), Vector2(77, size.y - 3), Color("34433a"), 1.0)
	elif view == "map":
		draw_line(Vector2(155, BODY_TOP), Vector2(155, size.y - 3), Color("34433a"), 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and view == "map":
			chart.overview = event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		elif event.button_index == MOUSE_BUTTON_LEFT:
			for index in range(tab_rects.size()):
				if tab_rects[index].has_point(event.position):
					open_view(VIEWS[index])
			var row := int((event.position.y - BODY_TOP - 2.0) / 9.0)
			if event.position.x < 77 and row >= 0:
				if view == "guide" and row < FieldGuide.TOPICS.size():
					topic = row
				elif view == "plan" and level.plan.expedition and row < level.plan.escape_options.size():
					level.select_route(row)
			if view == "map" and chart.get_rect().has_point(event.position):
				secondary()
		accept_event()
