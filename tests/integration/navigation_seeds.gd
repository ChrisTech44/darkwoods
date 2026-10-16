extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var ok:=true
	var checks:=0
	for value in [1,2,3,7,42,99,2026,6789,12345,76543,998877,2147483646]:
		root.get_node("Session").mode="woods"
		root.get_node("Session").next_seed=value
		change_scene_to_file("res://scenes/world/forest_level.tscn")
		await process_frame
		await physics_frame
		var level=current_scene
		for enemy in get_nodes_in_group("killers"):enemy.enabled=false
		var map=level.get_world_2d().navigation_map
		var pass_seed=true
		for entry in WoodsLayout.ENTRIES:
			var goal=level.plan.woods.center(entry)
			var path=NavigationServer2D.map_get_path(map,level.player.position,goal,true)
			pass_seed=pass_seed and path.size()>1 and path[-1].distance_to(goal)<8
		for item in level.pickups:
			var path=NavigationServer2D.map_get_path(map,level.player.position,item.position,true)
			pass_seed=pass_seed and path.size()>1 and path[-1].distance_to(item.position)<8
		print(JSON.stringify({"event":"nav_stress","seed":value,"passed":pass_seed}))
		ok=ok and pass_seed
		checks+=1
	print(JSON.stringify({"event":"test_result","suite":"navigation_seeds","checks":checks,"failures":0 if ok else 1}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if ok else 1)
