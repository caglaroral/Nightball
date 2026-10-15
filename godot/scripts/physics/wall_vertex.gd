class_name WallVertex
extends RefCounted
## Fixed point that discs bounce off, normally a segment endpoint.

var x: float
var y: float
var b_coef: float
var c_group: int
var c_mask: int


func _init(px: float, py: float, bounce: float, group: int, mask: int) -> void:
	x = px
	y = py
	b_coef = bounce
	c_group = group
	c_mask = mask
