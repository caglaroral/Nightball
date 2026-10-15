class_name PhysicsWorld
extends RefCounted
## Haxball-style disc physics. One step() advances one tick (1/60 s).
## The update order and collision responses follow Haxball's game-min.js:
## move, damp, then resolve disc-disc, plane, segment and vertex contacts.

var discs: Array[Disc] = []
var planes: Array[WallPlane] = []
var segments: Array[WallSegment] = []
var vertices: Array[WallVertex] = []


func step() -> void:
	for d in discs:
		d.x += d.vx
		d.y += d.vy
		d.vx = (d.vx + d.gravity_x) * d.damping
		d.vy = (d.vy + d.gravity_y) * d.damping

	var n := discs.size()
	for i in n:
		var a := discs[i]
		for j in range(i + 1, n):
			var b := discs[j]
			if a.collides_with(b.c_group, b.c_mask):
				_resolve_discs(a, b)
		if a.inv_mass == 0.0:
			continue
		for p in planes:
			if a.collides_with(p.c_group, p.c_mask):
				_resolve_plane(a, p)
		for s in segments:
			if a.collides_with(s.c_group, s.c_mask):
				_resolve_segment(a, s)
		for v in vertices:
			if a.collides_with(v.c_group, v.c_mask):
				_resolve_vertex(a, v)


static func _resolve_discs(a: Disc, b: Disc) -> void:
	var dx := a.x - b.x
	var dy := a.y - b.y
	var radii := a.radius + b.radius
	var dist_sq := dx * dx + dy * dy
	var mass_sum := a.inv_mass + b.inv_mass
	if dist_sq <= 0.0 or dist_sq > radii * radii or mass_sum == 0.0:
		return
	var dist := sqrt(dist_sq)
	var nx := dx / dist
	var ny := dy / dist
	var share_a := a.inv_mass / mass_sum
	var overlap := radii - dist
	a.x += nx * overlap * share_a
	a.y += ny * overlap * share_a
	b.x -= nx * overlap * (1.0 - share_a)
	b.y -= ny * overlap * (1.0 - share_a)

	var approach := nx * (a.vx - b.vx) + ny * (a.vy - b.vy)
	if approach < 0.0:
		approach *= a.b_coef * b.b_coef + 1.0
		a.vx -= nx * approach * share_a
		a.vy -= ny * approach * share_a
		b.vx += nx * approach * (1.0 - share_a)
		b.vy += ny * approach * (1.0 - share_a)


static func _resolve_plane(d: Disc, p: WallPlane) -> void:
	var penetration := p.distance - (p.normal_x * d.x + p.normal_y * d.y) + d.radius
	if penetration <= 0.0:
		return
	d.x += p.normal_x * penetration
	d.y += p.normal_y * penetration
	_bounce(d, p.normal_x, p.normal_y, p.b_coef)


static func _resolve_segment(d: Disc, s: WallSegment) -> void:
	var sx := s.x1 - s.x0
	var sy := s.y1 - s.y0
	# Only the part between the endpoints; the endpoints themselves are vertices.
	if (d.x - s.x0) * sx + (d.y - s.y0) * sy <= 0.0:
		return
	if (d.x - s.x1) * sx + (d.y - s.y1) * sy >= 0.0:
		return
	var nx := s.normal_x
	var ny := s.normal_y
	var dist := nx * (d.x - s.x1) + ny * (d.y - s.y1)
	if dist < 0.0:
		dist = -dist
		nx = -nx
		ny = -ny
	if dist >= d.radius:
		return
	var push := d.radius - dist
	d.x += nx * push
	d.y += ny * push
	_bounce(d, nx, ny, s.b_coef)


static func _resolve_vertex(d: Disc, v: WallVertex) -> void:
	var dx := d.x - v.x
	var dy := d.y - v.y
	var dist_sq := dx * dx + dy * dy
	if dist_sq <= 0.0 or dist_sq > d.radius * d.radius:
		return
	var dist := sqrt(dist_sq)
	var nx := dx / dist
	var ny := dy / dist
	var push := d.radius - dist
	d.x += nx * push
	d.y += ny * push
	_bounce(d, nx, ny, v.b_coef)


static func _bounce(d: Disc, nx: float, ny: float, wall_b_coef: float) -> void:
	var normal_speed := d.vx * nx + d.vy * ny
	if normal_speed < 0.0:
		normal_speed *= d.b_coef * wall_b_coef + 1.0
		d.vx -= nx * normal_speed
		d.vy -= ny * normal_speed
