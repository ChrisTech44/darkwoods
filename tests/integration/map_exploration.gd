extends SceneTree
## Seed42 authority/replication fixture: frozen AI, staged guest positions, no microphones.
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(JSON.stringify({"event":"assertion","name":label,"passed":ok}))
func run() -> void:
	root.get_node("Voice").mode = "off"
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	for i in range(12): await process_frame; await physics_frame
	var level := current_scene
	level.set_physics_process(false)
	level.night_clock.set_physics_process(false)
	for enemy in get_nodes_in_group("killers"): enemy.enabled = false
	level.player.position = Vector2(120,400)
	level.player.set_physics_process(false)
	var guest: CampPlayer = load("res://scenes/actors/player.tscn").instantiate()
	level.add_child(guest)
	guest.set_physics_process(false)
	var woods: WoodsLayout = level.plan.woods
	woods.visited.clear()
	guest.position = woods.center(WoodsLayout.ENTRY)
	level._physics_process(0)
	check(woods.visited.has(WoodsLayout.ENTRY), "non_reference_survivor_discovers_trail")
	check(woods.visited.size() == 1, "camp_and_unoccupied_cells_not_revealed")
	var first := woods.exploration_snapshot()
	guest.position = woods.center(WoodsLayout.ENTRY + Vector2i.LEFT)
	level._physics_process(0)
	check(woods.visited.size() == 2, "team_discovery_accumulates")
	guest.position = woods.center(Vector2i(0,0))
	guest.status = CampPlayer.Status.ESCAPED
	level._physics_process(0)
	check(not woods.visited.has(Vector2i.ZERO), "escaped_actor_does_not_explore")
	guest.status = CampPlayer.Status.DOWNED
	level._physics_process(0)
	check(woods.visited.has(Vector2i.ZERO), "downed_crawling_actor_can_explore")
	var net := root.get_node("Net")
	net.world = level
	net.actors = {1:level.player,2:guest}
	var state := WorldSync.capture(net)
	check(state.exploration is PackedByteArray and state.exploration.size() == 307, "world_snapshot_contains_bounded_exploration_bitmap")
	var expected := woods.visited.duplicate()
	woods.visited.clear()
	WorldSync.apply(net,state)
	check(woods.visited == expected, "world_replication_restores_team_exploration")
	var replica := WoodsLayout.new()
	replica.restore_exploration(first)
	check(replica.visited.size() == 1, "earlier_snapshot_has_only_earlier_discovery")
	replica.restore_exploration(state.exploration)
	check(replica.visited == expected, "complete_snapshot_recovers_missed_discoveries")
	replica.restore_exploration(PackedByteArray([255]))
	check(replica.visited == expected, "malformed_bitmap_does_not_mutate_map")
	for y in range(WoodsLayout.SIZE.y):
		for x in range(WoodsLayout.SIZE.x):
			var cell := Vector2i(x,y)
			if replica.valid(cell): replica.visited[cell] = true
	var full := replica.exploration_snapshot()
	check(full.size() == 307, "fully_explored_map_has_fixed_wire_cost")
	var decoded := WoodsLayout.new()
	decoded.restore_exploration(full)
	check(decoded.visited.size() == 2410 and decoded.visited.has(Vector2i(49,48)), "full_map_round_trip_including_final_partial_byte")
	var forged := full.duplicate()
	for i in range(forged.size()): forged[i] = 255
	decoded.restore_exploration(forged)
	check(decoded.visited.size() == 2410 and not decoded.visited.has(Vector2i(21,22)), "padding_and_camp_cells_rejected")
	decoded.generate(42)
	check(decoded.visited.is_empty() and decoded.received_exploration.is_empty(), "new_layout_clears_team_map_and_replication_cache")
	var before := woods.visited.duplicate()
	state.erase("exploration")
	WorldSync.apply(net,state)
	check(woods.visited == before, "older_optional_snapshot_format_remains_compatible")
	net.world = null
	net.actors.clear()
	net.motion_targets.clear()
	net.remote_motion.clear()
	net.motion_epochs.clear()
	print(JSON.stringify({"event":"test_result","suite":"map_exploration","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(1 if failures else 0)
