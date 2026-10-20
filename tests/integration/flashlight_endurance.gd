extends SceneTree
## Actual actor drain and accepted supply use, frozen AI/clock, voice off.
var checks:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(JSON.stringify({"event":"assertion","name":label,"passed":ok}))
func run() -> void:
	root.get_node("Voice").mode="off"
	root.get_node("Session").mode="woods"
	root.get_node("Session").survivor="alex"
	root.get_node("Session").next_seed=42
	RoundPlan.force_modifiers=[]
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	for i in range(12):await process_frame;await physics_frame
	var level: Node=current_scene
	var actor: CampPlayer=level.player
	actor.local_input=false;actor.set_physics_process(false)
	level.set_physics_process(false);level.abilities.set_physics_process(false)
	level.night_clock.set_physics_process(false)
	for enemy in get_nodes_in_group("killers"):enemy.enabled=false;enemy.set_physics_process(false)
	actor.position=level.plan.woods.center(WoodsLayout.ENTRY)
	for isolated in [false,true]:
		for jammed in [false,true]:
			actor.effects.clear()
			actor.kit.isolated=isolated
			if jammed:actor.add_effect("nightlight",2000)
			actor.flashlight_charge=90;actor.flashlight_on=true
			var duration:=840.0/(0.75 if isolated else 1.0)/(2.0 if jammed else 1.0)
			check(is_equal_approx(90/actor.passive_light_rate(),duration),"hud_duration_isolated_%s_jammed_%s"%[isolated,jammed])
			actor._physics_process(60)
			check(is_equal_approx(actor.flashlight_charge,90-60*90/duration),"actual_minute_drain_isolated_%s_jammed_%s"%[isolated,jammed])
	actor.effects.clear();actor.kit.isolated=false
	actor.position=Vector2(96,384)
	actor.flashlight_charge=70;actor.flashlight_on=true
	actor._physics_process(60)
	check(actor.flashlight_charge==70,"camp_does_not_drain")
	actor.position=level.plan.woods.center(WoodsLayout.ENTRY);actor.flashlight_on=false
	actor._physics_process(60)
	check(actor.flashlight_charge==70,"off_light_does_not_drain")
	for weak in [false,true]:
		level.plan.modifiers.assign(["dead_batteries"] if weak else [])
		actor.supplies.battery_pack=2;actor.flashlight_charge=0
		check(level.use_supply(actor,"battery_pack") and actor.flashlight_charge==(80 if weak else 90) and actor.flashlight_on and actor.supplies.battery_pack==1,"battery_refill_from_empty_weak_%s"%weak)
		actor.flashlight_charge=60
		check(level.use_supply(actor,"battery_pack") and actor.flashlight_charge==90,"battery_refill_caps_at_capacity_weak_%s"%weak)
		actor.supplies.battery_pack=1
		check(not level.use_supply(actor,"battery_pack") and actor.supplies.battery_pack==1,"full_light_keeps_battery_weak_%s"%weak)
	actor.effects.clear();actor.flashlight_charge=90;actor.flash_cooldown=0
	for index in range(3):
		level.use_flash(actor)
		check(actor.flashlight_charge==90-30*(index+1) and actor.flash_cooldown==CampPlayer.FLASH_COOLDOWN,"flash_costs_thirty_%d"%index)
		actor.flash_cooldown=0
	level.use_flash(actor)
	check(actor.flashlight_charge==0 and actor.flash_cooldown==0,"fourth_flash_rejected_without_charge")
	actor.flashlight_charge=29.9
	level.use_flash(actor)
	check(actor.flashlight_charge==29.9 and actor.flash_cooldown==0,"below_thirty_flash_keeps_charge")
	actor.flashlight_charge=30
	level.use_flash(actor)
	check(actor.flashlight_charge==0 and actor.flash_cooldown==CampPlayer.FLASH_COOLDOWN,"exact_thirty_allows_one_flash")
	actor.flashlight_charge=90
	level.use_flash(actor)
	check(actor.flashlight_charge==90,"flash_on_cooldown_keeps_charge")
	actor.flashlight_charge=0.01;actor.flashlight_on=true
	actor._physics_process(1)
	check(actor.flashlight_charge==0 and not actor.flashlight_on,"empty_light_switches_off")
	print(JSON.stringify({"event":"test_result","suite":"flashlight_endurance","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures==0 else 1)
