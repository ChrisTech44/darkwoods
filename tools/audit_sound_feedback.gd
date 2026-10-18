extends SceneTree
## Diagnostic accepted-cue counts, not a listening or network test.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	RoundPlan.force_headline = "stalker"
	RoundPlan.force_modifiers = []
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	for index in range(12):
		await process_frame
		await physics_frame
	var level: Node2D = current_scene
	level.player.local_input = false
	level.night_clock.active = false
	level.soundscape.set_physics_process(false)
	level.snares.set_physics_process(false)
	for enemy in get_nodes_in_group("killers"):
		enemy.enabled = false
	level.soundscape.played_counts.clear()
	level.player.supplies["air_horn"] = 1
	var horn_used: bool = level.use_supply(level.player, "air_horn")
	print(JSON.stringify({"check": "air_horn", "used": horn_used, "accepted_cues": level.soundscape.played_counts.duplicate()}))
	level.soundscape.played_counts.clear()
	var trap_at: Vector2 = level.plan.woods.center(Vector2i(18, 24))
	level.plan.woods.visited[level.plan.woods.cell_at(trap_at)] = true
	level.player.position = trap_at + Vector2(80, 0)
	var placed: bool = level.snares.try_place(trap_at)
	level.player.position = trap_at
	level.player.vault_time = 0.0
	level.snares.advance(0.01)
	level.soundscape._events()
	print(JSON.stringify({"check": "bear_trap", "placed": placed, "snared": level.player.snared, "accepted_cues": level.soundscape.played_counts.duplicate()}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if horn_used and placed and level.player.snared > 0.0 else 1)
