extends Control
## Shared reading page: complete art, transparent decoration, centered text.
const Layout = preload("res://scripts/book_layout.gd")
const FLORAL_FRAME = preload("res://assets/ui/reading_floral_frame.png")
const LINE_HEIGHT: float = 72.0
var illustration: TextureRect
var narration: Control
var font: SystemFont
var text_fade: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := ColorRect.new()
	paper.color = Layout.PAPER
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	illustration = TextureRect.new()
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	illustration.position = Layout.IMAGE.position
	illustration.size = Layout.IMAGE.size
	illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(illustration)
	var decoration := TextureRect.new()
	decoration.name = "FloralFrame"
	decoration.texture = FLORAL_FRAME
	decoration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	decoration.stretch_mode = TextureRect.STRETCH_SCALE
	decoration.position = Layout.CONTENT.position
	decoration.size = Layout.CONTENT.size
	decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(decoration)
	font = SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "楷体", "Microsoft YaHei", "Noto Sans CJK SC"])
	narration = Control.new()
	narration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(narration)

func show_page(texture: Texture2D, _title: String, body: String, animate: bool = true) -> void:
	illustration.texture = texture
	if text_fade != null:
		text_fade.kill()
	for child in narration.get_children():
		narration.remove_child(child)
		child.queue_free()
	var lines: PackedStringArray = body.split("\n")
	var block_height: float = lines.size() * LINE_HEIGHT
	narration.position = Vector2(1000, 540.0 - block_height * 0.5)
	narration.size = Vector2(800, block_height)
	# Keep authored line breaks and one common font size within each page.
	var text_size: int = 36
	for line in lines:
		var width: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		if width > 780.0:
			text_size = mini(text_size, maxi(1, int(floor(36.0 * 780.0 / width))))
	for index in range(lines.size()):
		var line_label := Label.new()
		line_label.text = lines[index]
		line_label.position = Vector2(0, index * LINE_HEIGHT)
		line_label.size = Vector2(800, LINE_HEIGHT)
		line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		line_label.add_theme_font_override("font", font)
		line_label.add_theme_font_size_override("font_size", text_size)
		line_label.add_theme_color_override("font_color", Color("705b40"))
		line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		narration.add_child(line_label)
	narration.modulate.a = 0.0
	if animate:
		reveal_text()

func reveal_text() -> void:
	if text_fade != null:
		text_fade.kill()
	text_fade = create_tween()
	text_fade.tween_property(narration, "modulate:a", 1.0, 0.45)
