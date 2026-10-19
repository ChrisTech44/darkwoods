class_name SignalFire
extends Node2D
## F5c Signal Fire: carry two kerosene cans and the flare gun (three regions,
## three directions) to the pyre on the White Stone Quarry rim. Lighting it starts
## a 45 s hold-out: the blaze beacons every creature in the woods toward the rim.
## Survivors standing by the pyre when the rescue plane passes are recovered.

const PARTS: Array[String] = ["kerosene_1", "kerosene_2", "flare_gun"]
const HOLD_SECONDS := 45.0
const RESCUE_RADIUS := 110.0
const BEACON_SECONDS := 6.0
var level: Node2D
var active := false
var pyre := Vector2.ZERO
var installed: Array[String] = []
var started := false
var remaining := HOLD_SECONDS
var beacon_clock := 0.0
var pulse := 0.0
var glow: PointLight2D


func _ready() -> void:
	set_meta("stand_in_world", true)
	z_index = 1
	active = level.plan.expedition and level.plan.has_escape("signal")
	if not level.plan.expedition:
		return
	pyre = level.plan.woods.zones[7]["position"] + Vector2(0, -150)
	if not active:
		return
	glow = CampLights.lamp(self, pyre + Vector2(0, -10), 260, Color("ff9a52"), 2.4)
	glow.enabled = false


func _process(delta: float) -> void:
	if not active:
		return
	pulse += delta
	glow.enabled = started
	if started:
		glow.energy = 2.2 + sin(pulse * 11.0) * 0.25 + sin(pulse * 3.7) * 0.2
	queue_redraw()


func near(actor: CampPlayer) -> bool:
	return actor.status == CampPlayer.Status.ALIVE and actor.global_position.distance_to(pyre) <= level.config.interact_radius * 1.6 and level.clear_path(actor.global_position, pyre)


func prompt(actor: CampPlayer) -> String:
	if not active or not near(actor):
		return ""
	if started:
		return "SIGNAL FIRE %.1fs · STAY BY THE PYRE" % remaining
	if installed.size() < PARTS.size():
		return "E · DOUSE THE PYRE: KEROSENE ×2 + FLARE GUN (%d/3)" % installed.size()
	return "E · LIGHT THE SIGNAL FIRE · 45s HOLD-OUT, EVERYTHING WILL COME"


func interact(actor: CampPlayer) -> bool:
	if not active or not level.rescue.authority() or level.paused or level.finished or not near(actor):
		return false
	if started:
		return true
	var count := 0
	for kind in PARTS:
		if kind in actor.inventory and kind not in installed:
			actor.inventory.erase(kind)
			installed.append(kind)
			count += 1
	if count > 0:
		level.announce("Signal pyre readied: %d/3. T shows where the rest are." % installed.size())
		return true
	if installed.size() < PARTS.size():
		level.announce(prompt(actor), actor)
		return false
	started = true
	remaining = HOLD_SECONDS
	beacon_clock = BEACON_SECONDS
	level.loud_noise(pyre, 1500)
	level.killer.hear_stimulus(pyre, 6000)
	level.announce("THE PYRE ROARS UP. A rescue plane will see it in 45s. Hold the quarry rim; everything in the woods saw it too!")
	return true


func advance(delta: float) -> void:
	if not active or not started or not level.rescue.authority() or level.paused or level.finished:
		return
	remaining = maxf(0.0, remaining - delta)
	beacon_clock -= delta
	if beacon_clock <= 0.0:
		beacon_clock = BEACON_SECONDS
		# The blaze is a fixed, visible location: creatures travel there normally.
		level.loud_noise(pyre, 1200)
		level.killer.hear_stimulus(pyre, 6000)
	if remaining <= 0.0:
		level.escapes._extract("SIGNAL FIRE", pyre, RESCUE_RADIUS)


func heading() -> String:
	if not active or not started:
		return ""
	return "SIGNAL FIRE %.1fs · HOLD THE QUARRY RIM" % remaining


func progress() -> float:
	return installed.size() / float(PARTS.size()) if active else 0.0


func pack_text() -> String:
	var text := "SIGNAL FIRE · PYRE ON THE WHITE STONE QUARRY RIM\n"
	for kind in PARTS:
		var where := WoodsLayout.short_name(level.plan.woods.zones[level.plan.signal_regions[kind]]) if level.plan.signal_regions.has(kind) else "?"
		text += ("✓ " if kind in installed else "· ") + kind.replace("_1", "").replace("_2", "").replace("_", " ").to_upper() + " / " + where + "\n"
	return text + "E AT PYRE: FIT PARTS, THEN LIGHT IT\n45s HOLD-OUT · CREATURES CONVERGE ON THE FIRE\nSTAND WITHIN THE FIRE RING · DOWNED TEAM RESCUED"


func snapshot() -> Dictionary:
	return {"installed": installed.duplicate(), "started": started, "remaining": remaining}


func restore(state: Dictionary) -> void:
	if state.is_empty():
		return
	installed.assign(state["installed"])
	started = state["started"]
	remaining = state["remaining"]


func _draw() -> void:
	if not level.plan.expedition:
		return
	var fuelled := installed.size()
	if not PixelArt.draw_standing(self, "pyre_lit" if started else "pyre", pyre + Vector2(0, 14), 46):
		# Fallback: a stacked log pyre with a soaked base.
		for row in range(3):
			for column in range(4 - row):
				var at := pyre + Vector2(-15 + column * 10 + row * 5, 8 - row * 7)
				draw_circle(at, 4.5, Color("5e4129"))
				draw_circle(at, 2.0, Color("a07a4c"))
		if started:
			for flame in range(7):
				var lift := fmod(pulse * 30.0 + flame * 9.0, 34.0)
				draw_circle(pyre + Vector2(sin(pulse * 5 + flame) * 7, -6 - lift), 6.0 - lift * 0.15, Color(1.0, 0.55 + flame * 0.04, 0.2, 1.0 - lift / 34.0))
	if not active:
		return
	if fuelled > 0 and not started:
		draw_arc(pyre, 20, -PI * 0.5, -PI * 0.5 + TAU * fuelled / 3.0, 24, Color("e0b06a"), 2)
	if started:
		draw_arc(pyre, RESCUE_RADIUS, 0.0, TAU, 72, Color(1.0, 0.7, 0.4, 0.55 + sin(pulse * 4.0) * 0.2), 2)
		for spark in range(10):
			var rise := fmod(pulse * 22.0 + spark * 7.0, 60.0)
			draw_circle(pyre + Vector2(sin(spark * 1.7 + pulse * 2.0) * 14.0, -18 - rise), 1.2, Color(1.0, 0.8, 0.45, 1.0 - rise / 60.0))
