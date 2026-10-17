extends SceneTree
## Real-window cardinal views at normal night exposure, plus sight/collision checks.
var checks := 0
var failures := 0
var level: Node2D
var before := false
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	before="--before" in OS.get_cmdline_user_args()
	root.get_node("Session").mode="woods"
	root.get_node("Session").next_seed=42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	while current_scene==null or current_scene.name!="ForestLevel": await process_frame
	await _frames(3)
	level=current_scene
	for enemy in get_nodes_in_group("killers"): enemy.enabled=false
	level.player.set_physics_process(false)
	var directions := [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]
	var labels := ["north","south","west","east"]
	for i in range(4):
		var found := false
		for cell: Vector2i in level.plan.woods.links:
			var neighbor: Vector2i=cell+directions[i]
			if not level.plan.woods.valid(neighbor) or neighbor in level.plan.woods.links[cell]: continue
			var at: Vector2=level.plan.woods.center(cell)
			var beyond: Vector2=level.plan.woods.center(neighbor)
			if CampMap.CAMP_BOUNDS.grow(400).has_point(at) or not level.plan.woods.zone_at(at).is_empty() or level.plan.woods.on_road(at): continue
			if level.clear_path(at,beyond): continue
			found=true
			level.player.position=at
			level.player.facing=Vector2(directions[i])
			level.player.flashlight_on=true
			level.player.get_node("Camera2D").offset=Vector2(directions[i])*(32 if i==0 else 24)
			var monster: CampKiller=get_nodes_in_group("cryptids")[0]
			monster.position=beyond
			level.player.get_node("Camera2D").force_update_scroll()
			level.player.queue_redraw()
			await _frames(5)
			for settled in range(3): await process_frame
			print(JSON.stringify({"event":"treeline_view","direction":labels[i],"at":at,"neighbor":beyond,"trees":level.camp_map.woods_canopy.trees.size(),"edge_trees":0 if before else level.camp_map.woods_canopy.trees.filter(func(tree):return level.sight.visible_edge_anchor(tree[3])!=null).size()}))
			_check(not level.sight.can_see(beyond) and not monster.visible,"hidden_neighbor_"+labels[i])
			if DisplayServer.get_name()!="headless":
				var lit := await _image()
				lit.save_png("res://artifacts/verification/treeline_%s_%s.png"%["before" if before else "after",labels[i]])
				if not before:
					level.sight.tree_line.hide()
					await _frames(2)
					var control := await _image()
					var foliage := 0
					for y in range(40,145):
						for x in range(384):
							if lit.get_pixel(x,y).get_luminance()-control.get_pixel(x,y).get_luminance()>0.015: foliage+=1
					_check(foliage>80,"readable_foliage_at_night_"+labels[i])
					level.sight.tree_line.show()
					level.player.flashlight_on=false
					await _frames(3)
					var dark := await _image()
					dark.save_png("res://artifacts/verification/treeline_unlit_%s.png"%labels[i])
			# Ordinary movement still stops at the wall; scenery does not carve routes.
			for step in range(100): level.player.apply_intent(Vector2(directions[i]),false,1.0/60)
			_check(level.player.position.distance_to(at)<65,"tree_wall_still_blocks_"+labels[i])
			break
		_check(found,"cardinal_fixture_"+labels[i])
	if not before and DisplayServer.get_name()!="headless":
		level.player.position=level.plan.woods.center(Vector2i(17,22))
		level.player.flashlight_on=true
		level.player.set_physics_process(true)
		Input.action_press("move_up")
		await _frames(120)
		Input.action_release("move_up")
		await process_frame
		var camera: Camera2D=level.player.get_node("Camera2D")
		_check(camera.offset.y < -25 and camera.offset.length()<40,"smooth_bounded_north_lookahead")
		_check(level.player.get_global_transform_with_canvas().origin.y<150,"survivor_stays_above_belt")
		var moving := await _image()
		moving.save_png("res://artifacts/verification/treeline_walking_north.png")
		print(JSON.stringify({"event":"treeline_render_sample","fps":Engine.get_frames_per_second(),"position":level.player.position,"screen":level.player.get_global_transform_with_canvas().origin,"hidden_spot":level.player.hidden_spot,"status":level.player.status,"visible":level.player.visible}))
		# Hide only the avatar drawing; its lights/camera and the foliage stay unchanged.
		var tint: Color=level.player.self_modulate
		level.player.self_modulate=Color(1,1,1,0)
		var avatar_control := await _image()
		level.player.self_modulate=tint
		var origin: Vector2=level.player.get_global_transform_with_canvas().origin
		var avatar_pixels := 0
		for y in range(int(origin.y)-26,int(origin.y)-3):
			for x in range(int(origin.x)-10,int(origin.x)+10):
				if moving.get_pixel(x,y).get_luminance()-avatar_control.get_pixel(x,y).get_luminance()>0.02: avatar_pixels+=1
		_check(avatar_pixels>20,"survivor_visible_against_north_wall")
		level.player.position=Vector2(96,384)
		await _frames(90)
		_check(camera.offset.length()<1,"camp_camera_recenters")
	print(JSON.stringify({"event":"test_result","suite":"treeline","checks":checks,"failures":failures}))
	current_scene.queue_free()
	await _frames(4)
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures==0 else 1)
func _frames(count: int) -> void:
	for frame in range(count): await physics_frame
func _image() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(JSON.stringify({"event":"assertion","name":label,"passed":ok}))
