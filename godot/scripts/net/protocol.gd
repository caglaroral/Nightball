class_name Protocol
## UDP message format: MAGIC (u16), VERSION (u8), type (u8), then the body. Big-endian.
##
## Reliability model: the host repeats the lobby state several times per second and sends a
## full snapshot every tick, and clients send their full input every frame, so a lost packet is
## simply replaced by the next one. Only JOIN is retried until answered.

const DISCOVERY_PORT := 47777
const GAME_PORT := 47778
const MAX_NAME_BYTES := 24

const MAGIC := 0x4E42
const VERSION := 2

# Discovery
const DISCOVER := 1
const ROOM_INFO := 2
# Client -> host
const JOIN := 3
const INPUT := 6
const TEAM := 7
const LEAVE := 8
# Host -> client
const WELCOME := 4
const REJECT := 5
const LOBBY := 9
const SNAPSHOT := 10
const BYE := 11


static func begin(type: int) -> StreamPeerBuffer:
	var b := StreamPeerBuffer.new()
	b.big_endian = true
	b.put_u16(MAGIC)
	b.put_u8(VERSION)
	b.put_u8(type)
	return b


## Wraps a received packet. Returns the message type, or -1 if it is not ours.
static func open(data: PackedByteArray, out: StreamPeerBuffer) -> int:
	out.big_endian = true
	out.data_array = data
	out.seek(0)
	if data.size() < 4 or out.get_u16() != MAGIC or out.get_u8() != VERSION:
		return -1
	return out.get_u8()


static func put_string(b: StreamPeerBuffer, value: String) -> void:
	var bytes := value.to_utf8_buffer()
	var length := mini(bytes.size(), MAX_NAME_BYTES)
	# Do not cut a multi-byte character in half.
	while length > 0 and length < bytes.size() and (bytes[length] & 0xC0) == 0x80:
		length -= 1
	b.put_u8(length)
	b.put_data(bytes.slice(0, length))


static func get_string(b: StreamPeerBuffer) -> String:
	var length := b.get_u8()
	var result: Array = b.get_data(length)
	if result[0] != OK:
		return ""
	return (result[1] as PackedByteArray).get_string_from_utf8()


static func put_snapshot(b: StreamPeerBuffer, s: Snapshot) -> void:
	b.put_32(s.tick)
	b.put_u8(s.state)
	b.put_u8(s.red_score)
	b.put_u8(s.blue_score)
	b.put_32(s.time_ticks)
	b.put_u16(s.time_limit_seconds)
	b.put_u8(s.kickoff_team)
	b.put_u8(s.last_scorer)
	b.put_u16(s.kick_count & 0xFFFF)
	b.put_u16(s.bounce_count & 0xFFFF)
	b.put_float(s.ball_x)
	b.put_float(s.ball_y)
	b.put_u8(s.player_count)
	for i in s.player_count:
		b.put_u8(s.player_ids[i])
		b.put_u8(s.player_teams[i] | (0x80 if s.player_kicking[i] else 0))
		b.put_float(s.player_x[i])
		b.put_float(s.player_y[i])


static func get_snapshot(b: StreamPeerBuffer, s: Snapshot) -> bool:
	# Fixed part is 28 bytes after the 4-byte packet header; each player adds 10.
	if b.get_available_bytes() < 28:
		return false
	s.tick = b.get_32()
	s.state = clampi(b.get_u8(), 0, Snapshot.State.OVER) as Snapshot.State
	s.red_score = b.get_u8()
	s.blue_score = b.get_u8()
	s.time_ticks = b.get_32()
	s.time_limit_seconds = b.get_u16()
	s.kickoff_team = b.get_u8()
	s.last_scorer = b.get_u8()
	s.kick_count = b.get_u16()
	s.bounce_count = b.get_u16()
	s.ball_x = b.get_float()
	s.ball_y = b.get_float()
	var count := mini(b.get_u8(), Snapshot.MAX_PLAYERS)
	if b.get_available_bytes() < count * 10:
		return false
	for i in count:
		s.player_ids[i] = b.get_u8()
		var flags := b.get_u8()
		s.player_teams[i] = flags & 0x7F
		s.player_kicking[i] = (flags & 0x80) != 0
		s.player_x[i] = b.get_float()
		s.player_y[i] = b.get_float()
	s.player_count = count
	return true


## Movement axis quantised to a signed byte.
static func pack_axis(value: float) -> int:
	return roundi(clampf(value, -1.0, 1.0) * 127.0)


static func unpack_axis(value: int) -> float:
	return value / 127.0
