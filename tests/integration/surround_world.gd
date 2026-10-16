extends SceneTree
var checks := 0
var failures := 0
var capture := false
var level: Node2D

class Overview extends Control:
	var plan: RoundPlan
	const COLORS := {"village":"c8b28b", "bog":"81ad92", "graveyard":"a3b7b4", "mill":"79aeb2", "orchard":"a9b878", "observatory":"aaa8d0", "rail":"c79c78", "quarry":"bac2ad", "chapel":"8cabbc"}
	func _draw() -> void:
		draw_rect(Rect2(0,0,384,216),Color("091614"))
		var scale := 180.0 / WoodsLayout.WORLD_BOUNDS.size.y
		var origin := Vector2(99,26)
		draw_rect(Rect2(origin-Vector2.ONE,WoodsLayout.WORLD_BOUNDS.size*scale+Vector2.ONE*2),Color("69816c"),false)
		draw_rect(Rect2(origin,WoodsLayout.WORLD_BOUNDS.size*scale),Color("1a3828"))
		for rect in plan.woods.corridors:
			draw_rect(Rect2(origin+(rect.position-WoodsLayout.ORIGIN)*scale,rect.size*scale),Color("685e3c"))
		for zone in plan.woods.zones:
			var rect: Rect2 = zone["bounds"]
			draw_rect(Rect2(origin+(rect.position-WoodsLayout.ORIGIN)*scale,rect.size*scale),Color(COLORS[zone["kind"]]))
		var camp := CampMap.CAMP_BOUNDS
		draw_rect(Rect2(origin+(camp.position-WoodsLayout.ORIGIN)*scale,camp.size*scale),Color("e0cb87"))
		for enemy in plan.encounters:
			var at: Vector2 = origin+(enemy["position"]-WoodsLayout.ORIGIN)*scale
			draw_circle(at,1.2,Color("f38e72"))
			if enemy.has("home"):
				draw_arc(at,2.5,0,TAU,12,Color("e6c49c"))
		# Number badges reference the two readable legends without covering trail geometry.
		for index in range(plan.woods.zones.size()):
			var zone: Dictionary = plan.woods.zones[index]
			var at: Vector2 = origin+(zone["bounds"].position-WoodsLayout.ORIGIN)*scale
			draw_rect(Rect2(at+Vector2(1,1),Vector2(7,9)),Color("10201d"))
			draw_string(ThemeDB.fallback_font,at+Vector2(2,8),str(index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("fff0c2"))
		var camp_at: Vector2 = origin+(camp.get_center()-WoodsLayout.ORIGIN)*scale
		draw_string(ThemeDB.fallback_font,camp_at+Vector2(-3,3),"C",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("17261c"))
		draw_string(ThemeDB.fallback_font,Vector2(8,12),"FOREST ATLAS / NIGHT %d / 9,600 x 9,408" % plan.seed_value,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e4d7ad"))
		draw_string(ThemeDB.fallback_font,Vector2(8,23),"9 REGIONS / 24 CRYPTIDS + CAMP STALKER / NORTH UP",HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("9eae96"))
		var labels := [
			[7,"8 QUARRY","STONEBACK RAM",Vector2(4,42)],
			[0,"1 VILLAGE","REQUIRED CACHE",Vector2(4,78)],
			[3,"4 FLOODED MILL","BOILER SAINT",Vector2(4,114)],
			[4,"5 ORCHARD","SEAMSTRESS",Vector2(4,150)],
			[2,"3 GRAVEYARD","REQUIRED CACHE",Vector2(4,186)],
			[5,"6 OBSERVATORY","SHUTTER WRAITH",Vector2(288,42)],
			[1,"2 WITCH'S BOG","REQUIRED CACHE",Vector2(288,86)],
			[6,"7 RAIL YARD","CONDUCTOR",Vector2(288,130)],
			[8,"9 CHAPEL","CANDLE GRAZER",Vector2(288,174)]
		]
		for label in labels:
			var zone: Dictionary=plan.woods.zones[label[0]]
			var at: Vector2=label[3]
			draw_string(ThemeDB.fallback_font,at,label[1],HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color(COLORS[zone["kind"]]))
			draw_string(ThemeDB.fallback_font,at+Vector2(0,10),label[2],HORIZONTAL_ALIGNMENT_LEFT,-1,6,Color("a8b69e"))
		draw_string(ThemeDB.fallback_font,Vector2(287,196),"C  FERNWOOD CAMP",HORIZONTAL_ALIGNMENT_LEFT,-1,6,Color("e0cb87"))
		draw_circle(Vector2(290,204),1.2,Color("f38e72"))
		draw_string(ThemeDB.fallback_font,Vector2(296,207),"CRYPTID SPAWN",HORIZONTAL_ALIGNMENT_LEFT,-1,6,Color("a8b69e"))

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
