class_name FieldCamera
extends RefCounted
## Decides which part of the field is on screen. Small fields are shown whole; on big fields the
## view follows the local player, leaning towards the ball, and never shows past the field edge.

## What everyone sees when following: the small field's whole-field view, so no device sees more
## than another. Matches Field.fit_area() for the small field.
const VIEW := Vector2(848, 368)
## How far the view leans from the player towards the ball (0 = player, 1 = ball).
const BALL_PULL := 0.3
const FOLLOW_SPEED := 6.0

var centre := Vector2.ZERO
var _following := false


## Returns the field scale for this frame and updates centre (in field units).
## fit_area is shown whole when not following; extent is how far the view may ever reach.
func update(delta: float, follow: bool, player: Vector2, ball: Vector2, screen: Vector2,
		fit_area: Vector2, extent: Vector2) -> float:
	if not follow:
		_following = false
		centre = Vector2.ZERO
		return fit_scale(screen, fit_area)
	var scale := fit_scale(screen, VIEW)
	var target := player.lerp(ball, BALL_PULL)
	if _following:
		centre = centre.lerp(target, 1.0 - exp(-FOLLOW_SPEED * delta))
	else:
		centre = target
		_following = true
	centre = clamp_centre(centre, screen / scale, extent)
	return scale


static func fit_scale(screen: Vector2, area: Vector2) -> float:
	return minf(screen.x / area.x, screen.y / area.y)


## Keeps the visible rectangle inside the field; centres any axis where the field is smaller.
static func clamp_centre(c: Vector2, visible: Vector2, extent: Vector2) -> Vector2:
	var result := c
	for axis in 2:
		var slack := (extent[axis] - visible[axis]) / 2.0
		result[axis] = 0.0 if slack <= 0.0 else clampf(c[axis], -slack, slack)
	return result
