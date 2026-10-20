extends SceneTree
## Real ENet, frozen AI/director and staged poses; no microphones.
var net: Node
var bridge: Bridge
var checks:=0
var failures:=0
var host_side:=OS.get_environment("HABIT_SIDE")=="host"
var port:=int(OS.get_environment("HABIT_PORT"))
class Bridge extends Node:
	var data:={}
	var reports:={}
	@rpc("authority","call_local","reliable",0)
	func stage(payload: Dictionary) -> void:
		data=payload
		if multiplayer.is_server(): reports.clear()
	@rpc("any_peer","call_remote","reliable",0)
	func report(payload: Dictionary) -> void:
		if multiplayer.is_server(): reports[multiplayer.get_remote_sender_id()]=payload
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(JSON.stringify({"event":"assertion","name":label,"passed":ok}))
func until(predicate: Callable, seconds: float=15) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	var ok: bool=predicate.call()
	check(ok,"wait_"+str(bridge.data.get("stage","start")))
	return ok
func run() -> void:
	root.get_node("Voice").mode="off"
	net=root.get_node("Net")
	bridge=Bridge.new();bridge.name="HabitBridge";root.add_child(bridge)
	if host_side:
		net.host(port,"Host","christian")
		if not await until(func(): return net.roster.size()==2): return finish()
		net.choose("christian",true)
		if not await until(func(): return net.can_start()): return finish()
		net.start_round("woods",42)
	else:
		net.join("127.0.0.1",port,"Guest","max")
		if not await until(func(): return net.phase=="lobby"): return finish()
		net.choose("max",true)
	if not await until(func(): return net.phase=="playing",90): return finish()
	net.world.soundscape.set_physics_process(false)
	if host_side: await host_checks()
	else: await client_checks()
	finish()
func host_checks() -> void:
	var level: Node=net.world
	level.night_clock.director_enabled=false
	for enemy: CampKiller in get_nodes_in_group("killers"): enemy.enabled=false;enemy.set_physics_process(false)
	for actor: CampPlayer in net.actors.values(): actor.position=Vector2(112,440);actor.ward_remaining=300
	var enemies:=get_nodes_in_group("cryptids")
	for kind: String in NewCreatureSamples.SOURCES:
		var enemy: CampCryptid
		for candidate: CampCryptid in enemies:
			if candidate.species==kind: enemy=candidate;break
		check(enemy!=null,"roster_contains_"+kind)
		if enemy==null: continue
		enemy.position=Vector2(170,440)
		enemy.enabled=true
		# Actual trigger for the whistle; frozen replicated presentation for others.
		if kind=="lifeguard":
			net.world.player.sprinting=true
			enemy.brain.physics(0.01)
		elif kind=="nobody": enemy.brain.physics(0.5)
		elif enemy.brain.get_property_list().any(func(p): return p.name=="tell"): enemy.brain.set("tell",1.25)
		elif kind=="nightlight_kid": enemy.brain.near_dark=true;enemy.brain.scream=0.5
		var state: Dictionary=enemy.brain.snapshot()
		bridge.stage.rpc({"stage":"state_"+kind,"index":enemies.find(enemy),"kind":kind,"state":state})
		if not await until(func(): return bridge.reports.size()==1): return
		check(bridge.reports.values()[0].same,"client_receives_"+kind+"_brain_state")
		var cue: String=CampSoundscape.CREATURE_CUES[kind]
		bridge.stage.rpc({"stage":"cue_"+kind,"cue":cue})
		if not await until(func(): return bridge.reports.size()==1): return
		bridge.stage.rpc({"stage":"heard_"+kind,"cue":cue,"before":bridge.reports.values()[0].before})
		enemy.brain.cue(cue)
		if not await until(func(): return bridge.reports.size()==1): return
		check(bridge.reports.values()[0].once,"client_hears_"+kind+"_cue_once")
		enemy.enabled=false
	# Recorded one-shots use the same host log and deduplication as brain cues.
	for cue: String in preload("res://tests/integration/october_audio.gd").CUES:
		if root.get_node("AudioManager").cues[cue].loop: continue
		bridge.stage.rpc({"stage":"cue_pack_"+cue,"cue":cue})
		if not await until(func(): return bridge.reports.size()==1): return
		bridge.stage.rpc({"stage":"heard_pack_"+cue,"cue":cue,"before":bridge.reports.values()[0].before})
		level.soundscape.broadcast(cue,Vector2(112,440))
		if not await until(func(): return bridge.reports.size()==1): return
		check(bridge.reports.values()[0].once,"recorded_client_hears_once_"+cue)
	var guest: CampPlayer
	for id: int in net.actors:
		if id!=1: guest=net.actors[id]
	guest.add_effect("asleep",20)
	bridge.stage.rpc({"stage":"loop_sleep_on"})
	if not await until(func(): return bridge.reports.size()==1): return
	check(bridge.reports.values()[0].valid,"replicated_sleep_starts_one_client_snore_loop")
	guest.clear_effect("asleep")
	bridge.stage.rpc({"stage":"loop_sleep_off"})
	if not await until(func(): return bridge.reports.size()==1): return
	check(bridge.reports.values()[0].valid,"replicated_wake_stops_client_snore")
	guest.supplies.flare=1
	check(level.use_supply(guest,"flare"),"host_uses_flare_for_replication")
	bridge.stage.rpc({"stage":"loop_flare_on"})
	if not await until(func(): return bridge.reports.size()==1): return
	check(bridge.reports.values()[0].valid,"replicated_flare_starts_one_client_hiss")
	for flare in get_nodes_in_group("flares"):flare.queue_free()
	bridge.stage.rpc({"stage":"loop_flare_off"})
	if not await until(func(): return bridge.reports.size()==1): return
	check(bridge.reports.values()[0].valid,"removed_flare_stops_client_hiss")
	bridge.stage.rpc({"stage":"done"})
	await create_timer(0.4).timeout
func client_checks() -> void:
	var previous:=""
	while net.active:
		await process_frame
		if bridge.data.is_empty() or bridge.data.stage==previous: continue
		previous=bridge.data.stage
		if previous=="done": return
		if previous.begins_with("state_"):
			var enemy: CampCryptid=get_nodes_in_group("cryptids")[bridge.data.index]
			if not await until(func(): return enemy.brain.snapshot()==bridge.data.state): return
			bridge.report.rpc_id(1,{"same":enemy.species==bridge.data.kind and enemy.brain.snapshot()==bridge.data.state})
		elif previous.begins_with("loop_"):
			var own: CampPlayer=net.actors[get_multiplayer().get_unique_id()]
			if previous.begins_with("loop_sleep"):
				var wanted: bool=previous.ends_with("on")
				if not await until(func(): return own.has_effect("asleep")==wanted):return
				net.world.soundscape._follow_loops()
				var key:="snore:%d" % own.get_instance_id()
				bridge.report.rpc_id(1,{"valid":net.world.soundscape.follow_loops.has(key)==wanted})
			else:
				var wanted: bool=previous.ends_with("on")
				if not await until(func(): return (get_nodes_in_group("flares").size()>0)==wanted):return
				net.world.soundscape._follow_loops()
				var keys: Array=net.world.soundscape.follow_loops.keys().filter(func(k):return str(k).begins_with("flare:"))
				bridge.report.rpc_id(1,{"valid":keys.size()==(1 if wanted else 0)})
		elif previous.begins_with("cue_"):
			bridge.report.rpc_id(1,{"before":net.world.soundscape.played_counts.get(bridge.data.cue,0)})
		elif previous.begins_with("heard_"):
			if not await until(func(): return net.world.soundscape.played_counts.get(bridge.data.cue,0)>bridge.data.before): return
			await create_timer(0.3).timeout
			bridge.report.rpc_id(1,{"once":net.world.soundscape.played_counts.get(bridge.data.cue,0)==bridge.data.before+1})
func finish() -> void:
	if net.active: net.leave()
	await create_timer(0.2).timeout
	print(JSON.stringify({"event":"test_result","suite":"habit_peer_host" if host_side else "habit_peer_client","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(1 if failures else 0)
