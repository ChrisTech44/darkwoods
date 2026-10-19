extends SceneTree
## Real shared CharacterBody movement, fixed physics frames; no world/AI fixtures.
var checks := 0
var failures := 0
var noise := 0
var authority: CampPlayer
var visual: CampPlayer
const DT := 1.0 / 60.0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(JSON.stringify({"event":"assertion", "name":label, "passed":ok}))
func reset() -> void:
	for player in [authority, visual]:
		player.position = Vector2.ZERO
		player.velocity = Vector2.ZERO
		player.stamina = player.config.stamina_max
		player.exhausted = false
		player.knock = Vector2.ZERO
		player.skid = Vector2.ZERO
		player.status = CampPlayer.Status.ALIVE
		player.health = 100
		player.vault_time = 0
		player.hidden_spot = -1
		player.snared = 0
		player.hex_remaining = 0
		player.motor_assisted = false
		player.assisting_motor = false
		player.ability_active = 0
		player.stride = 0
		player.inventory.clear()
		player.effects.clear()
		player.effect_data.clear()
		player.effect_data.pull_to = Vector2.ZERO
		player.blood.clear()
		player.blood_distance = 0
		player.noise_clock = 0
		player.role = "mechanic"
func scenario(label: String, setup: Callable, direction: Vector2 = Vector2.RIGHT) -> void:
	reset()
	for player in [authority, visual]: setup.call(player)
	var predictor := LocalPrediction.new()
	predictor.bind(visual)
	predictor.receive(authority.position, Vector2.ZERO, Vector2.DOWN, 0, LocalPrediction.capture(authority), 1, 0.0)
	var canonical := LocalPrediction.capture(visual)
	for i in range(8):
		await physics_frame
		authority.apply_intent(direction, true, DT)
		predictor.step(i+1, direction, true, DT, i*DT)
	check(predictor.simulated.distance_to(authority.position) < 0.01, "shared_movement_"+label)
	var retained := LocalPrediction.capture(visual)
	retained[13] = canonical[13] # Stride is presentation animation, not gameplay state.
	check(retained == canonical and visual.blood.is_empty(), "authority_state_untouched_"+label)
func run() -> void:
	root.get_node("Voice").mode = "off"
	authority = load("res://scenes/actors/player.tscn").instantiate()
	visual = load("res://scenes/actors/player.tscn").instantiate()
	root.add_child(authority)
	root.add_child(visual)
	for player in [authority, visual]: player.set_physics_process(false)
	visual.sprint_noise_emitted.connect(func(_at): noise += 1)
	await scenario("sprint", func(_p): pass)
	await scenario("diagonal", func(_p): pass, Vector2(1,1))
	await scenario("heavy", func(p): p.inventory.append("outboard_motor"))
	await scenario("assisted_motor", func(p): p.inventory.append("outboard_motor"); p.motor_assisted = true)
	await scenario("jock_wind", func(p): p.role = "jock"; p.ability_active = 3)
	await scenario("wounded", func(p): p.health = 40)
	await scenario("exhausted", func(p): p.stamina = 0; p.exhausted = true)
	await scenario("knock", func(p): p.knock = Vector2(250,0))
	await scenario("held", func(p): p.effects.held = 3)
	await scenario("vault", func(p): p.vault_time = 1)
	await scenario("hidden", func(p): p.hidden_spot = 0)
	await scenario("crawl", func(p): p.status = CampPlayer.Status.DOWNED)
	await scenario("snare", func(p): p.snared = 1)
	await scenario("hex", func(p): p.hex_remaining = 1)
	for effect: String in ["backwards", "frog", "drowsy", "hypnotized", "float", "piggyback", "slimed", "asleep", "tripped"]:
		await scenario(effect, func(p): p.effects[effect] = 2; p.effect_data.pull_to = Vector2(100,0); p.effect_data.drift = Vector2.DOWN)
	await scenario("jock_heavy", func(p): p.role = "jock"; p.inventory.append("outboard_motor"))
	await scenario("coffee", func(p): p.effects.drowsy = 2; p.effects.coffee = 2)
	var wall := StaticBody2D.new()
	wall.position = Vector2(13,0)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(2,200)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	await physics_frame
	await scenario("wall_slide", func(_p): pass, Vector2(1,1))
	check(authority.position.x < 9 and authority.position.y > 1, "shared_collision_slide_is_real")
	wall.queue_free()
	await physics_frame
	check(noise == 0, "prediction_never_emits_ai_hearing")
	reset()
	var predictor := LocalPrediction.new()
	predictor.bind(visual)
	predictor.receive(Vector2.ZERO,Vector2.ZERO,Vector2.RIGHT,0,LocalPrediction.capture(authority),1,0.0)
	await physics_frame
	predictor.step(1,Vector2.RIGHT,false,DT,DT)
	check(visual.position.x > 0 and predictor.history.size() == 1, "first_tick_moves_without_waiting_for_server")
	check(visual.stride > 0, "predicted_walking_animation_advances_immediately")
	var once := visual.position
	predictor.receive(once,Vector2.RIGHT*authority.config.walk_speed,Vector2.RIGHT,1,LocalPrediction.capture(authority),2,2*DT)
	await physics_frame
	predictor.step(2,Vector2.ZERO,false,DT,2*DT)
	check(predictor.simulated.distance_to(once) < 0.01 and predictor.history.size() == 1, "acknowledged_input_not_replayed_twice")
	for i in range(3,100):
		await physics_frame
		predictor.step(i,Vector2.RIGHT,false,DT,i*DT)
	check(predictor.simulated.x < once.x + authority.config.walk_speed * 0.3, "prediction_stops_after_250ms_without_authority")
	check(predictor.history.size() <= 16, "stalled_history_stays_bounded")
	var before := visual.position
	predictor.receive(predictor.simulated+Vector2(12,0),Vector2.ZERO,Vector2.RIGHT,99,LocalPrediction.capture(authority),100,100*DT)
	await physics_frame
	predictor.step(100,Vector2.ZERO,false,DT,100*DT)
	check(visual.position.distance_to(before) < 0.01, "ordinary_reconciliation_has_no_immediate_snap")
	predictor.render(DT)
	check(visual.position.distance_to(before) <= 180*DT+0.01, "render_correction_rate_is_bounded")
	predictor.receive(Vector2(2000,2000),Vector2.ZERO,Vector2.RIGHT,100,LocalPrediction.capture(authority),101,101*DT,1)
	await physics_frame
	predictor.step(101,Vector2.ZERO,false,DT,101*DT)
	check(visual.position.distance_to(Vector2(2000,2000)) < 0.01, "real_authority_teleport_resets_prediction")
	predictor.bind(null)
	check(not predictor.initialized and predictor.history.is_empty(), "new_round_clears_prediction")
	var buffer := RemoteMotion.new()
	buffer.push(Vector2.ZERO,Vector2(60,0),60,5.0)
	buffer.push(Vector2(6,0),Vector2(60,0),66,5.12)
	check(buffer.sample(5.13).distance_to(Vector2(3,0)) < 0.01, "jitter_buffer_interpolates_server_time")
	check(not buffer.push(Vector2(-100,0),Vector2.ZERO,62,5.14) and buffer.latest_tick == 66, "old_samples_ignored")
	check(buffer.sample(7.0).distance_to(Vector2(9,0)) < 0.01, "remote_extrapolation_stops_at_50ms")
	check(buffer.push(Vector2(900,900),Vector2.ZERO,67,7.1,1) and buffer.samples.size() == 1, "remote_teleport_flushes_buffer")
	var remote := Node2D.new()
	root.add_child(remote)
	var resumed := RemoteMotion.new()
	resumed.push(Vector2.ZERO,Vector2(70,0),60,5.0)
	resumed.push(Vector2(140,0),Vector2(70,0),180,7.0)
	check(resumed.samples.size() == 2, "long_gap_travel_is_not_misclassified_as_teleport")
	resumed.render(remote,7.1,DT)
	check(remote.position.length() <= 240*DT+0.01, "remote_gap_recovery_has_bounded_render_steps")
	remote.queue_free()
	var poses := []
	for id in range(4): poses.append([id,Vector2.ZERO,Vector2.ZERO,Vector2.DOWN,0])
	check(var_to_bytes([poses,2147483647,LocalPrediction.capture(authority),2147483647]).size() <= 900, "four_player_packet_fits_single_bounded_payload")
	var net := root.get_node("Net")
	net.motion_epochs.clear()
	authority.position = Vector2.ZERO
	authority.velocity = Vector2.ZERO
	check(net.motion_epoch(authority) == 0, "authority_epoch_starts_clean")
	authority.position = Vector2(200,0)
	check(net.motion_epoch(authority) == 1, "authority_marks_real_discontinuity")
	net.motion_epochs[authority] = [Vector2.ZERO,Vector2(70,0),Engine.get_physics_frames()-120,1]
	check(net.motion_epoch(authority) == 1, "authority_accepts_plausible_continuous_travel")
	net.motion_epochs.clear()
	var malformed := LocalPrediction.capture(authority)
	malformed[2] = Vector2(NAN,0)
	check(not LocalPrediction.valid(malformed) and not LocalPrediction.valid([]), "invalid_prediction_state_rejected")
	authority.queue_free()
	visual.queue_free()
	await process_frame
	print(JSON.stringify({"event":"test_result","suite":"movement_prediction","checks":checks,"failures":failures}))
	await root.get_node("AudioManager").prepare_shutdown()
	quit(1 if failures else 0)
