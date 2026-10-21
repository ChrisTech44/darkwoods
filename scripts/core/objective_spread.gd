class_name ObjectiveSpread
extends RefCounted
## Exhaustive max-min spread over legal region pickup anchors and fixed destinations.
## Distances are trail-graph steps with shortcuts/fences closed, not straight lines.
var woods: WoodsLayout
var points: Array[Vector2]=[]
var fields: Dictionary={}
var best: Array[int]=[]
var best_score: Array[int]=[]
var fixed: Array[Vector2]=[]
func _init(layout: WoodsLayout) -> void:
	woods=layout
	for zone: Dictionary in woods.zones:points.append(RoundPlan.cache_spot(zone))
func field(at: Vector2) -> Dictionary:
	var cell:=woods.cell_at(at)
	if not fields.has(cell):
		var starts: Array[Vector2i]=[]
		if WoodsLayout.CAMP_BOUNDS.has_point(at):starts.assign(WoodsLayout.ENTRIES)
		else:starts.append(cell)
		fields[cell]=woods.closed_distances(starts)
	return fields[cell]
func distance(a: Vector2,b: Vector2) -> int:
	if WoodsLayout.CAMP_BOUNDS.has_point(b):return int(field(b).get(woods.cell_at(a),1000000))
	return int(field(a).get(woods.cell_at(b),1000000))
func score(indices: Array[int],anchors: Array[Vector2]) -> Array[int]:
	var nodes: Array[Vector2]=anchors.duplicate()
	for index in indices:nodes.append(points[index])
	var result: Array[int]=[]
	for i in range(nodes.size()):
		for j in range(i):result.append(distance(nodes[i],nodes[j]))
	result.sort()
	return result
static func better(a: Array[int],b: Array[int]) -> bool:
	if b.is_empty():return true
	for i in range(a.size()):
		if a[i]!=b[i]:return a[i]>b[i]
	return false
func choose(count: int,anchors: Array[Vector2],exclude: Array[int],seed_value: int) -> Array[int]:
	fixed=anchors;best=[];best_score=[]
	var pool: Array[int]=[]
	for i in range(points.size()):
		if i not in exclude:pool.append(i)
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	for i in range(pool.size()-1,0,-1):
		var j:=rng.randi_range(0,i)
		var held:=pool[i];pool[i]=pool[j];pool[j]=held
	_search(pool,0,count,[])
	return best.duplicate()
func _search(pool: Array[int],cursor: int,count: int,picked: Array[int]) -> void:
	if count==0:
		var candidate:=score(picked,fixed)
		if better(candidate,best_score):best=picked.duplicate();best_score=candidate
		return
	for i in range(cursor,pool.size()-count+1):
		picked.append(pool[i]);_search(pool,i+1,count-1,picked);picked.pop_back()
