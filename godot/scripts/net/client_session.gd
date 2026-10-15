class_name ClientSession
extends Session
## Joins a room hosted on another device. Sends input every frame and draws the host's
## snapshots a few ticks in the past, blending between them for smooth movement.

const JOIN_RETRY_MS := 250
const JOIN_TIMEOUT_MS := 5000
const HOST_TIMEOUT_MS := 4000
const INPUT_INTERVAL_MS := 15
## How far behind the newest snapshot we draw, so there is always a next one to blend to.
const RENDER_DELAY_TICKS := 3.0
const BUFFER_SIZE := 32

var _host_ip: String
var _host_port: int
var _player_name: String
var _peer := PacketPeerUDP.new()
var _in := StreamPeerBuffer.new()
var _nonce := randi() & 0x7FFFFFFF

var _started_ms: int
var _next_join_ms := 0
var _last_heard_ms := 0
var _next_input_ms := 0
var _input_seq := 0
var _input := Vector2.ZERO
var _input_kick := false

var _player_id := -1
var _in_game := false

var _buffer: Array[Snapshot] = []
var _scratch := Snapshot.new()
var _render := Snapshot.new()
var _newest_tick := -1
var _render_tick := -1.0


func _init(host_ip: String, host_port: int, player_name: String, now_ms: int) -> void:
	_host_ip = host_ip
	_host_port = host_port
	_player_name = player_name
	_started_ms = now_ms
	_peer.bind(0)
	for i in BUFFER_SIZE:
		var s := Snapshot.new()
		s.tick = -1
		_buffer.append(s)


func update(delta: float, now_ms: int) -> void:
	if not closed_reason.is_empty():
		return
	if _player_id < 0:
		if now_ms - _started_ms > JOIN_TIMEOUT_MS:
			_close("Could not reach the room")
			return
		if now_ms >= _next_join_ms:
			_next_join_ms = now_ms + JOIN_RETRY_MS
			var join := Protocol.begin(Protocol.JOIN)
			join.put_32(_nonce)
			Protocol.put_string(join, _player_name)
			NetUtil.send(_peer, join, _host_ip, _host_port)

	_read_packets(now_ms)
	if not closed_reason.is_empty():
		return

	if _player_id >= 0:
		if now_ms - _last_heard_ms > HOST_TIMEOUT_MS:
			_close("Lost connection to the room")
			return
		if now_ms >= _next_input_ms:
			_next_input_ms = now_ms + INPUT_INTERVAL_MS
			_send_input()
	_advance_render_clock(delta)


func _read_packets(now_ms: int) -> void:
	while _peer.get_available_packet_count() > 0:
		var data := _peer.get_packet()
		if _peer.get_packet_ip() != _host_ip or _peer.get_packet_port() != _host_port:
			continue
		var type := Protocol.open(data, _in)
		if type == Protocol.WELCOME:
			if _in.get_available_bytes() >= 5 and _in.get_32() == _nonce and _player_id < 0:
				_player_id = _in.get_u8()
				room_name = Protocol.get_string(_in)
				_last_heard_ms = now_ms
		elif type == Protocol.REJECT:
			if _in.get_available_bytes() >= 4 and _in.get_32() == _nonce:
				_close(Protocol.get_string(_in))
				return
		elif _player_id < 0:
			continue
		elif type == Protocol.LOBBY:
			_last_heard_ms = now_ms
			_read_lobby()
		elif type == Protocol.SNAPSHOT:
			_last_heard_ms = now_ms
			_read_snapshot()
		elif type == Protocol.BYE:
			_close("The host closed the room")
			return


func _read_lobby() -> void:
	if _in.get_available_bytes() < 4:
		return
	var now_in_game := _in.get_u8() != 0
	field_mode = _in.get_u8()
	stadium_id = Stadium.BIG if _in.get_u8() == Stadium.BIG else Stadium.SMALL
	room_name = Protocol.get_string(_in)
	var count := _in.get_u8()
	var list: Array[LobbyPlayer] = []
	for i in count:
		if _in.get_available_bytes() < 3:
			return
		var id := _in.get_u8()
		var team := _in.get_u8()
		list.append(LobbyPlayer.new(id, Protocol.get_string(_in), team))
	players = list
	if _in_game and not now_in_game:
		_clear_snapshots()
	# in_game follows LOBBY packets only, so a late snapshot cannot reopen a finished match.
	_in_game = now_in_game


func _read_snapshot() -> void:
	if not Protocol.get_snapshot(_in, _scratch):
		return
	# A new match restarts tick numbering.
	if _newest_tick >= 0 and _scratch.tick < _newest_tick - BUFFER_SIZE:
		_clear_snapshots()
	_buffer[_scratch.tick % BUFFER_SIZE].copy_from(_scratch)
	_newest_tick = maxi(_newest_tick, _scratch.tick)
	if _render_tick < 0.0:
		_render_tick = _newest_tick - RENDER_DELAY_TICKS


func _clear_snapshots() -> void:
	for s in _buffer:
		s.tick = -1
	_newest_tick = -1
	_render_tick = -1.0


func _advance_render_clock(delta: float) -> void:
	if _render_tick < 0.0:
		return
	_render_tick += delta * MatchSim.TICKS_PER_SECOND
	var drift := (_newest_tick - RENDER_DELAY_TICKS) - _render_tick
	if absf(drift) > 20.0:
		_render_tick = _newest_tick - RENDER_DELAY_TICKS
	else:
		# Gently catch up with or wait for the host's clock.
		_render_tick += drift * 0.1
	_render_tick = minf(_render_tick, _newest_tick)


func _send_input() -> void:
	var packet := Protocol.begin(Protocol.INPUT)
	packet.put_u8(_player_id)
	packet.put_32(_nonce)
	_input_seq += 1
	packet.put_32(_input_seq)
	packet.put_8(Protocol.pack_axis(_input.x))
	packet.put_8(Protocol.pack_axis(_input.y))
	packet.put_u8(1 if _input_kick else 0)
	NetUtil.send(_peer, packet, _host_ip, _host_port)


func render_state() -> Snapshot:
	if _render_tick < 0.0 or not _in_game:
		return null
	var base := floori(_render_tick)
	var before: Snapshot = null
	var after: Snapshot = null
	var t := base
	while t > base - BUFFER_SIZE / 2 and t >= 0 and before == null:
		before = _stored(t)
		t -= 1
	t = base + 1
	while t <= _newest_tick and after == null:
		after = _stored(t)
		t += 1
	if before != null and after != null:
		var alpha := (_render_tick - before.tick) / float(after.tick - before.tick)
		_render.interpolate(before, after, clampf(alpha, 0.0, 1.0))
		return _render
	var only: Snapshot = before if before != null else (after if after != null else _stored(_newest_tick))
	if only == null:
		return null
	_render.copy_from(only)
	return _render


func _stored(tick: int) -> Snapshot:
	if tick < 0:
		return null
	var s := _buffer[tick % BUFFER_SIZE]
	return s if s.tick == tick else null


func is_connected_to_room() -> bool:
	return _player_id >= 0 and closed_reason.is_empty()


func local_player_id() -> int:
	return _player_id


func in_game() -> bool:
	return _in_game


func set_local_input(x: float, y: float, kick: bool) -> void:
	_input = Vector2(x, y)
	_input_kick = kick


func request_team(team: int) -> void:
	if _player_id < 0:
		return
	var packet := Protocol.begin(Protocol.TEAM)
	packet.put_u8(_player_id)
	packet.put_32(_nonce)
	packet.put_u8(team)
	NetUtil.send(_peer, packet, _host_ip, _host_port)


func close() -> void:
	if closed_reason.is_empty() and _player_id >= 0:
		var leave := Protocol.begin(Protocol.LEAVE)
		leave.put_u8(_player_id)
		leave.put_32(_nonce)
		NetUtil.send(_peer, leave, _host_ip, _host_port)
		NetUtil.send(_peer, leave, _host_ip, _host_port)
	_close("Left the room")


func _close(reason: String) -> void:
	if closed_reason.is_empty():
		closed_reason = reason
		_peer.close()
