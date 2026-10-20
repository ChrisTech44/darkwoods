extends SceneTree
## Real ENet recovery, with frozen enemies and normal lighting. No microphones.
var net: Node
var harness: Harness
var side := OS.get_environment("LNAC_RECOVERY_SIDE")
var port := int(OS.get_environment("LNAC_RECOVERY_PORT"))
var dedicated := OS.get_environment("LNAC_RECOVERY_DEDICATED") == "1"
var peers := int(OS.get_environment("LNAC_RECOVERY_PEERS"))
var index := int(OS.get_environment("LNAC_RECOVERY_INDEX"))
var checks := 0
var failures := 0
var capture := OS.get_environment("LNAC_RECOVERY_CAPTURE") == "1"

class Harness extends Node:
	var stage := ""
	var data := {}
	var reports := {}
	@rpc("authority", "call_local", "reliable", 0)
	func advance(value: String, payload: Dictionary = {}) -> void:
		stage = value
		data = payload
		if multiplayer.is_server(): reports.clear()
	@rpc("any_peer", "call_remote", "reliable", 0)
	func report(value: String, payload: Dictionary = {}) -> void:
		if multiplayer.is_server() and stage == value: reports[multiplayer.get_remote_sender_id()] = payload

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(JSON.stringify({"event":"assertion", "name":label, "passed":ok}))
func until(predicate: Callable, seconds: float = 15.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec() < end: await process_frame
	var ok: bool = predicate.call()
	check(ok, "wait_"+harness.stage+"_"+side)
	return ok
func reports(count: int) -> bool:
	return await until(func(): return harness.reports.size() == count, 60)
func run() -> void:
	root.get_node("Voice").mode = "off"
	net = root.get_node("Net")
	harness = Harness.new()
	harness.name = "RecoveryHarness"
	root.add_child(harness)
	if side == "host": await host_checks()
	else: await client_checks()
	if net.active:
		net.dedicated = false # The harness, not production shutdown, owns its exit code.
		net.leave()
	await create_timer(0.3).timeout
	if current_scene != null: current_scene.queue_free()
	await process_frame
	harness.queue_free()
	print(JSON.stringify({"event":"test_result", "suite":"reconnect_"+side, "checks":checks, "failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(1 if failures else 0)

func host_checks() -> void:
	if dedicated: check(net.host_dedicated(port) == OK, "dedicated_binds")
	else: check(net.host(port,"Host","john") == OK, "listen_binds")
	if not await until(func(): return net.roster.size() == peers): return
	if not dedicated: net.choose("john",true)
	if not await until(func(): return net.can_start()): return
	check(net.start_round("woods",42), "start_round")
	if not await until(func(): return net.phase == "playing", 90): return
	var level: Node2D = net.world
	level.night_clock.director_enabled = false
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
		enemy.set_physics_process(false)
	var target_id: int = 0
	for id: int in net.actors:
		var actor: CampPlayer = net.actors[id]
		actor.position = Vector2(96+net.actors.keys().find(id)*24,384)
		actor.ward_remaining = 300
		if actor.role == "alex": target_id = id
	var target: CampPlayer = net.actors[target_id]
	target.health = 61
	target.inventory.append("battery")
	for item: CampPickup in level.pickups:
		if item.kind == "battery": item.available = false
	target.kit.cash = 17
	target.ability_cooldown = 21
	target.kit.marker = Vector2(164,438)
	target.kit.marker_life = 75.0
	var other: CampPlayer
	for actor: CampPlayer in net.actors.values():
		if actor != target: other = actor; break
	if other != null:
		target.add_effect("tethered",60)
		other.add_effect("tethered",60)
		target.set_meta("tether_partner",other)
		other.set_meta("tether_partner",target)
		target.effect_data.tether_to = other.position
		other.effect_data.tether_to = target.position
	harness.advance.rpc("before", {"old_id":target_id})
	if not await reports(peers-int(not dedicated)): return
	net.snapshot_clock = 1000
	net.snapshot_sequence += 1
	var old_sequence: int = net.snapshot_sequence
	var old_world: PackedByteArray = var_to_bytes(WorldSync.capture(net)).compress(FileAccess.COMPRESSION_DEFLATE)
	var token: String = net.peer_tokens[target_id]
	var old_position := target.position
	check(token.length() == 64, "private_random_reconnect_ticket")
	net.multiplayer.multiplayer_peer.disconnect_peer(target_id)
	if not await until(func(): return net.reservations.has(token)): return
	check(not target.is_inside_tree() and not net.actors.has(target_id), "disconnected_body_removed_from_play")
	check(net.reservations[token].expires-Time.get_ticks_msec() > 290000, "reservation_is_five_minutes")
	check(not target.has_effect("tethered") and (other == null or not other.has_effect("tethered")), "both_tether_ends_released")
	check(target.health == 61 and target.inventory.is_empty() and target.supplies.values().all(func(amount): return amount == 0) and target.kit.cash == 17, "gear_dropped_and_character_state_preserved")
	check(level.pickups.any(func(item): return item.kind == "battery" and item.available), "objective_drops_immediately")
	check(level.pickups.filter(func(item): return item.kind == "flare" and item.available).size() >= 2, "carried_supplies_drop_immediately")
	if peers-int(not dedicated)-1 > 0:
		harness.advance.rpc("departure", {"old_id":target_id,"sequence":old_sequence})
		var parts := ceili(float(old_world.size())/net.SNAPSHOT_CHUNK)
		var stale_until := Time.get_ticks_msec()+5000
		while harness.reports.size() < peers-int(not dedicated)-1 and Time.get_ticks_msec() < stale_until:
			for part in range(parts):
				net._snapshot_piece.rpc(net.round_id,old_sequence,part,parts,old_world.slice(part*net.SNAPSHOT_CHUNK,(part+1)*net.SNAPSHOT_CHUNK))
			await create_timer(0.05).timeout
		if not await reports(peers-int(not dedicated)-1): return
		for report: Dictionary in harness.reports.values(): check(report.removed and report.stale,"departure_reliable_without_world_and_stale_snapshot_cannot_resurrect")
	net.snapshot_clock = 0
	if other != null:
		for item: CampPickup in level.pickups:
			if item.kind == "battery" and item.available:
				other.position = item.position
				level.try_interact(other)
				break
		check("battery" in other.inventory,"teammate_can_recover_disconnected_players_objective")
	if not await until(func(): return net.actors.values().has(target), 90): return
	var new_id: int = net.actors.find_key(target)
	check(new_id != target_id and not net.reservations.has(token), "new_transport_reclaims_same_body_once")
	check(target.health == 61 and target.inventory.is_empty() and target.supplies.values().all(func(amount): return amount == 0) and target.kit.cash == 17, "rejoin_preserves_injuries_without_duplicate_gear")
	check(target.position.distance_to(old_position) < 1 and target.kit.marker_life > 0 and target.ability_cooldown > 0, "rejoin_preserves_location_marker_and_cooldown")
	check(net.round_id == 1 and net.actors.size() == peers and not level.finished, "rejoin_keeps_current_night")
	if not await until(func(): return net.loaded.has(new_id)): return
	harness.advance.rpc("after", {"old_id":target_id,"new_id":new_id})
	if not await reports(peers-int(not dedicated)): return
	for report: Dictionary in harness.reports.values():
		check(report.restored and report.removed and report.marker and report.membership, "every_client_sees_restored_actor_and_shared_marker")
	# Silent client: transport stays connected, but input watchdog must notice.
	harness.advance.rpc("silence", {"target":new_id})
	if not await reports(peers-int(not dedicated)): return
	if not await until(func(): return net.reservations.has(token), 25): return
	check(not target.is_inside_tree(),"silent_connected_peer_removed_by_input_watchdog")
	if not await until(func(): return net.actors.values().has(target) and net.loaded.has(net.actors.find_key(target)), 90): return
	new_id = net.actors.find_key(target)
	harness.advance.rpc("resumed_silence", {"new_id":new_id})
	if not await reports(peers-int(not dedicated)): return
	# Expire the reservation; already dropped gear must not be duplicated.
	harness.advance.rpc("expiry", {"target":new_id})
	if not await reports(peers-int(not dedicated)): return
	net.multiplayer.multiplayer_peer.disconnect_peer(new_id)
	if not await until(func(): return net.reservations.has(token)): return
	net.reservations[token].expires = Time.get_ticks_msec()-1
	if not await until(func(): return not net.reservations.has(token)): return
	if peers == 1:
		check(net.phase == "lobby" and net.actors.is_empty(), "last_reservation_expiry_cleans_round")
	else:
		check(target_id != new_id and "battery" in other.inventory and not level.pickups.any(func(item): return item.kind == "battery" and item.available), "reservation_expiry_does_not_duplicate_recovered_gear")
	await create_timer(0.4).timeout
	if not net.actors.is_empty():
		harness.advance.rpc("done")
		if not await reports(net.actors.size()-int(not dedicated)): return

func client_checks() -> void:
	var role: String = ["alex","max","christian","john"][index]
	check(net.join("127.0.0.1",port,role.capitalize(),role) == OK, "client_connects")
	if not await until(func(): return net.phase == "lobby"): return
	net.choose(role,true)
	if not await until(func(): return net.phase == "playing", 90): return
	var handled := ""
	var deadline := Time.get_ticks_msec()+180000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if harness.stage == handled: continue
		handled = harness.stage
		match handled:
			"before":
				if not await until(func(): return net.actors[harness.data.old_id].health == 61): return
				check(net.actors[harness.data.old_id].kit.marker_life > 0,"remote_marker_in_authoritative_kit")
				if capture and role != "alex": await shot("shared_marker_before")
				harness.report.rpc_id(1, handled)
			"departure":
				if not await until(func(): return not net.actors.has(harness.data.old_id)): return
				check(net.actors.values().all(func(actor): return not actor.has_effect("tethered")),"departure_reliably_clears_remote_tether_without_snapshot")
				await create_timer(0.25).timeout
				harness.report.rpc_id(1,handled,{"removed":not net.actors.has(harness.data.old_id),"stale":not net.participants.has(harness.data.old_id) and net.last_snapshot < harness.data.sequence and net.actors.values().all(func(actor): return not actor.has_effect("tethered"))})
			"after":
				if not await until(func(): return net.phase == "playing" and net.actors.has(harness.data.new_id)): return
				var actor: CampPlayer = net.actors[harness.data.new_id]
				if not await until(func(): return actor.health == 61 and actor.inventory.is_empty() and actor.supplies.values().all(func(amount): return amount == 0)): return
				if capture and role != "alex": await shot("shared_marker_after")
				harness.report.rpc_id(1,handled,{"restored":actor.health == 61 and actor.inventory.is_empty() and actor.supplies.values().all(func(amount): return amount == 0),"removed":not net.actors.has(harness.data.old_id),"marker":actor.kit.marker_life > 0,"membership":net.participants.has(harness.data.new_id) and not net.participants.has(harness.data.old_id)})
			"silence":
				harness.report.rpc_id(1,handled)
				if role == "alex":
					net.set_physics_process(false)
					if not await until(func(): return not net.active, 30): return
					net.set_physics_process(true)
			"resumed_silence":
				if not await until(func(): return net.phase == "playing" and net.actors.has(harness.data.new_id)): return
				harness.report.rpc_id(1,handled)
			"expiry":
				if role == "alex":
					# Suppress automatic retry only for the expiry fixture.
					net.reconnect_token = ""
				harness.report.rpc_id(1,handled)
				if role == "alex":
					if not await until(func(): return not net.active): return
					return
			"done":
				harness.report.rpc_id(1,handled)
				await create_timer(0.2).timeout
				return
	check(false,"client_stage_deadline")

func shot(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(true)
	root.get_texture().get_image().save_png("res://artifacts/playtest_recovery/%s_%s_%d.png" % [label,"dedicated" if dedicated else "listen",index])
