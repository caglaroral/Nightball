class_name LanDiscovery
extends RefCounted
## Finds rooms on the local network: broadcasts DISCOVER once a second and collects the
## ROOM_INFO replies. Call update() every frame.

const QUERY_INTERVAL_MS := 1000
const ROOM_TIMEOUT_MS := 3500

class Room:
	var name: String
	var ip: String
	var port: int
	var players: int
	var max_players: int
	var in_game: bool
	var last_seen_ms: int

var _peer := PacketPeerUDP.new()
var _rooms := {}
var _targets: PackedStringArray
var _next_query_ms := 0
var _in := StreamPeerBuffer.new()


func _init() -> void:
	_peer.set_broadcast_enabled(true)
	_peer.bind(0)
	_targets = NetUtil.discovery_targets()


func is_open() -> bool:
	return _peer.is_bound()


func update(now_ms: int) -> void:
	if now_ms >= _next_query_ms:
		_next_query_ms = now_ms + QUERY_INTERVAL_MS
		var query := Protocol.begin(Protocol.DISCOVER)
		for target in _targets:
			NetUtil.send(_peer, query, target, Protocol.DISCOVERY_PORT)

	while _peer.get_available_packet_count() > 0:
		var data := _peer.get_packet()
		var ip := _peer.get_packet_ip()
		if Protocol.open(data, _in) != Protocol.ROOM_INFO or _in.get_available_bytes() < 6:
			continue
		var room := Room.new()
		room.name = Protocol.get_string(_in)
		room.port = _in.get_u16()
		room.players = _in.get_u8()
		room.max_players = _in.get_u8()
		room.in_game = _in.get_u8() != 0
		room.ip = ip
		room.last_seen_ms = now_ms
		# A room on this computer answers on loopback and on the LAN address; keep the LAN one.
		if ip == "127.0.0.1" and _has_lan_room(room.port):
			continue
		if ip != "127.0.0.1":
			_rooms.erase("127.0.0.1:%d" % room.port)
		_rooms["%s:%d" % [ip, room.port]] = room

	for key in _rooms.keys():
		if now_ms - (_rooms[key] as Room).last_seen_ms > ROOM_TIMEOUT_MS:
			_rooms.erase(key)


func _has_lan_room(port: int) -> bool:
	for room: Room in _rooms.values():
		if room.port == port and room.ip != "127.0.0.1":
			return true
	return false


func rooms() -> Array:
	return _rooms.values()


func close() -> void:
	_peer.close()
