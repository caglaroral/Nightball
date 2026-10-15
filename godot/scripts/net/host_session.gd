class_name HostSession
extends Session
## Runs the room: answers discovery, accepts players and simulates the match at 60 Hz.

const SCORE_LIMIT := 3
const TIME_LIMIT_SECONDS := 3 * 60
const HOST_ID := 0
const STEP := 1.0 / MatchSim.TICKS_PER_SECOND
const CLIENT_TIMEOUT_MS := 5000
const LOBBY_INTERVAL_MS := 250

class Remote:
	var id: int
	var ip: String
	var port: int
	var nonce: int
	var last_heard_ms: int
	var last_input_seq := -1

var _game := PacketPeerUDP.new()
var _discovery := PacketPeerUDP.new()
var _remotes: Array[Remote] = []
var _in := StreamPeerBuffer.new()

var _match: MatchSim
var _previous := Snapshot.new()
var _current := Snapshot.new()
var _render := Snapshot.new()
var _accumulator := 0.0
var _input := Vector2.ZERO
var _input_kick := false

var _next_id := 1
var _lobby_dirty := true
var _next_lobby_ms := 0


func _init(host_name: String, name_of_room: String) -> void:
	room_name = name_of_room
	if _game.bind(Protocol.GAME_PORT) != OK:
		# Port taken, e.g. a second room on the same computer; discovery reports the real port.
		_game.bind(0)
	if _discovery.bind(Protocol.DISCOVERY_PORT) != OK:
		# Rooms can still be joined by address.
		_discovery.close()
	players.append(LobbyPlayer.new(HOST_ID, host_name, Team.RED))


func is_open() -> bool:
	return _game.is_bound()


## True when other devices can find this room automatically.
func is_discoverable() -> bool:
	return _discovery.is_bound()


func port() -> int:
	return _game.get_local_port()


func update(delta: float, now_ms: int) -> void:
	if not closed_reason.is_empty():
		return
	_answer_discovery()
	_read_packets(now_ms)
	_drop_silent_clients(now_ms)

	if _match != null:
		_accumulator += minf(delta, 0.25)
		while _accumulator >= STEP:
			_accumulator -= STEP
			_match.set_input(HOST_ID, _input.x, _input.y, _input_kick)
			_match.tick()
			_previous.copy_from(_current)
			_match.write_snapshot(_current)
			_broadcast_snapshot()
		if _match.is_finished():
			stop_game()

	if _match == null:
		var next := resolve_stadium(field_mode, count_team(Team.RED), count_team(Team.BLUE))
		if next != stadium_id:
			stadium_id = next
			_lobby_dirty = true

	if _lobby_dirty or now_ms >= _next_lobby_ms:
		_lobby_dirty = false
		_next_lobby_ms = now_ms + LOBBY_INTERVAL_MS
		_broadcast_lobby()


func _answer_discovery() -> void:
	if not _discovery.is_bound():
		return
	while _discovery.get_available_packet_count() > 0:
		var data := _discovery.get_packet()
		var ip := _discovery.get_packet_ip()
		var from_port := _discovery.get_packet_port()
		if Protocol.open(data, _in) != Protocol.DISCOVER:
			continue
		var reply := Protocol.begin(Protocol.ROOM_INFO)
		Protocol.put_string(reply, room_name)
		reply.put_u16(port())
		reply.put_u8(players.size())
		reply.put_u8(MAX_PLAYERS)
		reply.put_u8(1 if _match != null else 0)
		NetUtil.send(_discovery, reply, ip, from_port)


func _read_packets(now_ms: int) -> void:
	while _game.get_available_packet_count() > 0:
		var data := _game.get_packet()
		var ip := _game.get_packet_ip()
		var from_port := _game.get_packet_port()
		var type := Protocol.open(data, _in)
		if type == Protocol.JOIN:
			if _in.get_available_bytes() >= 5:
				var nonce := _in.get_32()
				_handle_join(ip, from_port, nonce, Protocol.get_string(_in), now_ms)
			continue
		if type != Protocol.INPUT and type != Protocol.TEAM and type != Protocol.LEAVE:
			continue
		if _in.get_available_bytes() < 5:
			continue
		var remote := _remote(_in.get_u8(), _in.get_32(), ip, from_port)
		if remote == null:
			continue
		remote.last_heard_ms = now_ms
		if type == Protocol.INPUT and _in.get_available_bytes() >= 7:
			var seq := _in.get_32()
			var x := Protocol.unpack_axis(_in.get_8())
			var y := Protocol.unpack_axis(_in.get_8())
			var kick := _in.get_u8() != 0
			if seq > remote.last_input_seq:
				remote.last_input_seq = seq
				if _match != null:
					_match.set_input(remote.id, x, y, kick)
		elif type == Protocol.TEAM and _in.get_available_bytes() >= 1:
			_set_team(remote.id, _in.get_u8())
		elif type == Protocol.LEAVE:
			_remove_player(remote.id)


func _handle_join(ip: String, from_port: int, nonce: int, player_name: String, now_ms: int) -> void:
	var existing := _remote_at(ip, from_port)
	if existing != null and existing.nonce == nonce:
		_send_welcome(existing)
		return
	if existing != null:
		_remove_player(existing.id)
	if players.size() >= MAX_PLAYERS:
		var reject := Protocol.begin(Protocol.REJECT)
		reject.put_32(nonce)
		Protocol.put_string(reject, "Room is full")
		NetUtil.send(_game, reject, ip, from_port)
		return
	var id := _allocate_id()
	var team := Team.SPECTATOR if _match != null else _smaller_team()
	var clean := player_name.strip_edges()
	players.append(LobbyPlayer.new(id, clean if not clean.is_empty() else "Player %d" % id, team))
	var remote := Remote.new()
	remote.id = id
	remote.ip = ip
	remote.port = from_port
	remote.nonce = nonce
	remote.last_heard_ms = now_ms
	_remotes.append(remote)
	_send_welcome(remote)
	_lobby_dirty = true


func _send_welcome(remote: Remote) -> void:
	var welcome := Protocol.begin(Protocol.WELCOME)
	welcome.put_32(remote.nonce)
	welcome.put_u8(remote.id)
	Protocol.put_string(welcome, room_name)
	NetUtil.send(_game, welcome, remote.ip, remote.port)


func _allocate_id() -> int:
	while true:
		var id := _next_id
		_next_id = 1 if _next_id >= 250 else _next_id + 1
		if find_player(id) == null:
			return id
	return -1


func _smaller_team() -> int:
	var red := count_team(Team.RED)
	var blue := count_team(Team.BLUE)
	if mini(red, blue) >= MAX_PER_TEAM:
		return Team.SPECTATOR
	return Team.RED if red <= blue else Team.BLUE


func _drop_silent_clients(now_ms: int) -> void:
	for remote in _remotes.duplicate():
		if now_ms - remote.last_heard_ms > CLIENT_TIMEOUT_MS:
			_remove_player(remote.id)


func _remove_player(id: int) -> void:
	for remote in _remotes.duplicate():
		if remote.id == id:
			_remotes.erase(remote)
	var p := find_player(id)
	if p != null:
		players.erase(p)
	if _match != null:
		_match.remove_player(id)
	_lobby_dirty = true


func _set_team(id: int, team: int) -> void:
	var p := find_player(id)
	if p == null or _match != null or p.team == team:
		return
	if team != Team.SPECTATOR and count_team(team) >= MAX_PER_TEAM:
		return
	p.team = team
	_lobby_dirty = true


func _broadcast_lobby() -> void:
	var packet := Protocol.begin(Protocol.LOBBY)
	packet.put_u8(1 if _match != null else 0)
	packet.put_u8(field_mode)
	packet.put_u8(stadium_id)
	Protocol.put_string(packet, room_name)
	packet.put_u8(players.size())
	for p in players:
		packet.put_u8(p.id)
		packet.put_u8(p.team)
		Protocol.put_string(packet, p.name)
	for remote in _remotes:
		NetUtil.send(_game, packet, remote.ip, remote.port)


func _broadcast_snapshot() -> void:
	var packet := Protocol.begin(Protocol.SNAPSHOT)
	Protocol.put_snapshot(packet, _current)
	for remote in _remotes:
		NetUtil.send(_game, packet, remote.ip, remote.port)


func _remote(id: int, nonce: int, ip: String, from_port: int) -> Remote:
	for r in _remotes:
		if r.id == id and r.nonce == nonce and r.ip == ip and r.port == from_port:
			return r
	return null


func _remote_at(ip: String, from_port: int) -> Remote:
	for r in _remotes:
		if r.ip == ip and r.port == from_port:
			return r
	return null


func is_host() -> bool:
	return true


func local_player_id() -> int:
	return HOST_ID


func in_game() -> bool:
	return _match != null


func set_local_input(x: float, y: float, kick: bool) -> void:
	_input = Vector2(x, y)
	_input_kick = kick


func request_team(team: int) -> void:
	_set_team(HOST_ID, team)


func start_game() -> void:
	if _match != null or count_team(Team.RED) + count_team(Team.BLUE) == 0:
		return
	stadium_id = resolve_stadium(field_mode, count_team(Team.RED), count_team(Team.BLUE))
	_match = MatchSim.new(Stadium.by_id(stadium_id), SCORE_LIMIT, TIME_LIMIT_SECONDS)
	for p in players:
		_match.add_player(p.id, p.team)
	_match.reset_positions()
	_match.write_snapshot(_current)
	_previous.copy_from(_current)
	_accumulator = 0.0
	_lobby_dirty = true


func stop_game() -> void:
	_match = null
	_lobby_dirty = true


func set_field_mode(mode: int) -> void:
	if _match == null and mode != field_mode:
		field_mode = clampi(mode, FIELD_AUTO, FIELD_BIG)
		_lobby_dirty = true


## Auto picks the big field once a team has three or more players.
static func resolve_stadium(mode: int, red: int, blue: int) -> int:
	if mode == FIELD_SMALL:
		return Stadium.SMALL
	if mode == FIELD_BIG:
		return Stadium.BIG
	return Stadium.BIG if maxi(red, blue) >= 3 else Stadium.SMALL


func render_state() -> Snapshot:
	if _match == null:
		return null
	_render.interpolate(_previous, _current, _accumulator / STEP)
	return _render


func close() -> void:
	if not closed_reason.is_empty():
		return
	closed_reason = "Room closed"
	var bye := Protocol.begin(Protocol.BYE)
	for i in 3:
		for remote in _remotes:
			NetUtil.send(_game, bye, remote.ip, remote.port)
	_game.close()
	_discovery.close()
