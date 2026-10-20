extends SceneTree
## Staged fixtures: normal routes/light, frozen AI and night director, no microphone.
var level: Node2D
var actor: CampPlayer
var checks := 0
var failures := 0
var capture := "--capture" in OS.get_cmdline_user_args()
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(JSON.stringify({"event":"assertion","name":label,"passed":ok}))
func frames(n: int=6) -> void:
	for i in range(n): await physics_frame; await process_frame
func run() -> void:
	root.get_node("Voice").mode="off"
	root.get_node("Session").mode="woods"
	root.get_node("Session").next_seed=42
	root.get_node("Session").survivor="max"
	RoundPlan.force_modifiers=[]
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await frames(12)
	level=current_scene
	level.hud.broadcast.hide() # Dismiss transient titles for unobscured inspection.
	actor=level.player
	actor.local_input=false
	actor.set_physics_process(false)
	level.abilities.set_physics_process(false)
	level.night_clock.director_enabled=false
	level.night_clock.set_physics_process(false)
	for enemy in get_nodes_in_group("killers"): enemy.enabled=false; enemy.set_physics_process(false)
	await wheel()
	await creature_checks()
	print(JSON.stringify({"event":"test_result","suite":"wheel_monsters","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(1 if failures else 0)
func shot(label: String) -> void:
	if not capture: return
	DirAccess.make_dir_recursive_absolute("res://artifacts/wheel_monsters")
	level.abilities.queue_redraw()
	actor.queue_redraw()
	await frames(3)
	RenderingServer.force_draw(true)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/wheel_monsters/"+label+".png")==OK,"capture_"+label)
func wheel() -> void:
	check(FortuneWheel.WEIGHTS.reduce(func(a,b): return a+b,0)==100,"weighted_wheel_totals_one_hundred")
	check(actor.kit.cash==0 and SamplePresentation.detail(actor).is_empty(),"no_money_or_permanent_explanation_panel")
	check(level.abilities.use(actor) and actor.ability_cooldown==60,"one_spin_starts_sixty_second_cooldown")
	check(not level.abilities.use(actor) and not level.abilities.release(actor),"hold_release_and_repeat_cannot_reroll")
	await shot("wheel_spinning")
	actor.kit.wheel_pick=0
	FortuneWheel.advance(actor,2)
	check(actor.has_effect("hot_streak") and actor.notice=="HOT STREAK" and actor.kit.wheel_time==0,"spin_resolves_once_with_name_only")
	FortuneWheel.advance(actor,1)
	check(actor.effects.hot_streak==20,"advance_does_not_resolve_again")
	actor.position=Vector2(96,384)
	actor.apply_intent(Vector2.RIGHT,false,1.0/60,true)
	check(is_equal_approx(actor.velocity.length(),actor.config.walk_speed*1.5),"wheel_speed_boost_changes_shared_movement")
	var prediction := LocalPrediction.capture(actor)
	check(LocalPrediction.valid(prediction) and prediction[16] & (1<<LocalPrediction.EFFECTS.find("hot_streak")),"wheel_speed_projects_into_owner_prediction")
	actor.effects.clear()
	FortuneWheel.resolve(actor,1)
	actor.apply_intent(Vector2.RIGHT,false,1.0/60,true)
	check(is_equal_approx(actor.velocity.length(),actor.config.walk_speed*0.5),"wheel_slow_changes_shared_movement")
	actor.effects.clear()
	actor.health=80
	FortuneWheel.resolve(actor,2)
	check(actor.health==40,"bad_beat_halves_current_health")
	FortuneWheel.resolve(actor,4)
	check(actor.health==100,"second_wind_fully_heals")
	actor.inventory.assign(["battery"])
	actor.position=Vector2(136,420)
	FortuneWheel.resolve(actor,5)
	check(actor.position.distance_to(Vector2(96,384))<24 and actor.inventory==["battery"],"camp_warp_preserves_objective_and_safe_landing")
	var count: int=actor.supplies.flare
	actor.supplies={"flare":count}
	FortuneWheel.resolve(actor,7)
	check(actor.supplies.flare==count+1,"jackpot_copies_owned_supply_not_objective")
	actor.supplies={"flare":count+1,"battery_pack":0,"rations":0,"medkit":0}
	FortuneWheel.resolve(actor,8)
	check(actor.inventory.is_empty() and actor.supplies.flare==0,"butterfingers_uses_real_drop_path")
	check(level.pickups.any(func(p): return p.available and p.kind=="battery"),"dropped_objective_remains_recoverable")
	FortuneWheel.resolve(actor,9)
	actor._physics_process(0.01)
	check(actor.has_effect("dark") and not actor.flashlight_on,"lights_out_uses_existing_light_rule")
	actor.effects.clear()
	FortuneWheel.resolve(actor,3)
	check(actor.status==CampPlayer.Status.DOWNED,"rare_skull_downs_without_permanent_elimination")
	actor.set_status(CampPlayer.Status.ALIVE)
	actor.health=100
	actor.ability_cooldown=0
	level.abilities.use(actor)
	level.abilities.enabled=false
	SurvivorKits.advance(actor,3)
	check(actor.kit.wheel_time==0 and actor.ability_active==0,"disabled_powers_cancel_spin_without_outcome")
	level.abilities.enabled=true
	actor.effects.clear()
	actor.ability_cooldown=0
	FortuneWheel.start(actor)
	actor.add_effect("held",1)
	FortuneWheel.advance(actor,2)
	check(actor.kit.wheel_time==0 and actor.ability_cooldown==60,"interrupted_spin_keeps_cooldown")
	actor.effects.clear()
	actor.flashlight_on=true
	actor.kit.wheel_time=0
	actor.kit.wheel_show=0
	await shot("max_idle")
func creature_checks() -> void:
	if "lifeguard" in RoundPlan.ROAMER_SPECIES: await lifeguard_checks()

func specimen(kind: String, at: Vector2) -> CampCryptid:
	var enemy: CampCryptid=load("res://scenes/actors/cryptid.tscn").instantiate()
	enemy.species=kind
	enemy.position=at
	level.world_objects.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.enabled=true
	return enemy

func lifeguard_checks() -> void:
	actor.position=Vector2(112,440)
	actor.effects.clear()
	actor.status=CampPlayer.Status.ALIVE
	actor.stamina=4
	actor.sprinting=true
	var guard:=specimen("lifeguard",actor.position+Vector2(70,0))
	await frames()
	guard.brain.physics(0.01)
	check(guard.brain.tell>0,"lifeguard_raises_whistle_before_punishment")
	await shot("lifeguard_tell")
	var cues: int=level.soundscape.played_counts.get("lifeguard_whistle",0)
	level.night_clock.heat=0
	guard.brain.physics(0.7)
	check(level.night_clock.heat==3,"whistle_emits_separate_authority_hearing_stimulus")
	check(actor.stamina==0 and actor.exhausted,"lifeguard_punishes_sprinting")
	check(level.soundscape.played_counts.get("lifeguard_whistle",0)==cues+1,"lifeguard_has_native_cue_route")
	check(guard.brain.punished.has(actor.get_instance_id()),"lifeguard_has_per_survivor_cooldown")
	guard.brain.punished.clear()
	actor.sprinting=false
	guard.brain.physics(0.1)
	check(guard.brain.target==null,"walking_is_lifeguard_counter")
	actor.sprinting=true
	guard.brain.physics(0.1)
	guard.stun(1)
	check(guard.brain.tell==0 and guard.brain.target==null,"flash_cancels_lifeguard_windup")
	actor.role="christian"
	actor.kit.sample="lifeguard"
	actor.ability_cooldown=0
	actor.stamina=4
	check(CreatureSamples.use(actor),"lifeguard_sample_accepted")
	CreatureSamples.advance(actor,1)
	check(actor.stamina==0 and actor.exhausted,"copied_whistle_exhausts_caster_as_well")
	var snapshot: Dictionary=guard.brain.snapshot()
	guard.brain.restore(snapshot)
	check(guard.brain.snapshot()==snapshot,"lifeguard_tell_round_trips")
	guard.queue_free()
	actor.role="max"
