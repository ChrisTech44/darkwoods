extends Node
## Stable RPC endpoint. Only the listen host advances accepted gameplay.
signal changed
const RULES := "lnac-net-7"
const MAX_PLAYERS := 4
const DEFAULT_PORT := 27840
const SNAPSHOT_CHUNK := 1000
const MAX_SNAPSHOT_BYTES := 65536
var snapshot_parts := {}
var assembling_sequence := 0
var expected_parts := 0
var largest_snapshot_payload := 0
var active := false
var phase := "offline"
var status_text := "Host a camp or join a host address."
var roster: Dictionary = {}
var participants: Dictionary = {}
var actors: Dictionary = {}
var inputs: Dictionary = {}
var world: Node2D
var round_id := 0
var seed_value := 0
var mode := "camp"
var menu_open := false
var waiting := false
var loaded := {}
var deadline := 0
var pending := {}
var command_budgets := {}
var input_sequence := 0
var snapshot_sequence := 0
var last_snapshot := 0
var snapshot_clock := 0.0
var latest_snapshot_bytes := 0
var motion_targets := {}
var replicas := {}
var next_entity_id := 0
var local_name := "Camper"
var last_packet := 0

func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): leave("Connection failed. Check host address, UDP port and firewall."))
	multiplayer.server_disconnected.connect(func(): leave("Host disconnected. The camp session ended."))

func host(port: int, player_name: String, role: String) -> Error:
	if active or port<1 or port>65535: return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port,MAX_PLAYERS-1,3)
	if error!=OK:
		status_text="Cannot host on UDP port %d (%s)." % [port,error_string(error)]
		changed.emit()
		return error
	multiplayer.multiplayer_peer=peer
	active=true
	phase="lobby"
	local_name=_clean_name(player_name)
	roster={1:{"name":local_name,"role":SurvivorRoster.valid(role),"ready":false}}
	status_text="Hosting UDP %d. Share your LAN or reachable Internet/VPN address." % port
	changed.emit()
	return OK

func join(address: String, port: int, player_name: String, role: String) -> Error:
	if active or address.strip_edges().is_empty() or address.length()>253 or port<1 or port>65535: return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(),port,3)
	if error!=OK:
		status_text="Cannot join (%s)." % error_string(error)
		changed.emit()
		return error
	multiplayer.multiplayer_peer=peer
	active=true
	phase="connecting"
	local_name=_clean_name(player_name)
	get_node("/root/Session").survivor=SurvivorRoster.valid(role)
	deadline=Time.get_ticks_msec()+12000
	status_text="Connecting to %s:%d..." % [address,port]
	changed.emit()
	return OK

func _connected() -> void:
	_register.rpc_id(1,RULES,local_name,get_node("/root/Session").survivor)

func _peer_connected(id: int) -> void:
	if multiplayer.is_server(): pending[id]=Time.get_ticks_msec()+5000

@rpc("any_peer","call_remote","reliable",0)
func _register(version: String, player_name: String, role: String) -> void:
	if not active or not multiplayer.is_server(): return
	var id := multiplayer.get_remote_sender_id()
	if id==1 or not pending.has(id): return
	pending.erase(id)
	if version!=RULES or role not in SurvivorRoster.IDS:
		_reject_peer(id,"Incompatible game rules or survivor. Update both copies.")
		return
	if phase!="lobby" or roster.size()>=MAX_PLAYERS:
		_reject_peer(id,"Camp full or already running. Join in the lobby before the next night.")
		return
	roster[id]={"name":_clean_name(player_name),"role":role,"ready":false}
	_broadcast_roster()

func _reject_peer(id: int, reason: String) -> void:
	_rejected.rpc_id(id,reason)
	await get_tree().create_timer(0.2).timeout
	if active and multiplayer.is_server() and id in multiplayer.get_peers():
		multiplayer.multiplayer_peer.disconnect_peer(id)

@rpc("authority","call_remote","reliable",0)
func _rejected(reason: String) -> void:
	leave(reason)

func choose(role: String, ready: bool) -> void:
	if not active or phase!="lobby" or role not in SurvivorRoster.IDS: return
	if multiplayer.is_server(): _accept_choice(1,role,ready)
	else: _choice.rpc_id(1,role,ready)

@rpc("any_peer","call_remote","reliable",0)
func _choice(role: String, ready: bool) -> void:
	if active and multiplayer.is_server(): _accept_choice(multiplayer.get_remote_sender_id(),role,ready)

func _accept_choice(id: int, role: String, ready: bool) -> void:
	if phase!="lobby" or not roster.has(id) or role not in SurvivorRoster.IDS: return
	var different: bool=roster[id]["role"]!=role
	roster[id]["role"]=role
	roster[id]["ready"]=false if different else ready
	_broadcast_roster()

func _broadcast_roster() -> void:
	_lobby.rpc(roster,mode,seed_value)
	changed.emit()

@rpc("authority","call_remote","reliable",0)
func _lobby(peers: Dictionary, chosen_mode: String, value: int) -> void:
	if not active: return
	roster=peers
	mode=chosen_mode
	seed_value=value
	phase="lobby"
	status_text="Connected. Choose your survivor and mark Ready."
	changed.emit()

func configure_lobby(chosen_mode: String, value: int) -> void:
	if not active or not multiplayer.is_server() or phase!="lobby" or chosen_mode not in ["camp","woods"]: return
	value=clampi(value,0,2147483646)
	if mode==chosen_mode and seed_value==value: return
	mode=chosen_mode
	seed_value=value
	for entry in roster.values(): entry["ready"]=false
	_broadcast_roster()

func can_start() -> bool:
	if not active or phase!="lobby" or not multiplayer.is_server() or roster.is_empty(): return false
	for entry in roster.values():
		if not entry["ready"]: return false
	return true

func start_round(chosen_mode: String, chosen_seed: int) -> bool:
	if not can_start() or chosen_mode not in ["camp","woods"]: return false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var value := chosen_seed if chosen_seed>0 else rng.randi_range(1,2147483646)
	_begin.rpc(chosen_mode,clampi(value,1,2147483646),roster,round_id+1)
	return true

@rpc("authority","call_local","reliable",0)
func _begin(chosen_mode: String, value: int, peers: Dictionary, generation: int) -> void:
	if not active: return
	phase="loading"
	round_id=generation
	mode=chosen_mode
	seed_value=value
	participants=peers.duplicate(true)
	actors.clear()
	inputs.clear()
	loaded.clear()
	replicas.clear()
	motion_targets.clear()
	command_budgets.clear()
	world=null
	input_sequence=0
	snapshot_sequence=0
	last_snapshot=0
	assembling_sequence=0
	snapshot_parts.clear()
	expected_parts=0
	largest_snapshot_payload=0
	next_entity_id=0
	menu_open=false
	waiting=true
	deadline=Time.get_ticks_msec()+20000
	last_packet=Time.get_ticks_msec()
	var session: Node=get_node("/root/Session")
	session.mode=mode
	session.next_seed=seed_value
	session.survivor=participants[multiplayer.get_unique_id()]["role"]
	session.load_game()
	changed.emit()

func attach_world(level: Node2D) -> void:
	if not active: return
	world=level
	var local_id := multiplayer.get_unique_id()
	var ids: Array=participants.keys()
	ids.sort()
	for index in range(ids.size()):
		var id: int=ids[index]
		var actor: CampPlayer=level.player if id==local_id else level.PLAYER_SCENE.instantiate()
		if id!=local_id:
			actor.config=level.config
			actor.role=participants[id]["role"]
			actor.expedition=level.plan.expedition
			level.world_objects.add_child(actor)
		actor.position=Vector2(96+index*16,384)
		actor.peer_name=participants[id]["name"]
		actor.local_input=false
		actor.net_controlled=true
		actor.controls_enabled=false
		actors[id]=actor
		if id!=local_id:
			actor.noise_emitted.connect(func(origin: Vector2):
				if multiplayer.is_server(): level._on_noise(origin))
			actor.sprint_noise_emitted.connect(func(origin: Vector2):
				if multiplayer.is_server():
					for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
						enemy.hear_stimulus(origin,enemy.config.hearing_radius*actor.sprint_hearing*level.night_clock.hearing_scale()))
		if not multiplayer.is_server(): actor.set_physics_process(false)
	for enemy: CampKiller in get_tree().get_nodes_in_group("killers"):
		enemy.enabled=false
		if not multiplayer.is_server(): enemy.set_physics_process(false)
	if not multiplayer.is_server():
		for site in level.camp_map.sites: site.set_physics_process(false)
		level.night_clock.set_physics_process(false)
		level.props.set_physics_process(false)
	if multiplayer.is_server(): _accept_loaded(local_id,round_id)
	else: _world_loaded.rpc_id(1,round_id)

@rpc("any_peer","call_remote","reliable",0)
func _world_loaded(generation: int) -> void:
	if active and multiplayer.is_server(): _accept_loaded(multiplayer.get_remote_sender_id(),generation)

func _accept_loaded(id: int, generation: int) -> void:
	if phase!="loading" or generation!=round_id or not participants.has(id): return
	loaded[id]=true
	if loaded.size()==participants.size(): _go.rpc(round_id)

@rpc("authority","call_local","reliable",0)
func _go(generation: int) -> void:
	if not active or generation!=round_id or world==null: return
	phase="playing"
	waiting=false
	for actor: CampPlayer in actors.values(): actor.controls_enabled=true
	if multiplayer.is_server():
		for enemy: CampKiller in get_tree().get_nodes_in_group("killers"): enemy.enabled=true
	status_text="Night %d / %d survivors" % [seed_value,actors.size()]
	changed.emit()

func _physics_process(delta: float) -> void:
	if not active: return
	var now := Time.get_ticks_msec()
	if multiplayer.is_server():
		for id: int in pending.keys():
			if now>pending[id]:
				pending.erase(id)
				if id in multiplayer.get_peers(): multiplayer.multiplayer_peer.disconnect_peer(id)
	if phase in ["connecting","loading"] and now>deadline:
		leave("Connection/loading timed out. Check host, UDP port and firewall.")
		return
	if world==null or waiting or phase not in ["playing","results"]: return
	if phase=="playing":
		var direction := Vector2.ZERO if menu_open else Input.get_vector("move_left","move_right","move_up","move_down")
		var sprint := not menu_open and Input.is_action_pressed("sprint")
		var hold := not menu_open and Input.is_action_pressed("interact")
		input_sequence+=1
		if multiplayer.is_server(): _accept_input(1,round_id,input_sequence,direction,sprint,hold)
		else: _input_packet.rpc_id(1,round_id,input_sequence,direction,sprint,hold)
	if multiplayer.is_server():
		for id: int in actors:
			var intent: Dictionary=inputs.get(id,{})
			var fresh: bool=now-intent.get("time",0)<400
			actors[id].network_direction=intent.get("direction",Vector2.ZERO) if fresh else Vector2.ZERO
			actors[id].network_sprint=intent.get("sprint",false) if fresh else false
			if not fresh and inputs.has(id): inputs[id]["hold"]=false
		snapshot_clock-=delta
		if snapshot_clock<=0:
			snapshot_clock=0.05
			snapshot_sequence+=1
			var bytes: PackedByteArray=var_to_bytes(WorldSync.capture(self)).compress(FileAccess.COMPRESSION_DEFLATE)
			latest_snapshot_bytes=bytes.size()
			if bytes.size()>MAX_SNAPSHOT_BYTES:
				leave("Network state limit exceeded. Start a new camp session.")
				return
			var count := ceili(float(bytes.size())/SNAPSHOT_CHUNK)
			for part in range(count):
				var piece := bytes.slice(part*SNAPSHOT_CHUNK,(part+1)*SNAPSHOT_CHUNK)
				largest_snapshot_payload=maxi(largest_snapshot_payload,piece.size())
				_snapshot_piece.rpc(round_id,snapshot_sequence,part,count,piece)
	elif now-last_packet>10000:
		leave("Host stopped responding. The camp session ended.")

@rpc("any_peer","call_remote","unreliable_ordered",2)
func _input_packet(generation: int, sequence: int, direction: Vector2, sprint: bool, hold: bool) -> void:
	if active and multiplayer.is_server(): _accept_input(multiplayer.get_remote_sender_id(),generation,sequence,direction,sprint,hold)

func _accept_input(id: int, generation: int, sequence: int, direction: Vector2, sprint: bool, hold: bool) -> void:
	if phase!="playing" or generation!=round_id or not actors.has(id) or not direction.is_finite(): return
	if sequence<=inputs.get(id,{}).get("seq",-1): return
	inputs[id]={"seq":sequence,"direction":direction.limit_length(1),"sprint":sprint,"hold":hold,"time":Time.get_ticks_msec()}

func holding(id: int) -> bool:
	return inputs.get(id,{}).get("hold",false)

func action(code: String, slot: int = -1) -> void:
	if not active or phase!="playing" or menu_open: return
	if multiplayer.is_server(): _accept_action(1,round_id,code,slot)
	else: _action.rpc_id(1,round_id,code,slot)

@rpc("any_peer","call_remote","reliable",0)
func _action(generation: int, code: String, slot: int) -> void:
	if active and multiplayer.is_server(): _accept_action(multiplayer.get_remote_sender_id(),generation,code,slot)

func _accept_action(id: int, generation: int, code: String, slot: int) -> void:
	if code.length()>24: return
	if generation!=round_id or phase!="playing" or world==null or world.finished or not actors.has(id): return
	var now := Time.get_ticks_msec()
	var budget: Dictionary=command_budgets.get(id,{"since":now,"count":0})
	if now-budget["since"]>1000: budget={"since":now,"count":0}
	budget["count"]+=1
	command_budgets[id]=budget
	if budget["count"]>15: return
	var actor: CampPlayer=actors[id]
	if actor.status==CampPlayer.Status.DOWNED and code=="interact":
		world.call_for_help(actor)
		return
	if actor.status!=CampPlayer.Status.ALIVE: return
	match code:
		"flash": world.use_flash(actor)
		"interact": world.try_interact(actor)
		"select":
			if slot>=0 and slot<6: actor.selected_slot=slot
		"use": world.use_supply(actor,actor.held_item())
		"drop": world.drop_held(actor)
		"flare": world.use_supply(actor,"flare")
		"battery": world.use_supply(actor,"battery_pack")
		"food": world.use_supply(actor,"rations")
		"pin": world.place_pin(actor,id,actor.peer_name)
		"light":
			if not actor.expedition or actor.flashlight_charge>0: actor.flashlight_on=not actor.flashlight_on

@rpc("authority","call_remote","unreliable_ordered",1)
func _snapshot_piece(generation: int, sequence: int, part: int, count: int, bytes: PackedByteArray) -> void:
	if not active or multiplayer.is_server() or generation!=round_id or sequence<=last_snapshot or world==null: return
	if count<1 or count>66 or part<0 or part>=count or bytes.is_empty() or bytes.size()>SNAPSHOT_CHUNK: return
	if sequence<assembling_sequence: return
	if sequence>assembling_sequence:
		assembling_sequence=sequence
		expected_parts=count
		snapshot_parts.clear()
	if count!=expected_parts or snapshot_parts.has(part): return
	snapshot_parts[part]=bytes
	if snapshot_parts.size()!=count: return
	var complete := PackedByteArray()
	for index in range(count): complete.append_array(snapshot_parts[index])
	snapshot_parts.clear()
	if complete.size()>MAX_SNAPSHOT_BYTES: return
	var unpacked := complete.decompress_dynamic(1048576,FileAccess.COMPRESSION_DEFLATE)
	if unpacked.is_empty(): return
	var state: Variant=bytes_to_var(unpacked)
	if not state is Dictionary: return
	last_snapshot=sequence
	last_packet=Time.get_ticks_msec()
	latest_snapshot_bytes=complete.size()
	WorldSync.apply(self,state)

func _process(delta: float) -> void:
	if not active or multiplayer.is_server(): return
	for node: Node2D in motion_targets.keys():
		if not is_instance_valid(node):
			motion_targets.erase(node)
			continue
		var target: Vector2=motion_targets[node]
		node.position=target if node.position.distance_to(target)>80 else node.position.lerp(target,1-exp(-delta*22))

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		menu_open=not menu_open
		world.hud.show_pause(menu_open)
		get_viewport().set_input_as_handled()
		return
	if menu_open or event.is_echo(): return
	if event.is_action_pressed("inventory"):
		world.hud.inventory_label.visible=not world.hud.inventory_label.visible
		world.hud.chart.visible=world.hud.inventory_label.visible
		return
	if event is InputEventKey and event.pressed:
		var row := [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6]
		var pad := [KEY_KP_1,KEY_KP_2,KEY_KP_3,KEY_KP_4,KEY_KP_5,KEY_KP_6]
		var slot := row.find(event.physical_keycode)
		if slot<0: slot=pad.find(event.physical_keycode)
		if slot>=0: action("select",slot)
		if event.physical_keycode==KEY_V: action("use")
		if event.physical_keycode==KEY_G: action("drop")
	var bindings := {"interact":"interact","flashlight":"light","use_flare":"flare","recharge":"battery","eat":"food","map_pin":"pin","flash_burst":"flash"}
	for binding in bindings:
		if event.is_action_pressed(binding): action(bindings[binding])

func return_lobby(retry: bool) -> void:
	if active and multiplayer.is_server(): _return_lobby.rpc(seed_value if retry else 0)

@rpc("authority","call_local","reliable",0)
func _return_lobby(retry_seed: int) -> void:
	if not active: return
	world=null
	actors.clear()
	inputs.clear()
	motion_targets.clear()
	replicas.clear()
	snapshot_parts.clear()
	participants.clear()
	for entry in roster.values(): entry["ready"]=false
	seed_value=retry_seed
	phase="lobby"
	waiting=false
	menu_open=false
	get_tree().change_scene_to_file("res://scenes/ui/network_lobby.tscn")
	changed.emit()

func _peer_disconnected(id: int) -> void:
	pending.erase(id)
	if not active or not multiplayer.is_server(): return
	roster.erase(id)
	participants.erase(id)
	loaded.erase(id)
	inputs.erase(id)
	if actors.has(id):
		var actor: CampPlayer=actors[id]
		# Return objective objects so a departing player cannot strand the round.
		if world!=null:
			_drop_objectives(actor)
			world.van.passengers.erase(actor)
		actors.erase(id)
		actor.queue_free()
	if phase=="lobby": _broadcast_roster()
	elif phase=="loading" and world!=null and loaded.size()>=participants.size(): _go.rpc(round_id)

func _drop_objectives(actor: CampPlayer) -> void:
	if world==null: return
	world.drop_all_items(actor)

func leave(reason: String = "Left the camp.") -> void:
	if active: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	active=false
	phase="offline"
	world=null
	roster.clear()
	participants.clear()
	actors.clear()
	inputs.clear()
	pending.clear()
	motion_targets.clear()
	replicas.clear()
	menu_open=false
	waiting=false
	snapshot_parts.clear()
	assembling_sequence=0
	status_text=reason
	get_node("/root/Session").notice=reason
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	changed.emit()

func _clean_name(value: String) -> String:
	var result := value.strip_edges().replace("\n"," ").replace("\r"," ").left(20)
	return "Camper" if result.is_empty() else result
