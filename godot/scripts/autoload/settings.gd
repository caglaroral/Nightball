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


## Stick travel ignored around the centre, so a worn stick does not drift the player.
const STICK_DEAD_ZONE := 0.2


func _bind_keys() -> void:
	var keys := {
		"move_left": [KEY_LEFT, KEY_A],
		"move_right": [KEY_RIGHT, KEY_D],
		"move_up": [KEY_UP, KEY_W],
		"move_down": [KEY_DOWN, KEY_S],
		"kick": [KEY_X, KEY_SPACE, KEY_CTRL],
		"leave_match": [KEY_ESCAPE],
	}
	# Gamepad: left stick or d-pad to move; A, X or the right shoulder to kick; Back to leave.
	# B is left free because it means "back" in menus and would end a match by accident.
	var buttons := {
		"move_left": [JOY_BUTTON_DPAD_LEFT],
		"move_right": [JOY_BUTTON_DPAD_RIGHT],
		"move_up": [JOY_BUTTON_DPAD_UP],
		"move_down": [JOY_BUTTON_DPAD_DOWN],
		"kick": [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER],
		"leave_match": [JOY_BUTTON_BACK],
	}
	var axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0],
		"move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0],
		"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, STICK_DEAD_ZONE)
		for key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
		for button in buttons.get(action, []):
			var event := InputEventJoypadButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)
		if axes.has(action):
			var event := InputEventJoypadMotion.new()
			event.axis = axes[action][0]
			event.axis_value = axes[action][1]
			InputMap.action_add_event(action, event)


func has_gamepad() -> bool:
	return not Input.get_connected_joypads().is_empty()
