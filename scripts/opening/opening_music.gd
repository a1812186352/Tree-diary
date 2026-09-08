extends Node
## One player survives cover -> video -> story scene changes.
const TRACK = preload("res://assets/audio/opening_dusk.mp3")
const VOLUME: float = 0.44
var player: AudioStreamPlayer
var fade: Tween

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "OpeningBGM"
	var stream: AudioStreamMP3 = TRACK.duplicate()
	stream.loop = true
	player.stream = stream
	player.volume_linear = 0.0
	add_child(player)

func start() -> void:
	# Changing story pages must not restart the track or its fade-in.
	if player.playing and not player.stream_paused and player.volume_linear > 0.0:
		return
	if fade != null:
		fade.kill()
	if player.stream_paused:
		player.stream_paused = false
	elif not player.playing:
		player.play()
	fade = create_tween()
	fade.tween_property(player, "volume_linear", VOLUME, 0.8)

func pause_for_gameplay() -> void:
	if fade != null:
		fade.kill()
	fade = create_tween()
	fade.tween_property(player, "volume_linear", 0.0, 0.8)
	fade.tween_callback(func(): player.stream_paused = true)
