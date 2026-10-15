extends Control
## Left half: a floating joystick that appears where the thumb lands.
## Right half: hold anywhere to kick.

const STICK_RADIUS := 90.0
const DEAD_ZONE := 0.15

var move := Vector2.ZERO
var kick := false

var _stick_index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _kick_touches := {}
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/Inter-Bold.ttf")


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pos := _local(event.position)
		if event.pressed:
			if pos.x < size.x * 0.5 and _stick_index < 0:
				_stick_index = event.index
				_origin = pos
				_knob = pos
			elif pos.x >= size.x * 0.5:
				_kick_touches[event.index] = true
		else:
			if event.index == _stick_index:
				_stick_index = -1
			_kick_touches.erase(event.index)
		_update()
	elif event is InputEventScreenDrag and event.index == _stick_index:
		_knob = _local(event.position)
		_update()


func _local(screen_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_pos


func _update() -> void:
	kick = not _kick_touches.is_empty()
	move = Vector2.ZERO
	if _stick_index >= 0:
		var offset := (_knob - _origin) / STICK_RADIUS
		var length := offset.length()
		if length > DEAD_ZONE:
			move = offset / length * minf(1.0, (length - DEAD_ZONE) / (1.0 - DEAD_ZONE))
	queue_redraw()


func _draw() -> void:
	if _stick_index >= 0:
		draw_circle(_origin, STICK_RADIUS, Color(1, 1, 1, 0.07), true, -1.0, true)
		draw_arc(_origin, STICK_RADIUS, 0, TAU, 64, Color(1, 1, 1, 0.25), 2.0, true)
		var knob := _origin + (_knob - _origin).limit_length(STICK_RADIUS)
		draw_circle(knob, 38, Color(0, 0, 0, 0.25), true, -1.0, true)
		draw_circle(knob, 34, Color(1, 1, 1, 0.55), true, -1.0, true)
	var centre := Vector2(size.x - 130, size.y - 130)
	var glow := 0.35 if kick else 0.12
	draw_circle(centre, 84, Color(0.2, 0.77, 0.42, glow * 0.5), true, -1.0, true)
	draw_circle(centre, 72, Color(0.06, 0.08, 0.1, 0.45), true, -1.0, true)
	draw_arc(centre, 72, 0, TAU, 64, Color(1, 1, 1, 0.5 if kick else 0.25), 3.0, true)
	draw_string(_font, centre + Vector2(-60, 9), "KICK", HORIZONTAL_ALIGNMENT_CENTER, 120, 26,
			Color(1, 1, 1, 0.9 if kick else 0.6))
