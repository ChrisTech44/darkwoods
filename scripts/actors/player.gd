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
var network_input_sequence := 0
var network_applied_sequence := 0
## Used only around presentation-only shared movement; never set by client RPCs.
var prediction_kit: Array = []
var prediction_effect_bits := -1
var prediction_heavy := -1
var prediction_pull := Vector2.ZERO
var prediction_drift := Vector2.RIGHT
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
var role: String = "christian"
var kit: Dictionary = {}
var light_drain: float = 90.0 / 840.0
var sprint_hearing: float = 1.0
var belt: Array[String] = ["flare", "battery_pack", "rations", "", "", ""]
var selected_slot: int = 0
var role_applied := false
var ward_remaining: float = 0.0
var hex_remaining: float = 0.0
## Health: each creature hits for its own damage (see CampKiller.THREATS); at 0
## the survivor is downed. At or below half health they are wounded (bleeding,
## slower sprint). Medkits heal; a hit grants a short grace so two creatures
## cannot land back-to-back hits.
const MAX_HEALTH := 100.0
const WOUNDED_AT := 50.0
const DEFAULT_HIT := 50.0
const REVIVE_HEALTH := 35.0
const MEDKIT_HEAL := 50.0
const RATION_HEAL := 10.0
var health: float = MAX_HEALTH
## Damage of the latest hit and seconds since, for the HUD's hurt flash.
var last_hit := 0.0
var hurt_time := 0.0
## F3 chase toolkit: wounded before downed, a crawl while downed, flash-stun and solo recovery.
const WOUND_GRACE := 1.5
const WOUNDED_SPRINT := 0.9
const CRAWL_SPEED := 20.0
const FLASH_COST := 30.0
const FLASH_COOLDOWN := 8.0
## Derived from health: setting true drops to half health, false heals fully.
var wounded: bool:
	get:
		return health - float(kit.get("debt",0.0)) <= WOUNDED_AT
	set(value):
		health = minf(health, WOUNDED_AT) if value else MAX_HEALTH
var flash_time: float = 0.0
var flash_cooldown: float = 0.0
var self_recovery_used: bool = false
var help_cooldown: float = 0.0
var blood: Array[Vector2] = []
var blood_distance: float = 0.0
var hidden_spot: int = -1
var motor_assisted := false
var assisting_motor := false
var vault_time: float = 0.0
const BARRIER_LAYER := 8
## Lake water: solid to bodies, but not to sight, light or voice rays (layer 1).
const WATER_LAYER := 16
var breath: float = 1.0
## X active ability state (see SurvivorAbilities).
var ability_charges: int = 0
var ability_cooldown: float = 0.0
var ability_active: float = 0.0
## Seconds left held in a Groundskeeper snare.
var snared: float = 0.0
## Seconds of flashlight flicker (a build-up tell before the director's peaks).
var flicker: float = 0.0
## Monster revamp: timed effects by name -> seconds left (synced). See EFFECTS.
## "held" lasts until the holder lets go; the others count down.
var effects: Dictionary = {}
## Effect parameters: "pull_to" (hypnosis), "drift" (float), "held_by" (who
## holds you, for the HUD), "tether_to" (instance position of the other end).
var effect_data: Dictionary = {}
## 0..1 progress of mashing E while held (synced for the HUD).
var struggle: float = 0.0
## Fraction of a full break-free each E press earns (set by the holder).
var struggle_step: float = 0.1
## Struggle lost per second while you aren't pressing (set by the holder): slow
## or casual pressing never gets you out.
var struggle_decay: float = 0.1
## Times each kind of creature has grabbed this survivor tonight (escalation).
var grab_counts: Dictionary = {}
## Host only: the creature holding this survivor (CampKiller), or null.
var holder: Node = null
## Decaying shove from throws, pounces and charges (px/s).
var knock: Vector2 = Vector2.ZERO
const EFFECT_NAMES := {"held": "HELD", "frog": "FROG", "backwards": "BACKWARDS", "float": "FLOATING", "helium": "HELIUM VOICE",
	"sneezy": "SNEEZY", "drowsy": "DROWSY", "asleep": "ASLEEP", "hypnotized": "DRAWN", "whiteout": "BLINDED", "face_moth": "MOTH ON YOUR FACE",
	"tethered": "STITCHED", "garlic": "GARLIC", "bug_spray": "BUG SPRAY", "coffee": "CAFFEINATED", "marked": "PHOTOGRAPHED", "tripped": "TRIPPED",
	"slimed": "SLIMED", "piggyback": "HITCHHIKER ON YOUR BACK", "hot_streak":"HOT STREAK", "lead_boots":"LEAD BOOTS", "rally":"RALLY", "nightlight":"NIGHT-LIGHT", "lost": "LOST", "deaf": "DEAFENED", "dark": "CURSED DARK", "rewound": "REWOUND"}
## Slime skid: your actual velocity eases toward where you steer (Slug trails).
var skid := Vector2.ZERO
var form_motion := Vector2.ZERO


func _ready() -> void:
	apply_role()
	SurvivorAbilities.setup(self)
	sheet = load("res://assets/sprites/survivor_" + SurvivorRoster.art(role) + ".png")
	stamina = config.stamina_max
	flashlight_charge = config.flashlight_capacity
	add_to_group("survivors")
	var nameplate: Node2D = load("res://scripts/actors/survivor_nameplate.gd").new()
	nameplate.actor=self
	add_child(nameplate)
	collision_mask |= BARRIER_LAYER | WATER_LAYER


func _physics_process(delta: float) -> void:
	notice_time=maxf(0,notice_time-delta)
	ward_remaining = maxf(0, ward_remaining - delta)
	hex_remaining = maxf(0, hex_remaining - delta)
	flash_time = maxf(0.0, flash_time - delta)
	flash_cooldown = maxf(0.0, flash_cooldown - delta)
	help_cooldown = maxf(0.0, help_cooldown - delta)
	hurt_time = maxf(0.0, hurt_time - delta)
	flicker = maxf(0.0, flicker - delta)
	_tick_effects(delta)
	if effect_data.get("sample_moth",false):
		if has_effect("face_moth"): flashlight_charge = maxf(0.0,flashlight_charge-3*delta)
		else: effect_data.erase("sample_moth")
	if expedition and flashlight_charge<=0:
		flashlight_on=false
	elif has_effect("nightlight") and flashlight_charge>0:
		flashlight_on=true
	elif has_effect("dark"):
		flashlight_on = false
	if expedition and CampMap.is_woods(global_position) and flashlight_on and status == Status.ALIVE:
		flashlight_charge = maxf(0.0, flashlight_charge - delta * passive_light_rate())
		if flashlight_charge <= 0:
			flashlight_on = false
	invulnerability = maxf(0.0, invulnerability - delta)
	if net_controlled and controls_enabled:
		apply_intent(network_direction,network_sprint,delta)
		network_applied_sequence = network_input_sequence
	elif local_input and controls_enabled:
		apply_intent(Input.get_vector("move_left", "move_right", "move_up", "move_down"),
			Input.is_action_pressed("sprint"), delta)
	else:
		velocity = Vector2.ZERO
		sprinting = false
	queue_redraw()


func _movement_effect(effect: String) -> bool:
	if prediction_effect_bits < 0: return has_effect(effect)
	var index := LocalPrediction.EFFECTS.find(effect)
	return index >= 0 and (prediction_effect_bits & (1 << index)) != 0


func apply_intent(direction: Vector2, wants_sprint: bool, delta: float, presentation_only: bool = false) -> void:
	velocity = Vector2.ZERO
	if knock.length() > 30.0 and status == Status.ALIVE:
		# Thrown, pounced or launched: the shove wins until it fades.
		sprinting = false
		velocity = knock
		knock = knock.move_toward(Vector2.ZERO, 700.0 * delta)
		move_and_slide()
		if get_slide_collision_count() > 0:
			knock *= 0.4
		return
	knock = Vector2.ZERO
	if status == Status.ALIVE and (_movement_effect("held") or _movement_effect("asleep") or _movement_effect("tripped")):
		sprinting = false
		stamina = minf(config.stamina_max, stamina + delta * config.stamina_recovery * 0.5)
		return
	if status == Status.ALIVE and _movement_effect("backwards"):
		direction = -direction
	if vault_time > 0.0:
		sprinting = false
		return
	if hidden_spot >= 0:
		sprinting = false
		stamina = minf(config.stamina_max, stamina + delta * config.stamina_recovery * (1.35 if kit_isolated() else 1.0))
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
	if snared > 0.0:
		sprinting = false
		return
	if (kit.get("channel",0.0) if prediction_kit.is_empty() else prediction_kit[0]) > 0.0:
		sprinting = false
		return
	var movement := direction.limit_length(1.0)
	if movement.length_squared() > 0.0:
		facing = movement
	if exhausted and stamina >= config.stamina_restart:
		exhausted = false
	var heavy := "outboard_motor" in inventory if prediction_heavy < 0 else prediction_heavy == 1
	var frog := _movement_effect("frog")
	sprinting = wants_sprint and not heavy and not frog and not _movement_effect("piggyback") and not assisting_motor and movement != Vector2.ZERO and not exhausted and stamina > 0.0
	if sprinting:
		stamina = maxf(0.0, stamina - delta)
		if stamina == 0.0:
			exhausted = true
	else:
		stamina = minf(config.stamina_max, stamina + delta * config.stamina_recovery * (1.35 if kit_isolated() else 1.0))
	velocity = movement * (config.sprint_speed * (WOUNDED_SPRINT if wounded else 1.0) if sprinting else config.walk_speed)
	if heavy and not motor_assisted:
		velocity *= 0.75
	if hex_remaining > 0:
		velocity *= 0.6
	if frog:
		# A frog hops: short bursts of speed.
		velocity *= 0.55 + 0.6 * maxf(0.0, sin(stride * 0.35))
	if _movement_effect("drowsy") and not _movement_effect("coffee"):
		velocity *= 0.6
	if _movement_effect("hypnotized"):
		var pull: Vector2 = effect_data.get("pull_to", global_position) if prediction_effect_bits < 0 else prediction_pull
		# Fighting the pull: a sprint still gets you away, a walk barely holds ground.
		velocity = velocity * 0.5 + global_position.direction_to(pull) * 34.0
	if _movement_effect("float"):
		velocity = velocity * 0.4 + (Vector2(effect_data.get("drift", Vector2.RIGHT)) if prediction_effect_bits < 0 else prediction_drift) * 46.0
	if _movement_effect("piggyback"):
		# Something rides on your back: heavy, and no sprinting.
		velocity *= 0.68
	if _movement_effect("slimed"):
		# On slime you skate: hard to start, harder to stop or turn.
		skid = skid.lerp(velocity * 1.15, minf(1.0, 1.6 * delta))
		velocity = skid
	else:
		skid = velocity
	if _movement_effect("hot_streak"): velocity *= 1.5
	if _movement_effect("lead_boots"): velocity *= 0.5
	if _movement_effect("rally"): velocity *= 1.2
	velocity = CreatureSamples.player_velocity(self, velocity)
	var previous := position
	move_and_slide()
	var distance := position.distance_to(previous)
	stride += distance
	if presentation_only: return # No AI hearing, blood, or gameplay outcomes on clients.
	if wounded:
		# A short-lived trail: the newest drops show where a wounded survivor went.
		blood_distance += distance
		if blood_distance >= 18.0:
			blood_distance = 0.0
			blood.append(global_position.round())
			if blood.size() > 14:
				blood.pop_front()
	if sprinting and distance > 0.1 and not silent():
		noise_clock -= delta
		if noise_clock <= 0.0:
			noise_clock = config.sprint_noise_interval
			sprint_noise_emitted.emit(global_position)
	else:
		noise_clock = 0.0


## Shared noise hook; the replacement kits do not suppress basic footsteps.
func silent() -> bool:
	return false


## Returns true when the hit landed. Every landed hit grants WOUND_GRACE.
func receive_hit(damage: float = DEFAULT_HIT) -> bool:
	if invulnerability > 0.0 or ward_remaining > 0.0:
		return false
	if status != Status.ALIVE or hidden_spot >= 0:
		return false
	var was_wounded := wounded
	if role == "john" and ability_active > 0.0: damage *= 0.5
	SurvivorKits.hit(self,damage)
	if role == "john" and ability_active > 0.0:
		kit["debt"] = float(kit.get("debt",0.0)) + damage
		invulnerability = WOUND_GRACE
		last_hit = damage
		return true
	health = maxf(0.0, health - damage)
	last_hit = damage
	hurt_time = 0.6
	if health <= 0.0:
		set_status(Status.DOWNED)
		return true
	invulnerability = WOUND_GRACE
	if wounded and not was_wounded:
		get_tree().call_group("round_world", "on_survivor_wounded", self)
	queue_redraw()
	return true


func heal(amount: float) -> void:
	if kit.get("debt",0.0) > 0.0: return
	health = minf(MAX_HEALTH, health + amount)
	if not wounded:
		blood.clear()
	queue_redraw()


func has_effect(name: String) -> bool:
	return effects.get(name, 0.0) > 0.0


func add_effect(name: String, seconds: float) -> void:
	effects[name] = maxf(effects.get(name, 0.0), seconds)
	queue_redraw()


func clear_effect(name: String) -> void:
	effects.erase(name)
	if name == "held":
		struggle = 0.0
		effect_data.erase("held_by")


func _tick_effects(delta: float) -> void:
	if has_effect("held"):
		struggle = maxf(0.0, struggle - struggle_decay * delta)
	for name: String in effects.keys():
		if name == "held":
			continue
		effects[name] -= delta
		if effects[name] <= 0.0:
			effects.erase(name)
			if name == "tethered":
				effect_data.erase("tether_to")


## The survivor is grabbed by `by` (a creature) until it lets go or they wriggle
## free: every E press adds `per_press` of a full escape.
func grab(by: Node, label: String, per_press: float, decay: float = 0.1) -> void:
	SurvivorKits.cancel_return(self)
	if kit.get("debt",0.0) > 0.0 or (role == "john" and ability_active > 0.0):
		SurvivorKits.settle(self)
		if status != Status.ALIVE: return
	holder = by
	struggle = 0.0
	struggle_step = per_press
	struggle_decay = decay
	effect_data["held_by"] = label
	effects["held"] = 1.0
	knock = Vector2.ZERO
	velocity = Vector2.ZERO
	hidden_spot = -1
	queue_redraw()


## Let go (the holder calls this, or the survivor broke free / went down).
func release() -> void:
	var was: Node = holder
	holder = null
	clear_effect("held")
	if is_instance_valid(was) and was.has_method("on_released"):
		was.on_released(self)


## One press of E while held. True when it breaks the hold.
func wriggle() -> bool:
	if not has_effect("held"):
		return false
	struggle = minf(1.0, struggle + struggle_step)
	# 0.999: n presses of 1/n must free you despite float rounding.
	if struggle >= 0.999:
		release()
		return true
	return false


## A shove (throws, pounces, charges); collisions stop it at walls.
func shove(impulse: Vector2) -> void:
	if role == "john" and ability_active > 0.0: return
	if status != Status.ALIVE:
		return
	if has_effect("held"):
		release()
	knock = impulse
	hidden_spot = -1


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
	if next in [Status.BOARDED,Status.ESCAPED]:
		var was_alive := status == Status.ALIVE
		SurvivorKits.settle(self)
		if was_alive and status == Status.DOWNED: return
	status = next
	velocity = Vector2.ZERO
	if status != Status.ALIVE:
		hidden_spot = -1
		if holder != null:
			release()
		knock = Vector2.ZERO
	if status == Status.DOWNED:
		SurvivorKits.cleanup(self)
		bleedout = 0
		get_tree().call_group("round_world", "on_survivor_downed", self)
	if status == Status.ALIVE:
		# Revived survivors come back badly hurt: a solid hit downs them again.
		health = REVIVE_HEALTH
		stamina = config.stamina_max * 0.5
		invulnerability = config.revive_grace_seconds
	status_changed.emit()
	queue_redraw()


func _draw() -> void:
	if kit.get("form","")=="nobody": return
	if status in [Status.ESCAPED, Status.BOARDED]:
		return
	if hidden_spot >= 0:
		# Only a pair of eyes in the dark gives a hidden survivor away to teammates.
		draw_rect(Rect2(-3, -8, 2, 1), Color("d9e6c8"))
		draw_rect(Rect2(1, -8, 2, 1), Color("d9e6c8"))
		return
	if status == Status.ALIVE and CreatureSamples.draw_player(self): return
	if has_effect("tethered") and effect_data.has("tether_to"):
		# The Seamstress's thread to whoever (or whatever) you're stitched to.
		var other: Vector2 = to_local(effect_data["tether_to"])
		draw_line(Vector2(0, -10), other + Vector2(0, -10), Color("e8dcc0"), 1.0)
	if status == Status.ALIVE and has_effect("frog"):
		draw_circle(Vector2(0, 1), 5, Color(0, 0, 0, 0.35))
		var hop := absf(sin(stride * 0.35)) * 4.0
		if not PixelArt.draw_in(self, "frog", Rect2(-8, -15 - hop, 16, 16)):
			draw_circle(Vector2(0, -6 - hop), 6, Color("5f8f43"))
		return
	if status == Status.ALIVE and has_effect("asleep"):
		var t := Time.get_ticks_msec() * 0.001
		for index in range(3):
			draw_string(ThemeDB.fallback_font, Vector2(6 + index * 4, -30 - index * 5 - fmod(t * 6.0, 4.0)), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 6 + index, Color(0.85, 0.9, 1.0, 0.8))
	if status == Status.ALIVE and has_effect("held"):
		draw_set_transform(Vector2(sin(Time.get_ticks_msec() * 0.05) * 1.5, 0))
	if status == Status.ALIVE and has_effect("float"):
		draw_set_transform(Vector2(0, -6 + sin(Time.get_ticks_msec() * 0.006) * 2.0))
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
		if status == Status.DOWNED and not PixelArt.draw_in(self, "fx_help", Rect2(-6, -26, 12, 12)):
			draw_line(Vector2(-2, -12), Vector2(2, -12), Color("ecd6a0"), 2)
			draw_line(Vector2(0, -14), Vector2(0, -10), Color("ecd6a0"), 2)
		return
	draw_texture_rect_region(sheet, Rect2(-12, -29, 24, 32), Rect2(frame * 24, row * 32, 24, 32))
	if "outboard_motor" in inventory:
		PixelArt.draw_in(self,"outboard_motor",Rect2(-20,-18,14,20))
	if wounded and not PixelArt.draw_in(self, "fx_blood_trail", Rect2(-5, -15, 9, 7), Color(1, 1, 1, 0.85)):
		draw_rect(Rect2(-4, -14, 3, 3), Color("a8322c"))
		draw_rect(Rect2(2, -9, 2, 2), Color("8c2a25"))
	if flash_time > 0.0:
		var spread := facing.orthogonal() * 34
		var reach := facing * 90 + Vector2(0, -12)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -12), reach + spread, reach - spread]), Color(1, 0.98, 0.85, flash_time / 0.18 * 0.55))
	if not held_item().is_empty() and facing.y >= -0.5:
		# The held supply's own SpriteCook icon at the figure's hand; hidden in the back view.
		var hand := Vector2(5 if facing.x >= 0 else -11, -14)
		if not PixelArt.draw_in(self, held_item(), Rect2(hand, Vector2(7, 7))):
			draw_rect(Rect2(hand, Vector2(3, 4)), Color("e1c47c"))
	if ward_remaining > 0:
		draw_arc(Vector2.ZERO, 12, 0, TAU, 20, Color("ded9b2"), 1)


func apply_role() -> void:
	if role_applied:
		return
	role_applied = true
	role = SurvivorRoster.valid(role)
	config = SurvivorRoster.effective(config, role)
	for kind in ["noise_tin", "salt_ward", "glow_moss", "garlic", "wolfsbane", "bug_spray", "scissors", "train_ticket", "air_horn", "coffee"]:
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


func display_name() -> String:
	if kit.get("form","") == "mimic": return kit.get("mask_name",peer_name)
	return peer_name if not peer_name.is_empty() else role.to_upper()

func name_origin() -> Vector2:
	return Vector2(-ThemeDB.fallback_font.get_string_size(peer_name,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x * 0.5,-34)

func passive_light_rate() -> float:
	return light_drain*(0.75 if kit_isolated() else 1.0)*(2.0 if has_effect("nightlight") else 1.0)

func kit_isolated() -> bool:
	return bool(kit.get("isolated",false)) if prediction_kit.is_empty() else prediction_kit[1]

func on_released(_actor: CampPlayer) -> void:
	CreatureSamples.finish_cast(self)

## Holds drain continuously after ending Push Through at grab time; hit grace
## does not turn a bite/squeeze into one hit every 1.5 seconds.
func receive_drain(damage: float) -> void:
	if role == "john" and ability_active > 0.0 and status == Status.ALIVE:
		kit["debt"] = float(kit.get("debt",0.0)) + damage * 0.5
		return
	SurvivorKits.settle(self)
	if status != Status.ALIVE: return
	SurvivorKits.cancel_return(self)
	health = maxf(0.0,health-damage)
	hurt_time = 0.2
	if health <= 0.0: set_status(Status.DOWNED)
