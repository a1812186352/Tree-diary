extends Node
## One runtime owner for audio preferences across every scene.
signal audio_changed

var music_volume: float = 0.4:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		audio_changed.emit()

var effects_volume: float = 0.7:
	set(value):
		effects_volume = clampf(value, 0.0, 1.0)
		audio_changed.emit()
