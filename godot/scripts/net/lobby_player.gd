class_name LobbyPlayer
extends RefCounted

var id: int
var name: String
var team: int


func _init(player_id: int, player_name: String, player_team: int) -> void:
	id = player_id
	name = player_name
	team = player_team
