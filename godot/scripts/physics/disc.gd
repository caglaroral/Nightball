class_name Disc
extends RefCounted
## A moving circle. Units are pixels and ticks (60 ticks per second), as in Haxball.

var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var gravity_x := 0.0
var gravity_y := 0.0
var radius := 10.0
## 0 means immovable (goal posts).
var inv_mass := 1.0
## Velocity multiplier applied every tick.
var damping := 0.99
## Bounciness; a contact bounces with the product of both objects' b_coef.
var b_coef := 0.5
var c_group := CollisionGroups.ALL
var c_mask := CollisionGroups.ALL


static func create(px: float, py: float, r: float, inv_m: float, damp: float, bounce: float,
		group: int, mask: int) -> Disc:
	var d := Disc.new()
	d.x = px
	d.y = py
	d.radius = r
	d.inv_mass = inv_m
	d.damping = damp
	d.b_coef = bounce
	d.c_group = group
	d.c_mask = mask
	return d


func set_position(px: float, py: float) -> void:
	x = px
	y = py


func stop() -> void:
	vx = 0.0
	vy = 0.0


func speed_squared() -> float:
	return vx * vx + vy * vy


func collides_with(other_group: int, other_mask: int) -> bool:
	return (c_mask & other_group) != 0 and (c_group & other_mask) != 0
