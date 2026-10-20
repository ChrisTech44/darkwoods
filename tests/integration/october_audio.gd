extends SceneTree
## Supplied pack accepted-event/loop lifecycle checks, frozen AI and microphones off.
const CUES := ["lifeguard_shout","nightlight_scream","nobody_breathing","vulture_squawk","magician_drumroll","magician_tada","noise_tin_rattle","village_bell","flare_ignite","flare_hiss","flashlight_on","flashlight_off","snore","water_splash","huntmaster_horn"]
var level: Node
var actor: CampPlayer
var checks:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(JSON.stringify({"event":"assertion","name":label,"passed":ok}))
func frames(n: int=3) -> void:
	for i in range(n):await process_frame;await physics_frame
func count(cue: String) -> int:return level.soundscape.played_counts.get(cue,0)
func run() -> void:
	root.get_node("Voice").mode="off"
	root.get_node("Session").mode="woods"
	root.get_node("Session").survivor="christian"
	root.get_node("Session").next_seed=42
	RoundPlan.force_modifiers=[]
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await frames(12)
	level=current_scene;actor=level.player
	level.set_physics_process(false);level.abilities.set_physics_process(false)
	level.night_clock.set_physics_process(false);level.night_clock.force_phase(2)
	level.soundscape.set_physics_process(false)
	actor.local_input=false;actor.set_physics_process(false)
	for body in get_nodes_in_group("killers"):body.enabled=false;body.set_physics_process(false)
	var audio: Node=root.get_node("AudioManager")
	for cue: String in CUES:
		check(audio.cues[cue].source=="User supplied, 20 October 2026" and audio.stream_for(cue)!=null,"supplied_cue_loads_"+cue)
	actor.position=Vector2(112,440);actor.effects.clear();actor.flashlight_on=false
	var before:=count("flashlight_on")
	check(level.toggle_flashlight(actor) and actor.flashlight_on and count("flashlight_on")==before+1,"accepted_on_click_once")
	before=count("flashlight_off")
	check(level.toggle_flashlight(actor) and not actor.flashlight_on and count("flashlight_off")==before+1,"accepted_off_click_once")
	for effect: String in ["nightlight","dark"]:
		actor.add_effect(effect,5)
		check(not level.toggle_flashlight(actor) and count("flashlight_off")==before+1 and count("flashlight_on")==1,"locked_light_does_not_click_"+effect)
		actor.effects.clear()
	actor.flashlight_charge=0
	check(not level.toggle_flashlight(actor),"empty_light_does_not_play_success")
	actor.flashlight_charge=90
	var tin:=NoiseLure.new();tin.level=level;tin.position=actor.position;level.world_objects.add_child(tin);tin.set_physics_process(false)
	before=count("noise_tin_rattle")
	var heat: float=level.night_clock.heat
	tin._physics_process(1.5);tin._physics_process(2);tin._physics_process(2)
	check(count("noise_tin_rattle")==before+3,"tin_has_one_rattle_per_three_native_pulses")
	check(level.night_clock.heat>heat,"tin_keeps_separate_ai_noise")
	actor.supplies.flare=1
	before=count("flare_ignite")
	check(level.use_supply(actor,"flare") and count("flare_ignite")==before+1,"accepted_flare_ignites_once")
	check(not level.use_supply(actor,"flare") and count("flare_ignite")==before+1,"rejected_empty_supply_does_not_ignite")
	level.soundscape._follow_loops()
	var flare: Node=get_nodes_in_group("flares")[0]
	var flare_key:="flare:%d" % flare.get_instance_id()
	check(level.soundscape.follow_loops.has(flare_key),"flare_hiss_follows_live_flare")
	flare.remaining=0;level.soundscape._follow_loops()
	check(not level.soundscape.follow_loops.has(flare_key),"expired_flare_hiss_stops")
	flare.queue_free();await frames()
	actor.add_effect("asleep",6)
	level.soundscape._follow_loops()
	var snore_key:="snore:%d" % actor.get_instance_id()
	check(level.soundscape.follow_loops.has(snore_key),"sleep_state_starts_snore_loop")
	actor.effects.clear();level.soundscape._follow_loops()
	check(not level.soundscape.follow_loops.has(snore_key),"waking_stops_snore_loop")
	for site: ForestSite in level.camp_map.sites:
		if site.definition.kind!="village":continue
		actor.position=site.actions[0].position;site.cooldown=0
		before=count("village_bell")
		check(site.interact(actor) and count("village_bell")==before+1,"accepted_village_bell_tolls_once")
		check(not site.interact(actor) and count("village_bell")==before+1,"bell_cooldown_does_not_replay")
	actor.position=Vector2(112,440)
	level.escapes.lake_target=actor.position;level.escapes.lake_tell=.1
	before=count("water_splash")
	level.escapes._lake(.2)
	check(count("water_splash")==before+1,"lake_impact_splashes_once")
	level.escapes.lake_tell=.1
	var counter: Node2D=load("res://scripts/items/flare.gd").new();counter.position=actor.position
	level.world_objects.add_child(counter);counter.set_physics_process(false)
	level.escapes._lake(.2)
	check(level.escapes.lake_tell==0 and count("water_splash")==before+1,"flare_cancelled_lake_attack_has_no_impact_splash")
	counter.queue_free();await frames()
	actor.health=100;actor.invulnerability=0;actor.effects.clear()
	actor.kit.sample="lifeguard";actor.ability_cooldown=0
	before=count("lifeguard_shout")
	check(level.abilities.use(actor),"copied_whistle_accepts")
	SurvivorKits.advance(actor,1)
	check(count("lifeguard_shout")==before+1,"copied_lifeguard_uses_recorded_shout")
	level.soundscape.stop_round()
	check(level.soundscape.follow_loops.is_empty() and not level.soundscape.broadcast("village_bell",actor.position),"round_stop_cleans_loops_and_rejects_late_audio")
	print(JSON.stringify({"event":"test_result","suite":"october_audio","checks":checks,"failures":failures}))
	await audio.prepare_shutdown()
	quit(1 if failures else 0)
