extends Node
## Persistent one-shot player keeps the paper sound intact across scene changes.
const PAPER_SOUND = preload("res://arsset/music/纸张翻页-厚重.mp3")
@onready var user_settings: Node = get_node("/root/UserSettings")
var player: AudioStreamPlayer

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "PaperTurnSound"
	var stream: AudioStreamMP3 = PAPER_SOUND.duplicate()
	stream.loop = false
	player.stream = stream
	add_child(player)
	user_settings.audio_changed.connect(_apply_volume)
	_apply_volume()

func _apply_volume() -> void:
	player.volume_linear = user_settings.effects_volume

func play_page(music_manager: Node = null) -> void:
	if music_manager != null:
		# Gameplay retains its existing effect volume, gain and mute settings.
		music_manager.play_effect("page")
		return
	_apply_volume()
	player.play()
