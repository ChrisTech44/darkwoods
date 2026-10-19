class_name LocalPrediction
extends RefCounted
## Presentation-only movement. The authority still receives directions, never positions.
const FIELDS := ["stamina", "exhausted", "knock", "skid", "status", "health", "vault_time", "hidden_spot", "snared", "hex_remaining", "motor_assisted", "assisting_motor", "ability_active", "stride"]
const EFFECTS := ["held", "asleep", "tripped", "backwards", "frog", "piggyback", "drowsy", "coffee", "hypnotized", "float", "slimed"]
const MAX_AGE := 0.25
const MAX_HISTORY := 60
var actor: CampPlayer
var history: Array = []
var pending: Array = []
var shadow: Array = []
var simulated := Vector2.ZERO
var last_arrival := -1.0
var last_tick := -1
var last_epoch := -1
var initialized := false
var corrections := 0
var largest_correction := 0.0

static func capture(player: CampPlayer) -> Array:
	var row := []
	for field: String in FIELDS: row.append(player.get(field))
	row.append("outboard_motor" in player.inventory)
	var bits := 0
	for i in range(EFFECTS.size()):
		if player.has_effect(EFFECTS[i]): bits |= 1 << i
	row.append(bits)
	row.append(player.effect_data.get("pull_to", player.global_position))
	row.append(player.effect_data.get("drift", Vector2.RIGHT))
	return row

static func valid(row: Variant) -> bool:
	if not row is Array or row.size() != FIELDS.size() + 4: return false
	for i in range(FIELDS.size()):
		var kind := typeof(row[i])
		if i in [2, 3]:
			if kind != TYPE_VECTOR2 or not row[i].is_finite(): return false
		elif i in [1, 10, 11]:
			if kind != TYPE_BOOL: return false
		elif i in [4, 7]:
			if kind != TYPE_INT: return false
		else:
			if kind not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(row[i])): return false
	return row[14] is bool and row[15] is int and row[16] is Vector2 and row[16].is_finite() and row[17] is Vector2 and row[17].is_finite()

func bind(player: CampPlayer) -> void:
	actor = player
	initialized = false
	history.clear()
	pending.clear()
	shadow.clear()
	last_tick = -1
	last_epoch = -1
	last_arrival = -1.0
	corrections = 0
	largest_correction = 0.0

func receive(position: Vector2, velocity: Vector2, facing: Vector2, ack: int, state: Array, tick: int, now: float, epoch: int = 0) -> void:
	if tick <= last_tick: return
	pending = [position, velocity, facing, ack, state, tick, now, epoch]

func _restore(state: Array) -> void:
	for i in range(FIELDS.size()): actor.set(FIELDS[i], state[i])

func _simulate(input: Array) -> Vector2:
	var canonical := capture(actor)
	var visible := actor.position
	actor.position = simulated
	_restore(shadow)
	actor.prediction_effect_bits = shadow[15]
	actor.prediction_heavy = int(shadow[14])
	actor.prediction_pull = shadow[16]
	actor.prediction_drift = shadow[17]
	actor.apply_intent(input[1], input[2], input[3], true)
	var step := actor.position - simulated
	simulated = actor.position
	# Capture modified movement fields while retaining the authority's effect mask.
	for i in range(FIELDS.size()): shadow[i] = actor.get(FIELDS[i])
	_restore(canonical)
	actor.stride = shadow[13] # Presentation animation follows immediate movement.
	actor.prediction_effect_bits = -1
	actor.prediction_heavy = -1
	actor.position = visible
	return step

## Must run in a physics frame: shared move_and_slide uses the fixed physics delta.
func step(sequence: int, direction: Vector2, sprint: bool, delta: float, now: float) -> void:
	if not is_instance_valid(actor): return
	if not pending.is_empty():
		var packet := pending
		pending = []
		var warp: bool = initialized and packet[7] != last_epoch
		last_epoch = packet[7]
		var previous := simulated
		simulated = packet[0]
		shadow = packet[4].duplicate()
		last_tick = packet[5]
		last_arrival = packet[6]
		actor.velocity = packet[1]
		actor.facing = packet[2]
		history = history.filter(func(input: Array): return input[0] > packet[3] and now - input[4] <= MAX_AGE)
		for input: Array in history: _simulate(input)
		if not initialized or warp:
			actor.position = simulated
		else:
			var error := previous.distance_to(simulated)
			largest_correction = maxf(largest_correction, error)
			if error > 0.5: corrections += 1
		initialized = true
	if not initialized: return
	var input := [sequence, direction, sprint, delta, now]
	history.append(input)
	while history.size() > MAX_HISTORY or (not history.is_empty() and now - history[0][4] > MAX_AGE): history.pop_front()
	if now - last_arrival <= MAX_AGE:
		actor.position += _simulate(input)
	else:
		actor.velocity = Vector2.ZERO
		actor.sprinting = false
	actor.queue_redraw()

func render(delta: float) -> void:
	if not initialized or not is_instance_valid(actor): return
	# Normal corrections are rate limited. Genuine authoritative warps reset in step().
	var error := simulated - actor.position
	actor.position += (error * (1.0 - exp(-delta * 18.0))).limit_length(180.0 * delta)
