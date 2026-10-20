class_name CreatureSamples
extends RefCounted
## Borrowed signatures have explicit adapters, never generic player-state casts.
const SOURCES := ["witch","werewolf","shutter_wraith","ration_moth","bramble_seamstress","vampire","bigfoot","briar_revenant","lantern_moth","candle_grazer","switchback_hound","lens_eater","last_car_conductor","mimic","owl","bog_hands","imps","teddy","groundskeeper","cuckoo","banshee","slug","surveyor","hitchhiker","tollkeeper","echo","fortune_teller","boiler_saint","relay_jackal","stoneback_ram", "lifeguard", "nightlight_kid", "vulture", "nobody", "huntmaster", "magician", "shade"]
const FORMS := ["werewolf","briar_revenant","groundskeeper","mimic","nobody"]
const NAMES := {"shutter_wraith":"PAPARAZZO", "ration_moth":"PUFFBALL", "bramble_seamstress":"SEAMSTRESS", "briar_revenant":"SCARECROW", "candle_grazer":"SNUFFER", "switchback_hound":"BUSTER", "lens_eater":"PEEPER", "last_car_conductor":"CONDUCTOR", "relay_jackal":"JACKAL", "stoneback_ram":"RAM", "boiler_saint":"LULLABY SAINT", "teddy":"BEAR HUG"}
static var form_sheets: Dictionary = {}
static var history: Dictionary = {}
static var history_clock := 0.0

static func reset() -> void:
	history.clear()
	history_clock = 0.0

static func name_of(kind: String) -> String:
	return NAMES.get(kind,kind.replace("_"," ").to_upper())

static func encounter(actor: CampPlayer, source: CampCryptid, subtype: String = "") -> void:
	if not SurvivorKits.enabled(actor) or actor.role != "christian" or actor.status != CampPlayer.Status.ALIVE or source == null: return
	var level: Node = SurvivorKits.world(actor)
	if level == null or not is_instance_valid(level.abilities) or not level.rescue.authority(): return
	if source.species not in SOURCES or not actor.kit.get("sample","").is_empty() or not actor.kit.get("form","").is_empty(): return
	if actor.position.distance_to(source.position) > 400: return
	if source.species == "werewolf" and not source.brain.wolf: return
	var key := "research:%d:%d" % [actor.get_instance_id(),source.get_instance_id()]
	if level.abilities.receipts.has(key): return
	if not actor.kit.get("research",{}).is_empty(): return
	actor.kit["research"] = {"kind":source.species,"subtype":subtype,"wait":3.0,"life":50.0,"key":key}

static func use(actor: CampPlayer) -> bool:
	if not SurvivorKits.enabled(actor): return false
	var level: Node = SurvivorKits.world(actor)
	var form: String = actor.kit.get("form","")
	if not form.is_empty():
		if actor.kit.get("action_cd",0.0) > 0: return false
		if form in ["werewolf","groundskeeper"]:
			actor.kit["dash"] = 0.6
			actor.kit["dash_dir"] = actor.facing
			actor.kit["bowled"] = []
			actor.kit["action_cd"] = 3.0
			level.loud_noise(actor.position,650)
			return true
		return false
	if not actor.kit.get("cast",{}).is_empty():
		if actor.kit["cast"]["kind"] in ["owl","teddy","lens_eater","vampire","boiler_saint"]:
			finish_cast(actor)
			return true
		return false
	var kind: String = actor.kit.get("sample","")
	if kind.is_empty():
		level.announce("Bad Research: survive a real creature signature to collect a sample.",actor)
		return false
	if not actor.kit.get("cast",{}).is_empty(): return false
	if kind == "werewolf" and not level.night_clock.moon:
		level.announce("Werewolf sample needs the full moon. Sample kept.",actor)
		return false
	if kind == "witch" and actor.kit.get("subtype","") == "swap" and targets(actor,160,0.5).size() < 2:
		level.announce("Swap needs two visible bodies. Sample kept.",actor)
		return false
	if kind in ["bigfoot","lens_eater","teddy","owl","imps","relay_jackal","hitchhiker","lantern_moth"] and targets(actor,150,0.5).is_empty():
		level.announce("Face a nearby body with clear sight. Sample kept.",actor)
		return false
	if kind == "owl":
		var bodies := targets(actor,150,0.5)
		if not bodies.is_empty() and bodies[0] is CampPlayer and not level.holding(bodies[0]):
			level.announce("A willing passenger holds E. Face them, then X.",actor)
			return false
	var disguise: CampPlayer = null
	if kind == "mimic":
		for friend: CampPlayer in actor.get_tree().get_nodes_in_group("survivors"):
			if friend != actor and friend.status == CampPlayer.Status.ALIVE:
				disguise = friend
				break
		if disguise == null:
			level.announce("Mimic needs another living player in this round. Sample kept.",actor)
			return false
	if kind=="shade" and ShadowLight.lit(level,actor.position): return false
	if kind=="magician" and CreatureSwap.friend(actor)==null and CreatureSwap.creatures(actor).is_empty(): return false
	if kind=="vulture" and NewCreatureSamples.downed_friend(actor)==null: return false
	if kind not in SOURCES: return false
	actor.kit["sample"] = ""
	actor.kit["research"] = {}
	actor.ability_cooldown = 0.35
	level.announce("FIELD TEST: " + name_of(kind) + " — friends can be affected!",actor)
	if kind in FORMS:
		if kind=="nobody":
			for enemy: CampKiller in actor.get_tree().get_nodes_in_group("killers"):
				if enemy.visible_target==actor: enemy.visible_target=null
				if enemy.traits!=null and enemy.traits.favourite==actor: enemy.traits.favourite=null
				if enemy is CampCryptid and enemy.brain!=null: enemy.brain.survivor_left(actor)
		actor.kit["form"] = kind
		actor.kit["form_time"] = 10.0
		actor.kit["ram"] = false
		actor.kit["action_cd"] = 0.0
		actor.kit["dash"] = 0.0
		if kind == "mimic":
			actor.kit["mask"] = disguise.role
			actor.kit["mask_name"] = disguise.peer_name if not disguise.peer_name.is_empty() else disguise.role.to_upper()
			actor.kit["mask_source"] = disguise.get_instance_id()
		SamplePresentation.cue(actor,kind)
		if kind == "werewolf": level.soundscape.broadcast("werewolf_howl",actor.position,4.0)
		return true
	var delay := 0.8
	if kind in ["banshee","shutter_wraith"]: delay = 1.0
	if kind == "cuckoo": delay = 3.0
	if kind=="magician":
		delay=1.5
		level.soundscape.broadcast("magician_drumroll",actor.position)
	if kind=="shade":
		delay=2
		level.soundscape.broadcast("shade_inhale",actor.position)
	var at := actor.position
	if kind in ["witch","ration_moth","bramble_seamstress","bog_hands","echo","tollkeeper"]:
		var ahead := actor.position + actor.facing * 90
		if level.clear_path(actor.position,ahead): at = ahead
	actor.kit["cast"] = {"kind":kind,"subtype":actor.kit.get("subtype","frog"),"at":at,"direction":actor.facing,"wait":delay,"life":0.0,"pulse":0.0,"fired":false,"victim":0}
	SamplePresentation.cue(actor,kind)
	if kind == "shutter_wraith": level.soundscape.broadcast("camera_charge",actor.position,0.0)
	if kind == "cuckoo":
		var seen := targets(actor,210,0.6)
		if not seen.is_empty(): actor.kit["cast"]["victim"] = seen[0].get_instance_id()
	return true

static func advance(actor: CampPlayer, delta: float) -> void:
	var level: Node = SurvivorKits.world(actor)
	var research: Dictionary = actor.kit.get("research",{})
	if not research.is_empty():
		research["wait"] -= delta
		research["life"] -= delta
		if research["life"] <= 0 or actor.status != CampPlayer.Status.ALIVE:
			actor.kit["research"] = {}
		elif research["wait"] <= 0 and SurvivorKits.able(actor) and actor.kit.get("sample","").is_empty() and actor.kit.get("form","").is_empty():
			actor.kit["sample"] = research["kind"]
			actor.kit["subtype"] = research["subtype"] if not research["subtype"].is_empty() else "frog"
			level.abilities.receipts[research["key"]] = true
			actor.kit["research"] = {}
			level.announce("Sample collected: " + name_of(actor.kit["sample"]),actor)
	if actor.status != CampPlayer.Status.ALIVE:
		finish_cast(actor)
		actor.kit["form"] = ""
		actor.kit["form_time"] = 0.0
		return
	actor.kit["action_cd"] = maxf(0.0,actor.kit.get("action_cd",0.0)-delta)
	var form: String = actor.kit.get("form","")
	if not form.is_empty():
		actor.kit["form_time"] -= delta
		if (form == "mimic" and not valid_disguise(actor)) or actor.kit["form_time"] <= 0 or actor.has_effect("held") or (form == "werewolf" and ((not level.night_clock.moon and not actor.kit.get("ram",false)) or actor.has_effect("wolfsbane"))):
			actor.kit["form"] = ""
			actor.kit["dash"] = 0.0
		elif form in ["werewolf","groundskeeper","stoneback_ram"] and actor.kit.get("dash",0.0) > 0:
			actor.kit["dash"] = maxf(0.0,actor.kit["dash"]-delta)
			for body in targets(actor,30,-1.0):
				if body.get_instance_id() in actor.kit.get("bowled",[]): continue
				actor.kit["bowled"].append(body.get_instance_id())
				if body is CampPlayer:
					body.receive_hit(15)
					body.shove(actor.kit["dash_dir"] * 350)
				else: shove_enemy(body,actor.kit["dash_dir"]*30)
			for door: Dictionary in level.props.doors:
				if door["rect"].get_center().distance_to(actor.position) < 32:
					door["broken"] = 20.0
					door["open"] = true
					level.props._shape(door["body"],door["rect"],false)
	var impact: Dictionary=actor.kit.get("impact",{})
	if not impact.is_empty():
		impact["life"]-=delta
		if impact["life"]<=0: actor.kit["impact"]={}
	var cast: Dictionary = actor.kit.get("cast",{})
	if cast.is_empty(): return
	if actor.has_effect("held") or actor.has_effect("asleep"):
		finish_cast(actor)
		return
	if not cast["fired"]:
		cast["wait"] -= delta
		if cast["kind"] == "cuckoo":
			var victim: Object = instance_from_id(cast["victim"]) if cast["victim"] != 0 else null
			if not is_instance_valid(victim) or not level.clear_path(actor.position,victim.position):
				actor.kit["cast"] = {}
				return
		if cast["kind"] == "cuckoo":
			var calls: int=cast.get("calls",0)
			if calls<3 and cast["wait"]<=2.0-calls:
				cast["calls"]=calls+1
				level.soundscape.broadcast("squeak",actor.position,6.0,1.5 if calls%2==0 else 1.2)
		if cast["wait"] <= 0:
			cast["fired"] = true
			fire(actor,cast)
			if cast["life"] <= 0:
				cast["instant"]=true
				cast["life"]=0.35
	else:
		cast["life"] -= delta
		if cast.get("instant",false):
			if cast["life"]<=0: finish_cast(actor)
			return
		if cast.get("projectile",false):
			projectile(actor,cast,delta)
			if cast["life"] <= 0: finish_cast(actor)
			return
		cast["pulse"] -= delta
		if cast["pulse"] <= 0:
			cast["pulse"] = 0.5
			pulse(actor,cast)
		if cast["life"] <= 0: finish_cast(actor)

static func finish_cast(actor: CampPlayer) -> void:
	actor.kit["cast"] = {}
	for other: CampPlayer in actor.get_tree().get_nodes_in_group("survivors"):
		if other.holder == actor: other.release()

static func targets(actor: CampPlayer, reach: float, cone: float = -1.0, center: Vector2 = Vector2.INF, self_target: bool = false) -> Array:
	var level: Node = SurvivorKits.world(actor)
	var origin := actor.position if center == Vector2.INF else center
	var found: Array = []
	var bodies: Array = actor.get_tree().get_nodes_in_group("killers")
	bodies.append_array(actor.get_tree().get_nodes_in_group("survivors"))
	for body in bodies:
		if body == actor and not self_target: continue
		if body is CampPlayer and (body.status != CampPlayer.Status.ALIVE or body.hidden_spot >= 0): continue
		if body is CampKiller and not body.enabled: continue
		var diff: Vector2 = body.position-origin
		if diff.length() > reach or (diff.length()>1 and actor.facing.dot(diff.normalized())<cone) or not level.clear_path(origin,body.position): continue
		found.append(body)
	found.sort_custom(func(a,b): return a.position.distance_squared_to(origin)<b.position.distance_squared_to(origin))
	return found

static func apply(body: Node2D, kind: String, seconds: float) -> void:
	if body is CampPlayer:
		if kind == "face_moth":
			if body.has_effect("face_moth"): return
			body.effect_data["sample_moth"] = true
		if kind in ["frog","backwards","float"] and body.ward_remaining > 0: return
		body.add_effect(kind,seconds)
		if kind == "frog":
			var level: Node = SurvivorKits.world(body)
			for part: String in body.inventory.duplicate():
				if part in level.plan.required or part in FieldEscapes.BOAT_PARTS or part in SignalFire.PARTS or part.begins_with("gate_code_") or part == "rescue_fuse":
					body.inventory.erase(part)
					level.spawn_dropped(part,body.position+Vector2(8,8))
		if kind == "float": body.effect_data["drift"] = body.facing
		return
	if not body is CampKiller: return
	# The headline is disrupted only by sensory effects, never frog/hold-locks.
	if not body is CampCryptid and kind not in ["whiteout","deaf","lost","sneezy","slimed"]: return
	var timers: Dictionary = body.sample_state.get("timers",{})
	timers[kind] = minf(seconds,2.0) if not body is CampCryptid else minf(seconds,6.0)
	body.sample_state["timers"] = timers
	if kind in ["whiteout","lost","asleep","frog"]:
		if kind in ["frog","asleep"]: body.release_held()
		body.visible_target = null
		body.memory.clear()
		if kind == "lost":
			body.last_seen = body.position
			body.transition(CampKiller.State.SEARCH)
			body.search_remaining = seconds
		if body is CampCryptid: body.casting = false
	body.queue_redraw()

static func fire(actor: CampPlayer, cast: Dictionary) -> void:
	if cast["kind"] in NewCreatureSamples.SOURCES:
		NewCreatureSamples.fire(actor,cast["kind"])
		return
	var level: Node = SurvivorKits.world(actor)
	var kind: String = cast["kind"]
	if kind in SamplePresentation.SHOTS and not cast.get("resolved",false):
		cast["at"]=actor.position+cast["direction"]*12
		cast["life"]=2.5
		cast["projectile"]=true
		cast["distance_left"]=260.0 if kind=="witch" else (78.0 if kind=="ration_moth" else 138.0)
		return
	var bodies := targets(actor,170,0.4)
	if cast.has("hit"):
		var hit: Object=instance_from_id(cast["hit"])
		bodies=[hit] if is_instance_valid(hit) else []
	var first: Node2D = null if bodies.is_empty() else bodies[0]
	match kind:
		"witch":
			cast["at"] = actor.position+cast["direction"]*12
			cast["life"] = 2.5
			cast["projectile"] = true
		"shutter_wraith":
			level.soundscape.broadcast("camera_shutter",actor.position,2.0)
			apply(actor,"whiteout",0.8)
			for body in targets(actor,210,-1.0):
				if body.facing.dot(body.position.direction_to(actor.position))>0.0: apply(body,"whiteout",3.0)
				if body is CampPlayer:
					body.add_effect("marked",20.0)
					level.killer.hear_stimulus(body.position,INF)
			actor.add_effect("marked",20.0)
			level.killer.hear_stimulus(actor.position,INF)
		"ration_moth":
			cast["life"] = 0.8
			var caught := false
			for body in targets(actor,78,-1.0,cast["at"],true):
				if body.velocity.length() < 2: continue
				apply(body,"helium",30)
				apply(body,"sneezy",15)
				caught=true
			if caught: level.soundscape.broadcast("witch_cackle",cast["at"],0.0,2.2)
		"bramble_seamstress":
			var victims := targets(actor,80,-1.0,cast["at"],true)
			for i in range(mini(2,victims.size())):
				var body: Node2D = victims[i]
				apply(body,"tethered",6)
				var anchor: Vector2 = victims[1-i].position if victims.size()>1 else cast["at"]
				if body is CampPlayer:
					body.effect_data["tether_to"] = anchor
					if body.has_meta("tether_partner"): body.remove_meta("tether_partner")
					if victims.size()>1 and victims[1-i] is CampPlayer: body.set_meta("tether_partner",victims[1-i])
				else: body.sample_state["anchor"] = anchor
		"bigfoot":
			if first is CampPlayer:
				first.receive_hit(10)
				first.shove(actor.facing*430)
				level.drop_held(first)
			elif first != null: shove_enemy(first,actor.facing*55)
		"lantern_moth":
			if first != null:
				if first is CampPlayer and first.has_effect("bug_spray"): return
				apply(first,"face_moth",6)
		"imps","relay_jackal":
			if first is CampPlayer:
				if kind == "imps": apply(first,"tripped",1.2)
				level.drop_held(first)
			elif first is CampCryptid and "loot" in first.brain and not first.brain.loot.is_empty():
				var loot: String = first.brain.loot
				first.brain.loot = ""
				level.spawn_dropped(loot,actor.position)
		"hitchhiker":
			if first != null:
				cast["victim"] = first.get_instance_id()
				cast["life"] = 6.0
				apply(first,"piggyback",6)
		"last_car_conductor":
			var dest: Vector2 = Vector2(150,420) if actor.supplies.get("train_ticket",0)>0 else preload("res://scripts/ai/brains/last_car_conductor.gd")._rail_yard(level)
			if valid_move(actor,dest): actor.position = dest
			level.soundscape.broadcast("train",actor.position,-2.0)
		"cuckoo":
			var victim: Object = instance_from_id(cast["victim"])
			if is_instance_valid(victim):
				var rows: Array = history.get(victim.get_instance_id(),[])
				if not rows.is_empty() and valid_move(victim,rows[0]):
					victim.position = rows[0]
					victim.velocity=Vector2.ZERO
					if victim is CampPlayer:
						victim.add_effect("rewound",0.6)
						victim.add_effect("whiteout",0.35)
					history[victim.get_instance_id()]=[]
					level.soundscape.broadcast("bells",victim.position,0.0,1.8)
		"fortune_teller":
			var card: int = randi()%7
			match card:
				0:
					actor.flashlight_charge = actor.config.flashlight_capacity
					actor.stamina = actor.config.stamina_max
					actor.exhausted = false
				1: actor.heal(30)
				2:
					for part: String in level.clues:
						if level.clues[part]<1:
							level.read_note(part)
							break
				3: level.killer.hear_stimulus(actor.position,INF)
				4: apply(actor,"dark",10)
				5: spill_supplies(actor)
				6: actor.receive_hit(30)
			level.announce("Field Test tarot: " + ["THE SUN","STRENGTH","THE STAR","THE TOWER","THE MOON","THE FOOL","DEATH"][card],actor)
		"switchback_hound":
			var point: Vector2 = first.position if first != null else actor.position+actor.facing*80
			if level.clear_path(actor.position,point): level.killer.hear_stimulus(point,INF)
			level.loud_noise(actor.position,350)
			level.soundscape.broadcast("dog_bark",actor.position,4.0)
		"stoneback_ram":
			actor.kit["form"] = "stoneback_ram"
			actor.kit["form_time"] = 0.65
			actor.kit["ram"] = true
			actor.kit["dash"] = 0.6
			actor.kit["dash_dir"] = cast["direction"]
			actor.kit["bowled"] = []
		"banshee":
			for body in targets(actor,150,-1.0,actor.position,true): apply(body,"deaf",10)
			level.soundscape.broadcast("revenant_screech",actor.position,4.0)
		"surveyor":
			for body in targets(actor,110,-1.0,actor.position,true): apply(body,"lost",8)
		"owl","teddy","lens_eater":
			if first != null:
				cast["victim"] = first.get_instance_id()
				cast["life"] = 3.0
				cast["anchor"] = first.position
				pulse(actor,cast)
		"candle_grazer","vampire","boiler_saint","bog_hands","tollkeeper","echo","slug":
			cast["life"] = 6.0
			pulse(actor,cast)

static func pulse(actor: CampPlayer, cast: Dictionary) -> void:
	var level: Node = SurvivorKits.world(actor)
	var kind: String = cast["kind"]
	match kind:
		"candle_grazer":
			for body in targets(actor,100,-1.0,actor.position,true):
				if body is CampPlayer and not body.has_effect("glowing"): body.flashlight_on = false
			for flare in actor.get_tree().get_nodes_in_group("flares"):
				if flare.position.distance_to(actor.position)<100 and level.clear_path(actor.position,flare.position): flare.remaining = 0.0
		"vampire":
			for body in targets(actor,150,0.8):
				if body is CampPlayer and CreatureBrain.in_beam(body,actor.position):
					cast["life"] = 0.0
					continue
				apply(body,"hypnotized",0.7)
				if body is CampPlayer: body.effect_data["pull_to"] = actor.position
				else: body.sample_state["anchor"] = actor.position
		"boiler_saint":
			for body in targets(actor,120,-1.0,actor.position,true):
				if body is CampPlayer and body.has_effect("coffee"): continue
				apply(body,"drowsy",1.0)
				if body.velocity.length()<2:
					var key := "still:%d" % body.get_instance_id()
					cast[key] = float(cast.get(key,0.0))+0.5
					if cast[key]>=2 and not (body is CampPlayer and body.has_effect("asleep")):
						apply(body,"asleep",3)
						level.loud_noise(body.position,200)
				else: cast["still:%d" % body.get_instance_id()]=0.0
		"bog_hands","tollkeeper":
			for flare in actor.get_tree().get_nodes_in_group("flares"):
				if flare.position.distance_to(cast["at"])<80 and level.clear_path(flare.position,cast["at"]):
					cast["life"] = 0.0
					return
			for body in targets(actor,24,-1.0,cast["at"],true):
				if kind == "tollkeeper":
					if body is CampPlayer: cast["life"] = 0.0
					elif body is CampCryptid and not body.home.has_area(): apply(body,"tripped",0.7)
				else:
					if body is CampPlayer:
						if body.holder == null: body.grab(actor,"FIELD TEST MUD",0.2,0)
					else: apply(body,"tripped",0.7)
		"echo":
			level.loud_noise(cast["at"],480)
			if not cast.get("sounded",false):
				cast["sounded"] = true
				level.soundscape.broadcast("field_whistle",cast["at"],0.0,1.0,4.0)
			for friend: CampPlayer in actor.get_tree().get_nodes_in_group("survivors"):
				if CreatureBrain.in_beam(friend,cast["at"],110): cast["life"] = 0.0
		"slug":
			var patches: Array = cast.get("patches",[])
			patches.append(actor.position)
			while patches.size()>12: patches.pop_front()
			cast["patches"] = patches
			var caught := {}
			for point: Vector2 in patches:
				for body in targets(actor,22,-1.0,point,true): caught[body.get_instance_id()] = body
			for body in caught.values():
				if body is CampPlayer and body.ward_remaining>0:
					cast["life"] = 0.0
					continue
				apply(body,"slimed",3)
		"hitchhiker":
			var rider: Object = instance_from_id(cast["victim"])
			if not is_instance_valid(rider):
				cast["life"] = 0.0
				return
			cast["at"]=rider.position+Vector2(0,-18)
			if rider is CampPlayer: rider.flashlight_on = false
			for body in targets(actor,22,-1.0,rider.position,true):
				if body == rider: continue
				if rider is CampPlayer: rider.clear_effect("piggyback")
				else: rider.sample_state.get("timers",{}).erase("piggyback")
				apply(body,"piggyback",cast["life"])
				cast["victim"] = body.get_instance_id()
				break
		"owl","teddy","lens_eater":
			var victim: Object = instance_from_id(cast["victim"])
			if not is_instance_valid(victim) or not level.clear_path(actor.position,victim.position) or actor.flash_time>0:
				cast["life"] = 0.0
				return
			if victim is CampPlayer:
				if victim.holder == null: victim.grab(actor,"FIELD TEST " + name_of(kind),0.2,0)
			else: apply(victim,"tripped",0.7)
			if kind != "owl": apply(actor,"tripped",0.6)
			if kind == "owl":
				var destination: Vector2 = actor.position+Vector2(0,20)
				if valid_move(victim,destination): victim.position = destination
				for flare in actor.get_tree().get_nodes_in_group("flares"):
					if flare.position.distance_to(actor.position)<100: cast["life"] = 0.0

static func spill_supplies(actor: CampPlayer) -> void:
	var level: Node = SurvivorKits.world(actor)
	var index := 0
	for kind: String in actor.supplies:
		for unit in range(actor.supplies[kind]):
			level.spawn_dropped(kind,level._drop_position(actor.position,index))
			index += 1
		actor.supplies[kind] = 0
	actor.tidy_belt()

static func deceived(enemy: CampKiller, actor: CampPlayer) -> bool:
	return enemy is CampCryptid and actor.kit.get("form","") == "mimic" and actor.position.distance_to(enemy.position)>45 and enemy.visible_target != actor and not enemy.memory.has(actor.get_instance_id())

static func impact(actor: CampPlayer, cast: Dictionary, body: Node2D = null) -> void:
	var level: Node=SurvivorKits.world(actor)
	actor.kit["impact"]={"kind":cast["kind"],"subtype":cast["subtype"],"at":cast["at"],"life":0.45}
	cast["projectile"]=false
	cast["resolved"]=true
	if cast["kind"]=="witch":
		if body != null:
			var curse: String=cast["subtype"]
			if curse=="swap":
				var others := targets(actor,140,-1.0,body.position)
				others.erase(body)
				if not others.is_empty() and valid_move(body,others[0].position) and valid_move(others[0],body.position):
					var old: Vector2=body.position
					body.position=others[0].position
					others[0].position=old
			else: apply(body,curse,6)
			level.soundscape.broadcast("witch_cackle",body.position,4.0,1.2)
		cast["life"]=0.0
		return
	if body != null: cast["hit"]=body.get_instance_id()
	if body != null or cast["kind"]=="ration_moth":
		fire(actor,cast)
	else: cast["life"]=0.0

static func projectile(actor: CampPlayer, cast: Dictionary, delta: float) -> void:
	var level: Node = SurvivorKits.world(actor)
	var start: Vector2 = cast["at"]
	var step := minf(float(cast.get("distance_left",260.0)),104.0*delta)
	var end: Vector2 = start+cast["direction"]*step
	if not level.clear_path(start,end):
		cast["life"] = 0.0
		return
	var hit_radius:=10.0*SamplePresentation.projectile_scale(cast["kind"])
	for body in targets(actor,step+maxf(16.0,hit_radius),-1.0,start,cast.get("reflected",false)):
		if Geometry2D.get_closest_point_to_segment(body.position,start,end).distance_to(body.position)>hit_radius: continue
		if cast["kind"]=="witch" and body is CampPlayer and body.ward_remaining>0 and not cast.get("reflected",false):
			cast["direction"] = -cast["direction"]
			cast["reflected"] = true
			cast["at"] = body.position+cast["direction"]*(hit_radius+4.0)
			return
		cast["at"]=body.position
		impact(actor,cast,body)
		return
	cast["at"] = end
	cast["distance_left"]=maxf(0.0,float(cast.get("distance_left",260.0))-step)
	if cast["distance_left"]<=0: impact(actor,cast)

static func tick_enemy(enemy: CampKiller, delta: float) -> bool:
	var level: Node = enemy.get_tree().get_first_node_in_group("round_world")
	if level != null and level.paused: return true
	var timers: Dictionary = enemy.sample_state.get("timers",{})
	for key: String in timers.keys():
		timers[key] = maxf(0.0,float(timers[key])-delta)
		if timers[key] <= 0: timers.erase(key)
	if timers.has("whiteout") or timers.has("face_moth") or timers.has("lost"):
		enemy.visible_target = null
		enemy.memory.clear()
		if enemy is CampCryptid: enemy.casting = false
	if timers.has("sneezy"):
		enemy.sample_state["sneeze"] = float(enemy.sample_state.get("sneeze",0.0))-delta
		if enemy.sample_state["sneeze"] <= 0:
			enemy.sample_state["sneeze"] = 3.0
			level.loud_noise(enemy.position,300)
			level.soundscape.broadcast("sneeze",enemy.position,0.0)
	if timers.has("tethered"):
		var anchor: Vector2 = enemy.sample_state.get("anchor",enemy.position)
		if enemy.position.distance_to(anchor)>80:
			var next: Vector2 = anchor+(enemy.position-anchor).limit_length(80)
			if valid_move(enemy,next): enemy.position = next
	if timers.has("frog") or timers.has("asleep") or timers.has("tripped"):
		enemy.velocity = Vector2.ZERO
		enemy.queue_redraw()
		return true
	return false

static func motion(actor: CampPlayer) -> Array:
	var form: String = actor.kit.get("form","")
	var watched := false
	if form == "briar_revenant" and SurvivorKits.world(actor) != null:
		for observer: Node2D in actor.get_tree().get_nodes_in_group("survivors")+actor.get_tree().get_nodes_in_group("killers"):
			if observer == actor: continue
			if observer is CampKiller and (not observer.enabled or (observer.sample_state.get("timers",{}).has("whiteout") or observer.sample_state.get("timers",{}).has("asleep") or observer.sample_state.get("timers",{}).has("frog"))): continue
			if not SurvivorKits.world(actor).clear_path(observer.position,actor.position): continue
			var distance := observer.position.distance_to(actor.position)
			var facing_toward: float = observer.facing.dot(observer.position.direction_to(actor.position))
			if observer is CampPlayer:
				if observer.status != CampPlayer.Status.ALIVE or observer.hidden_spot >= 0: continue
				if CreatureBrain.in_beam(observer,actor.position,270,0.6) or (distance<90 and facing_toward>0.3): watched = true
			elif observer is CampKiller and distance<200 and facing_toward>0.5 and observer.can_sense(actor): watched = true
	var dir: Vector2 = actor.kit.get("dash_dir",Vector2.RIGHT) if actor.kit.get("dash",0.0)>0 else Vector2.RIGHT
	return [float(actor.kit.get("channel",0.0)),bool(actor.kit.get("isolated",false)),form == "briar_revenant",watched,float(actor.kit.get("dash",0.0)),dir,form == "groundskeeper"]

static func player_velocity(actor: CampPlayer, velocity: Vector2) -> Vector2:
	var state: Array = motion(actor) if actor.prediction_kit.is_empty() else actor.prediction_kit
	if state[2]: return Vector2.ZERO if state[3] else velocity.normalized()*120
	if state[6]:
		var dt := actor.get_physics_process_delta_time()
		var wanted := (state[5]*150 if state[4]>0 else velocity) as Vector2
		var heading := actor.form_motion.angle() if actor.form_motion.length()>1 else wanted.angle()
		heading += clampf(angle_difference(heading,wanted.angle()),-1.9*dt,1.9*dt)
		actor.form_motion = Vector2.from_angle(heading)*move_toward(actor.form_motion.length(),wanted.length(),100*dt)
		return actor.form_motion
	actor.form_motion = Vector2.ZERO
	if state[4]>0: return state[5]*150
	return velocity

static func valid_move(body: Node2D, at: Vector2) -> bool:
	if body is CampPlayer: return SurvivorKits.safe_point(body,at)
	if not body is CampCryptid: return false
	if body.home.has_area() and not body.home.grow(-8).has_point(at): return false
	var level: Node = body.get_tree().get_first_node_in_group("round_world")
	return CampMap.WORLD_BOUNDS.has_point(at) and level.clear_path(body.position,at) and (not CampKiller.camp_closed or not CampKiller.in_camp(at))

static func shove_enemy(enemy: CampKiller, offset: Vector2) -> void:
	var dest := enemy.position+offset
	if valid_move(enemy,dest): enemy.position = dest

static func can_interact(actor: CampPlayer) -> bool:
	return actor.kit.get("form","") not in ["werewolf","briar_revenant","groundskeeper","stoneback_ram"] and actor.kit.get("cast",{}).get("kind","") not in ["owl","teddy","lens_eater","vampire","boiler_saint"]

static func record_history(level: Node, delta: float) -> void:
	history_clock += delta
	if history_clock < 0.25: return
	history_clock = 0.0
	var alive := {}
	for body: Node2D in level.get_tree().get_nodes_in_group("survivors")+level.get_tree().get_nodes_in_group("killers"):
		var key := body.get_instance_id()
		alive[key] = true
		var rows: Array = history.get(key,[])
		rows.append(body.position)
		while rows.size()>32: rows.pop_front()
		history[key] = rows
	for key in history.keys():
		if not alive.has(key): history.erase(key)

static func valid_disguise(actor: CampPlayer) -> bool:
	var source: Object = instance_from_id(actor.kit.get("mask_source",0))
	return is_instance_valid(source) and source is CampPlayer and source != actor and source.is_in_group("survivors") and source.status == CampPlayer.Status.ALIVE

static func status(actor: CampPlayer) -> String:
	if not actor.kit.get("form","").is_empty(): return "X %s %.1fs" % [name_of(actor.kit["form"]),actor.kit["form_time"]]
	if not actor.kit.get("cast",{}).is_empty(): return "FIELD TEST: " + name_of(actor.kit["cast"]["kind"])
	var sample: String = actor.kit.get("sample","")
	return "X " + name_of(sample) + (" / " + str(actor.kit.get("subtype","" )).to_upper() if sample == "witch" else "") if not sample.is_empty() else "X FIELD TEST / NEED SAMPLE"

static func draw_player(actor: CampPlayer) -> bool:
	var form: String = actor.kit.get("form","")
	if form.is_empty(): return false
	var art := form
	if form == "mimic":
		art = "survivor_"+SurvivorRoster.art(actor.kit.get("mask","john"))
	if not form_sheets.has(art):
		form_sheets[art] = load("res://assets/sprites/"+art+".png")
	var texture: Texture2D = form_sheets[art]
	var width := 24 if form == "mimic" else 40
	var height := 32 if form == "mimic" else (48 if form == "groundskeeper" else 40)
	var cell := Vector2(24,32) if form == "mimic" else (Vector2(40,48) if form == "groundskeeper" else Vector2(64,64))
	if texture == null: return false
	var row := 2 if actor.facing.x>0.5 else (3 if actor.facing.x< -0.5 else (1 if actor.facing.y<0 else 0))
	var frame := 0 if actor.velocity.length()<1 else 1+int(actor.stride/6)%2
	if form == "groundskeeper":
		var machine := "mower_front" if actor.facing.y>0.5 else ("mower_back" if actor.facing.y< -0.5 else "mower_side")
		PixelArt.draw_in(actor,machine,Rect2(-22,-26,44,32))
	actor.draw_texture_rect_region(texture,Rect2(-width/2,-height+3,width,height),Rect2(Vector2(frame,row)*cell,cell))
	if "outboard_motor" in actor.inventory: PixelArt.draw_in(actor,"outboard_motor",Rect2(-20,-18,14,20))
	return true

static func visuals(level: Node) -> Array:
	var rows := []
	for actor: CampPlayer in level.get_tree().get_nodes_in_group("survivors"):
		var cast: Dictionary = actor.kit.get("cast",{})
		if not cast.is_empty(): rows.append([cast["kind"],cast["at"],cast["wait"],cast["life"]])
	return rows

static func draw_world(canvas: Node2D, level: Node) -> void:
	for shade: CampCryptid in canvas.get_tree().get_nodes_in_group("cryptids"):
		if shade.species=="shade" and shade.brain!=null and shade.brain.tell>0 and (level.sight==null or level.sight.can_see(shade.position)):
			canvas.draw_circle(shade.position+Vector2(-4,-17),2,Color("e8d6ff"))
			canvas.draw_circle(shade.position+Vector2(4,-17),2,Color("e8d6ff"))
	# Prints stay readable with muted/deafened audio and obey actual sight.
	for enemy: CampCryptid in canvas.get_tree().get_nodes_in_group("cryptids"):
		if enemy.species!="nobody" or enemy.brain==null: continue
		for i in range(enemy.brain.prints.size()):
			var mark: Array=enemy.brain.prints[i]
			var at: Vector2=mark[0]+Vector2(-3 if i%2==0 else 3,0)
			if level.sight!=null and not level.sight.can_see(at): continue
			canvas.draw_line(at,at+Vector2(0,-4),Color(0.65,0.78,0.8,mark[1]/4.0),2)
	for actor: CampPlayer in canvas.get_tree().get_nodes_in_group("survivors"):
		if not SurvivorKits.enabled(actor): continue
		if actor.role=="max": FortuneWheel.draw(canvas,actor)
		SamplePresentation.guide(canvas,level,actor)
		if actor.kit.get("marker_life",0.0)>0:
			PixelArt.draw_in(canvas,"kit_return",Rect2(actor.kit["marker"]-Vector2(9,9),Vector2(18,18)))
			canvas.draw_string(ThemeDB.fallback_font,actor.kit["marker"]+Vector2(-10,-15),("RETURN" if actor==level.player else actor.display_name()+" RETURN"),HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("82c9d9"))
		var impact_fx: Dictionary=actor.kit.get("impact",{})
		if not impact_fx.is_empty() and (level.sight==null or level.sight.can_see(impact_fx["at"])):
			SamplePresentation.sprite(canvas,impact_fx.kind,impact_fx.at,impact_fx.subtype,30,impact_fx.life/0.45)
		var cast: Dictionary=actor.kit.get("cast",{})
		if cast.is_empty(): continue
		var at: Vector2=cast["at"]
		if level.sight != null and not level.sight.can_see(at): continue
		var kind: String=cast["kind"]
		if not cast["fired"] and kind in SamplePresentation.SHOTS:
			SamplePresentation.sprite(canvas,kind,actor.position+cast["direction"]*12,cast["subtype"],12*SamplePresentation.projectile_scale(kind))
		elif cast.get("projectile",false):
			SamplePresentation.sprite(canvas,kind,at,cast["subtype"],18*SamplePresentation.projectile_scale(kind))
		elif kind=="slug":
			for patch: Vector2 in cast.get("patches",[]):
				if level.sight==null or level.sight.can_see(patch): SamplePresentation.sprite(canvas,kind,patch,"",32,0.65)
		elif kind in ["boiler_saint","candle_grazer","vampire","banshee","surveyor","shutter_wraith"]:
			SamplePresentation.sprite(canvas,kind,actor.position+Vector2(0,-24),cast["subtype"],24)
		else:
			SamplePresentation.sprite(canvas,kind,at,cast["subtype"],30)
