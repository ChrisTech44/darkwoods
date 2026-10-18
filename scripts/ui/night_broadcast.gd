class_name NightBroadcast
extends Control
## Phase-change presentation, run on every peer from replicated NightClock state:
## a short phase title (upper centre, ~3 s, no pause or input capture) and the
## ranger radio transcript crawling across a strip under the HUD while the
## static and chatter play. Dusk gets one opening title. If progress skips
## phases in one step, only the resulting phase is shown.

const TITLES := {
	0: ["DUSK", "Find your way. Prepare an escape."],
	1: ["NIGHTFALL", "The hunt deepens. Check the ranger's report."],
	2: ["DEEP NIGHT", "CAMP IS NO LONGER SAFE."],
	3: ["THE WITCHING HOUR", "Your escape is nearly ready. Finish it."],
}
const FADE_IN := 0.35
const HOLD := 1.8
const FADE_OUT := 0.6
## Transcript starts as the static gives way to voices.
const STATIC_SECONDS := 0.6
const CRAWL_SPEED := 52.0
const STRIP := Rect2(0, 47, 384, 13)
var level: Node2D
var shown_phase := -1
var title_time := -1.0
var title_phase := 0
var radio_time := -1.0
var radio_text := ""
var radio_width := 0.0
## Recent radio lines for the notebook log.
var history: Array[String] = []
## Place title: shown briefly when you enter a building, a woods region, camp or
## the open woods. The place must hold for PLACE_SETTLE seconds (no flicker on a
## doorstep) and the same place is not re-announced within PLACE_REPEAT seconds.
const PLACE_SETTLE := 0.5
const PLACE_SHOW := 2.4
const PLACE_REPEAT := 10.0
var place := ""
var place_pending := ""
var place_pending_time := 0.0
var place_time := -1.0
var place_title := ""
var place_sub := ""
var place_seen: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if level == null:
		return
	if level.finished:
		place_time = -1.0
		title_time = -1.0
		radio_time = -1.0
		queue_redraw()
		return
	_advance_place(delta)
	if level.night_clock == null or not level.night_clock.active:
		title_time = -1.0
		radio_time = -1.0
		queue_redraw()
		return
	var clock: NightClock = level.night_clock
	if clock.phase != shown_phase:
		var opening := shown_phase < 0
		shown_phase = clock.phase
		title_phase = clock.phase
		title_time = 0.0
		if not opening and clock.phase > 0:
			start_radio(clock.radio_text)
	if title_time >= 0.0:
		title_time += delta
		if title_time > FADE_IN + HOLD + FADE_OUT:
			title_time = -1.0
	if radio_time >= 0.0:
		radio_time += delta
		if radio_time > STATIC_SECONDS + (size.x + radio_width) / CRAWL_SPEED:
			radio_time = -1.0
	queue_redraw()


## Canonical place for the player: [title, subtitle]. Uses only where the
## player already is, so it never reveals anything unseen.
func current_place() -> Array:
	var point: Vector2 = level.player.global_position
	var map: CampMap = level.camp_map
	for building: CampBuilding in map.buildings:
		if building.bounds.grow(5).has_point(point):
			return [building.label, "CAMP BUILDING"]
	for building: CampBuilding in map.forest_buildings:
		if building.bounds.grow(5).has_point(point):
			return [building.label, "ABANDONED VILLAGE"]
	if CampMap.is_woods(point) and level.plan.expedition:
		var zone: Dictionary = level.plan.woods.zone_at(point)
		if not zone.is_empty():
			var direction: String = zone["label"].get_slice(" / ", 0) if zone["label"].get_slice(" / ", 0) in ["NORTH", "EAST", "SOUTH", "WEST", "SOUTHEAST"] else ""
			return [WoodsLayout.short_name(zone), (direction + " WOODS") if not direction.is_empty() else "WOODS REGION"]
		return ["THE WOODS", "Follow the lit roads and signposts"]
	var safe: bool = not level.plan.expedition or level.night_clock == null or level.night_clock.phase < 2
	return ["FERNWOOD CAMP", "Safe from creatures until Deep Night" if safe and level.plan.expedition else ("Camp is no longer safe" if level.plan.expedition else "Search the cabins")]


func _advance_place(delta: float) -> void:
	if place_time >= 0.0:
		place_time += delta
		if place_time > PLACE_SHOW:
			place_time = -1.0
	for key in place_seen.keys():
		place_seen[key] -= delta
		if place_seen[key] <= 0.0:
			place_seen.erase(key)
	if level.player.status != CampPlayer.Status.ALIVE:
		return
	var now: Array = current_place()
	if now[0] != place_pending:
		place_pending = now[0]
		place_pending_time = 0.0
		return
	place_pending_time += delta
	if place_pending_time < PLACE_SETTLE or place_pending == place:
		return
	var first := place.is_empty()
	var from_camp: bool = place == "FERNWOOD CAMP" or level.camp_map.buildings.any(func(building: CampBuilding) -> bool: return building.label == place)
	place = place_pending
	# "THE WOODS" is announced only when you leave camp, not after every region.
	if place == "THE WOODS" and not from_camp:
		return
	# The round opens on the Dusk title, not a place title.
	if first or place_seen.has(place):
		place_seen[place] = PLACE_REPEAT
		return
	place_seen[place] = PLACE_REPEAT
	place_title = now[0]
	place_sub = now[1]
	place_time = 0.0


func start_radio(text: String) -> void:
	radio_text = "RANGER RADIO: " + (text if not text.is_empty() else "Stay together.")
	radio_width = ThemeDB.fallback_font.get_string_size(radio_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	radio_time = 0.0
	history.append("%s · %s" % [NightClock.PHASES[level.night_clock.phase], radio_text])
	if history.size() > 6:
		history.pop_front()


func title_alpha() -> float:
	if title_time < 0.0:
		return 0.0
	if title_time < FADE_IN:
		return title_time / FADE_IN
	if title_time < FADE_IN + HOLD:
		return 1.0
	return clampf(1.0 - (title_time - FADE_IN - HOLD) / FADE_OUT, 0.0, 1.0)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if radio_time >= 0.0:
		_draw_radio(font)
	_draw_place(font)
	var alpha := title_alpha()
	if alpha <= 0.0:
		return
	# Critical survivor states win: shrink the title to a ribbon while held/downed.
	var urgent: bool = level.player.status != CampPlayer.Status.ALIVE or level.player.has_effect("held")
	var row: Array = TITLES[title_phase]
	var big := 10 if urgent else 17
	var top := 86.0 if not urgent else 74.0
	var heading: String = row[0]
	var width := font.get_string_size(heading, HORIZONTAL_ALIGNMENT_CENTER, -1, big).x
	var sub_width := font.get_string_size(row[1], HORIZONTAL_ALIGNMENT_CENTER, -1, 8).x if not urgent else 0.0
	var box_width := maxf(width, sub_width) + 24.0
	var box := Rect2((size.x - box_width) * 0.5, top - big - 4.0, box_width, big + (18.0 if not urgent else 8.0))
	draw_rect(box, Color(0.03, 0.04, 0.05, 0.72 * alpha))
	var red := title_phase >= 2
	var ink := Color("e7a07f") if red else Color("efe3ba")
	draw_string_outline(font, Vector2(0, top), heading, HORIZONTAL_ALIGNMENT_CENTER, size.x, big, 3, Color(0, 0, 0, alpha))
	draw_string(font, Vector2(0, top), heading, HORIZONTAL_ALIGNMENT_CENTER, size.x, big, Color(ink, alpha))
	if not urgent:
		draw_string(font, Vector2(0, top + 11.0), row[1], HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, Color(Color("c9c3a2"), alpha))


## Screen box of the place title while it shows (the skyline keeps labels out).
func place_box() -> Rect2:
	if place_time < 0.0 or title_alpha() > 0.0 or level == null or level.hud.notebook.visible:
		return Rect2()
	var font := ThemeDB.fallback_font
	var width := maxf(font.get_string_size(place_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, font.get_string_size(place_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x) + 20.0
	return Rect2((size.x - width) * 0.5, 118.0, width, 25.0)


## Lower-centre place title, above the belt; hidden under the notebook and
## while a phase title is up (the phase title wins).
func _draw_place(font: Font) -> void:
	var box := place_box()
	if not box.has_area():
		return
	var alpha := clampf(minf(place_time / 0.25, (PLACE_SHOW - place_time) / 0.5), 0.0, 1.0)
	draw_rect(box, Color(0.03, 0.04, 0.05, 0.7 * alpha))
	draw_line(box.position + Vector2(6, 0), Vector2(box.end.x - 6, box.position.y), Color(Color("c9b07a"), 0.8 * alpha), 1.0)
	draw_string_outline(font, Vector2(0, box.position.y + 12), place_title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, 3, Color(0, 0, 0, alpha))
	draw_string(font, Vector2(0, box.position.y + 12), place_title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color(Color("f0dca3"), alpha))
	draw_string(font, Vector2(0, box.position.y + 21), place_sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 7, Color(Color("b9b493"), alpha))


func _draw_radio(font: Font) -> void:
	var t := radio_time
	var crawl_end := STATIC_SECONDS + (size.x + radio_width) / CRAWL_SPEED
	# Strip slides in, then out at the end.
	var reveal := clampf(minf(t / 0.25, (crawl_end - t) / 0.4), 0.0, 1.0)
	var strip := Rect2(STRIP.position, Vector2(size.x, STRIP.size.y))
	draw_rect(strip, Color(0.04, 0.07, 0.07, 0.86 * reveal))
	draw_line(strip.position, strip.position + Vector2(strip.size.x, 0), Color(0.55, 0.62, 0.45, 0.8 * reveal))
	draw_line(strip.end - Vector2(strip.size.x, 0), strip.end, Color(0.55, 0.62, 0.45, 0.8 * reveal))
	var baseline := strip.position.y + 10.0
	var clip_left := 40.0
	if t < STATIC_SECONDS:
		# Static: flickering noise bars before the voice comes through.
		for index in range(40):
			var x := clip_left + randf() * (strip.size.x - clip_left)
			draw_rect(Rect2(x, strip.position.y + 2 + randi() % 9, randf_range(2, 9), 1), Color(0.75, 0.8, 0.7, randf_range(0.2, 0.6) * reveal))
	else:
		var x := size.x - (t - STATIC_SECONDS) * CRAWL_SPEED
		var text_alpha := reveal
		# Characters only show right of the radio badge.
		var cursor := x
		for character in radio_text:
			var w := font.get_char_size(character.unicode_at(0), 9).x
			if cursor + w > clip_left and cursor < size.x:
				draw_char(font, Vector2(cursor, baseline), character, 9, Color(Color("f0dca3"), text_alpha))
			cursor += w
	# Walkie-talkie badge on the left, with a blinking receive light.
	draw_rect(Rect2(0, strip.position.y, clip_left - 2.0, strip.size.y), Color(0.09, 0.12, 0.1, 0.95 * reveal))
	var body := Rect2(5, strip.position.y + 2, 6, 9)
	draw_rect(body, Color(0.25, 0.28, 0.22, reveal))
	draw_line(Vector2(9, strip.position.y + 2), Vector2(9, strip.position.y - 2), Color(0.6, 0.62, 0.5, reveal), 1.0)
	var blink := 1.0 if fmod(t, 0.5) < 0.3 else 0.3
	draw_rect(Rect2(6, strip.position.y + 3, 2, 2), Color(0.9, 0.35, 0.25, blink * reveal))
	draw_string(font, Vector2(13, baseline - 1.0), "CH 9", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(Color("c9d7a4"), reveal))
