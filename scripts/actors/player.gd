class_name CampPlayer
extends CharacterBody2D

signal noise_emitted(origin: Vector2)
signal sprint_noise_emitted(origin: Vector2)
signal status_changed

enum Status { ALIVE, DOWNED, DEAD, ESCAPED, LEFT_BEHIND, BOARDED }

var sheet: Texture2D
var config: CampConfig = preload("res://assets/default_config.tres")
var peer_name := ""
var notice := ""
var notice_time := 0.0
var net_controlled := false
var network_direction := Vector2.ZERO
var network_sprint := false
var local_input: bool = true
var controls_enabled: bool = true
var status: Status = Status.ALIVE
var facing := Vector2.DOWN
var stamina: float = 4.0
var exhausted: bool = false
var sprinting: bool = false
var flashlight_on: bool = true
var inventory: Array[String] = []
var bleedout: float = 0.0
var noise_clock: float = 0.0
var stride: float = 0.0
var expedition: bool = false
var flashlight_charge: float = 90.0
var supplies: Dictionary = {"flare": 2, "battery_pack": 1, "rations": 1, "medkit": 0}
var invulnerability: float = 0.0
var role: String = "jock"
var light_drain: float = 1.0
var sprint_hearing: float = 1.0
var belt: Array[String] = ["flare", "battery_pack", "rations", "", "", ""]
var selected_slot: int = 0
var role_applied := false
var ward_remaining: float = 0.0
var hex_remaining: float = 0.0
## F3 chase toolkit: wounded before downed, a crawl while downed, flash-stun and solo recovery.
const WOUND_GRACE := 1.2
const WOUNDED_SPRINT := 0.9
const CRAWL_SPEED := 20.0
const FLASH_COST := 15.0
const FLASH_COOLDOWN := 8.0
var wounded: bool = false
var flash_time: float = 0.0
var flash_cooldown: float = 0.0
var self_recovery_used: bool = false
var help_cooldown: float = 0.0
var blood: Array[Vector2] = []
var blood_distance: float = 0.0
var hidden_spot: int = -1
var vault_time: float = 0.0
const BARRIER_LAYER := 8
var breath: float = 1.0


func _ready() -> void:
	apply_role()
	sheet = load("res://assets/sprites/survivor_" + role + ".png")
	stamina = config.stamina_max
	flashlight_charge = config.flashlight_capacity
	add_to_group("survivors")
	collision_mask |= BARRIER_LAYER


func _physics_process(delta: float) -> void:
	notice_time=maxf(0,notice_time-delta)
	ward_remaining = maxf(0, ward_remaining - delta)
	hex_remaining = maxf(0, hex_remaining - delta)
	flash_time = maxf(0.0, flash_time - delta)
	flash_cooldown = maxf(0.0, flash_cooldown - delta)
	help_cooldown = maxf(0.0, help_cooldown - delta)
	if expedition and CampMap.is_woods(global_position) and flashlight_on and status == Status.ALIVE:
		flashlight_charge = maxf(0.0, flashlight_charge - delta * light_drain)
		if flashlight_charge <= 0:
			flashlight_on = false
	invulnerability = maxf(0.0, invulnerability - delta)
	if net_controlled and controls_enabled:
		apply_intent(network_direction,network_sprint,delta)
	elif local_input and controls_enabled:
		apply_intent(Input.get_vector("move_left", "move_right", "move_up", "move_down"),
			Input.is_action_pressed("sprint"), delta)
	else:
		velocity = Vector2.ZERO
		sprinting = false
	queue_redraw()


func apply_intent(direction: Vector2, wants_sprint: bool, delta: float) -> void:
	velocity = Vector2.ZERO
	if vault_time > 0.0:
		sprinting = false
		return
	if hidden_spot >= 0:
		sprinting = false
		stamina = minf(config.stamina_max, stamina + delta * config.stamina_recovery)
		return
	if status == Status.DOWNED:
		# Downed survivors drag themselves slowly toward cover or a teammate.
		sprinting = false
		var crawl := direction.limit_length(1.0)
		if crawl.length_squared() > 0.0:
			facing = crawl
		velocity = crawl * CRAWL_SPEED
		var before := position
		move_and_slide()
		stride += position.distance_to(before) * 0.5
		return
	if status != Status.ALIVE:
		sprinting = false
		return
	var movement := direction.limit_length(1.0)
	if movement.length_squared() > 0.0:
		facing = movement
	if exhausted and stamina >= config.stamina_restart:
		exhausted = false
	sprinting = wants_sprint and movement != Vector2.ZERO and not exhausted and stamina > 0.0
	if sprinting:
		stamina = maxf(0.0, stamina - delta)
		if stamina == 0.0:
			exhausted = true
	else:
		stamina = minf(config.stamina_max, stamina + delta * config.stamina_recovery)
	velocity = movement * (config.sprint_speed * (WOUNDED_SPRINT if wounded else 1.0) if sprinting else config.walk_speed)
	if hex_remaining > 0:
		velocity *= 0.6
	var previous := position
	move_and_slide()
	var distance := position.distance_to(previous)
	stride += distance
	if wounded:
		# A short-lived trail: the newest drops show where a wounded survivor went.
		blood_distance += distance
		if blood_distance >= 18.0:
			blood_distance = 0.0
			blood.append(global_position.round())
			if blood.size() > 14:
				blood.pop_front()
	if sprinting and distance > 0.1:
		noise_clock -= delta
		if noise_clock <= 0.0:
			noise_clock = config.sprint_noise_interval
			sprint_noise_emitted.emit(global_position)
	else:
		noise_clock = 0.0


func receive_hit() -> void:
	if invulnerability > 0.0 or ward_remaining > 0.0:
		return
	if status != Status.ALIVE or hidden_spot >= 0:
		return
	if not wounded:
		# First hit wounds: a brief grace window to run before a second hit downs.
		wounded = true
		invulnerability = WOUND_GRACE
		get_tree().call_group("round_world", "on_survivor_wounded", self)
		queue_redraw()
		return
	set_status(Status.DOWNED)


func apply_hex(seconds: float) -> void:
	if status != Status.ALIVE:
		return
	hex_remaining = maxf(hex_remaining, seconds)
	stamina = maxf(0, stamina - 1.5)
	queue_redraw()


func set_status(next: Status) -> void:
	# DEAD is retained only for old serialized/status indices. Downs never become deaths.
	if next == Status.DEAD: next = Status.DOWNED
	if status == next: return
	status = next
	velocity = Vector2.ZERO
	if status != Status.ALIVE:
		hidden_spot = -1
	if status == Status.DOWNED:
		bleedout = 0
		get_tree().call_group("round_world", "on_survivor_downed", self)
	if status == Status.ALIVE:
		# Revived survivors come back wounded: one more hit downs them again.
		wounded = true
		stamina = config.stamina_max * 0.5
		invulnerability = config.revive_grace_seconds
	status_changed.emit()
	queue_redraw()


func _draw() -> void:
	if status in [Status.ESCAPED, Status.BOARDED]:
		return
	if hidden_spot >= 0:
		# Only a pair of eyes in the dark gives a hidden survivor away to teammates.
		draw_rect(Rect2(-3, -8, 2, 1), Color("d9e6c8"))
		draw_rect(Rect2(1, -8, 2, 1), Color("d9e6c8"))
		return
	if not peer_name.is_empty():
		draw_string(ThemeDB.fallback_font,name_origin(),peer_name,HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("b9d4b2"))
	draw_circle(Vector2(0, 1), 7, Color(0, 0, 0, 0.35))
	if hex_remaining > 0 and status == Status.ALIVE:
		draw_arc(Vector2(0,-2), 11, 0, TAU, 16, Color("b4a3d3"), 1)
	var row := 0
	if absf(facing.x) > absf(facing.y):
		row = 2 if facing.x > 0 else 3
	elif facing.y < 0:
		row = 1
	var frame := 0 if velocity.length() < 1.0 else 1 + int(stride / 6.0) % 2
	if status in [Status.DOWNED, Status.DEAD]:
		draw_set_transform(Vector2(10, -2), -PI * 0.5)
		draw_texture_rect_region(sheet, Rect2(-12, -29, 24, 32), Rect2(0, 0, 24, 32), Color.WHITE if status == Status.DOWNED else Color("738080"))
		draw_set_transform(Vector2.ZERO)
		if status == Status.DOWNED:
			draw_line(Vector2(-2, -12), Vector2(2, -12), Color("ecd6a0"), 2)
			draw_line(Vector2(0, -14), Vector2(0, -10), Color("ecd6a0"), 2)
		return
	draw_texture_rect_region(sheet, Rect2(-12, -29, 24, 32), Rect2(frame * 24, row * 32, 24, 32))
	if wounded:
		draw_rect(Rect2(-4, -14, 3, 3), Color("a8322c"))
		draw_rect(Rect2(2, -9, 2, 2), Color("8c2a25"))
	if flash_time > 0.0:
		var spread := facing.orthogonal() * 34
		var reach := facing * 90 + Vector2(0, -12)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -12), reach + spread, reach - spread]), Color(1, 0.98, 0.85, flash_time / 0.18 * 0.55))
	if not held_item().is_empty():
		var hand := Vector2(9 if facing.x >= 0 else -10, -9)
		var colors := {"flare":"d58460", "battery_pack":"9bb5ad", "rations":"d1ae72", "medkit":"e5dfc2", "noise_tin":"a5b9bd", "salt_ward":"ded9bb", "glow_moss":"a6d99a"}
		draw_rect(Rect2(hand, Vector2(4, 6)), Color(colors.get(held_item(), "e1c47c")))
		draw_line(hand, hand + Vector2(3, 0), Color("fff0ba"))
		if held_item() == "glow_moss":
			draw_line(hand+Vector2(2,3),hand+Vector2(0,-4),Color("a9df92"))
		elif held_item() == "medkit":
			draw_line(hand+Vector2(2,1),hand+Vector2(2,4),Color("b56051"))
			draw_line(hand+Vector2(1,2),hand+Vector2(3,2),Color("b56051"))
	if ward_remaining > 0:
		draw_arc(Vector2.ZERO, 12, 0, TAU, 20, Color("ded9b2"), 1)


func apply_role() -> void:
	if role_applied:
		return
	role_applied = true
	role = SurvivorRoster.valid(role)
	config = SurvivorRoster.effective(config, role)
	match role:
		"mechanic": supplies["battery_pack"] += 1
		"scout":
			light_drain = 0.8
			supplies["rations"] += 1
		"medic":
			supplies["medkit"] += 1
			supplies["flare"] += 1
			belt[3] = "medkit"
		"quiet": sprint_hearing = 0.75
		"quartermaster":
			for kind in ["flare", "battery_pack", "rations"]:
				supplies[kind] += 1
	for kind in ["noise_tin", "salt_ward", "glow_moss"]:
		supplies[kind] = 0

func can_pack(kind: String) -> bool:
	return kind in belt or "" in belt

func pack(kind: String, count: int = 1) -> bool:
	if not can_pack(kind):
		return false
	if kind not in belt:
		belt[belt.find("")] = kind
	supplies[kind] = supplies.get(kind, 0) + count
	return true

func tidy_belt() -> void:
	for index in range(belt.size()):
		if supplies.get(belt[index], 0) <= 0:
			belt[index] = ""

func held_item() -> String:
	return belt[selected_slot]


func name_origin() -> Vector2:
	return Vector2(-ThemeDB.fallback_font.get_string_size(peer_name,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x * 0.5,-34)
