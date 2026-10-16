extends SceneTree
## F3a chase toolkit: wounded state, blood trail, medkit patch, kitless revive,
## downed crawl and help ping, solo self-recovery and flash-stun.
var checks := 0
var failures := 0
var capture := false
var level: Node2D
var player: CampPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	var previous_role: String = root.get_node("Session").survivor
	root.get_node("Session").survivor = "jock"
	root.get_node("Session").mode = "woods"
	root.get_node("Session").next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	while current_scene == null or current_scene.name != "ForestLevel":
		await process_frame
	level = current_scene
	player = level.player
	player.local_input = false
	level.night_clock.director_enabled = false
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	await _frames(4)
	await _wound_checks()
	await _solo_checks()
	await _flash_checks()
	await _team_checks()
	root.get_node("Session").select_survivor(previous_role)
	print(JSON.stringify({"event":"test_result","suite":"chase_toolkit","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _wound_checks() -> void:
	player.position = level.plan.woods.center(Vector2i(18, 24))
	player.receive_hit()
	_check(player.status == CampPlayer.Status.ALIVE and player.wounded and is_equal_approx(player.invulnerability, CampPlayer.WOUND_GRACE), "first_hit_wounds_with_grace")
	player.receive_hit()
	_check(player.status == CampPlayer.Status.ALIVE, "grace_blocks_immediate_second_hit")
	var spot := player.position
	player.position = Vector2(200, 880)
	await _frames(2)
	_check(level.hud.threat_label.text.contains("WOUNDED"), "wounded_hud_warning")
	player.position = spot
	player.stamina = player.config.stamina_max
	player.apply_intent(Vector2.RIGHT, true, 1.0 / 60.0)
	_check(is_equal_approx(player.velocity.length(), player.config.sprint_speed * CampPlayer.WOUNDED_SPRINT), "wounded_sprint_ten_percent_slower")
	player.blood.clear()
	for step in range(30):
		player.apply_intent(Vector2.RIGHT, false, 1.0 / 60.0)
	_check(player.blood.size() >= 1, "wounded_movement_leaves_blood")
	var listener: CampKiller = level.killer
	listener.enabled = true
	listener.position = player.blood.back() + Vector2(90, 0)
	listener.transition(CampKiller.State.PATROL)
	level.blood_clock = 0.0
	level._advance_chase_toolkit(0.016)
	_check(listener.state == CampKiller.State.INVESTIGATE and listener.last_seen == player.blood.back(), "fresh_blood_draws_patrolling_hunter")
	listener.enabled = false
	listener.transition(CampKiller.State.PATROL)
	_check(not level.use_supply(player, "medkit"), "no_medkit_no_patch")
	player.pack("medkit")
	_check(level.use_supply(player, "medkit") and not player.wounded and player.blood.is_empty() and player.supplies["medkit"] == 0, "medkit_patches_wound")
	player.pack("medkit")
	_check(not level.use_supply(player, "medkit") and player.supplies["medkit"] == 1, "healthy_survivor_keeps_medkit")
	player.invulnerability = 0.0
	player.receive_hit()
	player.invulnerability = 0.0
	player.receive_hit()
	_check(player.status == CampPlayer.Status.DOWNED, "second_hit_downs")
	var start := player.position
	for step in range(60):
		player.apply_intent(Vector2.LEFT, false, 1.0 / 60.0)
	var crawled := start.distance_to(player.position)
	_check(crawled > 15.0 and crawled < 22.0, "downed_crawl_about_20px_per_second_%d" % int(crawled))


func _solo_checks() -> void:
	_check(level.solo_recovery_available(player) and not level.call_for_help(player), "solo_has_recovery_but_no_help_call")
	level.advance_self_recovery(player, true, 4.0)
	level.advance_self_recovery(player, false, 0.1)
	_check(level.self_recovery_progress == 0.0 and player.status == CampPlayer.Status.DOWNED, "released_self_recovery_resets")
	var listener: CampKiller = level.killer
	listener.enabled = true
	listener.position = player.position + Vector2(400, 0)
	listener.transition(CampKiller.State.PATROL)
	level.advance_self_recovery(player, true, level.SELF_RECOVERY_SECONDS - 0.1)
	_check(player.status == CampPlayer.Status.DOWNED, "self_recovery_needs_full_hold")
	level.advance_self_recovery(player, true, 0.2)
	_check(player.status == CampPlayer.Status.ALIVE and player.wounded and player.self_recovery_used, "self_recovery_gets_up_wounded")
	_check(listener.state == CampKiller.State.INVESTIGATE, "self_recovery_is_loud")
	listener.enabled = false
	listener.transition(CampKiller.State.PATROL)
	player.invulnerability = 0.0
	player.receive_hit()
	_check(player.status == CampPlayer.Status.DOWNED and not level.solo_recovery_available(player), "self_recovery_once_per_night")
	player.set_status(CampPlayer.Status.ALIVE)
	player.wounded = false
	player.self_recovery_used = false


func _flash_checks() -> void:
	player.position = level.plan.woods.center(Vector2i(18, 24))
	player.facing = Vector2.RIGHT
	var front: CampCryptid
	var behind: CampCryptid
	for enemy: CampCryptid in get_nodes_in_group("cryptids"):
		if front == null:
			front = enemy
		elif behind == null:
			behind = enemy
	front.position = player.position + Vector2(60, 0)
	behind.position = player.position - Vector2(60, 0)
	for enemy in [front, behind]:
		enemy.enabled = true
		enemy.stun_remaining = 0.0
		enemy.stun_immunity = 0.0
	await _frames(1)
	if not level.clear_path(player.position, front.position):
		front.position = player.position + Vector2(40, 0)
	player.flashlight_charge = 50.0
	_check(level.use_flash(player) == 1 and front.stun_remaining > 0.0 and behind.stun_remaining == 0.0, "flash_stuns_only_creatures_in_beam")
	_check(is_equal_approx(player.flashlight_charge, 35.0) and player.flash_cooldown > 7.9, "flash_costs_light_and_starts_cooldown")
	if capture:
		await _snapshot("chase_flash")
	_check(level.use_flash(player) == -1, "flash_cooldown_blocks_spam")
	var before := front.position
	front.attack_remaining = 0.0
	player.invulnerability = 0.0
	for step in range(30):
		front._physics_process(1.0 / 60.0)
	_check(front.position == before and player.status == CampPlayer.Status.ALIVE and not player.wounded, "stunned_creature_cannot_move_or_attack")
	for step in range(70):
		front._physics_process(1.0 / 60.0)
	_check(front.stun_remaining == 0.0 and not front.stun(1.5), "stun_wears_off_with_immunity_window")
	player.flash_cooldown = 0.0
	player.flashlight_charge = 10.0
	_check(level.use_flash(player) == -1 and is_equal_approx(player.flashlight_charge, 10.0), "flash_needs_fifteen_charge")
	for enemy in [front, behind]:
		enemy.enabled = false


func _team_checks() -> void:
	var mate: CampPlayer = load("res://scenes/actors/player.tscn").instantiate()
	mate.local_input = false
	mate.peer_name = "Robin"
	mate.position = player.position + Vector2(16, 0)
	level.world_objects.add_child(mate)
	await _frames(2)
	mate.set_status(CampPlayer.Status.DOWNED)
	_check(not level.solo_recovery_available(mate), "no_self_recovery_with_teammates")
	_check(level.call_for_help(mate) and level.help_pings.size() == 1 and level.message.contains("Robin"), "downed_teammate_calls_for_help")
	_check(not level.call_for_help(mate), "help_call_cooldown")
	await _frames(2)
	_check(level.context_prompt().contains("BARE-HANDED"), "kitless_revive_prompt")
	level.advance_revive(player, mate, true, player.config.revive_seconds * level.KITLESS_REVIVE_FACTOR + 0.01)
	_check(mate.status == CampPlayer.Status.ALIVE and mate.wounded, "bare_handed_revive_works")
	level._advance_chase_toolkit(NightClock.RELIEF_SECONDS)
	_check(level.help_pings.is_empty(), "help_ping_expires")
	mate.queue_free()
	await _frames(2)


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _snapshot(label: String) -> void:
	await _frames(3)
	RenderingServer.force_draw(true)
	DirAccess.make_dir_recursive_absolute("res://artifacts/verification")
	_check(root.get_texture().get_image().save_png("res://artifacts/verification/%s.png" % label) == OK, "capture_" + label)


func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures += 1
	print(JSON.stringify({"event":"assertion","name":label,"passed":passed}))
