extends Node
## Sound effects. Each sound has a small pool of players so overlapping hits do not cut off.

const SOUNDS := {
	"kick": "res://assets/sfx/kick.wav",
	"bounce": "res://assets/sfx/bounce.wav",
	"whistle": "res://assets/sfx/whistle.wav",
	"goal": "res://assets/sfx/goal.wav",
	"win": "res://assets/sfx/win.wav",
	"click": "res://assets/sfx/click.wav",
}
const VOICES := 3

var _players := {}
var _next := {}
var _crowd: AudioStreamPlayer


func _ready() -> void:
	for key in SOUNDS:
		if not ResourceLoader.exists(SOUNDS[key]):
			continue
		var stream: AudioStream = load(SOUNDS[key])
		var pool: Array[AudioStreamPlayer] = []
		for i in VOICES:
			var p := AudioStreamPlayer.new()
			p.stream = stream
			add_child(p)
			pool.append(p)
		_players[key] = pool
		_next[key] = 0
	if ResourceLoader.exists("res://assets/sfx/crowd_loop.wav"):
		_crowd = AudioStreamPlayer.new()
		_crowd.stream = load("res://assets/sfx/crowd_loop.wav")
		_crowd.volume_db = -14.0
		add_child(_crowd)


func play(key: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not Settings.sound_enabled or not _players.has(key):
		return
	var pool: Array = _players[key]
	var p: AudioStreamPlayer = pool[_next[key]]
	_next[key] = (_next[key] + 1) % pool.size()
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Background crowd murmur during a match.
func set_crowd(on: bool) -> void:
	if _crowd == null:
		return
	if on and Settings.sound_enabled and not _crowd.playing:
		_crowd.play()
	elif (not on or not Settings.sound_enabled) and _crowd.playing:
		_crowd.stop()
