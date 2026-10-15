extends Node2D
## Draws the pitch and the discs in stadium coordinates (Haxball units, y pointing down).
## Layers: turf and lines, additive floodlight pools, then shadows, discs and the ball trail.

const PLAYER_RADIUS := 15.0
const BALL_RADIUS := 10.0
const TRAIL_LENGTH := 14

const TURF_OUTER := Color("2f5e36")
const TURF_A := Color("3d7a45")
const TURF_B := Color("37703f")
const LINE := Color(0.93, 0.98, 0.94, 0.82)
const OUTLINE := Color(0.05, 0.06, 0.07, 1.0)

var stadium := Stadium.classic()
var snapshot: Snapshot
var local_player_id := -1

var _pitch := Node2D.new()
var _lights := Node2D.new()
var _discs := Node2D.new()
var _sphere: Texture2D
var _shadow: Texture2D
var _spec: Texture2D
var _pool: Texture2D
var _trail: Array[Vector2] = []
var _time := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sphere = _sphere_texture(128)
	_shadow = _radial(Color(0, 0, 0, 0.75), Color(0, 0, 0, 0))
	_spec = _radial(Color(1, 1, 1, 0.95), Color(1, 1, 1, 0))
	_pool = _radial(Color(1, 1, 1, 1), Color(1, 1, 1, 0))

	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lights.material = additive
	# Added first so particles placed in the scene draw on top.
	for layer in [_discs, _lights, _pitch]:
		add_child(layer)
		move_child(layer, 0)
	_pitch.draw.connect(_draw_pitch)
	_lights.draw.connect(_draw_lights)
	_discs.draw.connect(_draw_discs)


## Everywhere a player can go, plus a thin margin. The camera never shows past this.
func extent() -> Vector2:
	return Vector2(stadium.width + 4.0, stadium.height + 4.0) * 2.0


## What a whole-field view fits on screen: full width, but vertically only the pitch lines plus a
## small margin. Players pressed against the top or bottom bounds may be partly cropped; the ball
## never goes there.
func fit_area() -> Vector2:
	return Vector2(stadium.width + 4.0, stadium.pitch_height + 14.0) * 2.0


func set_stadium(stadium_id: int) -> void:
	if stadium.id == stadium_id:
		return
	stadium = Stadium.by_id(stadium_id)
	_trail.clear()
	_pitch.queue_redraw()
	_lights.queue_redraw()


func show_snapshot(s: Snapshot, delta: float) -> void:
	snapshot = s
	_time += delta
	var ball := Vector2(s.ball_x, s.ball_y)
	if _trail.is_empty() or _trail[-1].distance_to(ball) > 60.0:
		_trail.clear()
	_trail.append(ball)
	while _trail.size() > TRAIL_LENGTH:
		_trail.pop_front()
	_discs.queue_redraw()


func clear_trail() -> void:
	_trail.clear()


# --- turf --------------------------------------------------------------------

func _draw_pitch() -> void:
	var c := _pitch
	var w := stadium.pitch_width
	var h := stadium.pitch_height
	var g := stadium.goal_half_width
	var depth := w + stadium.goal_depth
	# Turf reaches far past the playable area so wide screens show grass, not empty bars.
	var outer := Rect2(-stadium.width - 700, -stadium.height - 500, (stadium.width + 700) * 2, (stadium.height + 500) * 2)
	c.draw_rect(outer, TURF_OUTER)
	# Mowing stripes, aligned so the halfway line sits between two stripes.
	var stripe_w := w * 2.0 / 10.0
	var first := -ceili((outer.size.x / 2.0) / stripe_w)
	for i in range(first, -first):
		c.draw_rect(Rect2(i * stripe_w, outer.position.y, stripe_w + 0.5, outer.size.y),
				TURF_A if posmod(i, 2) == 0 else TURF_B)
	# Darker run-off outside the pitch lines.
	_run_off(c, outer, w, h, Color(0, 0, 0, 0.16))

	# Goals: dark mouth, team tint, net mesh.
	for side in [-1, 1]:
		var team := Team.RED if side < 0 else Team.BLUE
		var x0 := minf(side * w, side * depth)
		var mouth := Rect2(x0, -g, stadium.goal_depth, g * 2)
		c.draw_rect(mouth, Color(0, 0, 0, 0.35))
		c.draw_rect(mouth, Color(Team.color(team), 0.18))
		var step := 7.0
		var x := mouth.position.x
		while x <= mouth.end.x:
			c.draw_line(Vector2(x, -g), Vector2(x, g), Color(1, 1, 1, 0.13), 1.0, true)
			x += step
		var y := -g
		while y <= g:
			c.draw_line(Vector2(mouth.position.x, y), Vector2(mouth.end.x, y), Color(1, 1, 1, 0.13), 1.0, true)
			y += step
		# Net frame and a glowing goal line.
		c.draw_polyline(PackedVector2Array([Vector2(side * w, -g), Vector2(side * depth, -g),
				Vector2(side * depth, g), Vector2(side * w, g)]), Color(1, 1, 1, 0.55), 2.5, true)
		c.draw_line(Vector2(side * w, -g), Vector2(side * w, g), Color(Team.color(team), 0.35), 9.0, true)
		c.draw_line(Vector2(side * w, -g), Vector2(side * w, g), Color(Team.color(team).lightened(0.3), 0.9), 3.0, true)

	# Pitch markings.
	c.draw_polyline(PackedVector2Array([Vector2(-w, -g), Vector2(-w, -h), Vector2(w, -h), Vector2(w, -g)]), LINE, 3.0, true)
	c.draw_polyline(PackedVector2Array([Vector2(-w, g), Vector2(-w, h), Vector2(w, h), Vector2(w, g)]), LINE, 3.0, true)
	c.draw_line(Vector2(0, -h), Vector2(0, h), LINE, 3.0, true)
	c.draw_arc(Vector2.ZERO, stadium.kickoff_radius, 0, TAU, 96, LINE, 3.0, true)
	c.draw_circle(Vector2.ZERO, 4.0, LINE, true, -1.0, true)
	for corner in [Vector2(-w, -h), Vector2(w, -h), Vector2(-w, h), Vector2(w, h)]:
		var start := atan2(-signf(corner.y), -signf(corner.x))
		c.draw_arc(corner, 12.0, start - PI / 4, start + PI / 4, 16, LINE, 2.0, true)

	for post in stadium.posts:
		_disc(c, Vector2(post.x, post.y), post.radius, Color(0.92, 0.94, 0.96))


func _run_off(c: Node2D, outer: Rect2, w: float, h: float, shade: Color) -> void:
	c.draw_rect(Rect2(outer.position.x, outer.position.y, outer.size.x, -h - outer.position.y), shade)
	c.draw_rect(Rect2(outer.position.x, h, outer.size.x, outer.end.y - h), shade)
	c.draw_rect(Rect2(outer.position.x, -h, -w - outer.position.x, h * 2), shade)
	c.draw_rect(Rect2(w, -h, outer.end.x - w, h * 2), shade)


# --- floodlights ---------------------------------------------------------------

func _draw_lights() -> void:
	var w := stadium.pitch_width
	var h := stadium.pitch_height
	var pools := [Vector2(-w * 0.55, -h * 0.35), Vector2(w * 0.55, -h * 0.35),
			Vector2(-w * 0.55, h * 0.45), Vector2(w * 0.55, h * 0.45), Vector2.ZERO]
	var grow := w / 370.0
	for p in pools:
		var size := (Vector2(520, 380) if p != Vector2.ZERO else Vector2(700, 460)) * grow
		_lights.draw_texture_rect(_pool, Rect2(p - size / 2, size), false, Color(1, 1, 0.92, 0.055))


# --- discs ----------------------------------------------------------------------

func _draw_discs() -> void:
	var s := snapshot
	if s == null:
		return
	var c := _discs
	_draw_trail(c)

	# Shadows first so no disc is darkened by a neighbour's shadow.
	for i in s.player_count:
		_shadow_for(c, Vector2(s.player_x[i], s.player_y[i]), PLAYER_RADIUS)
	_shadow_for(c, Vector2(s.ball_x, s.ball_y), BALL_RADIUS)

	for i in s.player_count:
		var pos := Vector2(s.player_x[i], s.player_y[i])
		var team := s.player_teams[i]
		if s.player_ids[i] == local_player_id:
			var pulse := 0.5 + 0.5 * sin(_time * 4.0)
			c.draw_arc(pos, PLAYER_RADIUS + 8.0 + pulse * 1.5, 0, TAU, 48, Color(1, 1, 1, 0.35 + 0.25 * pulse), 2.0, true)
		_disc(c, pos, PLAYER_RADIUS, Team.color(team), s.player_kicking[i])
	_disc(c, Vector2(s.ball_x, s.ball_y), BALL_RADIUS, Color(0.97, 0.98, 1.0))


func _draw_trail(c: Node2D) -> void:
	if _trail.size() < 2:
		return
	var n := _trail.size()
	for i in range(1, n):
		var a := _trail[i - 1]
		var b := _trail[i]
		if a.distance_to(b) < 1.2:
			continue
		var t := float(i) / n
		c.draw_line(a, b, Color(1, 1, 1, 0.28 * t), BALL_RADIUS * 1.6 * t, true)


func _shadow_for(c: Node2D, pos: Vector2, r: float) -> void:
	var size := Vector2(r, r) * 2.9
	c.draw_texture_rect(_shadow, Rect2(pos + Vector2(3.0, 5.0) - size / 2, size), false, Color(1, 1, 1, 0.55))


## A lit sphere: dark outline (white while kicking), shaded body and a specular highlight.
func _disc(c: Node2D, pos: Vector2, r: float, color: Color, kicking := false) -> void:
	c.draw_circle(pos, r + 2.2, Color.WHITE if kicking else OUTLINE, true, -1.0, true)
	c.draw_texture_rect(_sphere, Rect2(pos - Vector2(r, r), Vector2(r, r) * 2), false, color.lightened(0.12))
	var spec := Vector2(r, r) * 0.9
	c.draw_texture_rect(_spec, Rect2(pos + Vector2(-r * 0.38, -r * 0.42) - spec / 2, spec), false, Color(1, 1, 1, 0.55))


# --- generated textures -------------------------------------------------------------

## White sphere lit from the top left; tinted by the draw colour.
static func _sphere_texture(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	var light := Vector3(-0.5, -0.6, 0.75).normalized()
	for y in size:
		for x in size:
			var p := Vector2((x - c) / c, (y - c) / c)
			var d := p.length()
			var alpha := clampf((1.0 - d) * c * 0.8, 0.0, 1.0)
			if alpha <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var n := Vector3(p.x, p.y, sqrt(maxf(0.0, 1.0 - d * d)))
			var shade := 0.6 + 0.4 * clampf(n.dot(light), 0.0, 1.0)
			# Soft bounce light from the turf along the bottom edge.
			shade += 0.06 * clampf(p.y, 0.0, 1.0) * d
			img.set_pixel(x, y, Color(shade, shade, shade, alpha))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _radial(inner: Color, outer: Color) -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
