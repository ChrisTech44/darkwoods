extends SceneTree
## F6a Roles 2.0: each survivor's active ability (X), item passing (H), the
## jury-rigged door barricade, Scout marks limited to what is in sight, and
## end-of-night award titles from host-tracked stats.
var checks := 0
var failures := 0
var level: Node2D
var player: CampPlayer
var spot := Vector2.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
	spot = level.plan.woods.center(Vector2i(18, 24))
	_check(SurvivorAbilities.ABILITIES.size() == SurvivorRoster.IDS.size() and SurvivorRoster.IDS.all(func(id: String) -> bool: return SurvivorAbilities.ABILITIES.has(id)), "every_role_has_an_ability")
	await _jock_checks()
	await _mechanic_checks()
	_scout_checks()
	_medic_checks()
	_quiet_checks()
	_quartermaster_checks()
	await _give_checks()
	await _team_hook_checks()
	_award_checks()
	root.get_node("Session").select_survivor(previous_role)
	print(JSON.stringify({"event": "test_result", "suite": "roles_abilities", "checks": checks, "failures": failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _survivor(role: String, at: Vector2) -> CampPlayer:
	var actor: CampPlayer = level.PLAYER_SCENE.instantiate()
	actor.role = role
	actor.local_input = false
	actor.config = level.config
	actor.expedition = true
	actor.position = at
	level.world_objects.add_child(actor)
	return actor


func _jock_checks() -> void:
	player.position = spot
	player.stamina = 0.2
	player.exhausted = true
	_check(level.abilities.use(player) and player.stamina == player.config.stamina_max and not player.exhausted and player.ability_charges == 0, "second_wind_refills_stamina_once")
	player.apply_intent(Vector2.RIGHT, true, 1.0 / 60.0)
	_check(is_equal_approx(player.velocity.length(), player.config.sprint_speed * SurvivorAbilities.SECOND_WIND_SPEED), "second_wind_sprints_ten_percent_faster")
	player.ability_active = 0.0
	_check(not level.abilities.use(player), "second_wind_spent_until_next_phase")
	await _frames(2)
	_check(level.hud.ability_label.text.contains("SECOND WIND USED") and level.hud.ability_label.text.contains("H GIVE"), "hud_shows_ability_state")
	level.night_clock.force_phase(1)
	_check(player.ability_charges == 1, "second_wind_refills_each_phase")


func _mechanic_checks() -> void:
	var building: CampBuilding = level.camp_map.buildings[0]
	var props: ChaseProps = level.props
	var index := props.doors.find(props.doors.filter(func(door: Dictionary) -> bool: return door["label"] == building.label)[0])
	var door: Dictionary = props.doors[index]
	var mechanic := _survivor("mechanic", building.door + Vector2(0, 16))
	mechanic.facing = Vector2.UP
	await _frames(2)
	_check(level.abilities.use(mechanic) and not door["open"] and door["barricade"] > 0.0 and mechanic.ability_charges == 1, "jury_rig_shuts_and_barricades_door")
	var hunter: CampKiller = level.killer
	hunter.enabled = true
	hunter.position = building.door + Vector2(0, 8)
	hunter.transition(CampKiller.State.PATROL)
	mechanic.position = building.bounds.get_center()
	props.advance(ChaseProps.DOOR_BREAK_SECONDS)
	_check(not door["open"] and door["progress"] == 0.0, "barricade_holds_against_pushing")
	props.advance(9.0)
	props.advance(ChaseProps.DOOR_BREAK_SECONDS + 0.2)
	_check(door["open"] and door["broken"] > 0.0, "barricade_expires_then_door_breaks")
	hunter.enabled = false
	hunter.position = Vector2(600, 520)
	level.night_clock.blackout = true
	mechanic.position = level.night_clock.generator_point()
	_check(level.abilities.use(mechanic) and not level.night_clock.blackout and mechanic.ability_charges == 0, "jury_rig_restores_power_quietly")
	_check(not level.abilities.use(mechanic), "jury_rig_two_charges_per_night")
	mechanic.queue_free()


func _scout_checks() -> void:
	var scout := _survivor("scout", spot)
	scout.facing = Vector2.RIGHT
	var target: CampCryptid
	for enemy: CampCryptid in get_nodes_in_group("cryptids"):
		target = enemy
		break
	target.position = spot + Vector2(80, 0)
	level.abilities.marks.clear()
	_check(level.abilities.use(scout) and level.abilities.marks.size() == 1 and level.abilities.marks[0]["position"].distance_to(target.position) < 2.0, "mark_tags_creature_in_sight")
	_check(scout.ability_cooldown == 30.0 and not level.abilities.use(scout), "mark_has_thirty_second_cooldown")
	level.abilities.advance(SurvivorAbilities.MARK_SECONDS + 0.1)
	_check(level.abilities.marks.is_empty(), "mark_fades_after_six_seconds")
	scout.ability_cooldown = 0.0
	scout.facing = Vector2.LEFT
	target.position = spot + Vector2(400, 0)
	var only_behind: bool = level.abilities.use(scout)
	_check(not only_behind or level.abilities.marks.all(func(mark: Dictionary) -> bool: return mark["position"].distance_to(target.position) > 2.0), "mark_never_reveals_unseen_creature")
	target.position = level.plan.woods.center(Vector2i(4, 4))
	scout.queue_free()


func _medic_checks() -> void:
	var medic := _survivor("medic", spot)
	var friend := _survivor("quiet", spot + Vector2(12, 0))
	friend.wounded = true
	friend.blood.append(spot)
	_check(level.abilities.use(medic) and not friend.wounded and friend.blood.is_empty() and medic.ability_charges == 1, "patch_heals_adjacent_teammate_without_medkit")
	medic.wounded = true
	_check(level.abilities.use(medic) and not medic.wounded and medic.ability_charges == 0, "patch_heals_self")
	medic.wounded = true
	_check(not level.abilities.use(medic), "patch_has_two_charges")
	medic.queue_free()
	friend.queue_free()


func _quiet_checks() -> void:
	var quiet := _survivor("quiet", spot)
	var heard := []
	quiet.sprint_noise_emitted.connect(func(origin: Vector2) -> void: heard.append(origin))
	_check(level.abilities.use(quiet) and quiet.silent(), "hold_breath_starts")
	quiet.stamina = quiet.config.stamina_max
	for step in range(30):
		quiet.apply_intent(Vector2.RIGHT, true, 1.0 / 60.0)
	_check(heard.is_empty(), "hold_breath_silences_sprint_noise")
	quiet.ability_active = 0.0
	for step in range(30):
		quiet.apply_intent(Vector2.RIGHT, true, 1.0 / 60.0)
	_check(not heard.is_empty(), "sprint_noise_returns_after_hold_breath")
	_check(quiet.ability_cooldown == 45.0, "hold_breath_cooldown")
	quiet.queue_free()


func _quartermaster_checks() -> void:
	var packer := _survivor("quartermaster", spot)
	var before: int = level.pickups.filter(func(pickup: CampPickup) -> bool: return pickup.available and pickup.position.distance_to(spot) < 30).size()
	_check(level.abilities.use(packer), "unpack_once")
	var after: int = level.pickups.filter(func(pickup: CampPickup) -> bool: return pickup.available and pickup.position.distance_to(spot) < 30).size()
	_check(after - before == 4, "unpack_drops_four_supplies_for_team")
	_check(not level.abilities.use(packer), "unpack_once_per_night")
	packer.queue_free()


func _give_checks() -> void:
	await _frames(2)
	var friend := _survivor("scout", spot + Vector2(14, 0))
	player.position = spot
	player.supplies["flare"] = 2
	player.belt[0] = "flare"
	player.selected_slot = 0
	var before: int = friend.supplies["flare"]
	var gave: bool = level.abilities.give(player)
	_check(gave and player.supplies["flare"] == 1 and friend.supplies["flare"] == before + 1, "hand_over_one_flare")
	friend.position = spot + Vector2(120, 0)
	_check(not level.abilities.give(player), "cannot_hand_over_at_a_distance")
	friend.queue_free()


func _team_hook_checks() -> void:
	var jock := _survivor("jock", spot)
	var other := _survivor("medic", spot + Vector2(0, 30))
	await _frames(2)
	jock.inventory.append("outboard_motor")
	other.inventory.append("outboard_motor")
	jock.apply_intent(Vector2.RIGHT, false, 1.0 / 60.0)
	other.apply_intent(Vector2.RIGHT, false, 1.0 / 60.0)
	_check(is_equal_approx(jock.velocity.length(), jock.config.walk_speed) and is_equal_approx(other.velocity.length(), other.config.walk_speed * 0.75), "jock_hauls_motor_at_full_walk")
	jock.queue_free()
	other.queue_free()
	var quiet := _survivor("quiet", spot)
	await _frames(1)
	quiet.wounded = true
	for step in range(40):
		quiet.apply_intent(Vector2.RIGHT, false, 1.0 / 60.0)
	_check(quiet.blood.is_empty(), "quiet_kid_leaves_no_blood_trail")
	quiet.queue_free()
	var helper := _survivor("scout", level.night_clock.generator_point() + Vector2(10, 0))
	player.position = level.night_clock.generator_point()
	level.night_clock.blackout = true
	var heat_before: float = level.night_clock.heat
	_check(level.night_clock.restart_generator(player) and level.night_clock.heat == heat_before, "two_person_generator_restart_is_quiet")
	helper.queue_free()
	level.night_clock.blackout = true
	await _frames(2)
	_check(level.night_clock.restart_generator(player) and level.night_clock.heat > heat_before, "solo_generator_restart_is_loud")


func _award_checks() -> void:
	var row: Dictionary = level.abilities.stat(player)
	row["flares"] = 4
	row["revives"] = 2
	row["chased"] = 25.0
	var titles: Array[String] = level.abilities.awards()
	_check(titles.any(func(title: String) -> bool: return title.begins_with("MOST FLARES WASTED")) and titles.any(func(title: String) -> bool: return title.begins_with("NEVER LEFT BEHIND")) and titles.any(func(title: String) -> bool: return title.begins_with("BAIT")), "awards_from_stats")
	level.finish_round(true, "Test escape.")
	_check(level.awards_text.contains("NEVER LEFT BEHIND") and level.hud.result_panel.visible, "awards_on_results_screen")


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame


func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": passed}))
