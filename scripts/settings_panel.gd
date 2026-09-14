extends Control
signal closed

const HOVER_SOUND = preload("res://arsset/music/UI-按钮点击.mp3")
const CONTENT_LEFT: float = 660.0
const CONTENT_WIDTH: float = 600.0
var config: Resource = preload("res://config/mvp.tres")
@onready var user_settings: Node = get_node("/root/UserSettings")
var font: SystemFont
var content: Control
var showing_help: bool = false
var hover_player: AudioStreamPlayer
var last_hover_ms: int = -1000

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	user_settings.audio_changed.connect(_apply_hover_volume)
	_rebuild()

func back() -> void:
	if showing_help:
		showing_help = false
		_rebuild()
	else:
		closed.emit()

func _rebuild() -> void:
	if is_instance_valid(content):
		remove_child(content)
		content.queue_free()
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if showing_help:
		var rows: Array = [
			["左键", "收集资源；拖放枝条"],
			["移动鼠标 / F", "吸附芽点后：旋转 / 镜像"],
			["右键", "取消拖动；取回当天枝条"],
			["滚轮 / 中键拖动", "缩放 / 移动视野"],
			["双击中键 / F11", "复位视野 / 全屏"],
			["Esc", "暂停 / 返回；取消动物拖动"],
			["顶部 1× / 2×", "切换游戏速度"],
			["动物换位", "黄昏/夜晚：拖动停驻动物，期间暂停"]]
		for i in range(rows.size()):
			var y: float = 326 + i * 48
			_help_label(rows[i][0], Vector2(CONTENT_LEFT, y), 180)
			_help_label(rows[i][1], Vector2(CONTENT_LEFT + 190, y), CONTENT_WIDTH - 190)
	else:
		_slider("刷怪速度（倍）", 360, 0.5, 2.0, 0.1, config.pest_spawn_multiplier, "pest_spawn_multiplier", 1.0)
		_slider("背景音乐音量", 460, 0, 100, 1, user_settings.music_volume * 100, "music_volume", 100.0, user_settings)
		_slider("音效音量", 560, 0, 100, 1, user_settings.effects_volume * 100, "effects_volume", 100.0, user_settings)
		_button("操作说明", 660, func():
			showing_help = true
			_rebuild())
	_button("返回设置" if showing_help else "返回", 738, back)
	queue_redraw()

func _label(text: String, point: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = point
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("54654f"))
	content.add_child(label)
	return label

func _help_label(text: String, point: Vector2, width: float) -> void:
	var label: Label = _label(text, point, 20)
	label.size.x = width
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_constant_override("line_spacing", 0)

func _slider(title: String, y: float, low: float, high: float, step_size: float, value: float, property: String, divisor: float, target: Object = null) -> void:
	var destination: Object = target if target != null else config
	var label: Label = _label("%s  %.1f" % [title, value], Vector2(CONTENT_LEFT, y), 22)
	var slider := HSlider.new()
	slider.position = Vector2(CONTENT_LEFT, y + 38)
	slider.size = Vector2(CONTENT_WIDTH, 30)
	slider.min_value = low
	slider.max_value = high
	slider.step = step_size
	slider.value = value
	slider.value_changed.connect(func(next: float):
		label.text = "%s  %.1f" % [title, next]
		destination.set(property, next / divisor))
	content.add_child(slider)

func _button(text: String, y: float, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.position = Vector2(800, y)
	button.size = Vector2(320, 60)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color("54654f"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("eee2c9") if state == "normal" else Color("fff0c4")
		style.border_color = Color("b88f3a")
		style.set_border_width_all(2)
		style.set_corner_radius_all(14)
		button.add_theme_stylebox_override(state, style)
	button.mouse_entered.connect(func():
		if button.is_visible_in_tree() and not button.disabled:
			_play_hover())
	button.pressed.connect(callback)
	content.add_child(button)

func _play_hover() -> void:
	var scene: Node = get_tree().current_scene
	var music: Node = scene.get_node_or_null("Systems/MusicManager") if scene != null else null
	if music != null:
		music.play_effect("hover")
		return
	var now: int = Time.get_ticks_msec()
	if now - last_hover_ms < 100:
		return
	last_hover_ms = now
	if not is_instance_valid(hover_player):
		hover_player = AudioStreamPlayer.new()
		var stream: AudioStreamMP3 = HOVER_SOUND.duplicate()
		stream.loop = false
		hover_player.stream = stream
		add_child(hover_player)
	_apply_hover_volume()
	hover_player.play()

func _apply_hover_volume() -> void:
	if is_instance_valid(hover_player):
		hover_player.volume_linear = user_settings.effects_volume * 0.45

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.25, 0.28, 0.22, 0.55))
	var rect := Rect2(460, 220, 1000, 640)
	if config.panel_texture != null:
		var dimensions: Vector2 = config.panel_texture.get_size()
		var fit: float = minf(rect.size.x / dimensions.x, rect.size.y / dimensions.y)
		dimensions *= fit
		draw_texture_rect(config.panel_texture, Rect2(rect.position + (rect.size - dimensions) * 0.5, dimensions), false)
	else:
		draw_rect(rect, Color("faf6e8"))
	var title: String = "操作说明" if showing_help else "设置"
	var origin := Vector2(780, 180)
	var dimensions := Vector2(360, 100)
	if config.title_banner_texture != null:
		dimensions.y = 360.0 * config.title_banner_texture.get_height() / config.title_banner_texture.get_width()
		origin = rect.position + Vector2((rect.size.x - dimensions.x) * 0.5, -dimensions.y * 0.35)
		draw_texture_rect(config.title_banner_texture, Rect2(origin, dimensions), false)
	var width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(font, origin + Vector2((dimensions.x - width) * 0.5, dimensions.y * 0.7), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("54654f"))
