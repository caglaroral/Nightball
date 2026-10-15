class_name Snapshot
extends RefCounted
## Everything needed to draw one tick. Sent from the host to clients and interpolated for rendering.

enum State { KICKOFF, PLAYING, GOAL, OVER }

const MAX_PLAYERS := 16

var tick := 0
var state := State.KICKOFF
var red_score := 0
var blue_score := 0
## Elapsed playing time in ticks.
var time_ticks := 0
var time_limit_seconds := 0
var kickoff_team := Team.RED
## Team that scored last; meaningful during GOAL and OVER.
var last_scorer := Team.SPECTATOR
## Counters that only go up; a change between two snapshots means the event happened.
var kick_count := 0
var bounce_count := 0
var ball_x := 0.0
var ball_y := 0.0

var player_count := 0
var player_ids := PackedInt32Array()
var player_teams := PackedInt32Array()
var player_x := PackedFloat32Array()
var player_y := PackedFloat32Array()
var player_kicking: Array[bool] = []


func _init() -> void:
	player_ids.resize(MAX_PLAYERS)
	player_teams.resize(MAX_PLAYERS)
	player_x.resize(MAX_PLAYERS)
	player_y.resize(MAX_PLAYERS)
	player_kicking.resize(MAX_PLAYERS)
	player_kicking.fill(false)


func copy_from(o: Snapshot) -> void:
	tick = o.tick
	state = o.state
	red_score = o.red_score
	blue_score = o.blue_score
	time_ticks = o.time_ticks
	time_limit_seconds = o.time_limit_seconds
	kickoff_team = o.kickoff_team
	last_scorer = o.last_scorer
	kick_count = o.kick_count
	bounce_count = o.bounce_count
	ball_x = o.ball_x
	ball_y = o.ball_y
	player_count = o.player_count
	for i in player_count:
		player_ids[i] = o.player_ids[i]
		player_teams[i] = o.player_teams[i]
		player_x[i] = o.player_x[i]
		player_y[i] = o.player_y[i]
		player_kicking[i] = o.player_kicking[i]


## Positions blended between a and b; everything else comes from b.
func interpolate(a: Snapshot, b: Snapshot, alpha: float) -> void:
	copy_from(b)
	# A kickoff reset teleports everything; blending across it would show discs sliding.
	if a.state != State.KICKOFF and b.state == State.KICKOFF:
		return
	ball_x = lerpf(a.ball_x, b.ball_x, alpha)
	ball_y = lerpf(a.ball_y, b.ball_y, alpha)
	for i in player_count:
		var index := a.index_of(player_ids[i])
		if index >= 0:
			player_x[i] = lerpf(a.player_x[index], b.player_x[i], alpha)
			player_y[i] = lerpf(a.player_y[index], b.player_y[i], alpha)


func index_of(player_id: int) -> int:
	for i in player_count:
		if player_ids[i] == player_id:
			return i
	return -1
