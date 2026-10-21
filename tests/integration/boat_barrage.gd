extends SceneTree
## Staged normal Boat night, frozen AI/director, normal lighting; microphone off.
var checks:=0
var failures:=0
var level: Node
var actor: CampPlayer
var field: FieldEscapes
var barrage: LakeBarrage
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(JSON.stringify({"event":"assertion","name":label,"passed":ok}))
func frames(n: int=4) -> void:
	for i in range(n):await physics_frame;await process_frame
func quiet() -> void:
	barrage.stop();barrage.clock=100
	actor.health=100;actor.invulnerability=0;actor.effects.clear();actor.hidden_spot=-1
	actor.status=CampPlayer.Status.ALIVE;actor.position=field.boat_point
func run() -> void:
	root.get_node("Voice").mode="off"
	root.get_node("Session").mode="woods";root.get_node("Session").survivor="christian";root.get_node("Session").next_seed=13
	RoundPlan.force_all_escapes=false;RoundPlan.force_modifiers=[]
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	while current_scene==null or current_scene.name!="ForestLevel":await process_frame
	await frames(10)
	level=current_scene;actor=level.player;field=level.escapes;barrage=field.barrage
	level.set_physics_process(false);level.abilities.set_physics_process(false);level.night_clock.set_physics_process(false)
	actor.set_physics_process(false);actor.local_input=false
	for enemy in get_nodes_in_group("killers"):enemy.enabled=false;enemy.set_physics_process(false)
	check(level.plan.escape_options==["van","boat"],"ordinary_two_route_boat_seed")
	actor.position=field.boat_point;actor.inventory.assign(FieldEscapes.BOAT_PARTS)
	check(field.interact(actor) and field.boat_installed.size()==3,"normal_component_install")
	check(field.interact(actor) and field.boat_started,"normal_launch_start")
	level.night_clock.force_phase(3)
	quiet()
	field.advance(1)
	check(field.boat_remaining==24 and field.boat_occupied,"inside_circle_advances_at_normal_rate")
	actor.position+=Vector2(0,100)
	field.advance(2)
	check(field.boat_remaining==24 and not field.boat_occupied and "PAUSED" in field.heading(),"outside_circle_pauses_without_losing_progress")
	actor.position=field.boat_point+Vector2(0,79)
	field.advance(1)
	check(field.boat_remaining==23,"inside_outer_circle_does_not_require_holding_interact")
	for effect in ["held","asleep"]:
		actor.add_effect(effect,10)
		field.advance(1)
		check(field.boat_remaining==23,"incapacitated_cannot_advance_"+effect)
		actor.effects.clear()
	actor.hidden_spot=0;field.advance(1)
	check(field.boat_remaining==23,"hidden_cannot_advance")
	actor.hidden_spot=-1
	var friend: CampPlayer=load("res://scenes/actors/player.tscn").instantiate()
	friend.local_input=false;friend.position=field.boat_point
	level.world_objects.add_child(friend);friend.set_physics_process(false)
	actor.position=field.boat_point+Vector2(0,140)
	field.advance(1)
	check(field.boat_remaining==22,"teammate_can_hold_circle_while_caster_is_out")
	actor.position=field.boat_point;field.advance(1)
	check(field.boat_remaining==21,"two_survivors_do_not_double_progress")
	friend.status=CampPlayer.Status.DOWNED;actor.position+=Vector2(0,140);field.advance(1)
	check(field.boat_remaining==21,"downed_body_does_not_hold_circle")
	friend.queue_free();await frames()
	quiet();barrage.clock=0
	field.advance(.01)
	check(barrage.shots.size()==1 and barrage.shots[0].tell==LakeBarrage.TELL,"first_shot_has_full_windup")
	var target: Vector2=barrage.shots[0].target
	actor.position+=Vector2(0,30)
	barrage.advance(.2)
	check(barrage.shots[0].target==target and barrage.shots[0].position==barrage.shots[0].origin,"telegraph_locks_aim_and_does_not_move_early")
	barrage.advance(.16)
	barrage.advance(.15)
	check(barrage.shots.size()==2 and barrage.sequence==2,"rapid_half_second_cadence_overlaps_shots")
	quiet()
	barrage.launch(actor.position-Vector2(20,0),actor.position);barrage.shots[0].tell=0
	barrage.advance(.2)
	check(actor.health==82 and barrage.shots.is_empty(),"swept_projectile_hits_and_removes_once")
	var health:=actor.health;barrage.advance(.2)
	check(actor.health==health,"removed_shot_cannot_damage_twice")
	quiet()
	var aim:=actor.position
	barrage.launch(aim-Vector2(20,0),aim);barrage.shots[0].tell=0
	actor.position+=Vector2(0,24);barrage.advance(.3)
	check(actor.health==100,"sidestep_inside_circle_dodges")
	quiet()
	var wall:=StaticBody2D.new();wall.position=actor.position-Vector2(14,0);wall.collision_layer=1
	var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(4,30);collision.shape=shape
	wall.add_child(collision);level.world_objects.add_child(wall);await frames()
	barrage.launch(actor.position-Vector2(30,0),actor.position);barrage.shots[0].tell=0
	barrage.advance(.3)
	check(actor.health==100 and barrage.shots.is_empty(),"wall_blocks_swept_projectile")
	wall.queue_free();await frames()
	quiet()
	barrage.launch(actor.position-Vector2(40,0),actor.position);barrage.shots[0].tell=0;barrage.shots[0].life=.01
	barrage.advance(1)
	check(actor.health==100 and barrage.shots.is_empty(),"expired_shot_cannot_sweep_beyond_lifetime")
	quiet();actor.health=10;field.boat_remaining=4
	barrage.launch(actor.position-Vector2(20,0),actor.position);barrage.shots[0].tell=0
	field.advance(.2)
	check(actor.status==CampPlayer.Status.DOWNED and field.boat_remaining==4 and not field.boat_occupied,"downing_last_crew_stops_progress_on_hit_tick")
	quiet();actor.role="john";actor.ability_active=6
	barrage.launch(actor.position-Vector2(20,0),actor.position);barrage.shots[0].tell=0
	barrage.advance(.2)
	check(actor.health==100 and actor.kit.debt==9,"john_half_damage_deferral_applies_to_shots")
	actor.kit.debt=0;actor.ability_active=0;actor.role="christian"
	quiet()
	var flare: Node2D=load("res://scripts/items/flare.gd").new();flare.position=actor.position
	level.world_objects.add_child(flare);flare.set_physics_process(false)
	barrage.launch(actor.position-Vector2(20,0),actor.position);barrage.shots[0].tell=0
	barrage.advance(.2)
	check(actor.health==100 and barrage.shots.is_empty(),"nearby_flare_blocks_crossing_shot")
	flare.queue_free();await frames()
	quiet()
	for i in range(30):barrage.launch(actor.position-Vector2(30,0),actor.position)
	check(barrage.shots.size()==LakeBarrage.MAX_SHOTS,"shot_count_bounded")
	var snapshot:=field.snapshot()
	barrage.stop();field.boat_occupied=false
	field.restore(snapshot)
	check(barrage.shots.size()==LakeBarrage.MAX_SHOTS and barrage.visual_age==0,"snapshot_restores_shots_without_spawning_or_replay")
	barrage.shots[0].position+=Vector2(1,0)
	check(barrage.shots[0].position!=snapshot.barrage.shots[0].position,"replicated_shot_data_is_independent")
	quiet();level.paused=true;barrage.clock=0
	var remaining:=field.boat_remaining
	field.advance(1)
	check(field.boat_remaining==remaining and barrage.shots.is_empty(),"offline_pause_stops_progress_and_firing")
	level.paused=false
	if "--capture" in OS.get_cmdline_user_args():
		quiet();barrage.clock=0;field.boat_remaining=14;field.boat_occupied=true
		for i in range(100):
			actor.position=field.boat_point+Vector2(0,sin(i*.13)*35)
			barrage.advance(1.0/60)
		actor.position=field.boat_point+Vector2(0,15)
		level.message_time=0;actor.notice_time=0;level.hud.broadcast.hide()
		await frames(40)
		await shot("barrage_normal")
		check(actor.get_node("Camera2D").zoom.x<.67,"launch_frames_complete_dodge_circle")
	quiet();field.boat_remaining=.02
	actor.position+=Vector2(0,110);field.advance(.1)
	check(not level.finished and field.boat_remaining==.02,"empty_circle_cannot_finish_launch")
	actor.position=field.boat_point;field.advance(.03)
	check(level.finished and level.won and actor.status==CampPlayer.Status.ESCAPED and barrage.shots.is_empty(),"circle_completion_extracts_and_clears_shots")
	field._frame_launch(.1)
	check(actor.get_node("Camera2D").zoom==Vector2.ONE,"completion_restores_camera_zoom")
	# Stop world-owned native playback before draining the audio backend.
	level.soundscape.stop_round()
	await frames()
	print(JSON.stringify({"event":"test_result","suite":"boat_barrage","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(1 if failures else 0)
func shot(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/boat_barrage"))
	await frames()
	await process_frame
	actor.get_node("Camera2D").force_update_scroll()
	RenderingServer.force_draw(true)
	check(root.get_texture().get_image().save_png("res://artifacts/boat_barrage/"+name+".png")==OK,"capture_"+name)
