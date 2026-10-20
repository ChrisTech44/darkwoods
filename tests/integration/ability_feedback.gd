extends SceneTree
## Actual handlers + native soundscape, controlled AI. Optional graphical evidence.
var checks := 0
var failures := 0
var level: Node2D
var actor: CampPlayer
var friend: CampPlayer
var capture := false
const OUT := "res://artifacts/ability_polish/"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(JSON.stringify({"event":"assertion","name":label,"passed":ok}))
func frames(n: int = 3) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func shot(label: String) -> void:
	if not capture: return
	actor.queue_redraw()
	friend.queue_redraw()
	level.abilities.queue_redraw()
	level._process(0)
	await frames()
	RenderingServer.force_draw(true)
	await process_frame
	check(root.get_texture().get_image().save_png(OUT+label+".png")==OK,"capture_"+label)
func reset(kind: String, role: String = "christian") -> void:
	CreatureSamples.finish_cast(actor)
	actor.role=role
	SurvivorAbilities.setup(actor)
	actor.position=Vector2(900,520)
	actor.facing=Vector2.RIGHT
	actor.peer_name="Christian" if role=="christian" else role.capitalize()
	actor.sheet=load("res://assets/sprites/survivor_"+role+".png")
	actor.effects.clear()
	actor.health=100
	actor.flash_time=0
	actor.holder=null
	actor.kit.sample=kind
	actor.kit.impact={}
	actor.notice_time=0
	actor.notice=""
	level.message_time=0
	friend.position=actor.position+Vector2(85,0)
	friend.effects.clear()
	friend.holder=null
	friend.velocity=Vector2(10,0)
func run() -> void:
	capture="--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_node("Voice").mode="off"
	root.get_node("Session").mode="woods"
	root.get_node("Session").next_seed=42
	root.get_node("Session").survivor="christian"
	RoundPlan.force_modifiers=[]
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await frames(15)
	level=current_scene
	actor=level.player
	level.hud.prompt.hide()
	level.hud.broadcast.hide()
	actor.local_input=false
	actor.set_physics_process(false)
	level.set_physics_process(false)
	level.abilities.set_physics_process(false)
	level.night_clock.active=false
	level.night_clock.set_physics_process(false)
	level.soundscape.set_physics_process(false)
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled=false
		enemy.set_physics_process(false)
	friend=load("res://scenes/actors/player.tscn").instantiate()
	friend.role="john"
	friend.peer_name="John"
	friend.local_input=false
	level.world_objects.add_child(friend)
	friend.set_physics_process(false)
	var camera := Camera2D.new()
	level.add_child(camera)
	camera.position=Vector2(945,520)
	camera.make_current()
	var banner := CanvasLayer.new()
	banner.layer=100
	level.add_child(banner)
	var label := Label.new()
	label.position=Vector2(8,205)
	label.add_theme_font_size_override("font_size",7)
	label.text="STAGED seed42 | normal light/sight | AI + clock frozen | mic OFF"
	banner.add_child(label)
	for kind: String in CreatureSamples.SOURCES:
		check(SamplePresentation.SHAPES.has(kind),"delivery_reviewed_"+kind)
	for kind in SamplePresentation.CUES:
		check(root.get_node("AudioManager").stream_for(SamplePresentation.CUES[kind][0])!=null,"copy_cue_registered_"+kind)
	for curse in ["frog","backwards","float","swap"]:
		reset("witch")
		actor.kit.subtype=curse
		if curse=="swap":
			# A second living target is required by the actual preflight.
			var extra: CampPlayer=load("res://scenes/actors/player.tscn").instantiate()
			extra.position=actor.position+Vector2(115,15)
			extra.local_input=false
			level.world_objects.add_child(extra)
			extra.set_physics_process(false)
		check(level.abilities.use(actor),"launch_curse_"+curse)
		CreatureSamples.advance(actor,0.81)
		CreatureSamples.advance(actor,0.32)
		check(actor.kit.cast.get("projectile",false) and friend.effects.is_empty(),"curse_visible_before_impact_"+curse)
		await shot("projectile_"+curse)
		CreatureSamples.advance(actor,0.5)
		if curse!="swap": check(friend.has_effect(curse),"curse_swept_hit_"+curse)
		await shot("impact_"+curse)
	for kind in ["ration_moth","bramble_seamstress","lantern_moth","hitchhiker"]:
		reset(kind)
		check(level.abilities.use(actor),"launch_copy_"+kind)
		CreatureSamples.advance(actor,0.81)
		CreatureSamples.advance(actor,0.32)
		check(actor.kit.cast.get("projectile",false),"copy_travels_"+kind)
		await shot("projectile_"+kind)
		CreatureSamples.advance(actor,0.5)
		var effect: String={"ration_moth":"sneezy","bramble_seamstress":"tethered","lantern_moth":"face_moth","hitchhiker":"piggyback"}[kind]
		check(friend.has_effect(effect),"copy_projectile_hits_"+kind)
	# A real physics wall blocks both the shot and its local direction guide.
	reset("witch")
	var wall := StaticBody2D.new()
	wall.position=actor.position+Vector2(45,0)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size=Vector2(4,64)
	collision.shape=rectangle
	wall.add_child(collision)
	level.world_objects.add_child(wall)
	await frames()
	level.abilities.use(actor)
	CreatureSamples.advance(actor,0.81)
	CreatureSamples.advance(actor,0.8)
	check(friend.effects.is_empty() and actor.kit.cast.is_empty(),"projectile_cannot_hit_through_wall")
	check(SamplePresentation.clipped(level,actor.position,Vector2.RIGHT,272).x<wall.position.x,"aim_guide_stops_at_same_wall")
	wall.queue_free()
	await frames()
	reset("witch")
	friend.ward_remaining=3
	level.abilities.use(actor)
	CreatureSamples.advance(actor,0.81)
	CreatureSamples.advance(actor,0.8)
	check(actor.kit.cast.get("reflected",false) and not friend.has_effect("frog"),"ward_reflects_visible_projectile")
	CreatureSamples.advance(actor,0.8)
	check(actor.has_effect("frog"),"reflected_projectile_can_hit_christian")
	friend.ward_remaining=0
	# Cuckoo's three calls and rewind use the creature's real cue/effect IDs.
	reset("cuckoo")
	level.soundscape.played_counts.clear()
	CreatureSamples.history[friend.get_instance_id()]=[friend.position-Vector2(20,0)]
	level.abilities.use(actor)
	for i in range(181): CreatureSamples.advance(actor,1.0/60)
	check(level.soundscape.played_counts.get("squeak",0)==3 and level.soundscape.played_counts.get("bells",0)==1,"cuckoo_three_calls_then_rewind_bell")
	check(friend.has_effect("rewound") and friend.has_effect("whiteout"),"cuckoo_native_rewind_screen_effects")
	# Continuous singing follows the copied Saint, ends on cancellation, and is reusable.
	reset("boiler_saint")
	level.abilities.use(actor)
	CreatureSamples.advance(actor,0.81)
	level.soundscape._follow_loops()
	var key := "sample_song:%d" % actor.get_instance_id()
	check(level.soundscape.follow_loops.has(key),"copied_saint_has_positional_lullaby_loop")
	if level.soundscape.follow_loops.has(key):
		var loop: AudioStreamPlayer2D=level.soundscape.follow_loops[key]
		check(loop.stream==root.get_node("AudioManager").stream_for("lullaby"),"copied_song_uses_native_audio_asset")
	await shot("lullaby_range")
	CreatureSamples.finish_cast(actor)
	level.soundscape._follow_loops()
	check(not level.soundscape.follow_loops.has(key),"copied_song_stops_on_cancel")
	reset("slug")
	level.abilities.use(actor)
	CreatureSamples.advance(actor,0.81)
	for i in range(4):
		actor.position.x+=12
		CreatureSamples.advance(actor,0.51)
	await shot("slime_trail")
	for kind in ["werewolf","briar_revenant","groundskeeper","mimic"]:
		reset(kind)
		level.night_clock.moon=true
		level.abilities.use(actor)
		check(SamplePresentation.detail(actor).contains("left"),"visible_form_timer_"+kind)
		await shot("form_"+kind)
	reset("","max")
	actor.kit.cash=0
	await shot("max_explained")
	level.abilities.use(actor)
	actor.kit.wheel_time=1.4
	await shot("max_gamble")
	level.abilities.enabled=false
	SurvivorKits.advance(actor,0.1)
	await shot("abilities_disabled")
	check(not level.abilities.use(actor),"disabled_rule_blocks_input")
	if capture:
		level=null
		change_scene_to_file("res://scenes/ui/main_menu.tscn")
		await frames(8)
		current_scene.get_node("Menu/Settings").pressed.emit()
		await frames()
		RenderingServer.force_draw(true)
		await process_frame
		root.get_texture().get_image().save_png(OUT+"offline_rule.png")
		change_scene_to_file("res://scenes/ui/network_lobby.tscn")
		await frames(8)
		RenderingServer.force_draw(true)
		await process_frame
		root.get_texture().get_image().save_png(OUT+"lobby_rule.png")
	print(JSON.stringify({"event":"test_result","suite":"ability_feedback","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(1 if failures else 0)
