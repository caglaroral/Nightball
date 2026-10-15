extends Control
## Lists rooms found on the Wi-Fi and lets the player type a host address instead.

var _discovery: LanDiscovery
var _shown_keys := ""
var _dots := 0.0
var _focused_first_room := false


func _ready() -> void:
	_discovery = LanDiscovery.new()
	if not _discovery.is_open():
		%Message.text = "Room search is unavailable here; join by address."
	%BackButton.pressed.connect(_back)
	%ConnectButton.pressed.connect(_join_typed)
	%AddressEdit.text_changed.connect(func(t): %ConnectButton.disabled = t.strip_edges().is_empty())
	%AddressEdit.text_submitted.connect(func(_t): _join_typed())
	Fx.juice_buttons(self)
	Fx.enter(%Content)
	if not DisplayServer.is_touchscreen_available():
		%BackButton.grab_focus.call_deferred()


func _process(delta: float) -> void:
	Fx.follow_keyboard(%Content, delta)
	_discovery.update(Time.get_ticks_msec())
	_dots = fmod(_dots + delta * 2.0, 4.0)
	var rooms := _discovery.rooms()
	%Status.text = ("Searching" + ".".repeat(int(_dots))) if rooms.is_empty() \
			else "%d room%s found" % [rooms.size(), "" if rooms.size() == 1 else "s"]
	%Empty.visible = rooms.is_empty()
	_rebuild_rows(rooms)


## Rebuilds the list only when it changed, so hover states are not reset every frame.
func _rebuild_rows(rooms: Array) -> void:
	var keys := ""
	for room in rooms:
		keys += "%s:%d:%d:%s|" % [room.ip, room.port, room.players, room.in_game]
	if keys == _shown_keys:
		return
	_shown_keys = keys
	for child in %Rooms.get_children():
		child.queue_free()
	for room in rooms:
		var row := Button.new()
		row.theme_type_variation = &"RowButton"
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var status := "  •  playing" if room.in_game else ""
		row.text = "%s      %d/%d players%s      %s" % [room.name, room.players, room.max_players, status, room.ip]
		var ip: String = room.ip
		var port: int = room.port
		row.pressed.connect(func(): _join(ip, port))
		%Rooms.add_child(row)
		Fx.juice(row)
	# Gamepad users land on the first room when one first shows up, or when the focused row was
	# replaced by a refresh. Old rows are still children until freed, so new rows are the last ones.
	if rooms.is_empty() or DisplayServer.is_touchscreen_available():
		return
	var first: Control = %Rooms.get_child(%Rooms.get_child_count() - rooms.size())
	var focus := get_viewport().gui_get_focus_owner()
	var lost_focus := focus == null or (focus.get_parent() == %Rooms and focus.is_queued_for_deletion())
	if lost_focus or not _focused_first_room:
		_focused_first_room = true
		first.grab_focus.call_deferred()


func _join_typed() -> void:
	var text: String = %AddressEdit.text.strip_edges()
	if text.is_empty():
		return
	var port := Protocol.GAME_PORT
	var colon := text.rfind(":")
	if colon > 0:
		if not text.substr(colon + 1).is_valid_int():
			%Message.text = "Port must be a number"
			return
		port = text.substr(colon + 1).to_int()
		text = text.substr(0, colon)
	var ip := text if text.is_valid_ip_address() else IP.resolve_hostname(text, IP.TYPE_IPV4)
	if ip.is_empty():
		%Message.text = "Not a valid address: " + text
		return
	_join(ip, port)


func _join(ip: String, port: int) -> void:
	Net.join(ip, port, Settings.player_name)
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _exit_tree() -> void:
	_discovery.close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
