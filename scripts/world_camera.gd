extends Camera2D
## View-only transform: branch positions and gameplay distances stay in world units.
signal view_changed
@export var minimum_zoom: float = 0.45
@export var maximum_zoom: float = 1.5
@export var zoom_step: float = 1.12
var dragging: bool = false
var home: Vector2 = Vector2(960, 540)
var travel_bounds := Rect2(-1800, -3000, 5520, 4200)

func _ready() -> void:
	position = home
	position_smoothing_enabled = false
	make_current()
	force_update_scroll()

func screen_to_world(point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * point

func world_to_screen(point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * point

func visible_world_rect() -> Rect2:
	var top_left := screen_to_world(Vector2.ZERO)
	return Rect2(top_left, screen_to_world(get_viewport_rect().size) - top_left)

func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			if event.pressed and event.double_click:
				reset_view()
				dragging = false
			return true
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before := screen_to_world(event.position)
			var multiplier: float = zoom_step if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / zoom_step
			zoom = Vector2.ONE * clampf(zoom.x * multiplier, minimum_zoom, maximum_zoom)
			force_update_scroll()
			position += before - screen_to_world(event.position)
			_commit_view()
			return true
	if event is InputEventMouseMotion and dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			dragging = false
			return false
		position -= event.relative / zoom
		_commit_view()
		return true
	return false

func reset_view() -> void:
	position = home
	zoom = Vector2.ONE
	_commit_view()

func _commit_view() -> void:
	position = position.clamp(travel_bounds.position, travel_bounds.end)
	force_update_scroll()
	view_changed.emit()
