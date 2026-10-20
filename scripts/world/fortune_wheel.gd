class_name FortuneWheel
extends RefCounted
## Authority selects and resolves a spin exactly once. The UI reveals names only.
const COOLDOWN := 60.0
const SPIN := 1.8
const NAMES := ["HOT STREAK", "LEAD BOOTS", "BAD BEAT", "DEAD MAN'S HAND", "SECOND WIND", "HOME SWEET HOME", "UNINVITED GUEST", "JACKPOT", "BUTTERFINGERS", "LIGHTS OUT", "DINNER BELL"]
const WEIGHTS := [18,14,12,1,15,10,10,8,6,3,3]
static var face: Texture2D

static func start(actor: CampPlayer) -> bool:
	if actor.kit.get("wheel_time",0.0)>0: return false
	var ticket := randi_range(0,99)
	var chosen := 0
	while ticket >= WEIGHTS[chosen]:
		ticket -= WEIGHTS[chosen]
		chosen += 1
	actor.kit["wheel_pick"] = chosen
	actor.kit["wheel_time"] = SPIN
	actor.kit["wheel_result"] = ""
	actor.ability_cooldown = COOLDOWN
	return true

static func advance(actor: CampPlayer, delta: float) -> void:
	if actor.kit.get("wheel_time",0.0)>0:
		actor.kit["wheel_time"] = maxf(0,actor.kit.wheel_time-delta)
		if not SurvivorKits.able(actor): cancel(actor)
		elif actor.kit.wheel_time<=0: resolve(actor,int(actor.kit.wheel_pick))
	actor.kit["wheel_show"] = maxf(0,actor.kit.get("wheel_show",0.0)-delta)
	var guest: Dictionary = actor.kit.get("wheel_guest",{})
	if not guest.is_empty():
		guest.wait -= delta
		if guest.wait<=0:
			actor.kit["wheel_guest"] = {}
			var enemy: Object = instance_from_id(guest.id)
			if actor.status==CampPlayer.Status.ALIVE and is_instance_valid(enemy) and not is_instance_valid(enemy.held):
				var at := landing(actor,enemy)
				if at!=Vector2.INF:
					enemy.position=at
					enemy.recover_remaining=maxf(enemy.recover_remaining,1.5)

static func cancel(actor: CampPlayer) -> void:
	actor.kit["wheel_time"] = 0.0
	actor.kit["wheel_guest"] = {}

static func resolve(actor: CampPlayer, chosen: int) -> void:
	var level: Node = SurvivorKits.world(actor)
	if level==null or not SurvivorKits.enabled(actor) or not SurvivorKits.able(actor) or chosen<0 or chosen>=NAMES.size(): return
	actor.kit["wheel_time"] = 0.0
	actor.kit["wheel_result"] = NAMES[chosen]
	actor.kit["wheel_show"] = 3.0
	level.announce(NAMES[chosen],actor)
	level.soundscape.broadcast("bells",actor.position,-6,1.4)
	match chosen:
		0: actor.add_effect("hot_streak",20)
		1: actor.add_effect("lead_boots",15)
		2: actor.health=maxf(1.0,actor.health*0.5)
		3: actor.set_status(CampPlayer.Status.DOWNED)
		4: actor.health=CampPlayer.MAX_HEALTH
		5:
			for offset in [Vector2.ZERO,Vector2(16,0),Vector2(0,16),Vector2(-16,0)]:
				if relocate(actor,Vector2(96,384)+offset): break
		6:
			var enemy := nearest_roamer(actor)
			if enemy!=null and landing(actor,enemy)!=Vector2.INF:
				actor.kit["wheel_guest"]={"id":enemy.get_instance_id(),"wait":1.5}
		7:
			var available: Array = []
			for kind: String in actor.supplies:
				if actor.supplies[kind]>0: available.append(kind)
			if not available.is_empty(): actor.pack(available[randi()%available.size()])
		8: level.drop_all_items(actor)
		9: actor.add_effect("dark",15)
		10:
			level.loud_noise(actor.position,900)
			level.soundscape.broadcast("air_horn",actor.position,-6)

static func nearest_roamer(actor: CampPlayer) -> CampKiller:
	var nearest: CampKiller
	for enemy: CampKiller in actor.get_tree().get_nodes_in_group("killers"):
		if not enemy.enabled or is_instance_valid(enemy.held) or (enemy is CampCryptid and enemy.home.has_area()): continue
		if nearest==null or enemy.position.distance_squared_to(actor.position)<nearest.position.distance_squared_to(actor.position): nearest=enemy
	return nearest

static func landing(actor: CampPlayer, enemy: CampKiller) -> Vector2:
	var level: Node = SurvivorKits.world(actor)
	for i in range(12):
		var at := actor.position+Vector2.from_angle(i*TAU/12)*80
		if CampKiller.camp_closed and CampKiller.in_camp(at): continue
		if level.clear_path(actor.position,at) and SurvivorKits.safe_point(actor,at):
			if enemy is CampCryptid and enemy.home.has_area() and not enemy.home.has_point(at): continue
			return at
	return Vector2.INF

## Used by chance relocations and the Magician; gear and injuries travel once.
static func relocate(actor: CampPlayer, at: Vector2) -> bool:
	if not SurvivorKits.safe_point(actor,at,1|CampPlayer.BARRIER_LAYER|CampPlayer.WATER_LAYER): return false
	var level: Node = SurvivorKits.world(actor)
	var partner: CampPlayer = actor.get_meta("tether_partner") if actor.has_meta("tether_partner") else null
	for end: CampPlayer in [actor,partner]:
		if not is_instance_valid(end): continue
		end.clear_effect("tethered")
		if end.has_meta("tether_partner"): end.remove_meta("tether_partner")
	level.props.vaults.erase(actor.get_instance_id())
	actor.vault_time=0
	actor.collision_mask |= CampPlayer.BARRIER_LAYER
	SurvivorKits.cancel_return(actor)
	actor.position=at
	actor.velocity=Vector2.ZERO
	return true

static func draw(canvas: Node2D, actor: CampPlayer) -> void:
	var remaining: float=actor.kit.get("wheel_time",0.0)
	if remaining<=0 and actor.kit.get("wheel_show",0.0)<=0: return
	var centre := actor.position+Vector2(0,-55)
	var chosen: int=actor.kit.get("wheel_pick",0)
	var before := 0
	for i in range(chosen): before+=WEIGHTS[i]
	var final_angle: float = -PI/2-TAU*(before+WEIGHTS[chosen]*0.5)/100.0
	var t := clampf(1.0-remaining/SPIN,0,1)
	var rotation: float = final_angle-TAU*4*pow(1-t,3)
	if face==null: face=load("res://assets/sprites/fortune_wheel.png")
	canvas.draw_texture_rect_region(face,Rect2(centre-Vector2(25,25),Vector2(50,50)),face.get_image().get_used_rect())
	canvas.draw_circle(centre,24,Color("e5c477"))
	var sum := 0
	for i in range(WEIGHTS.size()):
		var points := PackedVector2Array([centre])
		for j in range(9): points.append(centre+Vector2.from_angle(rotation+TAU*(sum+WEIGHTS[i]*j/8.0)/100.0)*23)
		canvas.draw_colored_polygon(points,Color.from_hsv(i/float(WEIGHTS.size()),0.55,0.65))
		sum+=WEIGHTS[i]
	canvas.draw_colored_polygon(PackedVector2Array([centre+Vector2(-3,-29),centre+Vector2(3,-29),centre+Vector2(0,-21)]),Color("f4e6bb"))
	canvas.draw_circle(centre,3,Color("e5c477"))
	if remaining<=0:
		var name_text: String=actor.kit.get("wheel_result","")
		var width := ThemeDB.fallback_font.get_string_size(name_text,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x
		canvas.draw_rect(Rect2(centre+Vector2(-width/2-3,28),Vector2(width+6,12)),Color("101d20"))
		canvas.draw_string(ThemeDB.fallback_font,centre+Vector2(-width/2,37),name_text,HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("f4e6bb"))
