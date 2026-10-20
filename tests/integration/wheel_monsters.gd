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
	level.set_physics_process(false)
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
	if "nightlight_kid" in RoundPlan.ROAMER_SPECIES: await nightlight_checks()
	if "vulture" in RoundPlan.ROAMER_SPECIES: await vulture_checks()
	if "nobody" in RoundPlan.ROAMER_SPECIES: await nobody_checks()
	if "huntmaster" in RoundPlan.ROAMER_SPECIES: await huntmaster_checks()
	if "magician" in RoundPlan.ROAMER_SPECIES: await magician_checks()
	if "shade" in RoundPlan.ROAMER_SPECIES: await shade_checks()

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

func nightlight_checks() -> void:
	CreatureSamples.finish_cast(actor)
	actor.effects.clear()
	actor.flashlight_charge=90
	actor.flashlight_on=false
	var kid:=specimen("nightlight_kid",actor.position+Vector2(60,0))
	await frames()
	check(kid.brain.senses(actor)==1,"kid_senses_only_unlit_survivor")
	var heat: float=level.night_clock.heat
	level.night_clock.heat=0
	kid.brain.contact(actor)
	check(actor.has_effect("nightlight") and actor.flashlight_on,"kid_forces_light_on")
	check(is_equal_approx(actor.passive_light_rate(),actor.light_drain*2),"nightlight_doubles_passive_drain")
	check(level.night_clock.heat==3 and level.soundscape.played_counts.get("nightlight_scream",0)>0,"kid_noise_and_native_cue_both_route")
	await shot("nightlight_kid_scream")
	actor.flashlight_on=false
	actor._physics_process(0.01)
	check(actor.flashlight_on,"forced_light_resists_switching_off")
	check(kid.brain.senses(actor)==0,"lit_survivor_is_safe_from_kid")
	actor.flashlight_charge=0
	actor.flashlight_on=false
	actor._physics_process(0.01)
	check(not actor.flashlight_on and actor.flashlight_charge==0,"empty_charge_never_lights_or_goes_negative")
	actor.effects.clear()
	actor.flashlight_charge=90
	actor.role="christian"
	actor.kit.sample="nightlight_kid"
	actor.ability_cooldown=0
	actor.flashlight_on=false
	check(CreatureSamples.use(actor),"kid_sample_accepted")
	CreatureSamples.advance(actor,1)
	check(actor.has_effect("nightlight") and actor.flashlight_on,"kid_sample_affects_caster")
	actor.effects.clear()
	actor.role="max"
	kid.queue_free()

func vulture_checks() -> void:
	CreatureSamples.finish_cast(actor)
	actor.effects.clear()
	actor.status=CampPlayer.Status.ALIVE
	actor.health=100
	actor.invulnerability=0
	actor.ward_remaining=0
	var friend: CampPlayer=load("res://scenes/actors/player.tscn").instantiate()
	friend.local_input=false
	friend.position=actor.position+Vector2(10,0)
	level.world_objects.add_child(friend)
	friend.set_physics_process(false)
	friend.set_status(CampPlayer.Status.DOWNED)
	var bird:=specimen("vulture",friend.position+Vector2(18,-8))
	await frames()
	bird.brain.physics(0.1)
	check(bird.brain.target==friend,"vulture_perches_on_downed_survivor")
	level.advance_revive(actor,friend,true,0.1)
	bird.brain.physics(0.1)
	check(bird.brain.tell>0,"vulture_warns_before_peck")
	await shot("vulture_peck")
	bird.brain.physics(0.5)
	check(actor.health==85 and friend.status==CampPlayer.Status.DOWNED,"vulture_pecks_reviver_without_executing_body")
	bird.stun(1)
	check(bird.brain.target==null and bird.brain.rest==20,"flash_sends_vulture_away_for_twenty_seconds")
	actor.role="christian"
	actor.kit.sample="vulture"
	actor.ability_cooldown=0
	check(CreatureSamples.use(actor),"vulture_sample_requires_and_accepts_downed_friend")
	CreatureSamples.advance(actor,1)
	check(actor.kit.get("vulture_guard",0.0)>0,"copied_vulture_guards_friend")
	level.revive_progress=0
	level.advance_revive(actor,friend,true,0.5)
	check(is_equal_approx(level.revive_progress,0.25),"copied_vulture_halves_casters_revive_speed")
	friend.set_status(CampPlayer.Status.ALIVE)
	NewCreatureSamples.advance(actor,0.1)
	check(actor.kit.vulture_guard==0,"guard_ends_when_friend_revives")
	bird.brain.rest=0
	bird.brain.target=friend
	bird.brain.physics(0.1)
	check(bird.brain.target==null,"vulture_releases_revived_target")
	friend.remove_from_group("survivors")
	actor.set_status(CampPlayer.Status.DOWNED)
	bird.brain.target=actor
	bird.position=actor.position+Vector2(18,-8)
	level.self_recovery_progress=0
	level.advance_self_recovery(actor,true,2)
	check(is_equal_approx(level.self_recovery_progress,1),"vulture_halves_solo_recovery_rate")
	actor.set_status(CampPlayer.Status.ALIVE)
	actor.health=100
	friend.queue_free()
	bird.queue_free()
	actor.role="max"

func nobody_checks() -> void:
	level.self_recovery_progress=0
	level.revive_progress=0
	level.revive_target=null
	level.revive_actor=null
	actor.hurt_time=0
	actor.notice_time=0
	level.message_time=0
	CreatureSamples.finish_cast(actor)
	actor.effects.clear()
	actor.health=100
	actor.invulnerability=0
	actor.ward_remaining=0
	actor.flashlight_charge=90
	actor.flashlight_on=false
	var ghost:=specimen("nobody",actor.position+Vector2(60,0))
	await frames()
	for i in range(12):
		ghost.position+=Vector2(4,0)
		ghost.brain.physics(0.6)
	check(ghost.brain.prints.size()==8 and not ghost.brain.shimmer,"invisible_creature_has_bounded_print_trail")
	await shot("nobody_prints")
	actor.flashlight_on=true
	actor.facing=actor.position.direction_to(ghost.position)
	ghost.brain.physics(0.01)
	check(ghost.brain.shimmer,"beam_reveals_nobody_shimmer")
	await shot("nobody_shimmer")
	ghost.stun(1)
	check(ghost.brain.revealed==3,"flash_reveals_nobody_for_three_seconds")
	ghost.brain.tick_status(1)
	check(ghost.brain.revealed==2,"reveal_and_prints_decay_during_stun")
	ghost.brain.contact(actor)
	check(actor.health==65 and ghost.brain.rest==20 and ghost.position.distance_to(actor.position)>400,"nobody_hits_then_relocates_and_rests")
	actor.role="christian"
	actor.kit.sample="nobody"
	actor.ability_cooldown=0
	check(CreatureSamples.use(actor) and actor.kit.form=="nobody","nobody_sample_becomes_timed_invisible_form")
	check(not ghost.can_sense(actor) and not level.killer.can_sense(actor),"copied_invisibility_blocks_creature_and_headline_sight")
	level.soundscape._follow_loops()
	check(level.soundscape.follow_loops.has("sample_breath:%d" % actor.get_instance_id()),"invisible_caster_has_audible_breathing_drawback")
	CreatureSamples.advance(actor,11)
	check(actor.kit.form.is_empty(),"invisibility_expires_without_resource_reset")
	ghost.queue_free()
	actor.role="max"

func huntmaster_checks() -> void:
	CreatureSamples.finish_cast(actor)
	actor.kit.form=""
	actor.effects.clear()
	actor.health=100
	actor.hurt_time=0
	var horn:=specimen("huntmaster",actor.position+Vector2(70,0))
	var friend:=specimen("werewolf",actor.position+Vector2(100,0))
	await frames()
	horn.brain.physics(0.01)
	check(horn.brain.tell==2,"huntmaster_has_two_second_windup")
	await shot("huntmaster_horn")
	level.night_clock.heat=0
	horn.brain.physics(2.1)
	check(friend.haste_remaining==15 and is_equal_approx(friend.motion_speed(100),130),"horn_hastens_other_creatures_for_fifteen_seconds")
	check(level.night_clock.heat==0,"support_horn_does_not_reveal_survivor_to_ai")
	level.killer.haste_remaining=15
	check(level.killer.motion_speed(100)<=90,"haste_preserves_headline_final_speed_cap")
	horn.brain.cooldown=0
	horn.brain.physics(0.1)
	horn.stun(1)
	check(horn.brain.tell==0,"flash_interrupts_support_horn")
	actor.role="christian"
	friend.haste_remaining=0
	actor.kit.sample="huntmaster"
	actor.ability_cooldown=0
	check(CreatureSamples.use(actor),"huntmaster_sample_accepted")
	CreatureSamples.advance(actor,1)
	check(actor.has_effect("rally") and friend.sample_state.timers.rally==10 and is_equal_approx(friend.motion_speed(100),120),"copied_horn_buffs_both_friends_and_creatures")
	check(LocalPrediction.valid(LocalPrediction.capture(actor)),"rally_has_valid_owner_movement_projection")
	actor.effects.clear()
	actor.role="max"
	horn.queue_free()
	friend.queue_free()

func magician_checks() -> void:
	CreatureSamples.finish_cast(actor)
	actor.effects.clear()
	actor.kit.form=""
	level.night_clock.force_phase(2) # Late-night camp access for staged swaps.
	level.hud.broadcast.hide()
	actor.position=Vector2(112,440)
	var mage:=specimen("magician",actor.position+Vector2(70,0))
	var other:=specimen("bigfoot",actor.position+Vector2(90,0))
	await frames()
	mage.brain.physics(0.01)
	check(mage.brain.tell==1.5,"magician_warns_with_stationary_ring")
	await shot("magician_ring")
	actor.position+=Vector2(0,40)
	mage.brain.physics(2)
	check(mage.brain.target==null and mage.brain.tell==0,"leaving_ring_cancels_swap")
	actor.position=Vector2(112,440)
	var old:=actor.position
	var destination:=other.position
	actor.inventory.assign(["battery"])
	actor.health=73
	check(CreatureSwap.perform(actor,other),"validated_creature_swap_succeeds")
	check(actor.position==destination and other.position==old and actor.inventory==["battery"] and actor.health==73,"swap_moves_bodies_not_gear_or_health_copies")
	other.hold(actor,"TEST",0.1)
	check(not CreatureSwap.valid(actor,other),"held_survivor_and_holding_creature_are_ineligible")
	actor.release()
	other.home=Rect2(Vector2(500,500),Vector2(100,100))
	check(not CreatureSwap.valid(actor,other),"swap_cannot_displace_regional_guard_outside_territory")
	other.home=Rect2()
	check(not CreatureSwap.creatures(actor,mage,false).has(level.killer),"headline_excluded_before_witching_hour")
	mage.brain.tell=1
	mage.stun(1)
	check(mage.brain.tell==0,"flash_cancels_magician")
	actor.role="christian"
	actor.kit.sample="magician"
	actor.ability_cooldown=0
	check(CreatureSamples.use(actor),"magician_sample_accepted_with_valid_partner")
	CreatureSamples.advance(actor,2)
	check(actor.kit.sample.is_empty(),"copied_swap_consumes_once")
	actor.role="max"
	mage.queue_free()
	other.queue_free()

func shade_checks() -> void:
	CreatureSamples.finish_cast(actor)
	actor.effects.clear()
	actor.flashlight_on=false
	actor.kit.form=""
	actor.hidden_spot=-1
	for encounter: Dictionary in level.plan.encounters:
		var at: Vector2=encounter.position
		if SurvivorKits.safe_point(actor,at) and SurvivorKits.safe_point(actor,at+Vector2(40,0)) and ShadowLight.dark_path(level,at,at+Vector2(40,0)) and level.clear_path(at,at+Vector2(40,0)):
			actor.position=at
			break
	actor.health=100
	actor.hurt_time=0
	actor.invulnerability=0
	actor.ward_remaining=0
	actor.ability_active=0
	actor.role="max"
	var shade:=specimen("shade",actor.position+Vector2(40,0))
	await frames()
	check(not ShadowLight.lit(level,shade.position),"shade_fixture_uses_actual_dark_ground")
	shade.brain.physics(0.01)
	check(shade.brain.tell==2,"shade_telegraphs_half_health_strike_for_two_seconds")
	level.hud.broadcast.hide()
	actor.notice_time=0
	level.message_time=0
	await shot("shade_eyes")
	shade.brain.physics(2.1)
	check(actor.health==50 and shade.brain.rest==8,"shade_half_health_hit_has_eight_second_recovery")
	actor.health=100
	actor.invulnerability=0
	actor.role="john"
	actor.ability_active=3
	shade.brain.rest=0
	shade.brain.physics(0.01)
	shade.brain.physics(2.1)
	check(actor.health==100 and actor.kit.debt==25,"john_halves_and_defers_shade_damage_during_ability")
	actor.kit.debt=0
	actor.role="max"
	actor.ability_active=0
	actor.flashlight_on=true
	actor.flashlight_charge=50
	actor.facing=actor.position.direction_to(shade.position)
	shade.brain.rest=0
	shade.brain.tell=2
	shade.brain.physics(1.1)
	check(shade.brain.tell==0 and shade.brain.rest==8,"steady_beam_cancels_windup_and_disperses_shade")
	check(not ShadowLight.dark_path(level,shade.position,actor.position),"lit_ground_blocks_shade_movement_path")
	actor.flashlight_charge=0
	check(not ShadowLight.lit(level,shade.position),"empty_flashlight_cannot_counter_shade")
	actor.flashlight_on=false
	var flare: Node2D=load("res://scripts/items/flare.gd").new()
	flare.position=shade.position
	level.world_objects.add_child(flare)
	check(ShadowLight.lit(level,shade.position),"native_flare_counts_as_shade_counter")
	flare.queue_free()
	await frames()
	actor.role="christian"
	actor.hurt_time=0
	actor.kit.sample="shade"
	actor.ability_cooldown=0
	actor.health=100
	actor.invulnerability=0
	check(CreatureSamples.use(actor),"shade_sample_accepts_dark_ground")
	await shot("shade_sample")
	CreatureSamples.advance(actor,2.1)
	check(actor.health==50 and actor.kit.sample.is_empty(),"copied_ambush_can_hit_caster_and_consumes_once")
	actor.kit.sample="shade"
	actor.ability_cooldown=0
	actor.flashlight_charge=50
	actor.flashlight_on=true
	actor.facing=Vector2.RIGHT
	# A nearby native radial lamp proves the lit-ground rejection independently of beam angle.
	var lamp:=CampLights.lamp(level.world_objects,actor.position,60,Color.WHITE)
	check(not CreatureSamples.use(actor) and actor.kit.sample=="shade","lit_ground_preserves_uncast_shade_sample")
	lamp.queue_free()
	actor.role="max"
	shade.queue_free()
