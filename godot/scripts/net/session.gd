class_name Session
extends RefCounted
## A room as seen by this device, whether it hosts the room or joined it.

const MAX_PLAYERS := 16
const MAX_PER_TEAM := 4

## Field choice in the lobby.
const FIELD_AUTO := 0
const FIELD_SMALL := 1
const FIELD_BIG := 2

var room_name := ""
var field_mode := FIELD_AUTO
## The field being played, or the one the next match will use.
var stadium_id := Stadium.SMALL
var players: Array[LobbyPlayer] = []
## Non-empty once the session has ended; explains why.
var closed_reason := ""


## Pumps the network and, on the host, advances the simulation.
func update(_delta: float, _now_ms: int) -> void:
	pass


func is_host() -> bool:
	return false


## False while a client is still waiting for the host to accept it.
func is_connected_to_room() -> bool:
	return closed_reason.is_empty()


func local_player_id() -> int:
	return -1


func in_game() -> bool:
	return false


## Movement direction (length up to 1) and kick button of the local player.
func set_local_input(_x: float, _y: float, _kick: bool) -> void:
	pass


func request_team(_team: int) -> void:
	pass


## Host only.
func start_game() -> void:
	pass


## Host only: ends the match and returns everyone to the lobby.
func stop_game() -> void:
	pass


## Host only.
func set_field_mode(_mode: int) -> void:
	pass


## Smoothed state to draw this frame, or null before the first snapshot.
func render_state() -> Snapshot:
	return null


func close() -> void:
	pass


func find_player(id: int) -> LobbyPlayer:
	for p in players:
		if p.id == id:
			return p
	return null


func count_team(team: int) -> int:
	var count := 0
	for p in players:
		if p.team == team:
			count += 1
	return count
