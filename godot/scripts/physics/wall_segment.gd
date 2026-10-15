class_name WallSegment
extends RefCounted
## Straight two-sided wall. Its endpoints are handled as separate vertices.

var x0: float
var y0: float
var x1: float
var y1: float
var normal_x: float
var normal_y: float
var b_coef: float
var c_group: int
var c_mask: int


func _init(ax: float, ay: float, bx: float, by: float, bounce: float, group: int, mask: int) -> void:
	x0 = ax
	y0 = ay
	x1 = bx
	y1 = by
	var dx := bx - ax
	var dy := by - ay
	var length := sqrt(dx * dx + dy * dy)
	normal_x = -dy / length
	normal_y = dx / length
	b_coef = bounce
	c_group = group
	c_mask = mask
