extends Node
## One player survives cover -> video -> story scene changes.
const TRACK = preload("res://assets/audio/opening_dusk.mp3")
@onready var user_settings: Node = get_node("/root/UserSettings")
var player: AudioStreamPlayer
var fade: Tween
var gain: float = 0.0
var playback_requested: bool = false

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "OpeningBGM"
	var stream: AudioStreamMP3 = TRACK.duplicate()
	stream.loop = true
	player.stream = stream
	player.volume_linear = 0.0
	add_child(player)
	user_settings.audio_changed.connect(_apply_volume)

func _apply_volume() -> void:
	player.volume_linear = gain * user_settings.music_volume

func _set_gain(value: float) -> void:
	gain = value
	_apply_volume()

func start() -> void:
	# Changing story pages must not restart the track or its fade-in.
	if playback_requested and player.playing and not player.stream_paused:
		return
	playback_requested = true
	if fade != null:
		fade.kill()
	if player.stream_paused:
		player.stream_paused = false
	elif not player.playing:
		player.play()
	fade = create_tween()
	fade.tween_method(_set_gain, gain, 1.0, 0.8)

func pause_for_video() -> void:
	playback_requested = false
	if fade != null:
		fade.kill()
	_set_gain(0.0)
	player.stream_paused = true

func pause_for_gameplay() -> void:
	playback_requested = false
	if fade != null:
		fade.kill()
	fade = create_tween()
	fade.tween_method(_set_gain, gain, 0.0, 0.8)
	fade.tween_callback(func(): player.stream_paused = true)
