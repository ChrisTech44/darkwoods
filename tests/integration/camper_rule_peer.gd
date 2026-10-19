extends SceneTree
## Real authority/client processes; no test RPCs enter the game protocol.
var net: Node
var side := OS.get_environment("LNAC_RULE_SIDE")
var port := int(OS.get_environment("LNAC_RULE_PORT"))
var index := int(OS.get_environment("LNAC_RULE_INDEX"))
var humans := int(OS.get_environment("LNAC_RULE_HUMANS"))
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(JSON.stringify({"event":"assertion","name":label,"passed":ok}))
func until(predicate: Callable) -> bool:
	var end := Time.get_ticks_msec()+90000
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	check(predicate.call(),"wait_"+net.phase)
	return predicate.call()
func run() -> void:
	root.get_node("Voice").mode="off"
	net=root.get_node("Net")
	if side=="host":
		check(net.host(port,"Christian","christian")==OK,"listen_host_binds")
		net.configure_lobby("camp",42,false)
		net.choose("christian",true)
		if not await until(func(): return net.roster.size()==humans and net.can_start()): finish();return
		check(net.start_round("camp",42),"listen_host_starts_disabled_round")
	elif side=="client":
		check(net.join("127.0.0.1",port,SurvivorRoster.NAMES[index],SurvivorRoster.IDS[index])==OK,"guest_joins")
		if not await until(func(): return net.phase=="lobby"): finish();return
		check(not net.camper_abilities_enabled,"guest_receives_host_rule_in_lobby")
		# A guest cannot re-enable a host rule through the public configure API.
		net.configure_lobby("camp",42,true)
		check(not net.camper_abilities_enabled,"guest_cannot_change_rule")
		net.choose(SurvivorRoster.IDS[index],true)
	if not await until(func(): return net.phase=="playing"): finish();return
	check(not net.world.abilities.enabled and not root.get_node("Session").camper_abilities_enabled,"round_uses_locked_host_rule")
	if side=="client":
		var mine: CampPlayer=net.world.player
		mine.kit.cash=100 # Presentation tampering must not authorize a purchase.
		net.action("ability")
		net.action("ability_release")
		await create_timer(1.5).timeout
		check(mine.ability_active==0 and mine.kit.form=="" and mine.kit.channel==0 and mine.kit.cash==0,"authority_rejects_guest_ability_and_restores_state")
		check(SurvivorKits.status(mine)=="CAMPER ABILITIES OFF","guest_hud_explains_rule")
		await create_timer(1.5+index*0.5).timeout
		net.leave("Rule check complete.")
	else:
		await create_timer(2.0).timeout
		check(net.actors.size()==humans,"authority_has_all_humans")
		for actor: CampPlayer in net.actors.values():
			check(not net.world.abilities.use(actor) and actor.kit.form=="" and actor.ability_active==0 and actor.kit.cash==0,"authority_blocks_"+actor.role)
			if actor.role=="john":
				actor.stamina=0
				SurvivorKits.progress(actor,"rule:real_round")
				check(actor.stamina==0,"authority_disables_progress_bonus")
			elif actor.role=="max":
				SurvivorKits.earn(actor,"rule:cash",4)
				check(actor.kit.cash==0,"authority_disables_earning")
			elif actor.role=="alex":
				actor.position=Vector2(1000,800)
				SurvivorKits.advance(actor,5)
				check(not actor.kit.isolated,"authority_disables_isolation")
		await create_timer(4.0).timeout
	finish()
func finish() -> void:
	print(JSON.stringify({"event":"test_result","suite":"camper_rule_"+side,"checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(1 if failures else 0)
