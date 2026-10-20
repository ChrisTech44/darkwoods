extends CreatureBrain
var target: CampPlayer
var tell := 0.0
var punished := {}
var flash := 0.0
func setup() -> void:
	display_name="The Lifeguard"
	tip="Walk in its sight. The raised whistle warns you; stop sprinting or flash it."
	body.config.sight_radius=240
	body.config.killer_patrol_speed=26
func physics(delta: float) -> bool:
	flash=maxf(0,flash-delta)
	for id in punished.keys():
		punished[id]-=delta
		if punished[id]<=0: punished.erase(id)
	if is_instance_valid(target):
		body.velocity=Vector2.ZERO
		if target.status!=CampPlayer.Status.ALIVE or not target.is_inside_tree() or not target.sprinting or not body.has_line_of_sight(target.position): target=null; tell=0; return true
		tell-=delta
		if tell<=0:
			target.stamina=0
			target.exhausted=true
			if level().night_clock.phase>=3: target.add_effect("tripped",0.8)
			punished[target.get_instance_id()]=12.0 if level().night_clock.phase>=3 else 20.0
			level().loud_noise(target.position,700)
			cue("lifeguard_whistle")
			cue("lifeguard_shout")
			announce("NO RUNNING!",target)
			flash=1.0
			target=null
		return true
	for actor in survivors():
		if not actor.sprinting or punished.has(actor.get_instance_id()) or actor.position.distance_to(body.position)>240 or not body.has_line_of_sight(actor.position): continue
		# Do not take the only sprint away during the headline killer's chase.
		if level().killer.visible_target==actor and level().killer.state==CampKiller.State.CHASE: continue
		target=actor
		tell=0.6
		CreatureSamples.encounter(actor,body)
		break
	wander(26,delta)
	body.queue_redraw()
	return true
func contact(_actor: CampPlayer) -> bool: return true
func on_stunned() -> void: target=null; tell=0
func draw_over() -> void:
	if tell>0 or flash>0:
		body.draw_arc(Vector2(0,-35),10,0,TAU,16,Color("f2d68a"),2)
		body.draw_string(ThemeDB.fallback_font,Vector2(-26,-62),"NO RUNNING!" if flash>0 else "...",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("f2d68a"))
func snapshot() -> Dictionary: return {"tell":tell,"flash":flash}
func restore(state: Dictionary) -> void: tell=state.get("tell",0.0); flash=state.get("flash",0.0)
