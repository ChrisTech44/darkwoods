class_name MoonDial
extends Control
## Top-right moon phase: a new moon until Nightfall, then a crescent that waxes
## toward full as the clouds thin. Full and glowing while the moon is out
## (werewolves change), with a ring that runs down until it hides again.
## Blood Moon nights draw it red. Reads replicated NightClock state only.

const LIT := Color("e9e4c8")
const DARK := Color("1b2428")
const RIM := Color("56605a")
const BLOOD_LIT := Color("e0503f")
const BLOOD_DARK := Color("2c1012")
const BLOOD_RIM := Color("7a2c26")
const RADIUS := 7
var level: Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(18, 18)


func _process(_delta: float) -> void:
	queue_redraw()


## 0 = new moon, 1 = full. While out the moon is full.
static func fullness(clock: NightClock) -> float:
	if clock.moon:
		return 1.0
	if clock.phase < 1:
		return 0.0
	return clampf(1.0 - clock.moon_clock / maxf(1.0, clock.moon_span), 0.0, 1.0)


func _draw() -> void:
	if level == null or level.night_clock == null or not level.night_clock.active:
		return
	var clock: NightClock = level.night_clock
	var blood: bool = level.plan.has_modifier("blood_moon")
	var lit := BLOOD_LIT if blood else LIT
	var dark := BLOOD_DARK if blood else DARK
	var rim := BLOOD_RIM if blood else RIM
	var middle := size * 0.5
	var f := fullness(clock)
	if clock.moon:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		draw_circle(middle, RADIUS + 3.0, Color(lit, 0.18 + 0.12 * pulse))
		# Time left before the clouds close again.
		var left := clampf(clock.moon_clock / maxf(1.0, clock.moon_span), 0.0, 1.0)
		draw_arc(middle, RADIUS + 2.0, -PI * 0.5, -PI * 0.5 + TAU * left, 24, Color(lit, 0.85), 1.0)
	# Pixel disc: the lit side grows from the right (waxing).
	var terminator := cos(PI * f)
	for y in range(-RADIUS, RADIUS + 1):
		for x in range(-RADIUS, RADIUS + 1):
			var cx := x + 0.5
			var cy := y + 0.5
			if cx * cx + cy * cy > RADIUS * RADIUS:
				continue
			var half := sqrt(maxf(0.0, RADIUS * RADIUS - cy * cy))
			var on := cx > half * terminator
			var edge := cx * cx + cy * cy > (RADIUS - 1) * (RADIUS - 1)
			var tint := lit if on else (rim if edge else dark)
			draw_rect(Rect2(middle + Vector2(x, y), Vector2.ONE), tint)
