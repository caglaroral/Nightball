class_name MatchSim
extends RefCounted
## Authoritative match simulation. Runs only on the host, one tick() per 1/60 s.
## Movement, kicking and scoring follow Haxball's per-tick game logic.

const TICKS_PER_SECOND := 60
const GOAL_PAUSE_TICKS := 150
const GAME_OVER_TICKS := 5 * TICKS_PER_SECOND
## Velocity change (px/tick) that counts as an audible bounce.
const BOUNCE_THRESHOLD := 1.2

# Player tuning: Haxball's playerPhysics defaults.
const PLAYER_RADIUS := 15.0
const PLAYER_INV_MASS := 0.5
const PLAYER_DAMPING := 0.96
const PLAYER_B_COEF := 0.5
const ACCELERATION := 0.1
const KICKING_ACCELERATION := 0.07
const KICKING_DAMPING := 0.96
const KICK_STRENGTH := 5.0
const KICKBACK := 0.0
## A kick reaches the ball when the gap between the two edges is below this.
const KICK_REACH := 4.0

var stadium: Stadium
var score_limit: int
var time_limit_seconds: int

var _world := PhysicsWorld.new()
var _ball: Disc
var _players: Array[MatchPlayer] = []

var state := Snapshot.State.KICKOFF
var tick_count := 0
var time_ticks := 0
var _state_timer := 0
var red_score := 0
var blue_score := 0
var kickoff_team := Team.RED
var last_scorer := Team.SPECTATOR
var kick_count := 0
var bounce_count := 0


func _init(field: Stadium, goals_to_win: int, minutes_seconds: int) -> void:
	stadium = field
	score_limit = goals_to_win
	time_limit_seconds = minutes_seconds
	_world.planes.assign(stadium.planes)
	_world.segments.assign(stadium.segments)
	_world.vertices.assign(stadium.vertices)
	_ball = Disc.create(0, 0, 10.0, 1.0, 0.99, 0.5,
			CollisionGroups.BALL | CollisionGroups.KICK | CollisionGroups.SCORE, CollisionGroups.ALL)
	_world.discs.append(_ball)
	_world.discs.append_array(stadium.posts)


func ball() -> Disc:
	return _ball


func add_player(id: int, team: int) -> MatchPlayer:
	if team == Team.SPECTATOR or player(id) != null:
		return null
	var mask := CollisionGroups.BALL | CollisionGroups.RED | CollisionGroups.BLUE | CollisionGroups.WALL
	var disc := Disc.create(0, 0, PLAYER_RADIUS, PLAYER_INV_MASS, PLAYER_DAMPING, PLAYER_B_COEF,
			Team.collision_group(team), mask)
	var p := MatchPlayer.new(id, team, disc)
	_players.append(p)
	_world.discs.append(disc)
	_place_at_spawn(p, _count_team(team) - 1)
	return p


func remove_player(id: int) -> void:
	var p := player(id)
	if p != null:
		_players.erase(p)
		_world.discs.erase(p.disc)


func player(id: int) -> MatchPlayer:
	for p in _players:
		if p.id == id:
			return p
	return null


func set_input(id: int, x: float, y: float, kick: bool) -> void:
	var p := player(id)
	if p != null:
		p.set_input(x, y, kick)


func tick() -> void:
	tick_count += 1
	for p in _players:
		var disc := p.disc
		if p.kicking and _try_kick(disc):
			p.kicking = false
		var acceleration := KICKING_ACCELERATION if p.kicking else ACCELERATION
		disc.vx += p.move_x * acceleration
		disc.vy += p.move_y * acceleration
		disc.damping = KICKING_DAMPING if p.kicking else PLAYER_DAMPING

	var ball_x := _ball.x
	var ball_y := _ball.y
	var expected_vx := _ball.vx * _ball.damping
	var expected_vy := _ball.vy * _ball.damping
	_world.step()
	if Vector2(_ball.vx - expected_vx, _ball.vy - expected_vy).length() > BOUNCE_THRESHOLD:
		bounce_count += 1

	match state:
		Snapshot.State.KICKOFF:
			_hold_kickoff_positions()
			if _ball.speed_squared() > 0.0:
				state = Snapshot.State.PLAYING
		Snapshot.State.PLAYING:
			time_ticks += 1
			var goal := stadium.goal_crossed(ball_x, ball_y, _ball.x, _ball.y)
			if goal != Team.SPECTATOR:
				_score_against(goal)
			elif time_limit_seconds > 0 and time_ticks >= time_limit_seconds * TICKS_PER_SECOND \
					and red_score != blue_score:
				_finish()
		Snapshot.State.GOAL:
			_state_timer -= 1
			if _state_timer <= 0:
				if score_limit > 0 and (red_score >= score_limit or blue_score >= score_limit):
					_finish()
				else:
					reset_positions()
		Snapshot.State.OVER:
			_state_timer -= 1


## Pushes the ball away if it is within reach. Returns whether the kick landed.
func _try_kick(kicker: Disc) -> bool:
	var dx := _ball.x - kicker.x
	var dy := _ball.y - kicker.y
	var dist := sqrt(dx * dx + dy * dy)
	if dist == 0.0 or dist - _ball.radius - kicker.radius >= KICK_REACH:
		return false
	var nx := dx / dist
	var ny := dy / dist
	_ball.vx += nx * KICK_STRENGTH * _ball.inv_mass
	_ball.vy += ny * KICK_STRENGTH * _ball.inv_mass
	kicker.vx -= nx * KICKBACK * kicker.inv_mass
	kicker.vy -= ny * KICKBACK * kicker.inv_mass
	kick_count += 1
	return true


func _score_against(defending: int) -> void:
	var scorer := Team.opponent(defending)
	if scorer == Team.RED:
		red_score += 1
	else:
		blue_score += 1
	last_scorer = scorer
	kickoff_team = defending
	state = Snapshot.State.GOAL
	_state_timer = GOAL_PAUSE_TICKS


func _finish() -> void:
	state = Snapshot.State.OVER
	_state_timer = GAME_OVER_TICKS


## Ball back to the centre and every team back to its own half.
func reset_positions() -> void:
	_ball.set_position(0, 0)
	_ball.stop()
	var red := 0
	var blue := 0
	for p in _players:
		if p.team == Team.RED:
			_place_at_spawn(p, red)
			red += 1
		else:
			_place_at_spawn(p, blue)
			blue += 1
	state = Snapshot.State.KICKOFF


func _place_at_spawn(p: MatchPlayer, index_in_team: int) -> void:
	# 0, -55, +55, -110, +110 ... along the spawn line.
	var row := (index_in_team + 1) / 2
	var y := (-1.0 if index_in_team % 2 == 1 else 1.0) * row * 55.0
	p.disc.set_position(Team.side(p.team) * stadium.spawn_distance, y)
	p.disc.stop()


## Before the kickoff both teams stay in their own half. The team taking the kickoff may also
## enter the centre circle; the other team must stay out of it.
func _hold_kickoff_positions() -> void:
	var circle := stadium.kickoff_radius
	for p in _players:
		var d := p.disc
		var side := float(Team.side(p.team))
		var r := d.radius
		var dist := sqrt(d.x * d.x + d.y * d.y)
		if p.team == kickoff_team:
			var in_own_half := side * d.x >= r
			var in_circle := dist + r <= circle
			if not in_own_half and not in_circle:
				var to_half := r - side * d.x
				var to_circle := dist + r - circle
				if to_half <= to_circle or dist == 0.0:
					_push_to(d, side * r, d.y)
				else:
					var scale := (circle - r) / dist
					_push_to(d, d.x * scale, d.y * scale)
		else:
			if side * d.x < r:
				_push_to(d, side * r, d.y)
			dist = sqrt(d.x * d.x + d.y * d.y)
			if dist < circle + r and dist > 0.0:
				var scale := (circle + r) / dist
				_push_to(d, d.x * scale, d.y * scale)


## Moves a disc and removes the velocity component that pushed it out.
static func _push_to(d: Disc, px: float, py: float) -> void:
	var nx := px - d.x
	var ny := py - d.y
	var length := sqrt(nx * nx + ny * ny)
	d.set_position(px, py)
	if length > 0.0:
		nx /= length
		ny /= length
		var into := d.vx * nx + d.vy * ny
		if into < 0.0:
			d.vx -= nx * into
			d.vy -= ny * into


func _count_team(team: int) -> int:
	var count := 0
	for p in _players:
		if p.team == team:
			count += 1
	return count


func write_snapshot(out: Snapshot) -> void:
	out.tick = tick_count
	out.state = state
	out.red_score = red_score
	out.blue_score = blue_score
	out.time_ticks = time_ticks
	out.time_limit_seconds = time_limit_seconds
	out.kickoff_team = kickoff_team
	out.last_scorer = last_scorer
	out.kick_count = kick_count
	out.bounce_count = bounce_count
	out.ball_x = _ball.x
	out.ball_y = _ball.y
	var count := mini(_players.size(), Snapshot.MAX_PLAYERS)
	out.player_count = count
	for i in count:
		var p := _players[i]
		out.player_ids[i] = p.id
		out.player_teams[i] = p.team
		out.player_x[i] = p.disc.x
		out.player_y[i] = p.disc.y
		out.player_kicking[i] = p.kicking


## True once the result screen has been shown long enough.
func is_finished() -> bool:
	return state == Snapshot.State.OVER and _state_timer <= 0
