extends SceneTree
## Source-plan invariants; native navigation/escape behavior covered separately.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(JSON.stringify({"event":"assertion","name":label,"passed":ok}))
func fraction(at: Vector2) -> float:
	var offset := (at-CampMap.CAMP_BOUNDS.get_center()).abs()/(WoodsLayout.WORLD_BOUNDS.size*0.5)
	return maxf(offset.x,offset.y)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.get_node("Voice").mode="off"
	RoundPlan.force_all_escapes=false
	RoundPlan.force_modifiers=[]
	var metrics:=[]
	for value in [1,7,13,42,99,2026,6789,76543]:
		var plan:=RoundPlan.new()
		plan.generate(value,"woods")
		var duplicate:=RoundPlan.new()
		duplicate.generate(value,"woods")
		check(plan.encounters==duplicate.encounters and plan.loot==duplicate.loot and plan.woods.approaches==duplicate.woods.approaches,"seed_%d_reproducible"%value)
		check(plan.woods.zones.size()==14 and plan.woods.approaches.size()==14,"seed_%d_fourteen_outer_destinations_and_approaches"%value)
		check(plan.encounters.size()==38,"seed_%d_full_population_retained"%value)
		for zone: Dictionary in plan.woods.zones:
			check(fraction(zone.position)>=0.78,"seed_%d_%s_outer_band"%[value,zone.kind])
			check(WoodsLayout.WORLD_BOUNDS.grow(-32).encloses(zone.bounds.grow(32)),"seed_%d_%s_inside_world"%[value,zone.kind])
			check(plan.woods.zones.all(func(other): return other.kind==zone.kind or not zone.bounds.grow(48).intersects(other.bounds.grow(48))),"seed_%d_%s_separated"%[value,zone.kind])
		var part_regions:={}
		for kind: String in plan.required:
			var parts:=plan.loot.filter(func(e): return e.kind==kind)
			check(parts.size()==1 and not CampMap.CAMP_BOUNDS.has_point(parts[0].position),"seed_%d_%s_no_van_part_in_camp"%[value,kind])
			part_regions[plan.cache_zone[kind]]=true
		check(part_regions.size()==5,"seed_%d_five_van_parts_in_five_distinct_regions"%value)
		var roamers:=plan.encounters.filter(func(e): return e.species in RoundPlan.ROAMER_SPECIES)
		check(roamers.size()==29,"seed_%d_all_twenty_nine_roamers"%value)
		check(roamers.all(func(e): return e.position.distance_to(CampMap.CAMP_BOUNDS.get_center())>=RoundPlan.SAFE_RADIUS and plan.woods.zone_at(e.position).is_empty()),"seed_%d_roamers_keep_camp_buffer_and_region_space"%value)
		var unique:={}
		for e in roamers: unique[e.cell]=true
		check(unique.size()==29,"seed_%d_no_stacked_roaming_starts"%value)
		var circuit:=plan.roaming_circuit()
		var rim:=roamers.slice(0,RoundPlan.PERIMETER_ROAMERS)
		var interior:=roamers.slice(RoundPlan.PERIMETER_ROAMERS)
		check(rim.size()==14 and rim.all(func(e): return RoundPlan.circuit_distance(e.position,circuit)<=384),"seed_%d_fourteen_on_region_circuit"%value)
		check(interior.size()==15 and interior.all(func(e): return Geometry2D.is_point_in_polygon(e.position,circuit) and RoundPlan.circuit_distance(e.position,circuit)>384),"seed_%d_fifteen_fill_enclosed_interior"%value)
		var closest:=INF
		for a in roamers:
			for b in plan.encounters:
				if a!=b: closest=minf(closest,a.position.distance_to(b.position))
		check(closest>=600,"seed_%d_roamers_separated_from_each_other_and_guardians"%value)
		var outer_hole:=0.0
		for index in range(circuit.size()):
			var a: Vector2=circuit[index]
			var b: Vector2=circuit[(index+1)%circuit.size()]
			for step in range(ceili(a.distance_to(b)/96)+1):
				var at:=a.lerp(b,float(step)/ceili(a.distance_to(b)/96))
				var gap:=INF
				for enemy in roamers:gap=minf(gap,at.distance_to(enemy.position))
				outer_hole=maxf(outer_hole,gap)
		check(outer_hole<=1600,"seed_%d_no_large_empty_region_loop_arc"%value)
		var inner_hole:=0.0
		for cell: Vector2i in plan.woods.links:
			var at:=plan.woods.center(cell)
			if at.distance_to(CampMap.CAMP_BOUNDS.get_center())<1100 or not plan.woods.zone_at(at).is_empty() or not Geometry2D.is_point_in_polygon(at,circuit):continue
			var gap:=INF
			for enemy in roamers:gap=minf(gap,at.distance_to(enemy.position))
			inner_hole=maxf(inner_hole,gap)
		check(inner_hole<=1600,"seed_%d_no_large_empty_interior_pocket"%value)
		for kind: String in plan.cache_zone:
			var item: Dictionary=plan.loot.filter(func(e): return e.kind==kind)[0]
			check(fraction(item.position)>=0.74,"seed_%d_%s_cache_follows_outer_region"%[value,kind])
		metrics.append({"seed":value,"loop_max_distance":outer_hole,"interior_max_distance":inner_hole,"minimum_roamer_separation":closest,"perimeter_count":rim.size(),"interior_count":interior.size()})
	# Verify every secondary-route objective remains outer, not only the sampled route.
	RoundPlan.force_all_escapes=true
	var full:=RoundPlan.new()
	full.generate(42,"woods")
	for kind in ["rescue_fuse","outboard_motor","boat_fuel","drain_plug","kerosene_1","kerosene_2","flare_gun","gate_code_1","gate_code_2","gate_code_3"]:
		var found:=full.loot.filter(func(e): return e.kind==kind)
		check(found.size()==1 and fraction(found[0].position)>=0.74,"all_routes_%s_outer"%kind)
	RoundPlan.force_all_escapes=false
	print(JSON.stringify({"event":"outskirts_metrics","plans":metrics}))
	print(JSON.stringify({"event":"test_result","suite":"outskirts_layout","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures==0 else 1)
