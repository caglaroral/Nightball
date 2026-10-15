class_name Stadium
extends RefCounted
## Field layout, centred on the kickoff spot. Red defends the left goal (negative x).
## Modelled on Haxball's Classic stadium.

## Half size of the area players can move in.
var width := 420.0
var height := 200.0
## Half size of the pitch the ball stays in (the white lines).
var pitch_width := 370.0
var pitch_height := 170.0
var goal_half_width := 64.0
var goal_depth := 30.0
var kickoff_radius := 75.0
var spawn_distance := 170.0
var post_radius := 8.0

var planes: Array[WallPlane] = []
var segments: Array[WallSegment] = []
var vertices: Array[WallVertex] = []
var posts: Array[Disc] = []


static func classic() -> Stadium:
	var s := Stadium.new()
	var w := s.pitch_width
	var h := s.pitch_height
	var g := s.goal_half_width
	var depth := w + s.goal_depth
	var ball_only := CollisionGroups.BALL
	var wall := CollisionGroups.WALL

	# Pitch lines: the ball bounces off them, players walk through.
	s._wall(-w, -h, w, -h, 1.0, wall, ball_only)
	s._wall(-w, h, w, h, 1.0, wall, ball_only)
	s._wall(-w, -h, -w, -g, 1.0, wall, ball_only)
	s._wall(-w, g, -w, h, 1.0, wall, ball_only)
	s._wall(w, -h, w, -g, 1.0, wall, ball_only)
	s._wall(w, g, w, h, 1.0, wall, ball_only)

	# Goal nets: soft, ball only.
	for side in [-1, 1]:
		s._wall(side * w, -g, side * depth, -g, 0.1, wall, ball_only)
		s._wall(side * depth, -g, side * depth, g, 0.1, wall, ball_only)
		s._wall(side * depth, g, side * w, g, 0.1, wall, ball_only)

	# Outer bounds for players.
	var players := CollisionGroups.RED | CollisionGroups.BLUE
	s.planes.append(WallPlane.new(0, 1, -s.height, 0.1, wall, players))
	s.planes.append(WallPlane.new(0, -1, -s.height, 0.1, wall, players))
	s.planes.append(WallPlane.new(1, 0, -s.width, 0.1, wall, players))
	s.planes.append(WallPlane.new(-1, 0, -s.width, 0.1, wall, players))

	# Goal posts collide with everything and never move.
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			s.posts.append(Disc.create(sx * w, sy * g, s.post_radius, 0.0, 1.0, 0.5, wall, CollisionGroups.ALL))
	return s


func _wall(ax: float, ay: float, bx: float, by: float, bounce: float, group: int, mask: int) -> void:
	segments.append(WallSegment.new(ax, ay, bx, by, bounce, group, mask))
	_add_vertex(ax, ay, bounce, group, mask)
	_add_vertex(bx, by, bounce, group, mask)


func _add_vertex(px: float, py: float, bounce: float, group: int, mask: int) -> void:
	for v in vertices:
		if v.x == px and v.y == py:
			return
	vertices.append(WallVertex.new(px, py, bounce, group, mask))


## Which goal the ball entered while moving from (ax, ay) to (bx, by):
## Team.RED for the left goal, Team.BLUE for the right one, Team.SPECTATOR for neither.
func goal_crossed(ax: float, ay: float, bx: float, by: float) -> int:
	if ax >= -pitch_width and bx < -pitch_width and _crosses_within_goal(ax, ay, bx, by, -pitch_width):
		return Team.RED
	if ax <= pitch_width and bx > pitch_width and _crosses_within_goal(ax, ay, bx, by, pitch_width):
		return Team.BLUE
	return Team.SPECTATOR


func _crosses_within_goal(ax: float, ay: float, bx: float, by: float, line_x: float) -> bool:
	var t := (line_x - ax) / (bx - ax)
	return absf(ay + (by - ay) * t) < goal_half_width
