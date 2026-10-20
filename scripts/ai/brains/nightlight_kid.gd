extends CreatureBrain
var near_dark := false
var scream := 0.0
var rest := 0.0
func setup() -> void:
	display_name="The Night-Light Kid"
	tip="Keep your light on near it. Its touch jams your light on and drains it faster."
	body.config.killer_chase_speed=50
	body.config.sight_radius=200
func senses(actor: CampPlayer) -> int:
	if actor.flashlight_on or actor.flashlight_charge<=0 or actor.kit.get("veil",0.0)>0: return 0
	for enemy: CampCryptid in body.get_tree().get_nodes_in_group("cryptids"):
		if enemy.species=="candle_grazer" and enemy.home.has_point(actor.position): return 0
	return 1
func physics(delta: float) -> bool:
	scream=maxf(0,scream-delta)
	rest=maxf(0,rest-delta)
	near_dark=nearest_seen(200)!=null
	if rest>0: wander(22,delta);return true
	return false
func contact(actor: CampPlayer) -> bool:
	if rest>0 or senses(actor)!=1: return true
	actor.add_effect("nightlight",45 if level().night_clock.phase>=3 else 30)
	actor.flashlight_on=true
	scream=1
	rest=8
	level().loud_noise(actor.position,500)
	cue("nightlight_scream")
	announce("LEAVE IT ON!",actor)
	return true
func draw_over() -> void:
	body.draw_circle(Vector2(7,-22),2,Color("f2d68a"))
	if near_dark or scream>0: body.draw_string(ThemeDB.fallback_font,Vector2(-24,-56),"LEAVE IT ON!" if scream>0 else "...",HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("f2d68a"))
func snapshot() -> Dictionary: return {"near_dark":near_dark,"scream":scream}
func restore(state: Dictionary) -> void: near_dark=state.get("near_dark",false);scream=state.get("scream",0.0)
