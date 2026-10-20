extends SceneTree
## Source-generated diagnostic map, not the discovery-limited in-game notebook.
const OUT := "res://docs/evidence/monster_distributions/"
const SEEDS := [13,42,2026]
const HIGHLIGHTS := {"teddy":Color("ffbe69"),"lifeguard":Color("6ee5d4"),"huntmaster":Color("cc9aff")}

class DistributionCanvas extends Node2D:
	var plans: Array = []
	var font := ThemeDB.fallback_font
	var ink := Color("e6e9ec")
	const SCALE := 530.0/9600.0
	func label(at: Vector2, value: String, size: int=17, color: Color=Color("e6e9ec")) -> void:
		draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
	func point(at: Vector2, origin: Vector2) -> Vector2:
		return origin+(at-WoodsLayout.WORLD_BOUNDS.position)*SCALE
	func _draw() -> void:
		draw_rect(Rect2(0,0,1800,1080),Color("10181f"))
		label(Vector2(35,40),"WHERE THE ROAMERS START",30)
		label(Vector2(35,70),"Three actual seeded Woods plans • 29 roamers per map • numbered by species below",18,Color("a8bac8"))
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
				draw_circle(at,10.5,Color("10181f"))
				draw_circle(at,10.5,color,false,1.0)
				var number:=str(index+1)
				var width:=font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
				label(at+Vector2(-width/2,4),number,12,color)
			label(origin+Vector2(0,545),"29 roamer starts  •  9 regional creatures",16,Color("a8bac8"))
		label(Vector2(35,722),"NUMBER KEY",18)
		for index in range(RoundPlan.ROAMER_SPECIES.size()):
			var species: String=RoundPlan.ROAMER_SPECIES[index]
			var column:=index/10
			var row:=index%10
			var title:=CampProfile.display_name(species)
			label(Vector2(35+column*590,748+row*23),"%02d  %s" % [index+1,title],16,HIGHLIGHTS.get(species,ink))
		label(Vector2(35,1000),"Colored outlines = assigned 16-waypoint footprints for Bear Hug, Lifeguard and Huntmaster. Tiny colored dots = waypoints.",17)
		label(Vector2(35,1027),"They are not territories or chase limits. Gray diamonds = regional spawns; tinted boxes = named regions. Routes can overlap.",17,Color("a8bac8"))
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
	for value in SEEDS:
		var plan:=RoundPlan.new()
		plan.generate(value,"woods")
		canvas.plans.append(plan)
		var encounters:=[]
		for encounter: Dictionary in plan.encounters:
			var route:=[]
			for at: Vector2 in plan.woods.roaming_route(encounter.cell): route.append([at.x,at.y])
			encounters.append({"species":encounter.species,"position":[encounter.position.x,encounter.position.y],"roamer":encounter.species in RoundPlan.ROAMER_SPECIES,"assigned_waypoints":route})
		records.append({"seed":value,"encounters":encounters})
	viewport.add_child(canvas)
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var error:=viewport.get_texture().get_image().save_png(OUT+"sample_distributions.png")
	var file:=FileAccess.open(OUT+"plans.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"  ")+"\n")
	file.close()
	print(JSON.stringify({"event":"distribution_capture","seeds":SEEDS,"png_error":error,"size":[1800,1080]}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if error==OK else 1)
