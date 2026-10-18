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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if level == null or level.night_clock == null or not level.night_clock.active or level.finished:
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
