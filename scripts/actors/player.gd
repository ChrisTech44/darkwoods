class_name CampPlayer
extends CharacterBody2D

signal noise_emitted(origin: Vector2)
signal status_changed

enum Status { ALIVE, DOWNED, DEAD, ESCAPED, LEFT_BEHIND, BOARDED }

var config: CampConfig = preload("res://assets/default_config.tres")
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
var hex_remaining: float = 0.0


func _ready() -> void:
	stamina = config.stamina_max
	flashlight_charge = config.flashlight_capacity
	add_to_group("survivors")


func _physics_process(delta: float) -> void:
	hex_remaining = maxf(0, hex_remaining - delta)
	if expedition and global_position.x >= 1536 and flashlight_on and status == Status.ALIVE:
		flashlight_charge = maxf(0.0, flashlight_charge - delta)
		if flashlight_charge <= 0:
			flashlight_on = false
	invulnerability = maxf(0.0, invulnerability - delta)
	if local_input and controls_enabled:
		apply_intent(Input.get_vector("move_left", "move_right", "move_up", "move_down"),
			Input.is_action_pressed("sprint"), delta)
	else:
		velocity = Vector2.ZERO
		sprinting = false
	if status == Status.DOWNED:
		bleedout -= delta
		if bleedout <= 0.0:
			set_status(Status.DEAD)
	queue_redraw()


func apply_intent(direction: Vector2, wants_sprint: bool, delta: float) -> void:
	velocity = Vector2.ZERO
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
	velocity = movement * (config.sprint_speed if sprinting else config.walk_speed)
	if hex_remaining > 0:
		velocity *= 0.6
	var previous := position
	move_and_slide()
	var distance := position.distance_to(previous)
	stride += distance
	if sprinting and distance > 0.1:
		noise_clock -= delta
		if noise_clock <= 0.0:
			noise_clock = config.sprint_noise_interval
			noise_emitted.emit(global_position)
	else:
		noise_clock = 0.0


func receive_hit() -> void:
	if invulnerability > 0.0:
		return
	if status == Status.ALIVE:
		set_status(Status.DOWNED)
	elif status == Status.DOWNED:
		set_status(Status.DEAD)


func apply_hex(seconds: float) -> void:
	if status != Status.ALIVE:
		return
	hex_remaining = maxf(hex_remaining, seconds)
	stamina = maxf(0, stamina - 1.5)
	queue_redraw()


func set_status(next: Status) -> void:
	status = next
	velocity = Vector2.ZERO
	if status == Status.DOWNED:
		bleedout = config.bleedout_seconds
	if status == Status.ALIVE:
		stamina = config.stamina_max * 0.5
		invulnerability = config.revive_grace_seconds
	status_changed.emit()
	queue_redraw()


func _draw() -> void:
	if status in [Status.ESCAPED, Status.BOARDED]:
		return
	draw_circle(Vector2(0, 1), 7, Color(0, 0, 0, 0.35))
	if hex_remaining > 0 and status == Status.ALIVE:
		draw_arc(Vector2(0,-2), 11, 0, TAU, 16, Color("b4a3d3"), 1)
	var sheet: Texture2D = preload("res://assets/sprites/camper.png")
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
