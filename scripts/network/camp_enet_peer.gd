class_name CampENetPeer
extends MultiplayerPeerExtension
## Delegate ENet unchanged except sends to peers already closing inside poll().
## SceneMultiplayer relays disconnect notifications before ENet finishes draining
## its batch of disconnect events. Other IDs can still be listed after their
## native channels have gone away. Filtering at the packet boundary also covers
## those engine control packets; disabling relay would break proximity voice.
var transport := ENetMultiplayerPeer.new()
var connected: Dictionary = {}
var target := 0
var dropped_closing_packets := 0
func _init() -> void:
	transport.peer_connected.connect(_connected_peer)
	transport.peer_disconnected.connect(_disconnected_peer)
func _connected_peer(id: int) -> void:
	connected[id]=true
	peer_connected.emit(id)
func _disconnected_peer(id: int) -> void:
	connected.erase(id)
	peer_disconnected.emit(id)
func create_server(port: int, clients: int = 32, channels: int = 0) -> Error:
	return transport.create_server(port,clients,channels)
func create_client(address: String, port: int, channels: int = 0) -> Error:
	return transport.create_client(address,port,channels)
func get_peer(id: int) -> ENetPacketPeer:
	return transport.get_peer(id)
func live(id: int) -> bool:
	if not connected.has(id): return false
	var peer: ENetPacketPeer=transport.get_peer(id)
	return peer!=null and peer.get_state()==ENetPacketPeer.STATE_CONNECTED
func _put_packet_script(buffer: PackedByteArray) -> Error:
	if target>0:
		if not live(target):
			dropped_closing_packets+=1
			return OK
		transport.set_target_peer(target)
		return transport.put_packet(buffer)
	for id: int in connected.keys():
		if id==-target: continue
		if not live(id):
			dropped_closing_packets+=1
			continue
		transport.set_target_peer(id)
		var result := transport.put_packet(buffer)
		if result!=OK: return result
	return OK
func _get_packet_script() -> PackedByteArray: return transport.get_packet()
func _get_available_packet_count() -> int: return transport.get_available_packet_count()
func _get_max_packet_size() -> int: return transport.get_max_packet_size()
func _get_packet_channel() -> int: return transport.get_packet_channel()
func _get_packet_mode() -> MultiplayerPeer.TransferMode: return transport.get_packet_mode()
func _set_transfer_channel(channel: int) -> void: transport.set_transfer_channel(channel)
func _get_transfer_channel() -> int: return transport.get_transfer_channel()
func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void: transport.set_transfer_mode(mode)
func _get_transfer_mode() -> MultiplayerPeer.TransferMode: return transport.get_transfer_mode()
func _set_target_peer(id: int) -> void: target=id
func _get_packet_peer() -> int: return transport.get_packet_peer()
func _is_server() -> bool: return transport.is_server()
func _poll() -> void:
	if transport.get_connection_status()!=MultiplayerPeer.CONNECTION_DISCONNECTED: transport.poll()
func _close() -> void:
	transport.close()
	connected.clear()
func _disconnect_peer(id: int, force: bool) -> void:
	if force: connected.erase(id)
	transport.disconnect_peer(id,force)
func _get_unique_id() -> int: return transport.get_unique_id()
func _set_refuse_new_connections(value: bool) -> void: transport.refuse_new_connections=value
func _is_refusing_new_connections() -> bool: return transport.refuse_new_connections
func _is_server_relay_supported() -> bool: return transport.is_server_relay_supported()
func _get_connection_status() -> MultiplayerPeer.ConnectionStatus: return transport.get_connection_status()
