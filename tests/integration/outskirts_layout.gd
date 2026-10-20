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
		check(roamers.all(func(e): return fraction(e.position)<=RoundPlan.ROAMER_INNER_FRACTION and e.position.distance_to(CampMap.CAMP_BOUNDS.get_center())>=RoundPlan.SAFE_RADIUS and plan.woods.zone_at(e.position).is_empty()),"seed_%d_roamers_inner_transit_with_camp_buffer"%value)
		var unique:={}
		for e in roamers: unique[e.cell]=true
		check(unique.size()==29,"seed_%d_no_stacked_roaming_starts"%value)
		var coverage:=[]
		for approach: Dictionary in plan.woods.approaches:
			var near:=0
			for enemy in roamers:
				if approach.cells.any(func(cell): return (Vector2(cell-enemy.cell)).length()<=sqrt(2.0)+0.01): near+=1
			coverage.append(near)
			check(near>0,"seed_%d_approach_%d_has_nearby_roamer"%[value,approach.zone])
		for kind: String in plan.cache_zone:
			var item: Dictionary=plan.loot.filter(func(e): return e.kind==kind)[0]
			check(fraction(item.position)>=0.74,"seed_%d_%s_cache_follows_outer_region"%[value,kind])
		metrics.append({"seed":value,"approach_roamer_counts":coverage})
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
