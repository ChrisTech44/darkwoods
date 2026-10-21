extends SceneTree
## Seed diversity, closed-barrier connectivity and global objective spread.
var checks:=0
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(JSON.stringify({"event":"assertion","name":label,"passed":ok}))
func run() -> void:
	root.get_node("Voice").mode="off"
	RoundPlan.force_all_escapes=false;RoundPlan.force_modifiers=[]
	var signatures:={};var roads:={};var trails:={};var orchard_sides:={};var metrics:=[]
	for value in [1,7,13,42,99,2026,6789,76543]:
		var plan:=RoundPlan.new();plan.generate(value,"woods")
		var again:=RoundPlan.new();again.generate(value,"woods")
		var woods:=plan.woods
		check(woods.zones==again.woods.zones and woods.roads==again.woods.roads and woods.links==again.woods.links and plan.loot==again.loot,"seed_%d_full_layout_reproduces"%value)
		signatures[hash(woods.zones)]=true;roads[hash(woods.roads)]=true;trails[hash(woods.links)]=true
		orchard_sides[WoodsLayout.cardinal(woods.zones[4].position)]=true
		check(woods.closed_distances(WoodsLayout.ENTRIES).size()==woods.links.size(),"seed_%d_all_clearings_reachable_with_barriers_closed"%value)
		var selected: Array[int]=[]
		var unique:={};var distinct:=true
		for kind in plan.objective_zone:
			var region: int=plan.objective_zone[kind]
			if unique.has(region):distinct=false
			unique[region]=true;selected.append(region)
			var items:=plan.loot.filter(func(item): return item.kind==kind)
			check(items.size()==1 and items[0].position==RoundPlan.cache_spot(woods.zones[region]),"seed_%d_%s_unique_region_anchor"%[value,kind])
		check(distinct and selected.all(func(i):return i not in plan.objective_excluded),"seed_%d_all_route_pieces_separate_from_each_other_and_destinations"%value)
		var score:=plan.objective_spread.score(selected,plan.objective_anchors)
		check(score==plan.objective_score and score[0]>0,"seed_%d_spacing_scores_include_every_piece_and_destination"%value)
		# An independent exchange property catches accidental omission of a route,
		# destination or candidate: no single replacement may improve the chosen set.
		var optimal:=true
		for slot in range(selected.size()):
			for candidate in range(woods.zones.size()):
				if candidate in selected or candidate in plan.objective_excluded:continue
				var trial: Array[int]=selected.duplicate();trial[slot]=candidate
				if ObjectiveSpread.better(plan.objective_spread.score(trial,plan.objective_anchors),score):optimal=false
		check(optimal,"seed_%d_no_better_region_exchange"%value)
		metrics.append({"seed":value,"route":plan.escape_options,"orchard":woods.zones[4].position,"minimum_graph_steps":score[0],"pieces":selected.size(),"region_assignment":plan.objective_zone,"anchors":plan.objective_anchors})
	check(signatures.size()==8 and roads.size()==8 and trails.size()==8,"all_eight_seeds_have_different_regions_roads_and_trails")
	var safe:=true
	for value in range(2,34):
		var woods:=WoodsLayout.new();woods.generate(value)
		orchard_sides[WoodsLayout.cardinal(woods.zones[4].position)]=true
		for zone: Dictionary in woods.zones:
			safe=safe and WoodsLayout.WORLD_BOUNDS.grow(-32).encloses(zone.bounds.grow(32))
			for other: Dictionary in woods.zones:
				if zone.kind!=other.kind and zone.bounds.grow(48).intersects(other.bounds.grow(48)):safe=false
	check(orchard_sides.size()==4,"orchard_moves_between_all_four_sides")
	check(safe,"thirty_two_extra_seed_region_bounds_and_separation")
	var fallback:=WoodsLayout.new()
	for y in range(WoodsLayout.SIZE.y):
		for x in range(WoodsLayout.SIZE.x):
			var cell:=Vector2i(x,y)
			if fallback.valid(cell):fallback.links[cell]=[]
	var rng:=RandomNumberGenerator.new();rng.seed=42
	fallback._make_zones(rng,32)
	var fallback_safe:=fallback.zones.size()==14
	for zone: Dictionary in fallback.zones:
		fallback_safe=fallback_safe and WoodsLayout.WORLD_BOUNDS.grow(-32).encloses(zone.bounds.grow(32))
		for other: Dictionary in fallback.zones:
			if zone.kind!=other.kind and zone.bounds.grow(48).intersects(other.bounds.grow(48)):fallback_safe=false
	check(fallback_safe,"bounded_region_fallback_keeps_every_region_separated_inside_world")
	print(JSON.stringify({"event":"randomized_layout_metrics","plans":metrics}))
	print(JSON.stringify({"event":"test_result","suite":"randomized_layout","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown();quit(1 if failures else 0)
