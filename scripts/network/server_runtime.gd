class_name ServerRuntime
extends Node
## Dedicated authority: no local survivor, UI, audio devices or voice codec.
var enabled := false
var port := 27840
var game_mode := "woods"
var configured_seed := 0
var min_players := 1
var camper_abilities_enabled := true
var start_delay := 3.0
var result_delay := 15.0
var ready_since := -1.0
var result_since := -1.0
var next_status := 0.0

static func requested() -> bool:
	return OS.has_feature("dedicated_server") or "--dedicated-server" in OS.get_cmdline_user_args()

func _ready() -> void:
	enabled = requested()
	if not enabled:
		set_process(false)
		return
	if DisplayServer.get_name() != "headless" or AudioServer.get_driver_name() != "Dummy":
		fail("Use tools/run_server.py or --headless --audio-driver Dummy.")
		return
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		var option: String = args[index]
		if option == "--no-camper-abilities":
			camper_abilities_enabled = false
			index += 1
			continue
		if option == "--dedicated-server":
			index += 1
			continue
		if option not in ["--port", "--mode", "--seed", "--min-players", "--start-delay", "--result-delay"] or index + 1 >= args.size():
			fail("Unknown or incomplete server option: " + option)
			return
		var value: String = args[index + 1]
		if option == "--mode": game_mode = value
		elif not value.is_valid_int():
			fail("Server options require whole numbers: " + option)
			return
		else:
			match option:
				"--port": port = int(value)
				"--seed": configured_seed = int(value)
				"--min-players": min_players = int(value)
				"--start-delay": start_delay = float(value)
				"--result-delay": result_delay = float(value)
		index += 2
	if port < 1 or port > 65535 or game_mode not in ["camp", "woods"] or configured_seed < 0 or configured_seed > 2147483646 or min_players < 1 or min_players > 4 or start_delay < 1.0 or start_delay > 60.0 or result_delay < 3.0 or result_delay > 300.0:
		fail("Invalid server options. See docs/dedicated_server.md.")
		return
	boot.call_deferred()

func fail(reason: String) -> void:
	print(JSON.stringify({"event": "server_error", "reason": reason}))
	get_tree().quit(2)

func boot() -> void:
	var net: Node = get_node("/root/Net")
	var error: Error = net.host_dedicated(port)
	if error != OK:
		fail("Cannot bind UDP port %d: %s" % [port, error_string(error)])
		return
	net.configure_lobby(game_mode, configured_seed, camper_abilities_enabled)
	show_lobby()
	print(JSON.stringify({"event": "server_listening", "port": port, "mode": game_mode, "min_players": min_players, "rules": net.RULES, "max_players": 4, "camper_abilities_enabled": camper_abilities_enabled, "audio_driver": AudioServer.get_driver_name()}))

func show_lobby() -> void:
	ready_since = -1.0
	result_since = -1.0
	get_tree().change_scene_to_file("res://scenes/network/server_lobby.tscn")

func _process(_delta: float) -> void:
	if not enabled: return
	var net: Node = get_node("/root/Net")
	if not net.active: return
	var now := Time.get_ticks_msec() / 1000.0
	if net.phase == "lobby":
		if net.roster.size() >= min_players and net.can_start():
			if ready_since < 0.0:
				ready_since = now
				print(JSON.stringify({"event": "server_ready_countdown", "seconds": start_delay, "players": net.roster.size()}))
			elif now - ready_since >= start_delay:
				ready_since = -1.0
				net.start_round(game_mode, configured_seed)
		else: ready_since = -1.0
	elif net.phase == "results":
		if result_since < 0.0:
			result_since = now
			print(JSON.stringify({"event": "server_results", "next_lobby_in": result_delay, "won": net.world.won if net.world != null else false}))
		elif now - result_since >= result_delay:
			net.return_lobby(false)
	if now >= next_status:
		next_status = now + 30.0
		print(JSON.stringify({"event": "server_status", "phase": net.phase, "players": net.roster.size(), "round": net.round_id, "snapshot_bytes": net.latest_snapshot_bytes, "loaded": net.loaded.keys(), "participants": net.participants.keys()}))
