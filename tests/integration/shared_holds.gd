extends SceneTree
## Staged actor poses isolate authority hold arbitration; no input/network mocking
## is used by the companion real ENet contested-ignition regression.
class Holds extends Node:
	var actors: Dictionary={}
	var held: Array[int]=[]
	func holding(id: int) -> bool:return id in held
var checks:=0
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(JSON.stringify({"event":"assertion","name":label,"passed":ok}))
func run() -> void:
	root.get_node("Voice").mode="off"
	root.get_node("Session").mode="camp"
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	while current_scene==null or current_scene.name!="ForestLevel":await process_frame
	var level: Node2D=current_scene
	level.set_physics_process(false);level.player.set_physics_process(false)
	level.killer.enabled=false;level.night_clock.set_physics_process(false)
	var holders:=Holds.new();root.add_child(holders)
	holders.actors[1]=level.player
	for id in [20,30]:
		var body: CampPlayer=load("res://scenes/actors/player.tscn").instantiate()
		body.local_input=false;level.world_objects.add_child(body);body.set_physics_process(false)
		holders.actors[id]=body
	var van: CampVan=level.van
	van.installed.assign(van.required_parts)
	for body: CampPlayer in holders.actors.values():body.position=van.interaction_point()
	holders.held.assign([30]);level._advance_network_holds(holders,.4)
	check(van.start_actor==holders.actors[30] and is_equal_approx(van.start_progress,.4),"first_holder_owns_ignition")
	holders.held.assign([1,20,30]);level._advance_network_holds(holders,.3)
	check(van.start_actor==holders.actors[30] and is_equal_approx(van.start_progress,.7),"lower_ids_cannot_preempt_or_multiply_ignition")
	holders.held.assign([20,30]);level._advance_network_holds(holders,.2)
	check(van.start_actor==holders.actors[30] and is_equal_approx(van.start_progress,.9),"non_operator_release_keeps_progress")
	holders.held.assign([1,20]);level._advance_network_holds(holders,.1)
	check(van.start_actor==holders.actors[1] and is_equal_approx(van.start_progress,.1),"operator_release_resets_for_new_operator")
	holders.actors[1].position+=Vector2(0,100);level._advance_network_holds(holders,.2)
	check(van.start_actor==holders.actors[20] and is_equal_approx(van.start_progress,.2),"out_of_range_operator_yields_without_inheriting_progress")
	holders.held.clear();level._advance_network_holds(holders,.2)
	check(van.start_actor==null and van.start_progress==0,"everyone_releasing_resets_ignition")
	holders.held.assign([30]);level._advance_network_holds(holders,.3)
	holders.actors.erase(30);holders.held.assign([20]);level._advance_network_holds(holders,.1)
	check(van.start_actor==holders.actors[20] and is_equal_approx(van.start_progress,.1),"disconnected_operator_cannot_retain_hold")
	level._advance_network_holds(holders,2)
	check(van.running and holders.actors[20].status==CampPlayer.Status.BOARDED,"selected_operator_starts_and_boards")
	# A higher-ID rescuer must likewise retain their target while another joins.
	van.running=false;van.start_progress=0;van.start_actor=null
	var patient: CampPlayer=level.player
	patient.position=Vector2(120,400);patient.set_status(CampPlayer.Status.DOWNED)
	var rescuer: CampPlayer=holders.actors[20]
	rescuer.set_status(CampPlayer.Status.ALIVE);rescuer.position=patient.position+Vector2(20,0)
	holders.held.assign([20]);level._advance_network_holds(holders,.4)
	check(level.revive_actor==rescuer and is_equal_approx(level.revive_progress,.4),"first_rescuer_owns_revive")
	var helper: CampPlayer=load("res://scenes/actors/player.tscn").instantiate()
	helper.local_input=false;level.world_objects.add_child(helper);helper.set_physics_process(false)
	helper.position=patient.position+Vector2(-20,0);holders.actors[10]=helper
	holders.held.assign([10,20]);level._advance_network_holds(holders,.3)
	check(level.revive_actor==rescuer and is_equal_approx(level.revive_progress,.7),"lower_id_helper_cannot_reset_or_accelerate_revive")
	holders.held.assign([10]);level._advance_network_holds(holders,.1)
	check(level.revive_actor==helper and is_equal_approx(level.revive_progress,.1),"actual_rescuer_change_starts_fresh")
	holders.held.clear();level._advance_network_holds(holders,.1)
	check(level.revive_actor==null and level.revive_progress==0,"all_helpers_releasing_resets_revive")
	holders.queue_free()
	print(JSON.stringify({"event":"test_result","suite":"shared_holds","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(1 if failures else 0)
