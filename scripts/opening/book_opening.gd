extends Control
const Layout = preload("res://scripts/book_layout.gd")
## Self-contained opening. Connect opening_finished to the future story sequence.
signal opening_finished

enum Stage { COVER, STARTING, PLAYING, PAPER }
@export var config: Resource
var media_dimensions := Vector2(960, 720)

var stage: Stage = Stage.COVER
var video: VideoStreamPlayer
var cover: TextureRect
var paper: ColorRect
var read_button: Button
var return_button: Button
var error_label: Label
var playback_wait: float = 0.0
var fade_started: bool = false
var paper_transition: Tween
var hover_transition: Tween
var button_transition: Tween
var cover_transition: Tween
var chapter_tab: Button
var skip_button: Button
var backdrop_material: ShaderMaterial

func _ready() -> void:
	get_node("/root/OpeningMusic").start()
	get_node("/root/BookFrame").set_mode("cover")
	if config == null:
		config = load("res://config/opening.tres")
	if config.cover_texture != null:
		media_dimensions = config.cover_texture.get_size()
	var background := ColorRect.new()
	background.color = config.paper_color
	_full_rect(background)
	add_child(background)
	# Average broad paper areas once; render a smooth gradient without carrying
	# the image grain or video compression blocks into the side margins.
	var backdrop := TextureRect.new()
	backdrop.name = "MatchedPaperBackdrop"
	backdrop.texture = config.cover_texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop_material = ShaderMaterial.new()
	backdrop_material.shader = preload("res://shaders/opening_backdrop.gdshader")
	_configure_paper_gradient()
	backdrop.material = backdrop_material
	_full_rect(backdrop)
	add_child(backdrop)
	video = VideoStreamPlayer.new()
	video.name = "OpeningVideo"
	video.expand = true
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video.stream = config.video_stream
	video.volume = config.video_volume
	video.finished.connect(_finish_to_paper)
	add_child(video)
	cover = TextureRect.new()
	cover.name = "MatchedCover"
	cover.texture = config.cover_texture
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_SCALE
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	var tab_script = preload("res://scripts/opening/paper_tab.gd")
	chapter_tab = tab_script.new()
	chapter_tab.name = "ChapterPaperTab"
	chapter_tab.chapter = true
	chapter_tab.caption = config.chapter_text
	chapter_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chapter_tab.focus_mode = Control.FOCUS_NONE
	add_child(chapter_tab)
	skip_button = tab_script.new()
	skip_button.name = "SkipOpening"
	skip_button.caption = config.skip_text
	skip_button.tooltip_text = "跳过视频，进入下一页"
	skip_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skip_button.pressed.connect(_skip_opening)
	add_child(skip_button)
	paper = ColorRect.new()
	paper.name = "PaperTransition"
	paper.color = config.paper_color
	paper.modulate.a = 0.0
	_full_rect(paper)
	add_child(paper)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	read_button = Button.new()
	read_button.name = "StartReading"
	read_button.text = config.button_text
	read_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	read_button.add_theme_font_override("font", font)
	read_button.add_theme_font_size_override("font_size", 32)
	read_button.add_theme_color_override("font_color", Color("62553f"))
	read_button.add_theme_color_override("font_hover_color", Color("51442e"))
	read_button.add_theme_color_override("font_pressed_color", Color("51442e"))
	for state_name in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("fff9eb") if state_name == "hover" else Color("f6ecda")
		style.border_color = Color("b5a080") if state_name == "focus" else Color("d8c8ab")
		style.set_border_width_all(2 if state_name == "focus" else 1)
		style.set_corner_radius_all(5)
		style.shadow_color = Color(0.30, 0.24, 0.15, 0.14)
		style.shadow_size = 12
		style.shadow_offset = Vector2(2, 5)
		read_button.add_theme_stylebox_override(state_name, style)
	read_button.pressed.connect(_start_reading)
	read_button.mouse_entered.connect(_hover.bind(true))
	read_button.mouse_exited.connect(_hover.bind(false))
	add_child(read_button)
	return_button = Button.new()
	return_button.name = "ReturnToCover"
	return_button.text = "返回封面"
	return_button.flat = true
	return_button.visible = false
	return_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return_button.add_theme_font_override("font", font)
	return_button.add_theme_font_size_override("font_size", 23)
	return_button.add_theme_color_override("font_color", Color("93856c"))
	return_button.pressed.connect(_return_to_cover)
	add_child(return_button)
	error_label = Label.new()
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_font_override("font", font)
	error_label.add_theme_font_size_override("font_size", 24)
	error_label.add_theme_color_override("font_color", Color("62553f"))
	add_child(error_label)
	resized.connect(_layout_media)
	_layout_media()
	if video.stream == null or cover.texture == null:
		error_label.text = "开场素材未能载入，请确认 assets/opening 文件夹完整。"
		read_button.disabled = true
	print("OPENING_READY")

func _configure_paper_gradient() -> void:
	if config.cover_texture == null:
		return
	var source: Image = config.cover_texture.get_image()
	if source == null or source.is_empty():
		return
	if source.is_compressed() and source.decompress() != OK:
		return
	var regions := {
		"top_left": Rect2(0.0, 0.02, 0.025, 0.30),
		"bottom_left": Rect2(0.0, 0.68, 0.025, 0.30),
		"top_right": Rect2(0.975, 0.02, 0.025, 0.30),
		"bottom_right": Rect2(0.975, 0.68, 0.025, 0.30),
	}
	for parameter in regions:
		var region: Rect2 = regions[parameter]
		var total := Color(0, 0, 0, 0)
		for y in range(32):
			for x in range(8):
				var uv: Vector2 = region.position + region.size * Vector2((x + 0.5) / 8.0, (y + 0.5) / 32.0)
				total += source.get_pixel(mini(int(uv.x * source.get_width()), source.get_width() - 1), mini(int(uv.y * source.get_height()), source.get_height() - 1))
		var average: Color = total / 256.0
		average.a = 1.0
		backdrop_material.set_shader_parameter(parameter, average)

func _full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _layout_media() -> void:
	# A single aspect-preserving rectangle for both poster and video: no jump.
	var area := Rect2(Vector2.ZERO, size)
	var media_scale: float = minf(area.size.x / media_dimensions.x, area.size.y / media_dimensions.y)
	var media_size: Vector2 = media_dimensions * media_scale
	var media_position: Vector2 = area.position + (area.size - media_size) * 0.5
	if size.x > 0.0 and size.y > 0.0:
		backdrop_material.set_shader_parameter("media_rect", Vector4(
			media_position.x / size.x, media_position.y / size.y,
			media_size.x / size.x, media_size.y / size.y))
	video.position = media_position
	video.size = media_size
	cover.position = media_position
	cover.size = media_size
	chapter_tab.position = media_position + media_size * config.chapter_rect_uv.position
	chapter_tab.size = media_size * config.chapter_rect_uv.size
	skip_button.position = media_position + media_size * config.skip_rect_uv.position
	skip_button.size = media_size * config.skip_rect_uv.size
	read_button.size = media_size * config.button_size_uv
	read_button.position = media_position + media_size * config.button_position_uv
	read_button.pivot_offset = read_button.size * 0.5
	return_button.position = Vector2(1630, 926)
	return_button.size = Vector2(170, 48)
	error_label.position = Vector2(160, 946)
	error_label.size = Vector2(1400, 50)

func _hover(entered: bool) -> void:
	if stage != Stage.COVER:
		return
	if hover_transition:
		hover_transition.kill()
	hover_transition = create_tween()
	hover_transition.tween_property(read_button, "scale", Vector2.ONE * (1.025 if entered else 1.0), 0.18)

func _start_reading() -> void:
	if stage != Stage.COVER or read_button.disabled:
		return
	stage = Stage.STARTING
	read_button.disabled = true
	error_label.text = ""
	button_transition = create_tween()
	button_transition.tween_property(read_button, "modulate:a", 0.0, 0.22)
	await button_transition.finished
	if stage != Stage.STARTING:
		return
	read_button.hide()
	playback_wait = 0.0
	video.play()
	print("OPENING_PLAY_REQUESTED")

func _process(delta: float) -> void:
	if stage == Stage.STARTING and not read_button.visible:
		playback_wait += delta
		# Keep the matching still over the decoder until a frame is available.
		if video.is_playing() and video.stream_position > 0.0:
			stage = Stage.PLAYING
			cover_transition = create_tween()
			cover_transition.tween_property(cover, "modulate:a", 0.0, 0.10)
			print("OPENING_VIDEO_LIVE")
		elif playback_wait > 5.0:
			_return_to_cover()
			error_label.text = "视频暂时未能播放，请点击开始阅读重试。"
	if stage == Stage.PLAYING and not fade_started and video.stream_position >= config.video_duration - 0.28:
		_finish_to_paper()

func _finish_to_paper() -> void:
	if fade_started or stage not in [Stage.STARTING, Stage.PLAYING]:
		return
	fade_started = true
	skip_button.disabled = true
	skip_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper_transition = create_tween()
	paper_transition.set_parallel(true)
	paper_transition.tween_property(paper, "modulate:a", 1.0, 0.55)
	paper_transition.tween_property(video, "volume", 0.0, 0.55)
	await paper_transition.finished
	video.stop()
	stage = Stage.PAPER
	print("OPENING_PAPER_READY")
	opening_finished.emit()
	if not config.next_scene.is_empty():
		var change_error := get_tree().change_scene_to_file(config.next_scene)
		if change_error != OK:
			error_label.text = "下一页暂时无法打开。"
			return_button.show()
	else:
		# Standalone review only; the future story scene takes over this paper.
		return_button.show()

func _skip_opening() -> void:
	if stage == Stage.PAPER or fade_started:
		return
	if button_transition:
		button_transition.kill()
	read_button.hide()
	read_button.disabled = true
	stage = Stage.PLAYING
	_finish_to_paper()

func _return_to_cover() -> void:
	if button_transition:
		button_transition.kill()
	if cover_transition:
		cover_transition.kill()
	if hover_transition:
		hover_transition.kill()
	if paper_transition:
		paper_transition.kill()
	video.stop()
	video.volume = config.video_volume
	skip_button.disabled = false
	skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
	stage = Stage.COVER
	fade_started = false
	cover.modulate.a = 1.0
	paper.modulate.a = 0.0
	read_button.modulate.a = 1.0
	read_button.disabled = false
	read_button.scale = Vector2.ONE
	read_button.show()
	return_button.hide()
	error_label.text = ""
	print("OPENING_RETURNED")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and stage != Stage.COVER:
			_return_to_cover()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_ENTER, KEY_SPACE] and stage == Stage.COVER:
			_start_reading()
			get_viewport().set_input_as_handled()
