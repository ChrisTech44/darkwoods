class_name CampCryptid
extends CampKiller
## Woods creatures. Everything that makes a species itself lives in its
## CreatureBrain (scripts/ai/brains/<species>.gd, docs/monster_revamp.md); this
## class is the shared body: home limits, the walk sheet, the telegraphed charge
## the Ram uses, the witch's cast state and network fields.

signal spell_started

var home := Rect2()
var species: String = "werewolf"
var sheet: Texture2D
var brain: CreatureBrain
## Sight and hearing before weather and modifiers (x, y), for checks and tuning.
var base_senses := Vector2.ZERO
## Telegraphed charge (the Ram): a tell ring at the aim, then a straight dash.
var power_clock := 0.0
var power_aim := Vector2.ZERO
var power_tell := 0.0
var dash_remaining := 0.0
var dash_direction := Vector2.ZERO
var hunt_clock: float = 0.0
## The witch's wind-up (kept here so the existing sync and sound hooks work).
var casting: bool = false
var cast_remaining: float = 0.0
var cast_aim := Vector2.ZERO
## Brain state for clients (drawing only), synced by WorldSync.
var brain_state: Dictionary:
	get:
		return brain.snapshot() if brain != null else {}
	set(value):
		if brain != null:
			brain.restore(value)


func _ready() -> void:
	super._ready()
	if ResourceLoader.exists("res://assets/sprites/" + species + ".png"):
		sheet = load("res://assets/sprites/" + species + ".png")
	add_to_group("cryptids")
	config = config.duplicate() as CampConfig
	config.killer_patrol_speed = 32
	config.search_seconds = 8
	config.sight_radius = 150
	config.hearing_radius = 200
	brain = CreatureBrain.for_species(species)
	if brain != null:
		brain.body = self
		brain.setup()
	base_senses = Vector2(config.sight_radius, config.hearing_radius)


func threat_key() -> String:
	return species


func _physics_process(delta: float) -> void:
	if CreatureSamples.tick_enemy(self,delta): return
	if not enabled:
		velocity = Vector2.ZERO
		return
	if tick_stun(delta):
		dash_remaining = 0
		power_tell = 0
		casting = false
		return
	hunt_clock += delta
	if recover_remaining > 0.0 and not is_instance_valid(held):
		# After a hit or a broken hold every creature pauses: your head start.
		recover_remaining = maxf(0.0, recover_remaining - delta)
		velocity = Vector2.ZERO
		queue_redraw()
		return
	if brain != null and brain.physics(delta):
		return
	super._physics_process(delta)


func strike(actor: CampPlayer) -> void:
	if brain != null:
		var hp := actor.health
		var old_effects := actor.effects.duplicate()
		if brain.contact(actor):
			if hp != actor.health or old_effects != actor.effects: CreatureSamples.encounter(actor,self)
			return
	super.strike(actor)


func stun(seconds: float) -> bool:
	if brain != null and not brain.stunnable():
		return false
	var stunned := super.stun(seconds)
	if stunned and brain != null:
		brain.on_stunned()
	return stunned


func on_released(actor: CampPlayer) -> void:
	super.on_released(actor)
	if brain != null:
		brain.on_released(actor)


func can_sense(actor: CampPlayer) -> bool:
	if CreatureSamples.deceived(self,actor): return false
	if sample_state.get("timers",{}).has("whiteout") or sample_state.get("timers",{}).has("lost"): return false
	if home.has_area() and not home.has_point(actor.global_position):
		return false
	if brain != null:
		var verdict := brain.senses(actor)
		if verdict >= 0:
			return verdict == 1
	return true


func pursuit_goal(actor: CampPlayer) -> Vector2:
	if brain != null:
		var goal := brain.goal(actor)
		if goal != Vector2.INF:
			return goal
	return super.pursuit_goal(actor)


func fears_flare() -> bool:
	return brain.fears_flare() if brain != null else true


func is_class_cryptid() -> bool:
	return true


func display_name() -> String:
	return brain.display_name if brain != null else species.replace("_", " ").capitalize()


func _draw() -> void:
	if sample_state.get("timers",{}).has("tethered"):
		draw_line(Vector2(0,-8),to_local(sample_state.get("anchor",position))+Vector2(0,-8),Color("e8dcc0"),1)
	if sample_state.get("timers",{}).has("frog"):
		PixelArt.draw_in(self,"frog",Rect2(-10,-20,20,20))
		return
	if sample_state.get("timers",{}).has("asleep"):
		draw_string(ThemeDB.fallback_font,Vector2(0,-35),"zzz",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("b9d4e8"))
	if power_tell > 0:
		var at := to_local(power_aim)
		draw_arc(at, 23, 0, TAU, 24, Color("f1c27d"), 2)
		draw_line(Vector2.ZERO, at, Color("b99a72"), 1)
		draw_string(ThemeDB.fallback_font, Vector2(-28, -72), "CHARGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("f4d3a0"))
	if brain == null or not brain.draw():
		draw_sheet()
	if brain != null:
		brain.draw_over()
	if casting:
		draw_arc(Vector2(0, -20), 22, 0, TAU * (1 - cast_remaining / 0.8), 24, Color("c4aadf"), 2)
	draw_stun(-66)


## The SpriteCook walk sheet (64x64 frames: down, up, right, left).
func draw_sheet(tint := Color.WHITE, lift := 0.0) -> void:
	if sheet == null:
		return
	var row := 0
	if absf(facing.x) > absf(facing.y):
		row = 2 if facing.x > 0 else 3
	elif facing.y < 0:
		row = 1
	var frame := 0 if velocity.length() < 1 else 1 + int(stride / 10.0) % 2
	draw_texture_rect_region(sheet, Rect2(-32, -58 - lift, 64, 64), Rect2(frame * 64, row * 64, 64, 64), tint)


func constrain_destination(point: Vector2) -> Vector2:
	if not home.has_area():
		return point
	if not home.has_point(global_position):
		transition(State.PATROL)
	return point.clamp(home.position + Vector2.ONE * 16, home.end - Vector2.ONE * 16)


func hear_stimulus(origin: Vector2, radius: float) -> void:
	if home.has_area() and not home.has_point(origin):
		return
	super.hear_stimulus(origin, radius)
