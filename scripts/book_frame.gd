extends CanvasLayer
## Persistent screen-space edge masks also contain the page-turn animation.
const Layout = preload("res://scripts/book_layout.gd")
var mode: String = "cover"
var ink: Node2D
var reveal_tween: Tween

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	ink = Node2D.new()
	add_child(ink)
	ink.draw.connect(_draw_frame)
	set_mode(mode)

func set_mode(value: String) -> void:
	if reveal_tween != null:
		reveal_tween.kill()
	mode = value
	if is_instance_valid(ink):
		ink.visible = mode != "cover"
		ink.modulate.a = 1.0
		ink.queue_redraw()

func reveal_reading() -> void:
	set_mode("reading")
	ink.modulate.a = 0.0
	reveal_tween = create_tween()
	reveal_tween.tween_property(ink, "modulate:a", 1.0, 0.3)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var window := get_window()
		window.mode = Window.MODE_WINDOWED if window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()

func _draw_frame() -> void:
	var r: Rect2 = Layout.CONTENT
	ink.draw_rect(Rect2(0, 0, 1920, r.position.y), Layout.DESK)
	ink.draw_rect(Rect2(0, r.end.y, 1920, 1080 - r.end.y), Layout.DESK)
	ink.draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), Layout.DESK)
	ink.draw_rect(Rect2(r.end.x, r.position.y, 1920 - r.end.x, r.size.y), Layout.DESK)
	var edge := StyleBoxFlat.new()
	edge.bg_color = Layout.PAPER
	edge.border_color = Layout.PAPER
	edge.draw_center = false
	edge.set_border_width_all(24)
	edge.set_corner_radius_all(18)
	edge.shadow_color = Color(0.24, 0.19, 0.12, 0.18)
	edge.shadow_size = 10
	edge.shadow_offset = Vector2(0, 7)
	edge.draw(ink.get_canvas_item(), Layout.BOOK)
	ink.draw_rect(Layout.BOOK.grow(-4), Color("cbbb9b"), false, 1.5)
	if mode != "cover":
		var strength: float = 0.025 if mode == "game" else 0.10
		for i in range(12):
			var alpha: float = strength * (1.0 - float(i) / 12.0)
			ink.draw_line(Vector2(960 - i * 2, 76), Vector2(960 - i * 2, 1004), Color(0.40, 0.32, 0.20, alpha), 2)
			ink.draw_line(Vector2(961 + i * 2, 76), Vector2(961 + i * 2, 1004), Color(0.40, 0.32, 0.20, alpha * 0.55), 2)
