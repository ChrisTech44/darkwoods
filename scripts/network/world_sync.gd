class_name WorldSync
extends RefCounted
## Host snapshots contain plain data only. Clients render, never simulate outcomes.
const PLAYER_FIELDS := ["notice","notice_time","velocity","status","stamina","exhausted","sprinting","flashlight_on","flashlight_charge","bleedout","invulnerability","hex_remaining","ward_remaining","selected_slot","facing","stride","wounded","flash_time","flash_cooldown","self_recovery_used","help_cooldown","hidden_spot","breath","vault_time","motor_assisted","assisting_motor"]
const ENEMY_FIELDS := ["enabled","velocity","facing","stride","state","stun_remaining"]
const CRYPTID_FIELDS := ["power_tell","power_aim","dash_remaining","casting","cast_remaining","cast_aim","hunt_clock"]

static func capture(net: Node) -> Dictionary:
	var level: Node2D=net.world
	var players := {}
	for id: int in net.actors:
		var actor: CampPlayer=net.actors[id]
		var row := {"position":actor.position,"inventory":actor.inventory,"supplies":actor.supplies,"belt":actor.belt,"blood":actor.blood}
		for field in PLAYER_FIELDS: row[field]=actor.get(field)
		players[id]=row
	var enemies := []
	for enemy: CampKiller in level.get_tree().get_nodes_in_group("killers"):
		var row := {"position":enemy.position}
		row["target_peer"]=0
		for id: int in net.actors:
			if enemy.visible_target==net.actors[id]: row["target_peer"]=id
		for field in ENEMY_FIELDS: row[field]=enemy.get(field)
		if enemy is CampCryptid:
			for field in CRYPTID_FIELDS: row[field]=enemy.get(field)
		enemies.append(row)
	var items := []
	for pickup: CampPickup in level.pickups:
		items.append([pickup.kind,pickup.position,pickup.available,pickup.locked])
	var sites := []
	for site: ForestSite in level.camp_map.sites:
		var used := []
		for action in site.actions: used.append(action["used"])
		sites.append([used,site.cooldown])
	var entities := {}
	var nodes: Array=level.get_tree().get_nodes_in_group("hazards")
	nodes.append_array(level.get_tree().get_nodes_in_group("flares"))
	for entity: Node2D in nodes:
		if entity.is_queued_for_deletion(): continue
		if not entity.has_meta("network_id"):
			net.next_entity_id+=1
			entity.set_meta("network_id",net.next_entity_id)
		var row := {"position":entity.position}
		if entity is HexBolt:
			row.merge({"kind":"bolt","direction":entity.direction,"remaining":entity.remaining})
		elif entity is LandmarkHazard:
			row.merge({"kind":"patch","thorns":entity.thorns,"remaining":entity.remaining})
		elif entity is NoiseLure:
			row.merge({"kind":"tin","pulses":entity.pulses,"elapsed":entity.elapsed})
		else:
			row.merge({"kind":"flare","remaining":entity.remaining,"time":entity.time})
		entities[entity.get_meta("network_id")]=row
	return {"players":players,"enemies":enemies,"items":items,"sites":sites,"entities":entities,
		"van":{"installed":level.van.installed,"progress":level.van.start_progress,"running":level.van.running,"remaining":level.van.remaining},
		"escapes":level.escapes.snapshot(),"rescue":level.rescue.snapshot(),"pins":level.pins,"clues":level.clues,"help":level.help_pings,"self_recovery":level.self_recovery_progress,"revive_duration":level.revive_duration,"night":level.night_clock.snapshot(),"props":level.props.snapshot(),"revive":level.revive_progress,"finished":level.finished,"won":level.won,"escape_route":level.escape_route,"message":level.message,"message_time":level.message_time}

static func apply(net: Node, state: Dictionary) -> void:
	var level: Node2D=net.world
	var players: Dictionary=state["players"]
	for id: int in net.actors.keys():
		if not players.has(id):
			var old: CampPlayer=net.actors[id]
			net.motion_targets.erase(old)
			level.van.passengers.erase(old)
			net.actors.erase(id)
			old.queue_free()
	for id: int in players:
		if not net.actors.has(id): continue # Mid-round joining is disallowed.
		var actor: CampPlayer=net.actors[id]
		var row: Dictionary=players[id]
		net.motion_targets[actor]=row["position"]
		for field in PLAYER_FIELDS: actor.set(field,row[field])
		actor.inventory.assign(row["inventory"])
		actor.belt.assign(row["belt"])
		actor.blood.assign(row["blood"])
		actor.supplies=row["supplies"]
		actor.queue_redraw()
	var enemies: Array=level.get_tree().get_nodes_in_group("killers")
	for index in range(mini(enemies.size(),state["enemies"].size())):
		var enemy: CampKiller=enemies[index]
		var row: Dictionary=state["enemies"][index]
		net.motion_targets[enemy]=row["position"]
		var previous := enemy.state
		for field in ENEMY_FIELDS: enemy.set(field,row[field])
		if enemy is CampCryptid:
			for field in CRYPTID_FIELDS: enemy.set(field,row[field])
		enemy.visible_target=net.actors.get(row["target_peer"])
		if enemy.state!=previous: enemy.state_changed.emit(enemy.state)
		enemy.queue_redraw()
	for index in range(state["items"].size()):
		var row: Array=state["items"][index]
		if index>=level.pickups.size():
			var pickup: CampPickup=load("res://scenes/items/pickup.tscn").instantiate()
			pickup.kind=row[0]
			pickup.position=row[1]
			level.pickups.append(pickup)
			level.add_child(pickup)
		var pickup: CampPickup=level.pickups[index]
		pickup.kind=row[0]
		pickup.z_index=1 if index>=level.plan.loot.size() else 0
		pickup.position=row[1]
		pickup.queue_redraw()
		pickup.available=row[2]
		pickup.visible=row[2]
		pickup.locked=row[3]
	for index in range(level.camp_map.sites.size()):
		var site: ForestSite=level.camp_map.sites[index]
		for j in range(site.actions.size()): site.actions[j]["used"]=state["sites"][index][0][j]
		site.cooldown=state["sites"][index][1]
		site.queue_redraw()
	for id: int in net.replicas.keys():
		if not state["entities"].has(id):
			var old: Node2D=net.replicas[id]
			net.motion_targets.erase(old)
			net.replicas.erase(id)
			old.queue_free()
	for id: int in state["entities"]:
		var row: Dictionary=state["entities"][id]
		var entity: Node2D
		if net.replicas.has(id): entity=net.replicas[id]
		else:
			match row["kind"]:
				"bolt": entity=HexBolt.new()
				"patch": entity=LandmarkHazard.new()
				"tin": entity=NoiseLure.new()
				_: entity=load("res://scripts/items/flare.gd").new()
			entity.position=row["position"]
			level.world_objects.add_child(entity)
			entity.set_physics_process(false)
			net.replicas[id]=entity
		net.motion_targets[entity]=row["position"]
		for field in row:
			if field not in ["kind","position"]: entity.set(field,row[field])
		entity.queue_redraw()
	var van: Dictionary=state["van"]
	level.van.installed.assign(van["installed"])
	level.van.start_progress=van["progress"]
	level.van.running=van["running"]
	level.van.remaining=van["remaining"]
	level.van.passengers.clear()
	for actor: CampPlayer in net.actors.values():
		if actor.status==CampPlayer.Status.BOARDED: level.van.passengers.append(actor)
	level.van.queue_redraw()
	level.pins.assign(state["pins"])
	level.clues=state["clues"]
	level.help_pings.assign(state["help"])
	level.self_recovery_progress=state["self_recovery"]
	level.revive_duration=state["revive_duration"]
	level.night_clock.restore(state["night"])
	level.rescue.restore(state["rescue"])
	level.escapes.restore(state["escapes"])
	level.props.restore(state["props"])
	level.revive_progress=state["revive"]
	level.message=state["message"]
	level.message_time=state["message_time"]
	level.escape_route=state["escape_route"]
	if state["finished"] and not level.finished:
		level.finished=true
		level.won=state["won"]
		net.phase="results"
		level.soundscape.stop_round()
		level.hud.show_result(level.won,level.escape_route + "\nYou: %s.\nNight %d" % [CampPlayer.Status.keys()[level.player.status].to_lower().replace("_"," "),net.seed_value])
