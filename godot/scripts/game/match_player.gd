class_name MatchPlayer
extends RefCounted

var id: int
var team: int
var disc: Disc

var move_x := 0.0
var move_y := 0.0
var _kick_held := false
## True from a kick press until the kick lands or the button is released (Haxball's behaviour).
var kicking := false


func _init(player_id: int, player_team: int, player_disc: Disc) -> void:
	id = player_id
	team = player_team
	disc = player_disc


## Movement is a direction with length up to 1; longer vectors are normalised.
func set_input(x: float, y: float, kick: bool) -> void:
	var length_sq := x * x + y * y
	if length_sq > 1.0:
		var length := sqrt(length_sq)
		x /= length
		y /= length
	move_x = x
	move_y = y
	if kick and not _kick_held:
		kicking = true
	elif not kick:
		kicking = false
	_kick_held = kick
