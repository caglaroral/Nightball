extends Control
## Match screen: draws the session's state, sends local input, and turns state changes into
## effects (sounds, goal celebration, screen shake).

@onready var field: Node2D = %Field
@onready var touch: Control = %TouchControls

var _session: Session
var _last: Snapshot
var _names := {}
var _names_key := ""
var _shake := 0.0
var _touch_mode := false
var _camera := FieldCamera.new()

const TOP_BAR := 52.0


func _ready() -> void:
	_session = Net.session
	if _session == null:
		_to_menu("")
		return
	_touch_mode = DisplayServer.is_touchscreen_available()
	touch.visible = _touch_mode
	%Hint.visible = not _touch_mode
	%ExitButton.text = "End match" if _session.is_host() else "Leave"
	%ExitButton.pressed.connect(_exit)
	%NameTags.field = field
	%Banner.visible = false
	%Flash.color.a = 0.0
	%RedDot.add_theme_stylebox_override("panel", _dot(Team.color(Team.RED)))
	%BlueDot.add_theme_stylebox_override("panel", _dot(Team.color(Team.BLUE)))
	%RedScore.add_theme_color_override("font_color", Team.color(Team.RED).lightened(0.15))
	%BlueScore.add_theme_color_override("font_color", Team.color(Team.BLUE).lightened(0.15))
	Fx.juice(%ExitButton)
	Sfx.set_crowd(true)
	Sfx.play("whistle", -4.0)
	var tween := create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(%Hint, "modulate:a", 0.0, 1.0)


static func _dot(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(7)
	s.shadow_color = Color(color, 0.6)
	s.shadow_size = 6
	return s


func _process(delta: float) -> void:
	_send_input()
	if not _session.closed_reason.is_empty():
		_to_menu(_session.closed_reason)
		return
	if not _session.in_game():
		Sfx.set_crowd(false)
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")
		return

	var s := _session.render_state()
	if s == null:
		return
	_place_field(s, delta)
	_update_names()
	field.local_player_id = _session.local_player_id()
	field.show_snapshot(s, delta)
	_react(s)
	_update_hud(s)

	_shake = maxf(0.0, _shake - delta * 2.5)
	field.position += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * _shake * 14.0


func _send_input() -> void:
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var kick := Input.is_action_pressed("kick")
	if _touch_mode and (touch.move != Vector2.ZERO or touch.kick):
		move = touch.move
		kick = kick or touch.kick
	_session.set_local_input(move.x, move.y, kick)


## Fits the field below the score bar; on the big field the camera follows the local player.
func _place_field(s: Snapshot, delta: float) -> void:
	field.set_stadium(_session.stadium_id)
	var top := TOP_BAR
	var screen := Vector2(size.x, size.y - top)
	var me := s.index_of(_session.local_player_id())
	var follow: bool = field.stadium.id == Stadium.BIG and me >= 0
	var player := Vector2(s.player_x[me], s.player_y[me]) if me >= 0 else Vector2.ZERO
	var scale := _camera.update(delta, follow, player, Vector2(s.ball_x, s.ball_y), screen,
			field.fit_area(), field.extent())
	field.scale = Vector2(scale, scale)
	field.position = Vector2(size.x / 2.0, top + screen.y / 2.0) - _camera.centre * scale


func _update_names() -> void:
	var key := ""
	for p in _session.players:
		key += "%d:%s|" % [p.id, p.name]
	if key != _names_key:
		_names_key = key
		_names.clear()
		for p in _session.players:
			_names[p.id] = p.name
		%NameTags.names = _names


## Compares with the previous frame to fire one-off effects.
func _react(s: Snapshot) -> void:
	if _last == null:
		_last = Snapshot.new()
		_last.copy_from(s)
		return
	if s.kick_count != _last.kick_count:
		Sfx.play("kick", 0.0, randf_range(0.95, 1.05))
		%KickPuff.position = Vector2(s.ball_x, s.ball_y)
		%KickPuff.restart()
	elif s.bounce_count != _last.bounce_count:
		Sfx.play("bounce", -6.0, randf_range(0.9, 1.1))
	if s.state != _last.state:
		match s.state:
			Snapshot.State.GOAL:
				_celebrate(s.last_scorer)
			Snapshot.State.OVER:
				_finish(s)
			Snapshot.State.KICKOFF:
				if _last.state == Snapshot.State.GOAL:
					Sfx.play("whistle", -4.0)
					field.clear_trail()
					_hide_banner()
	_last.copy_from(s)


func _celebrate(scorer: int) -> void:
	Sfx.play("goal")
	# The announcer comes in just after the crowd.
	get_tree().create_timer(0.25).timeout.connect(func(): Sfx.play("commentator", 1.0))
	_shake = 1.0
	var color := Team.color(scorer)
	# Confetti bursts out of the goal that was scored in.
	var confetti: CPUParticles2D = %ConfettiRight if scorer == Team.RED else %ConfettiLeft
	var goal_x: float = field.stadium.pitch_width + 2.0
	%ConfettiLeft.position.x = -goal_x
	%ConfettiRight.position.x = goal_x
	var ramp := Gradient.new()
	ramp.set_color(0, color.lightened(0.35))
	ramp.set_color(1, color.darkened(0.1))
	ramp.add_point(0.5, Color(1, 0.86, 0.3))
	confetti.color_initial_ramp = ramp
	confetti.restart()
	_flash(color)
	_show_banner("GOAL!", "%s scores" % Team.display_name(scorer), color)


func _finish(s: Snapshot) -> void:
	Sfx.play("win")
	var winner := Team.RED if s.red_score > s.blue_score else Team.BLUE
	_show_banner("%s WINS" % Team.display_name(winner).to_upper(), "%d - %d" % [s.red_score, s.blue_score],
			Team.color(winner))


func _flash(color: Color) -> void:
	%Flash.color = Color(color.lightened(0.6), 0.35)
	create_tween().tween_property(%Flash, "color:a", 0.0, 0.5)


func _show_banner(title: String, subtitle: String, color: Color) -> void:
	var banner: Control = %Banner
	%BannerTitle.text = title
	%BannerTitle.add_theme_color_override("font_color", color.lightened(0.2))
	%BannerSub.text = subtitle
	banner.visible = true
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.3, 0.3)
	banner.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "modulate:a", 1.0, 0.2)


func _hide_banner() -> void:
	var tween := create_tween()
	tween.tween_property(%Banner, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): %Banner.visible = false)


func _update_hud(s: Snapshot) -> void:
	%RedScore.text = str(s.red_score)
	%BlueScore.text = str(s.blue_score)
	var seconds := s.time_ticks / MatchSim.TICKS_PER_SECOND
	var clock := "%d:%02d" % [seconds / 60, seconds % 60]
	if s.time_limit_seconds > 0 and seconds >= s.time_limit_seconds:
		clock += "  golden goal"
	%Clock.text = clock


func _exit() -> void:
	if _session.is_host():
		_session.stop_game()
	else:
		_to_menu("")


func _to_menu(message: String) -> void:
	set_process(false)
	Sfx.set_crowd(false)
	Net.leave()
	preload("res://scripts/ui/menu.gd").pending_message = message
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_exit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_exit()
