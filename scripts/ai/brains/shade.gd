extends CreatureBrain
var target: CampPlayer
var tell:=0.0
var exposure:=0.0
var rest:=0.0
func setup() -> void:
	display_name="The Shade"
	tip="It stays in darkness. Its eyes open before it strikes. Hold your beam on it or use a flare."
func physics(delta: float) -> bool:
	rest=maxf(0,rest-delta)
	if ShadowLight.lit(level(),body.position):
		tell=0;target=null
		exposure+=delta
		if exposure>=1: rest=8
		body.velocity=Vector2.ZERO
		body.queue_redraw()
		return true
	exposure=0
	if rest>0: body.velocity=Vector2.ZERO;return true
	if tell>0:
		body.velocity=Vector2.ZERO
		if not is_instance_valid(target) or not target.is_inside_tree() or target.status!=CampPlayer.Status.ALIVE or target.hidden_spot>=0 or target.position.distance_to(body.position)>100 or not body.has_line_of_sight(target.position) or not ShadowLight.dark_path(level(),body.position,target.position):
			tell=0;target=null;return true
		tell-=delta
		if tell<=0:
			target.receive_hit(50)
			cue("shade_strike")
			rest=8;target=null
	else:
		var actor:=nearest_seen(240)
		if actor!=null and not ShadowLight.lit(level(),actor.position):
			if actor.position.distance_to(body.position)<=80:
				target=actor;tell=2;cue("shade_inhale");CreatureSamples.encounter(actor,body)
			else: body.steer(actor.position,45,delta)
	body.queue_redraw()
	return true
func contact(_actor: CampPlayer) -> bool: return true
func on_stunned() -> void: tell=0;target=null;rest=8
func draw() -> bool:
	body.draw_sheet(Color(0.25,0.3,0.4,0.8 if tell>0 else (0.15 if rest>0 else 0.4)))
	return true
func snapshot() -> Dictionary: return {"tell":tell,"exposure":exposure,"rest":rest}
func restore(state: Dictionary) -> void: tell=state.get("tell",0.0);exposure=state.get("exposure",0.0);rest=state.get("rest",0.0)
