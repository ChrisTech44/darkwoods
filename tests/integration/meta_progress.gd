extends SceneTree
## F8 meta: score and grades, the local profile (best per seed, daily night,
## journal sightings, merit badges), results-screen lines and the menu's Daily
## Night and Camp Journal. Uses the separate test profile file.
var checks := 0
var failures := 0
var level: Node2D
var player: CampPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session: Node = root.get_node("Session")
	var profile: CampProfile = session.profile
	_check(profile.path == CampProfile.TEST_PATH, "tests_never_touch_the_real_profile")
	profile.reset()
	_score_checks()
	_profile_checks(profile)
	profile.reset()
	await _round_checks(session)
	await _menu_checks(session)
	profile.reset()
	print(JSON.stringify({"event": "test_result", "suite": "meta_progress", "checks": checks, "failures": failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(0 if failures == 0 else 1)


func _score_checks() -> void:
	_check(CampProfile.grade(1800) == "S" and CampProfile.grade(1799) == "A" and CampProfile.grade(1000) == "B" and CampProfile.grade(600) == "C" and CampProfile.grade(10) == "D", "grade_boundaries")
	_check(CampProfile.daily_seed({"year": 2026, "month": 10, "day": 17}) == 20261017, "daily_seed_from_date")
	var card := CampProfile.score_night(true, "SIGNAL FIRE", 2, 3, 1, 4, 1, true)
	var expected := int(round((1000 + 200 + 300 + 75 + 100 + 40) * 1.15))
	_check(card["score"] == expected and card["grade"] == CampProfile.grade(expected), "score_counts_escape_rumour_relics_notes_rescues_modifiers")
	_check(CampProfile.score_night(false, "", 0, 0, 0, 0, 0, false)["score"] == 0, "no_escape_scores_nothing")


func _profile_checks(profile: CampProfile) -> void:
	var card := {"score": 1900, "grade": "S"}
	var earned := profile.record_night(42, card, true, "SIGNAL FIRE", "stalker", ["blood_moon"], true, true, ["mower"])
	for id in ["first_light", "pyromaniac", "snare_dancer", "red_sky", "daily_dose", "top_marks", "team_player"]:
		_check(id in earned, "badge_" + id)
	_check(profile.best(42) == 1900 and profile.get_count("nights") == 1 and profile.get_count("escapes") == 1, "night_recorded")
	_check(profile.record_night(42, {"score": 500, "grade": "C"}, false, "", "stalker", [], false, false).is_empty() and profile.best(42) == 1900, "best_kept_and_badges_once")
	profile.record_night(7, {"score": 1100}, true, "VAN", "stalker", [], false, false)
	_check("route_master" in profile.record_night(8, {"score": 1100}, true, "BOAT", "stalker", [], false, false), "three_routes_earn_route_master")
	_check(profile.record_sighting("werewolf") and not profile.record_sighting("werewolf") and profile.seen("werewolf"), "sighting_recorded_once")
	var text := profile.journal_text()
	_check(text.contains("%s: %s" % [CampProfile.display_name("werewolf"), CampProfile.TIPS["werewolf"]]) and text.contains("??? (not yet sighted)") and text.contains("★ PYROMANIAC"), "journal_shows_tips_and_badges")
	var reloaded := CampProfile.new()
	_check(reloaded.best(42) == 1900 and reloaded.seen("werewolf"), "profile_persists")


func _round_checks(session: Node) -> void:
	session.survivor = "jock"
	session.mode = "woods"
	session.daily = false
	session.next_seed = 42
	change_scene_to_file("res://scenes/world/forest_level.tscn")
	while current_scene == null or current_scene.name != "ForestLevel":
		await process_frame
	level = current_scene
	player = level.player
	player.local_input = false
	for enemy: CampKiller in get_nodes_in_group("killers"):
		enemy.enabled = false
	await _frames(4)
	var cryptid: CampCryptid = get_nodes_in_group("cryptids")[0]
	player.position = level.plan.woods.center(Vector2i(18, 24))
	cryptid.position = player.position + Vector2(60, 0)
	await _frames(3)
	_check(level.tonight_seen.has(cryptid.species) and session.profile.seen(cryptid.species), "first_sighting_unlocks_journal_entry")
	level.read_note(level.plan.cache_zone.keys().filter(func(kind: String) -> bool: return level.clues[kind] == 0)[0])
	_check(level.notes_read == 1, "notes_counted_for_score")
	level.escape_route = "VAN"
	level.finish_round(true, "Test escape.")
	var detail: String = level.hud.result_panel.get_child(0).get_node("Detail").text
	_check(level.score_card["score"] >= 1000 and detail.contains("SCORE") and detail.contains("GRADE"), "results_show_score_and_grade")
	_check(detail.contains("NEW BADGE: FIRST LIGHT") and detail.contains("BEST ON NIGHT 42"), "results_show_new_badges_and_best")
	_check(session.profile.get_count("nights") == 1, "round_end_records_night_once")


func _menu_checks(session: Node) -> void:
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	while current_scene == null or current_scene.name != "MainMenu":
		await process_frame
	await _frames(3)
	var menu: Control = current_scene
	_check(menu.get_node("Menu/Mode").item_count == 3 and menu.get_node("Menu/Mode").get_item_text(2) == "DAILY NIGHT", "daily_night_in_mode_list")
	menu.get_node("Menu/Mode").select(2)
	menu._mode_selected(2)
	menu.get_node("Menu/Play").pressed.emit()
	_check(session.daily and session.mode == "woods" and session.next_seed == CampProfile.daily_seed(Time.get_date_dict_from_system()), "daily_night_uses_todays_seed")
	session.daily = false
	session.next_seed = 0
	menu.get_node("SurvivorSelection/Back").pressed.emit()
	await _frames(2)
	menu.get_node("Menu/Journal").pressed.emit()
	_check(menu.get_node("JournalPanel").visible and menu.get_node("JournalPanel/Content/Body").text.contains("CREATURES SEEN"), "camp_journal_opens")
	menu.get_node("JournalPanel/Content/Back").pressed.emit()
	_check(not menu.get_node("JournalPanel").visible and menu.get_node("Menu").visible, "journal_closes")


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame


func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures += 1
	print(JSON.stringify({"event": "assertion", "name": label, "passed": passed}))
