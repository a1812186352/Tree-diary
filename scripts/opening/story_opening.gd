extends Control
## Keep the transition alive until the new scene is fully revealed.
@export var config: Resource
const TURN_SETTINGS = preload("res://config/mvp.tres")
const Layout = preload("res://scripts/book_layout.gd")
const ReadingSpread = preload("res://scripts/reading_spread.gd")

var page_index: int = 0
var busy: bool = true
var content: Control
var spread: Control
var next_button: Button
var page_number: Label
var veil: ColorRect
var turn: CanvasLayer
var game: Node
var game_music: Node
var original_mute: bool = false

func _ready() -> void:
	get_node("/root/OpeningMusic").start()
	if config == null:
		config = preload("res://config/story.tres")
	get_node("/root/BookFrame").set_mode("cover")
	content = Control.new()
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.gui_input.connect(_on_page_input)
	spread = ReadingSpread.new()
	content.add_child(spread)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	next_button = Button.new()
	next_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	next_button.add_theme_font_override("font", font)
	next_button.add_theme_font_size_override("font_size", 25)
	next_button.add_theme_color_override("font_color", Color("725c3f"))
	next_button.add_theme_color_override("font_hover_color", Color("475d36"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("eee2c9") if state == "hover" else Color("f6f1e6")
		style.set_corner_radius_all(18)
		next_button.add_theme_stylebox_override(state, style)
	next_button.pressed.connect(_advance)
	content.add_child(next_button)
	page_number = Label.new()
	page_number.add_theme_font_override("font", font)
	page_number.add_theme_font_size_override("font_size", 22)
	page_number.add_theme_color_override("font_color", Color("998362"))
	page_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(page_number)
	veil = ColorRect.new()
	veil.color = config.paper_color
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	turn = preload("res://scripts/page_turn.gd").new()
	add_child(turn)
	turn.covered.connect(_on_covered)
	turn.finished.connect(_on_finished)
	resized.connect(_layout)
	_layout()
	_show_page()
	next_button.disabled = true
	var fade := create_tween()
	fade.tween_property(veil, "modulate:a", 0.0, 0.5)
	await fade.finished
	veil.hide()
	get_node("/root/BookFrame").reveal_reading()
	spread.reveal_text()
	busy = false
	next_button.disabled = false

func _layout() -> void:
	next_button.position = Layout.NEXT.position
	next_button.size = Layout.NEXT.size
	page_number.position = Layout.PAGE_NUMBER.position
	page_number.size = Layout.PAGE_NUMBER.size

func _show_page() -> void:
	var title: String = ""
	var body: String = config.page_narrations[page_index] if page_index < config.page_narrations.size() else ""
	spread.show_page(config.pages[page_index], title, body, false)
	page_number.text = "%d / %d" % [page_index + 1, config.pages.size()]
	next_button.text = "进入第一天  ›" if page_index == config.pages.size() - 1 else "翻到下一页  ›"

func _on_page_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Layout.contains(event.position):
		accept_event()
		_advance()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_RIGHT]:
			get_viewport().set_input_as_handled()
			_advance()

func _advance() -> void:
	if busy:
		return
	busy = true
	next_button.disabled = true
	next_button.release_focus()
	turn.play(TURN_SETTINGS.page_duration, TURN_SETTINGS.swap_progress,
		config.paper_color, TURN_SETTINGS.page_curl_strength, TURN_SETTINGS.page_shadow_strength,
		TURN_SETTINGS.page_grain_strength)

func _on_covered() -> void:
	if page_index + 1 < config.pages.size():
		page_index += 1
		_show_page()
		return
	# Build Day 1 beneath opaque paper. Disabled processing also blocks input
	# and prevents the first day's clock from running during the reveal.
	game = config.next_scene.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game_music = game.get_node_or_null("Systems/MusicManager")
	if game_music != null:
		original_mute = game_music.muted
		game_music.muted = true
	get_tree().root.add_child(game)
	content.hide()

func _on_finished() -> void:
	if game != null:
		get_node("/root/OpeningMusic").pause_for_gameplay()
		get_tree().current_scene = game
		game.process_mode = Node.PROCESS_MODE_INHERIT
		if game_music != null:
			game_music.muted = original_mute
		queue_free()
		return
	spread.reveal_text()
	busy = false
	next_button.disabled = false
