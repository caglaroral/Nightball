extends Node
## Player preferences and input bindings.

const PATH := "user://settings.cfg"

var player_name := "Player"
var sound_enabled := true


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		player_name = config.get_value("player", "name", player_name)
		sound_enabled = config.get_value("audio", "enabled", sound_enabled)
	_bind_keys()


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", player_name)
	config.set_value("audio", "enabled", sound_enabled)
	config.save(PATH)


func _bind_keys() -> void:
	var bindings := {
		"move_left": [KEY_LEFT, KEY_A],
		"move_right": [KEY_RIGHT, KEY_D],
		"move_up": [KEY_UP, KEY_W],
		"move_down": [KEY_DOWN, KEY_S],
		"kick": [KEY_X, KEY_SPACE, KEY_CTRL],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
