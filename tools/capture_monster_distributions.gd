extends SceneTree
## Source-generated diagnostic map, not the discovery-limited in-game notebook.
const OUT := "res://artifacts/monster_distributions/"
const SEEDS := [13,42,2026]
const HIGHLIGHTS := {"teddy":Color("ffbe69"),"lifeguard":Color("6ee5d4"),"huntmaster":Color("cc9aff")}

class DistributionCanvas extends Node2D:
	var plans: Array = []
	var outer_regions := false
	var font := ThemeDB.fallback_font
	var ink := Color("e6e9ec")
	const SCALE := 530.0/9600.0
	func label(at: Vector2, value: String, size: int=17, color: Color=Color("e6e9ec")) -> void:
		draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
	func point(at: Vector2, origin: Vector2) -> Vector2:
		return origin+(at-WoodsLayout.WORLD_BOUNDS.position)*SCALE
	func _draw() -> void:
		draw_rect(Rect2(0,0,1800,1080),Color("10181f"))
		label(Vector2(35,40),"WHERE MONSTERS AND OBJECTIVES START" if outer_regions else "WHERE THE ROAMERS START",30)
		label(Vector2(35,70),"Three seeded Woods plans • 14 circuit + 15 interior roaming starts • five van parts in five separate outer regions" if outer_regions else "Three actual seeded Woods plans • 29 roamers per map • numbered by species below",18,Color("a8bac8"))
		for panel in range(plans.size()):
			var plan: RoundPlan=plans[panel]
			var origin:=Vector2(35+panel*590,125)
			label(origin-Vector2(0,18),"SEED %d" % SEEDS[panel],20)
			draw_rect(Rect2(origin,Vector2(530,9408*SCALE)),Color("19272b"))
			for tile: Vector2i in plan.woods.open_tiles:
				draw_rect(Rect2(point(Vector2(tile)*32,origin),Vector2.ONE*32*SCALE+Vector2.ONE*0.15),Color("344346"))
			for zone: Dictionary in plan.woods.zones:
				var bounds: Rect2=zone.bounds
				draw_rect(Rect2(point(bounds.position,origin),bounds.size*SCALE),Color(0.36,0.50,0.55,0.19))
				draw_rect(Rect2(point(bounds.position,origin),bounds.size*SCALE),Color("526a73"),false,1)
			var camp:=Rect2(point(CampMap.CAMP_BOUNDS.position,origin),CampMap.CAMP_BOUNDS.size*SCALE)
			draw_rect(camp,Color("60513b"))
			label(camp.position+Vector2(20,30),"CAMP",13,Color("ffe0a0"))
			for encounter: Dictionary in plan.encounters:
				if not encounter.species in RoundPlan.ROAMER_SPECIES:
					var at:=point(encounter.position,origin)
					draw_colored_polygon(PackedVector2Array([at+Vector2(0,-4),at+Vector2(4,0),at+Vector2(0,4),at+Vector2(-4,0)]),Color("92a1aa"))
			if outer_regions:
				for zone: Dictionary in plan.woods.zones:
					var name: String=WoodsLayout.SIGN_NAMES[zone.kind]
					var width:=font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
					var at:=point(zone.position,origin)
					at.x=clampf(at.x-width/2,origin.x+3,origin.x+530-width-3)
					var parts: Array = plan.cache_zone.keys().filter(func(kind): return plan.woods.zones[plan.cache_zone[kind]].kind==zone.kind)
					label(at+Vector2(0,-3 if not parts.is_empty() else 4),name,11,Color("acced3"))
					if not parts.is_empty():
						var part: String=parts[0].replace("_"," ").to_upper()
						var part_width:=font.get_string_size(part,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
						label(Vector2(clampf(point(zone.position,origin).x-part_width/2,origin.x+3,origin.x+530-part_width-3),at.y+11),part,10,Color("ffdc8e"))
			var circuit:=plan.roaming_circuit()
			for index in range(circuit.size()):
				draw_dashed_line(point(circuit[index],origin),point(circuit[(index+1)%circuit.size()],origin),Color("779397"),1.2,5)
			# These hulls enclose assigned waypoints, not a hard movement boundary.
			for encounter: Dictionary in plan.encounters:
				if not HIGHLIGHTS.has(encounter.species): continue
				var color: Color=HIGHLIGHTS[encounter.species]
				var points:=PackedVector2Array()
				for waypoint: Vector2 in plan.woods.roaming_route(encounter.cell): points.append(point(waypoint,origin))
				var hull:=Geometry2D.convex_hull(points)
				if hull.size()>3:
					draw_colored_polygon(hull,Color(color,0.12))
					draw_polyline(hull,Color(color,0.8),1.6,true)
				for at in points: draw_circle(at,2,color)
			for encounter: Dictionary in plan.encounters:
				var index:=RoundPlan.ROAMER_SPECIES.find(encounter.species)
				if index<0: continue
				var at:=point(encounter.position,origin)
				var color: Color=HIGHLIGHTS.get(encounter.species,Color("d6e4eb"))
				var ordinal:=plan.encounters.filter(func(e): return e.species in RoundPlan.ROAMER_SPECIES).find(encounter)
				if ordinal<RoundPlan.PERIMETER_ROAMERS: draw_circle(at,13,Color("6aa4ac"),false,1.2)
				draw_circle(at,10.5,Color("10181f"))
				draw_circle(at,10.5,color,false,1.0)
				var number:=str(index+1)
				var width:=font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
				label(at+Vector2(-width/2,4),number,12,color)
			label(origin+Vector2(0,545),"14 circuit + 15 interior  •  9 regional creatures",16,Color("a8bac8"))
		label(Vector2(35,722),"NUMBER KEY",18)
		for index in range(RoundPlan.ROAMER_SPECIES.size()):
			var species: String=RoundPlan.ROAMER_SPECIES[index]
			var column:=index/10
			var row:=index%10
			var title:=CampProfile.display_name(species)
			label(Vector2(35+column*590,748+row*23),"%02d  %s" % [index+1,title],16,HIGHLIGHTS.get(species,ink))
		label(Vector2(35,1000),"Dashed line = region-center circuit, not a new road. Outer halos = 14 circuit starts; plain circles = 15 interior starts.",17)
		label(Vector2(35,1027),"Colored outlines = sample patrol waypoints, not chase limits. Gray diamonds = regional creatures; tinted boxes = named regions.",17,Color("a8bac8"))
		label(Vector2(35,1054),"Diagnostic overview: all starts revealed. No simulated movement, altered lighting, frozen gameplay or forced escape routes. Stalker excluded.",16,Color("a8bac8"))

func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.get_node("Voice").mode="off"
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1800,1080)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.world_2d=World2D.new()
	root.add_child(viewport)
	var canvas:=DistributionCanvas.new()
	var records:=[]
	var output:=OUT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): output=argument.trim_prefix("--out=").trim_suffix("/")+"/"
	canvas.outer_regions="--region-labels" in OS.get_cmdline_user_args()
	for value in SEEDS:
		var plan:=RoundPlan.new()
		plan.generate(value,"woods")
		canvas.plans.append(plan)
		var encounters:=[]
		var roaming_index:=0
		for encounter: Dictionary in plan.encounters:
			var route:=[]
			for at: Vector2 in plan.woods.roaming_route(encounter.cell): route.append([at.x,at.y])
			var roaming: bool=encounter.species in RoundPlan.ROAMER_SPECIES
			encounters.append({"species":encounter.species,"position":[encounter.position.x,encounter.position.y],"roamer":roaming,"spawn_band":("circuit" if roaming_index<RoundPlan.PERIMETER_ROAMERS else "interior") if roaming else "regional","assigned_waypoints":route})
			if roaming:roaming_index+=1
		var parts:=[]
		for kind: String in plan.cache_zone:
			var item: Dictionary=plan.loot.filter(func(e): return e.kind==kind)[0]
			parts.append({"kind":kind,"region":plan.woods.zones[plan.cache_zone[kind]].kind,"position":[item.position.x,item.position.y]})
		var circuit:=[]
		for at: Vector2 in plan.roaming_circuit():circuit.append([at.x,at.y])
		var regions:=[]
		for zone: Dictionary in plan.woods.zones:
			var bounds: Rect2=zone.bounds
			regions.append({"kind":zone.kind,"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]})
		records.append({"seed":value,"encounters":encounters,"van_parts":parts,"region_circuit":circuit,"regions":regions})
	viewport.add_child(canvas)
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var error:=viewport.get_texture().get_image().save_png(output+"sample_distributions.png")
	var file:=FileAccess.open(output+"plans.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"  ")+"\n")
	file.close()
	print(JSON.stringify({"event":"distribution_capture","seeds":SEEDS,"png_error":error,"size":[1800,1080]}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if error==OK else 1)
