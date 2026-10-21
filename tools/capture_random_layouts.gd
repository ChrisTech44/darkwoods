extends SceneTree
## Native diagnostic overview; all layout/objective information deliberately revealed.
const SEEDS: Array[int]=[13,42,2026]
const OUT:="res://docs/evidence/random_layout/"
class Canvas extends Node2D:
	var plans: Array[RoundPlan]=[]
	const SCALE:=530.0/9600.0
	const GOLD:=Color("ffdc8e")
	const BLUE:=Color("86dce7")
	func point(at: Vector2,origin: Vector2) -> Vector2:return origin+(at-WoodsLayout.WORLD_BOUNDS.position)*SCALE
	func text(at: Vector2,value: String,size: int=16,color: Color=Color("e6e9ec")) -> void:draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
	func marker(at: Vector2,code: String,color: Color) -> void:
		draw_circle(at,11,Color("10181f"));draw_circle(at,11,color,false,1)
		var width:=ThemeDB.fallback_font.get_string_size(code,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
		text(at+Vector2(-width/2,3),code,10,color)
	func _draw() -> void:
		draw_rect(Rect2(0,0,1800,1120),Color("10181f"))
		text(Vector2(35,40),"SEEDED REGIONS, WINDING ROADS AND SPREAD OBJECTIVES",28)
		text(Vector2(35,71),"Normal nights: Van + one secondary. All unique pieces optimized together, with destinations included.",18,Color("a8bac8"))
		for panel in range(plans.size()):
			var plan:=plans[panel];var woods:=plan.woods;var origin:=Vector2(35+590*panel,125)
			text(origin-Vector2(0,18),"SEED %d  /  %s"%[plan.seed_value,plan.escape_options[1].to_upper()],20)
			draw_rect(Rect2(origin,Vector2(530,9408*SCALE)),Color("19272b"))
			for tile: Vector2i in woods.open_tiles:draw_rect(Rect2(point(Vector2(tile)*32,origin),Vector2.ONE*(32*SCALE+.15)),Color("344346"))
			for road: Rect2 in woods.roads:draw_rect(Rect2(point(road.position,origin),road.size*SCALE),Color("74734b"))
			for encounter: Dictionary in plan.encounters:draw_circle(point(encounter.position,origin),2.6,Color("b07678"))
			for zone: Dictionary in woods.zones:
				draw_rect(Rect2(point(zone.bounds.position,origin),zone.bounds.size*SCALE),Color("526a73"),false,1)
				var name: String=WoodsLayout.SIGN_NAMES[zone.kind]
				var width:=ThemeDB.fallback_font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
				var at:=point(zone.position,origin)+Vector2(-width/2,-12)
				at.x=clampf(at.x,origin.x+2,origin.x+528-width)
				text(at,name,11,Color("b8d2d6"))
			var camp:=Rect2(point(CampMap.CAMP_BOUNDS.position,origin),CampMap.CAMP_BOUNDS.size*SCALE)
			draw_rect(camp,Color("60513b"));text(camp.position+Vector2(17,18),"CAMP",12,GOLD)
			var rows: Array=[]
			for i in range(plan.required.size()):rows.append(["V%d"%(i+1),plan.required[i],GOLD])
			var extra:=0
			for kind in plan.objective_zone:
				if kind in plan.required:continue
				extra+=1;rows.append(["S%d"%extra,kind,BLUE])
			for i in range(rows.size()):
				var row: Array=rows[i];var zone: Dictionary=woods.zones[plan.objective_zone[row[1]]]
				var item: Dictionary=plan.loot.filter(func(entry):return entry.kind==row[1])[0]
				marker(point(item.position,origin),row[0],row[2])
				text(origin+Vector2(0,590+i*23),"%s  %s / %s"%[row[0],row[1].replace("_"," ").to_upper(),WoodsLayout.SIGN_NAMES[zone.kind]],13,row[2])
			for i in range(plan.objective_anchors.size()):marker(point(plan.objective_anchors[i],origin),"D%d"%i,Color("f59f9a"))
			var gap:=1000000
			var selected: Array=plan.objective_zone.values()
			for index: int in selected:
				var at: Vector2=plan.objective_spread.points[index]
				for other: int in selected:
					if index!=other:gap=mini(gap,plan.objective_spread.distance(at,plan.objective_spread.points[other]))
				for anchor: Vector2 in plan.objective_anchors:gap=mini(gap,plan.objective_spread.distance(at,anchor))
			text(origin+Vector2(0,551),"Closest piece ↔ piece/destination: %d trail cells"%gap,14)
		text(Vector2(35,1034),"Gold = main roads; gray = maze/approaches; red dots = creature starts; D = fixed route destinations/preparation sites.",17)
		text(Vector2(35,1063),"V = van pieces; S = secondary pieces. Region assignments are unique across both routes; no van pieces in camp.",17,Color("a8bac8"))
		text(Vector2(35,1092),"Diagnostic reveal, not the in-game map. Distances use the closed-barrier trail graph; no simulation or lighting alteration.",16,Color("a8bac8"))
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.get_node("Voice").mode="off";RoundPlan.force_all_escapes=false;RoundPlan.force_modifiers=[]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var viewport:=SubViewport.new();viewport.size=Vector2i(1800,1120);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.world_2d=World2D.new();root.add_child(viewport)
	var canvas:=Canvas.new();var records:=[]
	for value in SEEDS:
		var plan:=RoundPlan.new();plan.generate(value,"woods");canvas.plans.append(plan)
		records.append({"seed":value,"routes":plan.escape_options,"regions":plan.woods.zones,"roads":plan.woods.roads,"objectives":plan.objective_zone,"anchors":plan.objective_anchors})
	viewport.add_child(canvas)
	await process_frame;await process_frame;RenderingServer.force_draw(true);await process_frame
	var result:=viewport.get_texture().get_image().save_png(OUT+"sample_layouts.png")
	var file:=FileAccess.open(OUT+"plans.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"\t")+"\n");file.close()
	print(JSON.stringify({"event":"test_result","suite":"random_layout_capture","checks":1,"failures":0 if result==OK else 1}))
	await root.get_node("AudioManager").prepare_shutdown();quit(0 if result==OK else 1)
