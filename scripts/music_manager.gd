extends Node
## Music and event sounds; editor preview never plays audio.

@export_group("场景音乐（拖入音频）")
@export var day_music: AudioStream
@export var dusk_music: AudioStream
@export var night_music: AudioStream
@export var page_turn_music: AudioStream
@export var win_music: AudioStream
@export var lose_music: AudioStream
@export var extra_music: Dictionary[String, AudioStream] = {}
@export_group("播放设置")
@export_range(0.0, 1.0, 0.01) var music_volume: float = 0.7:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_apply_volume()
@export var muted: bool = false:
	set(value):
		muted = value
		_apply_volume()
@export_range(0.0, 5.0, 0.1) var fade_seconds: float = 1.0
@export var loop_music: bool = true
@export_group("场景音效")
@export var effects: Dictionary[String, AudioStream] = {}
@export_range(0.0, 1.0) var effects_volume: float = 0.75:
	set(value):
		effects_volume = clampf(value, 0, 1)
		for player in _effect_players:
			player.volume_linear = effects_volume * player.get_meta("effect_gain", 1.0)
@export var effect_gains: Dictionary[String, float] = {"hover": 0.45, "throw": 0.6}
var _effect_players: Array[AudioStreamPlayer] = []
var _last_hover_ms: int = -1000

var current_context: String = ""
var _players: Array[AudioStreamPlayer] = []
var _gains: Array[float] = [0.0, 0.0]
var _active: int = 0
var _fade: Tween

func _ready() -> void:
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % (i + 1)
		add_child(player)
		_players.append(player)
		player.finished.connect(_on_finished.bind(i))
	_apply_volume()
	for i in range(12):
		var player := AudioStreamPlayer.new()
		player.name = "EffectPlayer%d" % i
		add_child(player)
		_effect_players.append(player)
	var animals: Node = get_node_or_null("../CompanionSystem")
	if animals != null:
		animals.sound_requested.connect(play_effect)
	var phase: Node = get_node_or_null("../PhaseManager")
	if phase != null:
		phase.changed.connect(_on_phase_changed)
		_on_phase_changed(phase.phase)

func _on_phase_changed(next: String) -> void:
	if next == "GAMEOVER":
		var phase: Node = get_node("../PhaseManager")
		play_context("WIN" if phase.result == "WIN" else "LOSE")
	else:
		play_context(next)

## Additional gameplay scenes may call play_context("CUSTOM_NAME").
func play_context(context: String) -> void:
	current_context = context
	var tracks: Dictionary = {
		"DAY": day_music, "DUSK": dusk_music, "NIGHT": night_music,
		"PAGE_TURN": page_turn_music, "WIN": win_music, "LOSE": lose_music,
	}
	var track: AudioStream = tracks.get(context, extra_music.get(context))
	play_stream(track)

func play_stream(track: AudioStream, restart: bool = false) -> void:
	if _players.is_empty():
		return
	if not restart and track != null and _players[_active].stream == track and _players[_active].playing:
		return
	if _fade != null:
		_fade.kill()
	var outgoing: int = _active
	_active = 1 - _active
	_players[_active].stop()
	_players[_active].stream = track
	_set_gain(0.0, _active)
	if track != null:
		_players[_active].play()
	if fade_seconds <= 0.0:
		_set_gain(0.0, outgoing)
		_players[outgoing].stop()
		_set_gain(1.0 if track != null else 0.0, _active)
		return
	_fade = create_tween().set_parallel(true)
	_fade.tween_method(_set_gain.bind(outgoing), _gains[outgoing], 0.0, fade_seconds)
	_fade.tween_method(_set_gain.bind(_active), 0.0, 1.0 if track != null else 0.0, fade_seconds)
	_fade.chain().tween_callback(_players[outgoing].stop)

func stop_music() -> void:
	current_context = ""
	play_stream(null)

func _set_gain(value: float, index: int) -> void:
	_gains[index] = value
	_apply_volume()

func _apply_volume() -> void:
	for i in range(_players.size()):
		_players[i].volume_linear = 0.0 if muted else music_volume * _gains[i]

func _on_finished(index: int) -> void:
	if loop_music and index == _active and _players[index].stream != null:
		_players[index].play()

func _process(_delta: float) -> void:
	if not loop_music or _players.is_empty() or (_fade != null and _fade.is_running()):
		return
	var player: AudioStreamPlayer = _players[_active]
	if player.stream == null or not player.playing:
		return
	var length: float = player.stream.get_length()
	# Overlap the tail with the next beginning, avoiding an abrupt loop seam.
	if length > fade_seconds * 2.0 and player.get_playback_position() >= length - fade_seconds:
		play_stream(player.stream, true)

func play_effect(event: String) -> void:
	var stream: AudioStream = effects.get(event)
	if stream == null or muted:
		return
	if event == "hover":
		var now: int = Time.get_ticks_msec()
		if now - _last_hover_ms < 100:
			return
		_last_hover_ms = now
	for player in _effect_players:
		if not player.playing:
			player.stream = stream
			player.set_meta("effect_gain", effect_gains.get(event, 1.0))
			player.volume_linear = effects_volume * effect_gains.get(event, 1.0)
			player.play()
			return
	# Keep combat bursts bounded; recycle the oldest available slot.
	var player: AudioStreamPlayer = _effect_players.pop_front()
	player.stop()
	player.stream = stream
	player.set_meta("effect_gain", effect_gains.get(event, 1.0))
	player.volume_linear = effects_volume * effect_gains.get(event, 1.0)
	player.play()
	_effect_players.append(player)
