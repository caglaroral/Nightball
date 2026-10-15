extends Control
## Player names under the discs, drawn in screen space so they stay sharp at any field scale.

var field: Node2D
var names := {}
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/Inter-Bold.ttf")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if field == null or field.snapshot == null:
		return
	var s: Snapshot = field.snapshot
	var to_screen := get_global_transform_with_canvas().affine_inverse() * field.get_global_transform_with_canvas()
	var scale := field.global_scale.x
	for i in s.player_count:
		var label: String = names.get(s.player_ids[i], "")
		if label.is_empty():
			continue
		var pos: Vector2 = to_screen * Vector2(s.player_x[i], s.player_y[i] + 15.0 + 13.0)
		var size := 15
		var width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var origin := pos + Vector2(-width / 2.0, 6.0 * scale)
		draw_string_outline(_font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.55))
		draw_string(_font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.92))
