extends CreatureBrain
var target: CampPlayer
var tell:=0.0
var cooldown:=0.0
var flash:=0.0
func setup() -> void:
	display_name="The Huntmaster"
	tip="Flash it while it raises its horn. Its horn makes nearby creatures faster."
	body.config.sight_radius=300
func physics(delta: float) -> bool:
	cooldown=maxf(0,cooldown-delta)
	flash=maxf(0,flash-delta)
	if tell>0:
		body.velocity=Vector2.ZERO
		if not is_instance_valid(target) or not target.is_inside_tree() or target.status!=CampPlayer.Status.ALIVE or not body.can_sense(target) or not body.has_line_of_sight(target.position): tell=0;target=null;return true
		tell-=delta
		if tell<=0: blow()
	elif cooldown<=0:
		target=nearest_seen(300)
		if target!=null:
			tell=2
			cue("huntmaster_inhale")
			CreatureSamples.encounter(target,body)
	else: wander(28,delta)
	body.queue_redraw()
	return true
func blow() -> void:
	var radius:=550.0 if level().night_clock.phase>=3 else 400.0
	for enemy: CampKiller in body.get_tree().get_nodes_in_group("killers"):
		if enemy.enabled and enemy.position.distance_to(body.position)<=radius: enemy.haste_remaining=maxf(enemy.haste_remaining,15)
	cue("huntmaster_horn")
	cooldown=45
	flash=1
	target=null
func contact(_actor: CampPlayer) -> bool: return true
func on_stunned() -> void: tell=0;target=null;cooldown=maxf(cooldown,5)
func draw_over() -> void:
	if tell>0 or flash>0:
		body.draw_arc(Vector2.ZERO,35,0,TAU,32,Color("e4b75c"),2)
		body.draw_string(ThemeDB.fallback_font,Vector2(-20,-64),"HORN",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("e4b75c"))
func snapshot() -> Dictionary: return {"tell":tell,"flash":flash}
func restore(state: Dictionary) -> void: tell=state.get("tell",0.0);flash=state.get("flash",0.0)
