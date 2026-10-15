class_name WallPlane
extends RefCounted
## Infinite wall. Discs are kept on the side where normal·p >= distance + radius.

var normal_x: float
var normal_y: float
var distance: float
var b_coef: float
var c_group: int
var c_mask: int


func _init(nx: float, ny: float, dist: float, bounce: float, group: int, mask: int) -> void:
	var length := sqrt(nx * nx + ny * ny)
	normal_x = nx / length
	normal_y = ny / length
	distance = dist
	b_coef = bounce
	c_group = group
	c_mask = mask
