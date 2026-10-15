extends Node
## Holds the room this device is in and pumps it once per frame, before any screen runs.

var session: Session


func _process(delta: float) -> void:
	if session != null:
		session.update(delta, Time.get_ticks_msec())


## Opens a room on this device. Returns an error message, or "" on success.
func host(player_name: String) -> String:
	var room := HostSession.new(player_name, "%s's room" % player_name)
	if not room.is_open():
		return "Could not open a network port"
	_replace(room)
	return ""


func join(ip: String, port: int, player_name: String) -> void:
	_replace(ClientSession.new(ip, port, player_name, Time.get_ticks_msec()))


func leave() -> void:
	_replace(null)


func _replace(next: Session) -> void:
	if session != null and session != next:
		session.close()
	session = next


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		leave()
