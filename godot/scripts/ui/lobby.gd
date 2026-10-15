extends Control
## Team picker. The host starts the match; everyone moves to the game screen when it begins.

## Desktop testing: start as soon as a second player joins (set by the --start argument).
static var auto_start := false

var _session: Session
var _shown := ""


func _ready() -> void:
	_session = Net.session
	if _session == null:
		_to_menu("")
		return
	%LeaveButton.pressed.connect(func(): _to_menu(""))
	%StartButton.pressed.connect(func(): _session.start_game())
	%RedJoin.pressed.connect(func(): _session.request_team(Team.RED))
	%SpecJoin.pressed.connect(func(): _session.request_team(Team.SPECTATOR))
	%BlueJoin.pressed.connect(func(): _session.request_team(Team.BLUE))
	for pair in [[%RedAccent, Team.RED], [%SpecAccent, Team.SPECTATOR], [%BlueAccent, Team.BLUE]]:
		var bar := StyleBoxFlat.new()
		bar.bg_color = Team.color(pair[1])
		bar.set_corner_radius_all(3)
		bar.shadow_color = Color(Team.color(pair[1]), 0.5)
		bar.shadow_size = 8
		(pair[0] as Panel).add_theme_stylebox_override("panel", bar)
	%RedTitle.add_theme_color_override("font_color", Team.color(Team.RED))
	%BlueTitle.add_theme_color_override("font_color", Team.color(Team.BLUE))
	%StartButton.visible = _session.is_host()
	%Waiting.visible = not _session.is_host()
	%JoinHint.text = _join_hint()
	Fx.juice_buttons(self)
	Fx.enter(%Content)
	Sfx.set_crowd(false)


func _join_hint() -> String:
	if not _session.is_host():
		return ""
	var host := _session as HostSession
	var addresses := NetUtil.local_addresses()
	var port := "" if host.port() == Protocol.GAME_PORT else ":%d" % host.port()
	var hint := "" if host.is_discoverable() else "Room search is unavailable here. "
	if addresses.is_empty():
		return hint + "Connect to Wi-Fi so others can join."
	var list := PackedStringArray()
	for a in addresses:
		list.append(a + port)
	return hint + "Friends on this Wi-Fi can join at " + " or ".join(list)


func _process(_delta: float) -> void:
	if not _session.closed_reason.is_empty():
		_to_menu(_session.closed_reason)
		return
	if _session.in_game():
		get_tree().change_scene_to_file("res://scenes/game.tscn")
		return

	var connected := _session.is_connected_to_room()
	%Connecting.visible = not connected
	%Content.visible = connected
	if not connected:
		%Connecting.text = "Connecting" + ".".repeat(int(Time.get_ticks_msec() / 400) % 4)
		return

	%RoomName.text = _session.room_name
	var playing := _session.count_team(Team.RED) + _session.count_team(Team.BLUE)
	%StartButton.disabled = playing == 0
	if auto_start and _session.is_host() and _session.players.size() >= 2:
		auto_start = false
		_session.start_game()
	_refresh_teams()


## Rebuilds the player lists only when membership changes.
func _refresh_teams() -> void:
	var key := ""
	for p in _session.players:
		key += "%d:%d:%s|" % [p.id, p.team, p.name]
	if key == _shown:
		return
	_shown = key
	var me := _session.find_player(_session.local_player_id())
	for entry in [[Team.RED, %RedPlayers, %RedCount, %RedJoin], [Team.SPECTATOR, %SpecPlayers, %SpecCount, %SpecJoin],
			[Team.BLUE, %BluePlayers, %BlueCount, %BlueJoin]]:
		var team: int = entry[0]
		var list: VBoxContainer = entry[1]
		for child in list.get_children():
			child.queue_free()
		for p in _session.players:
			if p.team == team:
				list.add_child(_chip(p, me != null and p.id == me.id))
		var count := _session.count_team(team)
		(entry[2] as Label).text = str(count) if team == Team.SPECTATOR else "%d/%d" % [count, Session.MAX_PER_TEAM]
		var full := team != Team.SPECTATOR and count >= Session.MAX_PER_TEAM
		(entry[3] as Button).disabled = me == null or me.team == team or full


func _chip(p: LobbyPlayer, is_me: bool) -> Control:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"PlayerChip"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Team.color(p.team)
	style.set_corner_radius_all(6)
	dot.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = p.name + ("  (you)" if is_me else "")
	if is_me:
		label.add_theme_color_override("font_color", Color.WHITE)
	else:
		label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.88))
	row.add_child(dot)
	row.add_child(label)
	chip.add_child(row)
	return chip


func _to_menu(message: String) -> void:
	set_process(false)
	Net.leave()
	preload("res://scripts/ui/menu.gd").pending_message = message
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_to_menu("")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_to_menu("")
