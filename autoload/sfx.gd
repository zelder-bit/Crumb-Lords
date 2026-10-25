extends Node
## Reusable voices; loaded streams and missing-name warnings are cached.

const VOICES_2D := 12
const VOICES_3D := 16
var _players: Array[AudioStreamPlayer] = []
var _players_3d: Array[AudioStreamPlayer3D] = []
var _streams: Dictionary = {}
var _next_2d := 0
var _next_3d := 0


func _ready() -> void:
	for i in range(VOICES_2D):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_players.append(voice)
	for i in range(VOICES_3D):
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = 10.0
		voice.max_distance = 120.0
		add_child(voice)
		_players_3d.append(voice)


func _stream(sound_name: String) -> AudioStream:
	if _streams.has(sound_name):
		return _streams[sound_name] as AudioStream
	var path := "res://assets/sfx/%s.wav" % sound_name
	var stream: AudioStream = null
	if sound_name.is_valid_filename() and ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	_streams[sound_name] = stream
	if stream == null:
		push_warning("Sfx: missing sound '%s'" % sound_name)
	return stream


func play(sound_name: String, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	var stream := _stream(sound_name)
	if stream == null or _players.is_empty():
		return
	var index := _next_2d
	for offset in range(VOICES_2D):
		var candidate := (_next_2d + offset) % VOICES_2D
		if not _players[candidate].playing:
			index = candidate
			break
	var voice := _players[index]
	voice.stop()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = maxf(0.01, 1.0 + randf_range(-absf(pitch_jitter), absf(pitch_jitter)))
	voice.play()
	_next_2d = (index + 1) % VOICES_2D


func play_at(sound_name: String, pos: Vector3, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	var stream := _stream(sound_name)
	if stream == null or _players_3d.is_empty():
		return
	var index := _next_3d
	for offset in range(VOICES_3D):
		var candidate := (_next_3d + offset) % VOICES_3D
		if not _players_3d[candidate].playing:
			index = candidate
			break
	var voice := _players_3d[index]
	voice.stop()
	voice.stream = stream
	voice.global_position = pos
	voice.volume_db = volume_db
	voice.pitch_scale = maxf(0.01, 1.0 + randf_range(-absf(pitch_jitter), absf(pitch_jitter)))
	voice.play()
	_next_3d = (index + 1) % VOICES_3D
