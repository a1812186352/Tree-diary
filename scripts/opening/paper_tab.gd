extends Button
## Opaque paper tabs: the artwork covers the video, including its corner marks.
var chapter: bool = false
var caption: String = ""
var ink_font: SystemFont

func _ready() -> void:
	ink_font = SystemFont.new()
	ink_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(queue_redraw)

func _draw() -> void:
	if ink_font == null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(216, 76))
	var shape := PackedVector2Array([Vector2(0, 0), Vector2(216, 0), Vector2(216, 76), Vector2(0, 76), Vector2(7, 38)])
	if chapter:
		shape = PackedVector2Array([Vector2(0, 0), Vector2(216, 0), Vector2(208, 38), Vector2(216, 76), Vector2(0, 76)])
	var shadow := PackedVector2Array()
	for point in shape:
		shadow.append(point + Vector2(2, 4))
	draw_colored_polygon(shadow, Color(0.35, 0.28, 0.18, 0.13))
	var fill := Color("e9ddc6") if chapter else Color("f1e6d2")
	if not chapter and (is_hovered() or has_focus()):
		fill = Color("fff3da")
	draw_colored_polygon(shape, fill)
	var border := shape.duplicate()
	border.append(shape[0])
	draw_polyline(border, Color("cbb99a"), 1.2, true)
	draw_line(Vector2(14, 10), Vector2(198, 10), Color("d9cbb2"), 1.0, true)
	draw_line(Vector2(14, 66), Vector2(198, 66), Color("d9cbb2"), 1.0, true)
	# Small olive leaf, kept separate from the caption for a handbound-book feel.
	draw_colored_polygon(PackedVector2Array([Vector2(24, 45), Vector2(22, 33), Vector2(29, 25), Vector2(40, 24), Vector2(40, 35), Vector2(33, 43)]), Color("929775"))
	draw_line(Vector2(21, 49), Vector2(36, 29), Color("68724e"), 1.4, true)
	draw_string(ink_font, Vector2(56, 46), caption, HORIZONTAL_ALIGNMENT_LEFT, 150, 24 if chapter else 21, Color("66583f"))
	if not chapter and has_focus():
		draw_rect(Rect2(10, 6, 196, 64), Color("9b875d"), false, 2.0)
	draw_set_transform(Vector2.ZERO)
