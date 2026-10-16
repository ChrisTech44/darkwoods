class_name CampPlayer
extends CharacterBody2D

signal noise_emitted(origin: Vector2)
signal status_changed

enum Status { ALIVE, DOWNED, DEAD, ESCAPED, LEFT_BEHIND }

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
var invulnerability: float = 0.0


func _ready() -> void:
	stamina = config.stamina_max
	add_to_group("survivors")


func _physics_process(delta: float) -> void:
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
	if status == Status.ESCAPED:
		return
	draw_ellipse_shadow()
	if status == Status.DEAD or status == Status.DOWNED:
		draw_rect(Rect2(-7, -3, 14, 6), Color("9c6b55") if status == Status.DOWNED else Color("514c4b"))
		if status == Status.DOWNED:
			draw_line(Vector2(-2, -8), Vector2(2, -8), Color("ecd6a0"), 2)
			draw_line(Vector2(0, -10), Vector2(0, -6), Color("ecd6a0"), 2)
		return
	var step := 1.0 if int(stride / 5.0) % 2 == 0 else -1.0
	draw_rect(Rect2(-4, 1 + step, 3, 5), Color("283c52"))
	draw_rect(Rect2(1, 1 - step, 3, 5), Color("283c52"))
	draw_rect(Rect2(-5, -5, 10, 8), Color("a9af7d"))
	draw_rect(Rect2(-3, -10, 6, 6), Color("dab98b"))
	draw_rect(Rect2(-3, -11, 6, 2), Color("584637"))
	draw_line(Vector2.ZERO, facing * 9.0, Color("f1e8bb"), 2.0)
	if flashlight_on:
		draw_circle(facing * 10.0, 2, Color("ffe3a0"))


func draw_ellipse_shadow() -> void:
	draw_rect(Rect2(-6, 2, 12, 5), Color(0, 0, 0, 0.3))
