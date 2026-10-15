extends Control

## Shown on the next menu visit, e.g. why the last room closed.
static var pending_message := ""
static var _launched := false


func _ready() -> void:
	if not _launched:
		_launched = true
		if _apply_launch_arguments():
			return
	%NameEdit.text = Settings.player_name
	%Message.text = pending_message
	pending_message = ""
	%Version.text = "v" + str(ProjectSettings.get_setting("application/config/version"))
	%HostButton.pressed.connect(_host)
	%JoinButton.pressed.connect(_join)
	%NameEdit.text_submitted.connect(func(_t): _host())
	%SoundButton.pressed.connect(_toggle_sound)
	_update_sound_label()
	Fx.juice_buttons(self)
	Fx.enter(%Content)
	Sfx.set_crowd(false)
	if not DisplayServer.is_touchscreen_available():
		%HostButton.grab_focus()


## Desktop testing shortcuts, passed after "--":
##   --name Ali --host [--start]     open a room (and start when a second player joins)
##   --name Veli --join 127.0.0.1    join a room
## Returns true when it switched screens.
func _apply_launch_arguments() -> bool:
	var args := OS.get_cmdline_user_args()
	var i := 0
	var join := ""
	var host := false
	while i < args.size():
		match args[i]:
			"--name":
				if i + 1 < args.size():
					i += 1
					Settings.player_name = args[i]
					get_window().title = "Nightball - " + args[i]
			"--host":
				host = true
			"--start":
				preload("res://scripts/ui/lobby.gd").auto_start = true
			"--join":
				if i + 1 < args.size():
					i += 1
					join = args[i]
		i += 1
	if host and Net.host(Settings.player_name).is_empty():
		get_tree().change_scene_to_file.call_deferred("res://scenes/lobby.tscn")
		return true
	if not join.is_empty():
		var port := Protocol.GAME_PORT
		if join.contains(":"):
			port = join.get_slice(":", 1).to_int()
			join = join.get_slice(":", 0)
		Net.join(join, port, Settings.player_name)
		get_tree().change_scene_to_file.call_deferred("res://scenes/lobby.tscn")
		return true
	return false


func _remember_name() -> String:
	var player_name: String = %NameEdit.text.strip_edges()
	if player_name.is_empty():
		player_name = "Player"
	Settings.player_name = player_name
	Settings.save()
	return player_name


func _host() -> void:
	var error := Net.host(_remember_name())
	if not error.is_empty():
		%Message.text = error
		return
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _join() -> void:
	_remember_name()
	get_tree().change_scene_to_file("res://scenes/browse.tscn")


func _toggle_sound() -> void:
	Settings.sound_enabled = not Settings.sound_enabled
	Settings.save()
	_update_sound_label()


func _update_sound_label() -> void:
	%SoundButton.text = "Sound: On" if Settings.sound_enabled else "Sound: Off"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
