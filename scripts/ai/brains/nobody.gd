extends CreatureBrain
var prints: Array=[]
var step_clock:=0.0
var revealed:=0.0
var shimmer:=false
var rest:=0.0
func setup() -> void:
	display_name="Nobody"
	tip="Follow its footprints and breathing. Sweep your beam to reveal a shimmer, then flash it."
	body.config.killer_chase_speed=55
	body.config.killer_patrol_speed=32
func tick_status(delta: float) -> void:
	revealed=maxf(0,revealed-delta)
	for mark: Array in prints: mark[1]-=delta*(2.0 if level().night_clock.phase>=3 else 1.0)
	prints=prints.filter(func(mark): return mark[1]>0)
func physics(delta: float) -> bool:
	rest=maxf(0,rest-delta)
	step_clock-=delta
	if step_clock<=0 and rest<=0:
		prints.append([body.position,4.0])
		if prints.size()>8: prints.pop_front()
		step_clock=0.5
	shimmer=false
	for actor in survivors():
		if actor.flashlight_charge>0 and in_beam(actor,body.position,240,0.8) and body.has_line_of_sight(actor.position): shimmer=true
	body.queue_redraw()
	if rest>0: body.velocity=Vector2.ZERO;return true
	return false
func contact(actor: CampPlayer) -> bool:
	if rest>0: return true
	actor.receive_hit(35)
	CreatureSamples.encounter(actor,body)
	cue("nobody_exhale")
	for cell: Vector2i in level().plan.woods.links:
		var at: Vector2=level().plan.woods.center(cell)
		if at.distance_to(actor.position)>600 and not CampKiller.in_camp(at):
			body.position=reachable(at)
			break
	rest=20
	body.visible_target=null
	body.transition(CampKiller.State.PATROL)
	return true
func on_stunned() -> void: revealed=3.0
func draw() -> bool:
	if revealed>0 or shimmer: body.draw_sheet(Color(0.7,0.9,1.0,1.0 if revealed>0 else 0.35))
	return true
func snapshot() -> Dictionary: return {"prints":prints,"revealed":revealed,"shimmer":shimmer,"rest":rest}
func restore(state: Dictionary) -> void: prints=state.get("prints",[]);revealed=state.get("revealed",0.0);shimmer=state.get("shimmer",false);rest=state.get("rest",0.0)
