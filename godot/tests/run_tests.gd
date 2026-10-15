extends SceneTree
## Headless test runner:  godot --headless --path godot -s res://tests/run_tests.gd

var _failures := 0
var _current := ""


func _initialize() -> void:
	var tests := [
		"test_player_reaches_haxball_top_speed",
		"test_diagonal_movement_is_not_faster",
		"test_kick_gives_the_ball_kick_strength",
		"test_kickoff_keeps_defenders_out",
		"test_ball_in_right_goal_scores_for_red",
		"test_ball_bounces_off_side_line",
		"test_elastic_disc_collision_swaps_velocity",
		"test_snapshot_round_trip",
		"test_auto_field_picks_big_for_three_a_side",
		"test_big_field_goal",
		"test_camera_stays_inside_field",
		"test_field_choice_reaches_clients",
		"test_host_and_clients_play_a_match",
		"test_client_gives_up_without_room",
		"test_discovery_finds_local_room",
	]
	for t in tests:
		_current = t
		var before := _failures
		call(t)
		print(("PASS  " if _failures == before else "FAIL  ") + t)
	print("\n%d tests, %d failures" % [tests.size(), _failures])
	quit(1 if _failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("  %s: %s" % [_current, message])


func near(actual: float, expected: float, tolerance: float, label: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s: expected %f, got %f" % [label, expected, actual])


# --- physics and rules -------------------------------------------------------

func test_player_reaches_haxball_top_speed() -> void:
	var m := MatchSim.new(Stadium.classic(), 3, 0)
	var p := m.add_player(1, Team.RED)
	m.reset_positions()
	# Stays in its own half for the whole run, so the kickoff rule does not interfere.
	p.disc.set_position(-400, 0)
	for i in 150:
		m.set_input(1, 1, 0, false)
		m.tick()
	# Terminal speed of v' = (v + a) * d is a*d / (1 - d) = 0.1 * 0.96 / 0.04 = 2.4 px/tick.
	near(sqrt(p.disc.speed_squared()), 2.4, 0.01, "top speed")


func test_diagonal_movement_is_not_faster() -> void:
	near(_speed_after(1, 1), _speed_after(1, 0), 1e-6, "diagonal speed")


func _speed_after(x: float, y: float) -> float:
	var m := MatchSim.new(Stadium.classic(), 3, 0)
	var p := m.add_player(1, Team.BLUE)
	p.disc.set_position(200, 0)
	for i in 30:
		m.set_input(1, x, y, false)
		m.tick()
	return p.disc.speed_squared()


func test_kick_gives_the_ball_kick_strength() -> void:
	var m := MatchSim.new(Stadium.classic(), 3, 0)
	var p := m.add_player(1, Team.RED)
	m.reset_positions()
	var ball := m.ball()
	p.disc.set_position(ball.x - ball.radius - p.disc.radius - 1.0, 0)
	m.set_input(1, 0, 0, true)
	m.tick()
	# 5 px/tick added, then one tick of ball damping (0.99).
	near(ball.vx, 5.0 * 0.99, 1e-6, "ball speed after kick")
	near(ball.vy, 0.0, 1e-6, "ball vy")
	check(m.state == Snapshot.State.PLAYING, "kick starts play")
	check(m.kick_count == 1, "kick counted")
	# Holding the button does not kick again.
	var speed := ball.vx
	m.set_input(1, 0, 0, true)
	m.tick()
	check(ball.vx < speed and m.kick_count == 1, "held kick does not repeat")


func test_kickoff_keeps_defenders_out() -> void:
	var m := MatchSim.new(Stadium.classic(), 3, 0)
	m.add_player(1, Team.RED)
	var blue := m.add_player(2, Team.BLUE)
	m.reset_positions()
	for i in 300:
		m.set_input(2, -1, 0, false)
		m.tick()
	var d := blue.disc
	check(m.state == Snapshot.State.KICKOFF, "still kickoff")
	check(d.x >= d.radius - 0.01, "blue stays in own half")
	check(sqrt(d.x * d.x + d.y * d.y) >= 75.0 + d.radius - 0.01, "blue stays out of circle")


func test_ball_in_right_goal_scores_for_red() -> void:
	var m := MatchSim.new(Stadium.classic(), 1, 0)
	m.add_player(1, Team.RED)
	m.reset_positions()
	var ball := m.ball()
	ball.set_position(300, 0)
	ball.vx = 7.0
	for i in 40:
		if m.state == Snapshot.State.GOAL:
			break
		m.tick()
	check(m.state == Snapshot.State.GOAL, "goal state")
	check(m.red_score == 1 and m.blue_score == 0, "red scored")
	for i in 200:
		m.tick()
	check(m.state == Snapshot.State.OVER, "score limit ends match")


func test_ball_bounces_off_side_line() -> void:
	var m := MatchSim.new(Stadium.classic(), 3, 0)
	var ball := m.ball()
	ball.set_position(0, 100)
	ball.vy = 7.4
	for i in 20:
		m.tick()
	check(ball.vy < 0.0, "bounced back")
	check(ball.y <= 170.0 - ball.radius + 0.01, "stayed on pitch")
	check(m.bounce_count >= 1, "bounce counted")


func test_elastic_disc_collision_swaps_velocity() -> void:
	var w := PhysicsWorld.new()
	var a := Disc.create(0, 0, 10, 1, 1, 1, 1, 1)
	var b := Disc.create(19, 0, 10, 1, 1, 1, 1, 1)
	a.vx = 2.0
	w.discs.append(a)
	w.discs.append(b)
	w.step()
	near(a.vx, 0.0, 1e-9, "a.vx")
	near(b.vx, 2.0, 1e-9, "b.vx")


func test_snapshot_round_trip() -> void:
	var m := MatchSim.new(Stadium.classic(), 3, 120)
	m.add_player(7, Team.RED)
	m.add_player(9, Team.BLUE)
	m.reset_positions()
	m.set_input(7, 1, 0, true)
	for i in 10:
		m.tick()
	var original := Snapshot.new()
	m.write_snapshot(original)
	var packet := Protocol.begin(Protocol.SNAPSHOT)
	Protocol.put_snapshot(packet, original)
	var reader := StreamPeerBuffer.new()
	check(Protocol.open(packet.data_array, reader) == Protocol.SNAPSHOT, "type")
	var copy := Snapshot.new()
	check(Protocol.get_snapshot(reader, copy), "decodes")
	check(copy.tick == original.tick and copy.player_count == 2, "header")
	check(copy.player_ids[1] == 9 and copy.player_teams[1] == Team.BLUE, "players")
	near(copy.player_x[0], original.player_x[0], 1e-3, "player x")
	check(copy.time_limit_seconds == 120, "time limit")


func test_auto_field_picks_big_for_three_a_side() -> void:
	check(HostSession.resolve_stadium(Session.FIELD_AUTO, 1, 1) == Stadium.SMALL, "1v1 small")
	check(HostSession.resolve_stadium(Session.FIELD_AUTO, 2, 2) == Stadium.SMALL, "2v2 small")
	check(HostSession.resolve_stadium(Session.FIELD_AUTO, 3, 2) == Stadium.BIG, "3v2 big")
	check(HostSession.resolve_stadium(Session.FIELD_AUTO, 4, 4) == Stadium.BIG, "4v4 big")
	check(HostSession.resolve_stadium(Session.FIELD_BIG, 1, 1) == Stadium.BIG, "forced big")
	check(HostSession.resolve_stadium(Session.FIELD_SMALL, 4, 4) == Stadium.SMALL, "forced small")


func test_big_field_goal() -> void:
	var m := MatchSim.new(Stadium.big(), 3, 0)
	m.add_player(1, Team.RED)
	m.reset_positions()
	check(m.player(1).disc.x == -280.0, "spawns on big field spawn line")
	var ball := m.ball()
	# Inside the big goal (half width 80) but outside the small one (64).
	ball.set_position(500, 70)
	ball.vx = 7.0
	for i in 40:
		if m.state == Snapshot.State.GOAL:
			break
		m.tick()
	check(m.state == Snapshot.State.GOAL and m.red_score == 1, "goal at y=70 on the big field")


func test_camera_stays_inside_field() -> void:
	var extent := Stadium.big().width * 2.0 + 8.0
	var visible := Vector2(848, 408)
	var big_extent := Vector2(extent, Stadium.big().height * 2.0 + 8.0)
	var c := FieldCamera.clamp_centre(Vector2(9999, -9999), visible, big_extent)
	near(c.x, (big_extent.x - visible.x) / 2.0, 1e-3, "clamped right")
	near(c.y, -(big_extent.y - visible.y) / 2.0, 1e-3, "clamped top")
	var small := Vector2(848, 408)
	c = FieldCamera.clamp_centre(Vector2(100, 50), Vector2(900, 450), small)
	check(c == Vector2.ZERO, "field smaller than view is centred")
	var cam := FieldCamera.new()
	var scale := cam.update(0.016, true, Vector2(-590, 0), Vector2(-590, 0), Vector2(1280, 650), big_extent, big_extent)
	near(scale, minf(1280.0 / 848.0, 650.0 / 368.0), 1e-4, "follow scale shows the small-field area")
	check(cam.centre.x - 1280.0 / scale / 2.0 >= -big_extent.x / 2.0 - 0.01, "left edge stays on the field")


# --- networking over real UDP sockets on this machine ------------------------

func _pump(condition: Callable, sessions: Array) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	var last := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			return false
		OS.delay_msec(5)
		var now := Time.get_ticks_msec()
		for s in sessions:
			s.update((now - last) / 1000.0, now)
		last = now
	return true


func test_host_and_clients_play_a_match() -> void:
	var host := HostSession.new("Host", "Test room")
	var now := Time.get_ticks_msec()
	var alice := ClientSession.new("127.0.0.1", host.port(), "Alice", now)
	var bob := ClientSession.new("127.0.0.1", host.port(), "Bob", now)
	var all := [host, alice, bob]

	check(_pump(func(): return alice.is_connected_to_room() and bob.is_connected_to_room() \
			and alice.players.size() == 3 and bob.players.size() == 3, all), "both joined")
	check(alice.room_name == "Test room", "room name")
	check(host.find_player(alice.local_player_id()).team == Team.BLUE, "alice balanced to blue")
	check(host.find_player(bob.local_player_id()).team == Team.RED, "bob balanced to red")

	bob.request_team(Team.SPECTATOR)
	check(_pump(func(): return alice.find_player(bob.local_player_id()).team == Team.SPECTATOR, all),
			"team change reaches others")

	host.start_game()
	check(_pump(func(): return alice.in_game() and alice.render_state() != null, all), "match starts")
	var first := alice.render_state()
	check(first.player_count == 2, "two players on the pitch")
	var start_x := first.player_x[first.index_of(alice.local_player_id())]

	# Alice (blue, right side) runs left; the host simulates it and sends it back.
	alice.set_local_input(-1, 0, false)
	check(_pump(func():
		var s := alice.render_state()
		var i := s.index_of(alice.local_player_id())
		return i >= 0 and s.player_x[i] < start_x - 30.0, all), "remote input moves player")

	host.stop_game()
	check(_pump(func(): return not alice.in_game() and not bob.in_game(), all), "back to lobby")

	bob.close()
	check(_pump(func(): return host.players.size() == 2, [host, alice]), "leave is noticed")

	host.close()
	check(_pump(func(): return not alice.closed_reason.is_empty(), [alice]), "host close reaches client")
	check(alice.closed_reason == "The host closed the room", "close reason")
	alice.close()


func test_field_choice_reaches_clients() -> void:
	var host := HostSession.new("Host", "Fields")
	var guest := ClientSession.new("127.0.0.1", host.port(), "Guest", Time.get_ticks_msec())
	check(_pump(func(): return guest.is_connected_to_room() and guest.players.size() == 2, [host, guest]), "joined")
	check(guest.stadium_id == Stadium.SMALL and guest.field_mode == Session.FIELD_AUTO, "auto small")
	host.set_field_mode(Session.FIELD_BIG)
	check(_pump(func(): return guest.stadium_id == Stadium.BIG and guest.field_mode == Session.FIELD_BIG,
			[host, guest]), "big choice reaches guest")
	host.start_game()
	check(_pump(func(): return guest.in_game() and guest.render_state() != null, [host, guest]), "starts")
	var s := guest.render_state()
	check(absf(s.player_x[0]) == 280.0, "players placed on the big field")
	guest.close()
	host.close()


func test_client_gives_up_without_room() -> void:
	var start := Time.get_ticks_msec()
	var lonely := ClientSession.new("127.0.0.1", 1, "Nobody", start)
	lonely.update(0, start)
	check(lonely.closed_reason.is_empty(), "still trying")
	lonely.update(0, start + 6000)
	check(lonely.closed_reason == "Could not reach the room", "gives up")


func test_discovery_finds_local_room() -> void:
	var host := HostSession.new("Host", "Findable")
	if not host.is_discoverable():
		print("  (discovery port busy; skipped)")
		host.close()
		return
	var discovery := LanDiscovery.new()
	var found = null
	var deadline := Time.get_ticks_msec() + 5000
	while found == null and Time.get_ticks_msec() < deadline:
		var now := Time.get_ticks_msec()
		host.update(0.005, now)
		discovery.update(now)
		for room in discovery.rooms():
			if room.name == "Findable" and room.port == host.port():
				found = room
		OS.delay_msec(5)
	check(found != null, "room discovered")
	if found != null:
		check(found.players == 1 and not found.in_game, "room info")
	discovery.close()
	host.close()
