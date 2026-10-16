extends SceneTree
var checks := 0
var failures := 0
var capture := false
var level: Node2D

class Overview extends Control:
	var plan: RoundPlan
	func _draw() -> void:
		draw_rect(Rect2(0,0,384,216),Color("091614"))
		var scale := 180.0 / WoodsLayout.WORLD_BOUNDS.size.y
		var origin := Vector2(100,24)
		draw_rect(Rect2(origin,WoodsLayout.WORLD_BOUNDS.size*scale),Color("1a3828"))
		for rect in plan.woods.corridors:
			draw_rect(Rect2(origin+(rect.position-WoodsLayout.ORIGIN)*scale,rect.size*scale),Color("685e3c"))
		for zone in plan.woods.zones:
			var rect: Rect2 = zone["bounds"]
			draw_rect(Rect2(origin+(rect.position-WoodsLayout.ORIGIN)*scale,rect.size*scale),Color("a9ad79"))
		var camp := CampMap.CAMP_BOUNDS
		draw_rect(Rect2(origin+(camp.position-WoodsLayout.ORIGIN)*scale,camp.size*scale),Color("e0cb87"))
		for enemy in plan.encounters:
			draw_circle(origin+(enemy["position"]-WoodsLayout.ORIGIN)*scale,1.5,Color("dd8161"))
		draw_string(ThemeDB.fallback_font,Vector2(10,14),"INSPECTION / 9,600 x 9,408 / CAMP AT CENTRE",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e4d7ad"))
		draw_string(ThemeDB.fallback_font,Vector2(6,45),"NW VILLAGE",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("c4c2a0"))
		draw_string(ThemeDB.fallback_font,Vector2(294,100),"EAST BOG",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("c4c2a0"))
		draw_string(ThemeDB.fallback_font,Vector2(6,170),"S GRAVEYARD",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("c4c2a0"))
		draw_string(ThemeDB.fallback_font,Vector2(294,160),"24 CREATURES",HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("c4c2a0"))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	_check(WoodsLayout.WORLD_BOUNDS.get_center() == CampMap.CAMP_BOUNDS.get_center(), "camp_exactly_at_world_centre")
	_check(WoodsLayout.WORLD_BOUNDS.get_area() > 30.0 * 1600 * 1600, "forest_more_than_thirty_times_old_area")
	for value in [42,2026,6789]:
		var plan := RoundPlan.new()
		plan.generate(value,"woods")
		_check(plan.woods.links.size() == 2410 and plan.woods.distances_from(WoodsLayout.ENTRY).size() == 2410,"all_forest_cells_connected_%d"%value)
		_check(plan.encounters.size() == 24,"twenty_four_surrounding_creatures_%d"%value)
		var sides := {}
		for enemy in plan.encounters:
			var offset: Vector2 = enemy["position"]-CampMap.CAMP_BOUNDS.get_center()
			sides["EW" + str(signf(offset.x)) if absf(offset.x)>absf(offset.y) else "NS" + str(signf(offset.y))] = true
		_check(sides.size()==4,"monsters_on_all_four_sides_%d"%value)
		for zone in plan.woods.zones:
			var clear := true
			for wall in plan.woods.walls:
				if wall.intersects(zone["bounds"].grow(16)):
					clear = false
			_check(clear,"spacious_clear_apron_%d_%s"%[value,zone["kind"]])
	root.get_node("Session").mode="woods"
	root.get_node("Session").next_seed=42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await _frames(5)
	level=current_scene
	for enemy in get_nodes_in_group("killers"):
		enemy.enabled=false
	for attempt in range(240):
		await physics_frame
		if _reachable(level.pickups[0].position):
			break
	for entry in WoodsLayout.ENTRIES:
		_check(_reachable(level.plan.woods.center(entry)),"native_camp_exit_%s"%entry)
	for enemy in level.plan.encounters:
		_check(_reachable(enemy["position"]),"native_creature_home_%s_%s"%[enemy["species"],enemy["cell"]])
	for zone in level.plan.woods.zones:
		_check(_reachable(zone["position"]),"native_region_centre_%s"%zone["kind"])
	var gates := [[Vector2(80,520),"move_left",140],[Vector2(1440,520),"move_right",180],[Vector2(672,192),"move_up",270],[Vector2(864,880),"move_down",180]]
	for gate in gates:
		level.player.position=gate[0]
		Input.action_press(gate[1])
		await _frames(gate[2])
		Input.action_release(gate[1])
		_check(CampMap.is_woods(level.player.position),"input_traverses_camp_gate_%s"%gate[1])
	if capture:
		await _tour()
	print(JSON.stringify({"event":"test_result","suite":"surround_world","checks":checks,"failures":failures,"walls":level.plan.woods.walls.size(),"clearings":level.plan.woods.links.size()}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures==0 else 1)

func _reachable(goal: Vector2) -> bool:
	var path:=NavigationServer2D.map_get_path(level.get_world_2d().navigation_map,level.player.position,goal,true)
	return path.size()>1 and path[-1].distance_to(goal)<8

func _tour() -> void:
	var layer := CanvasLayer.new()
	layer.layer=20
	root.add_child(layer)
	var overview:=Overview.new()
	overview.plan=level.plan
	layer.add_child(overview)
	await _frames(3)
	await _snapshot("surround_overview")
	layer.queue_free()
	level.sight.enabled=false
	for node in level.get_children():
		if node.get_script()==load("res://scripts/ui/night_overlay.gd"):
			node.set_process(false)
			node.ambient.color=Color(0.7,0.7,0.7)
	level.player.get_node("Camera2D").zoom=Vector2(0.25,0.25)
	for zone in level.plan.woods.zones:
		level.player.position=zone["position"]
		await _frames(12)
		await _snapshot("surround_"+zone["kind"])
	level.player.get_node("Camera2D").zoom=Vector2.ONE

func _snapshot(name: String) -> void:
	await process_frame
	RenderingServer.force_draw(true)
	_check(root.get_texture().get_image().save_png("res://artifacts/verification/"+name+".png")==OK,"capture_"+name)

func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func _check(passed: bool,name: String) -> void:
	checks+=1
	failures+=0 if passed else 1
	print(JSON.stringify({"event":"assertion","name":name,"passed":passed}))
