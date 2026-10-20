extends CreatureBrain
var target: CampPlayer
var ring:=Vector2.ZERO
var tell:=0.0
var cooldown:=0.0
var last_target:=0
func setup() -> void:
	display_name="The Shell Game Magician"
	tip="Step out of its ring before the drumroll ends. Flash cancels its swap."
	body.config.sight_radius=200
func physics(delta: float) -> bool:
	cooldown=maxf(0,cooldown-delta)
	if tell>0:
		body.velocity=Vector2.ZERO
		if not is_instance_valid(target) or not target.is_inside_tree() or target.status!=CampPlayer.Status.ALIVE or target.has_effect("held") or target.position.distance_to(ring)>26:
			target=null;tell=0;return true
		tell-=delta
		if tell<=0:
			var eligible:=CreatureSwap.creatures(target,body,level().night_clock.phase>=3)
			if not eligible.is_empty(): CreatureSwap.perform(target,eligible[randi()%eligible.size()])
			target=null
		return true
	if cooldown<=0:
		var options: Array[CampPlayer]=[]
		for actor in survivors():
			if actor.has_effect("held") or actor.position.distance_to(body.position)>200 or not body.can_sense(actor) or not body.has_line_of_sight(actor.position): continue
			if not CreatureSwap.creatures(actor,body,level().night_clock.phase>=3).is_empty(): options.append(actor)
		if options.size()>1: options=options.filter(func(actor): return actor.get_instance_id()!=last_target)
		if not options.is_empty():
			target=options[randi()%options.size()]
			last_target=target.get_instance_id()
			ring=target.position
			tell=1.5
			cooldown=40
			cue("magician_drumroll")
			CreatureSamples.encounter(target,body)
	else: wander(25,delta)
	body.queue_redraw()
	return true
func contact(_actor: CampPlayer) -> bool: return true
func on_stunned() -> void: tell=0;target=null
func draw_over() -> void:
	if tell>0:
		var at:=ring-body.position
		body.draw_arc(at,26,0,TAU,32,Color("d3a9e8"),2)
		body.draw_string(ThemeDB.fallback_font,at+Vector2(-15,-28),"...",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("d3a9e8"))
func snapshot() -> Dictionary: return {"tell":tell,"ring":ring}
func restore(state: Dictionary) -> void: tell=state.get("tell",0.0);ring=state.get("ring",Vector2.ZERO)
