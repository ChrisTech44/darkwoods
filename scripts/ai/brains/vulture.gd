extends CreatureBrain
var target: CampPlayer
var tell := 0.0
var peck_clock := 0.0
var rest := 0.0
func setup() -> void:
	display_name="The Vulture"
	tip="Flash it before a rescue. It pecks rescuers and slows a lone survivor's recovery."
	body.collision_layer=0
	body.collision_mask=0
func physics(delta: float) -> bool:
	rest=maxf(0,rest-delta)
	if rest>0: wander(65,delta);return true
	if not is_instance_valid(target) or not target.is_inside_tree() or target.status!=CampPlayer.Status.DOWNED or target.get_meta("hooked",false):
		target=null
		tell=0
		for actor: CampPlayer in body.get_tree().get_nodes_in_group("survivors"):
			if actor.status!=CampPlayer.Status.DOWNED or actor.get_meta("hooked",false): continue
			if target==null or actor.position.distance_to(body.position)<target.position.distance_to(body.position): target=actor
		if target!=null: cue("vulture_squawk");cue("vulture_wings")
	if target==null: wander(32,delta);return true
	var perch := target.position+Vector2(18,-8)
	if body.position.distance_to(perch)>8:
		body.position=body.position.move_toward(perch,70*delta)
		body.velocity=Vector2.ZERO
		body.queue_redraw()
		return true
	body.velocity=Vector2.ZERO
	var reviver: CampPlayer=level().revive_actor
	if level().revive_target!=target or not is_instance_valid(reviver) or reviver.status!=CampPlayer.Status.ALIVE or reviver.position.distance_to(target.position)>reviver.config.interact_radius:
		tell=0
		return true
	peck_clock-=delta
	if peck_clock<=0 and tell<=0: tell=0.45
	elif tell>0:
		tell-=delta
		if tell<=0:
			reviver.receive_hit(15)
			cue("vulture_peck")
			CreatureSamples.encounter(reviver,body)
			peck_clock=1.5 if level().night_clock.phase>=3 else 2.0
	body.queue_redraw()
	return true
func contact(_actor: CampPlayer) -> bool: return true
func on_stunned() -> void:
	rest=20
	target=null
	tell=0
	cue("vulture_wings")
func draw_over() -> void:
	if target!=null or perched:
		body.draw_arc(Vector2(0,0),17,0,TAU,24,Color("b99a72"),1)
	if tell>0: body.draw_string(ThemeDB.fallback_font,Vector2(-12,-60),"PECK",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("f4d3a0"))
var perched := false
func snapshot() -> Dictionary: return {"perched":is_instance_valid(target),"tell":tell,"rest":rest}
func restore(state: Dictionary) -> void: perched=state.get("perched",false);tell=state.get("tell",0.0);rest=state.get("rest",0.0)
