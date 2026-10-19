extends SceneTree
## Staged rendering: frozen AI, explicit pile positions, normal seed/lighting.
var checks := 0
var failures := 0
var counts := {"pickups":0, "site":0}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(JSON.stringify({"event":"assertion", "name":label, "passed":ok}))
func frames(n: int = 4) -> void:
	for i in range(n): await process_frame
func run() -> void:
	root.get_node("Voice").mode = "off"
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	await frames(12)
	var level := current_scene
	for enemy in get_nodes_in_group("killers"): enemy.enabled = false
	level.player.local_input = false
	level.night_clock.set_physics_process(false)
	for old: CampPickup in level.pickups: old.consume()
	var first := CampPickup.new()
	first.kind = "flare"
	first.position = Vector2(350, 400)
	level.add_child(first)
	level.pickups.append(first)
	var second := CampPickup.new()
	second.kind = "flare"
	second.position = first.position + Vector2(5, 0)
	level.add_child(second)
	level.pickups.append(second)
	first.draw.connect(func(): counts.pickups += 1)
	second.draw.connect(func(): counts.pickups += 1)
	var site: ForestSite = level.camp_map.sites.filter(func(n): return not n.actions.is_empty())[0]
	site.draw.connect(func(): counts.site += 1)
	var net := root.get_node("Net")
	net.world = level
	net.actors = {1:level.player}
	await frames(8)
	var state := WorldSync.capture(net)
	counts.pickups = 0
	counts.site = 0
	for i in range(8):
		WorldSync.apply(net, state)
		await frames(2)
	check(counts.pickups == 0 and counts.site == 0, "unchanged_replication_keeps_cached_draws")
	check(first._pile_title("FLARE") == "FLARE ×2", "initial_stacked_pile_title")
	var row: Array = state.items.back()
	row[0] = "battery_pack"
	WorldSync.apply(net, state)
	await frames()
	check(counts.pickups >= 2, "changed_kind_invalidates_both_pile_labels")
	check(first._pile_title("FLARE") == "SUPPLIES ×2", "mixed_pile_title_updates")
	counts.pickups = 0
	row[1] = second.position + Vector2(100, 0)
	WorldSync.apply(net, state)
	await frames()
	check(first._pile_title("FLARE") == "FLARE" and counts.pickups >= 2, "moving_item_invalidates_old_and_new_piles")
	var index: int = level.camp_map.sites.find(site)
	state.sites[index][0][0] = true
	WorldSync.apply(net, state)
	await frames()
	check(site.actions[0].used and counts.site == 1, "changed_site_action_redraws_once")
	state.items[state.items.size()-2][2] = false
	WorldSync.apply(net, state)
	await frames()
	check(not first.visible and not first.available, "consumed_pickup_disappears")
	check(level.get_children().filter(func(n): return n is CallingCards)[0].last_hook == level.hook_point(), "cached_hook_matches_seeded_lair")
	net.world = null
	net.actors.clear()
	net.motion_targets.clear()
	print(JSON.stringify({"event":"test_result", "suite":"render_replication", "checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(1 if failures else 0)
