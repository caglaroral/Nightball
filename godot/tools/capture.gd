extends SceneTree
## Saves screenshots of every screen, including a goal celebration, for visual review.
##   godot --path godot -s res://tools/capture.gd -- <output dir>
## Needs a display (not --headless).

var _out := "user://captures"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(2)
	var path := _out.path_join(name + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var net: Node = root.get_node("Net")
	var settings: Node = root.get_node("Settings")
	# Non-ASCII names check that Turkish glyphs render.
	settings.player_name = "Çağlar"

	change_scene_to_file("res://scenes/menu.tscn")
	await _frames(40)
	await _shot("1_menu")

	change_scene_to_file("res://scenes/browse.tscn")
	await _frames(90)
	await _shot("2_browse")

	net.host("Çağlar")
	var host: HostSession = net.session
	var guest := ClientSession.new("127.0.0.1", host.port(), "Deniz", Time.get_ticks_msec())
	var guest2 := ClientSession.new("127.0.0.1", host.port(), "Ece", Time.get_ticks_msec())
	var pump := func():
		guest.update(0.016, Time.get_ticks_msec())
		guest2.update(0.016, Time.get_ticks_msec())
	process_frame.connect(pump)
	change_scene_to_file("res://scenes/lobby.tscn")
	await _frames(60)
	await _shot("3_lobby")

	host.start_game()
	await _frames(30)
	await _shot("4_kickoff")

	# Push the ball towards the right goal so red scores.
	var sim: MatchSim = host._match
	sim.ball().set_position(250, 20)
	sim.ball().vx = 6.5
	sim.ball().vy = -0.4
	await _frames(14)
	await _shot("5_shot")
	await _frames(12)
	await _shot("6_goal")
	await _frames(40)
	await _shot("7_goal_later")

	host.stop_game()
	await _frames(20)
	host.set_field_mode(Session.FIELD_BIG)
	await _frames(30)
	await _shot("8_lobby_big")
	host.start_game()
	await _frames(40)
	await _shot("9_big_field")

	# A 20:9 phone screen, small field.
	host.stop_game()
	host.set_field_mode(Session.FIELD_SMALL)
	root.size = Vector2i(1600, 720)
	await _frames(20)
	host.start_game()
	await _frames(40)
	await _shot("10_phone_small")

	process_frame.disconnect(pump)
	guest.close()
	guest2.close()
	net.leave()
	quit()
