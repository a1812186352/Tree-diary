@tool
extends Node2D
const Layout = preload("res://scripts/book_layout.gd")
const ReadingSpread = preload("res://scripts/reading_spread.gd")

@export var config: Resource
@export_group("编辑器预览（不影响游戏）")
@export_enum("DAY", "DUSK", "NIGHT") var editor_phase: String = "DAY"
@export var editor_show_actors: bool = false
@onready var phase: Node = $Systems/PhaseManager
@onready var resources: Node = $Systems/ResourceSystem
@onready var growth: Node = $Systems/GrowthSystem
@onready var animals: Node = $Systems/CompanionSystem
@onready var branches: Node2D = $World/Branches
@onready var foliage: Node2D = $World/FoliageSystem
@onready var anchors: Node2D = $World/Anchors
@onready var overlay: Node2D = $HUD/Overlay
@onready var world_camera: Camera2D = $WorldCamera
var hearts: int = 3
var selected_kind: int = -1
var preview: Node2D
var preview_mirrored: bool = false
var preview_angle: float = 0.0
var candidate: Node2D
var pointer := Vector2.ZERO
var dragging: bool = false
var animal_drag: Dictionary = {}
var animal_drag_offset: Vector2 = Vector2.ZERO
var animal_drop_node: Node2D
var status: String = "点击收集阳光与水滴，再把枝条拖到芽点"
var hint_time: float = 0
var page_swapped: bool = false
var page_turn: CanvasLayer
var buttons: Array[Button] = []
var time_scale: float = 1.0
var game_speed: float = 1.0
var speed_button: Button
var sky_previous: String = "DAY"
var sky_current: String = "DAY"
var sky_progress: float = 1
var pocket_shake: float = 0
var damage_marks: int = 0
var collection_flights: Array[Dictionary] = []
var placement_lock: float = 0
var clock_time: float = 0.0
var title_font: SystemFont
enum MenuMode { NONE, PAUSED, SETTINGS, RESTART_CONFIRM }
var menu_mode: int = MenuMode.NONE
var menu_buttons: Array[Button] = []
var settings_controls: Array[Control] = []
var settings_panel: Control

func _ready() -> void:
	if config == null:
		config = preload("res://config/mvp.tres")
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	if Engine.is_editor_hint():
		return
	get_node("/root/BookFrame").set_mode("game")
	page_turn = preload("res://scripts/page_turn.gd").new()
	page_turn.name = "PageTurn"
	add_child(page_turn)
	page_turn.covered.connect(_prepare_next_page)
	page_turn.finished.connect(_finish_next_page)
	growth.config = config
	growth.branch_root = branches
	growth.resources = resources
	growth.animals = animals
	animals.config = config
	animals.anchors = anchors
	animals.branch_root = branches
	foliage.setup(config, branches)
	hearts = config.max_hearts
	phase.changed.connect(_on_phase_changed)
	growth.placed.connect(_on_branch_placed)
	animals.pest_hit.connect(_on_pest_hit)
	_build_ui()
	world_camera.view_changed.connect(_on_view_changed)
	_on_phase_changed("DAY")
	_draw_land()

func _on_view_changed() -> void:
	pointer = world_camera.screen_to_world(get_viewport().get_mouse_position())
	_update_preview()
	_update_animal_drag(get_viewport().get_mouse_position())
	queue_redraw()
	overlay.queue_redraw()

func _build_ui() -> void:
	var labels := ["单芽枝条", "双芽枝条", "三芽枝条"]
	for i in range(3):
		var button := Button.new()
		button.name = "BranchChoice%d" % (i + 1)
		button.text = ""
		button.tooltip_text = labels[i]
		var card_rect: Rect2 = overlay.tray_card_rect(i)
		button.position = card_rect.position
		button.size = card_rect.size
		button.add_theme_font_override("font", title_font)
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_color_override("font_color", Color("54654f"))
		_apply_tray_style(button, false)
		button.button_down.connect(_select_branch.bind(i))
		$UI.add_child(button)
		buttons.append(button)
	var retry := Button.new()
	retry.name = "Restart"
	retry.text = "再种一棵"
	var restart_anchor: Marker2D = $UI.get_node_or_null("RestartAnchor")
	if restart_anchor != null:
		retry.position = restart_anchor.position
	else:
		retry.position = Vector2(820, 650)
	retry.size = Vector2(280, 66)
	retry.add_theme_font_override("font", title_font)
	retry.add_theme_font_size_override("font_size", 28)
	retry.pressed.connect(func(): get_tree().reload_current_scene())
	retry.visible = false
	retry.z_index = 20
	$UI.add_child(retry)
	_build_menu_buttons()
	_hide_menu()

func _bind_ui_audio(button: Button) -> void:
	if button.has_meta("hover_audio_bound"):
		return
	button.set_meta("hover_audio_bound", true)
	button.mouse_entered.connect(func():
		if button.is_visible_in_tree() and not button.disabled:
			$Systems/MusicManager.play_effect("hover"))

func _apply_tray_style(button: Button, selected: bool) -> void:
	_bind_ui_audio(button)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		var is_idle: bool = state in ["normal", "disabled", "focus"]
		if selected:
			style.bg_color = Color(0.99, 0.93, 0.65, 0.25) if not is_idle else Color(0.99, 0.93, 0.65, 0.15)
			style.border_color = Color("b88f3a")
			style.set_border_width_all(3 if state == "pressed" else 2)
		else:
			style.bg_color = Color(1, 1, 1, 0) if is_idle else Color(1, 1, 0.85, 0.18)
			style.border_color = Color("d0d6bc")
			style.set_border_width_all(0)
		style.set_corner_radius_all(16)
		button.add_theme_stylebox_override(state, style)

func _refresh_tray_styles() -> void:
	for i in range(buttons.size()):
		_apply_tray_style(buttons[i], selected_kind == i and phase.phase == "DAY")

func _build_menu_buttons() -> void:
	# Top-bar icon buttons (pause / settings). Each uses a TextureRect + Button on top.
	var top_anchors := [Vector2(1768, 88), Vector2(1698, 88)]
	var top_icons: Array[Texture2D] = [config.icon_pause, config.icon_settings]
	var top_actions: Array[String] = ["open_pause", "open_settings"]
	var top_tooltips: Array[String] = ["暂停", "设置"]
	for i in range(2):
		var btn := Button.new()
		btn.name = "TopBarBtn%d" % i
		btn.tooltip_text = top_tooltips[i]
		btn.position = top_anchors[i]
		btn.size = Vector2(60, 60)
		btn.z_index = 30
		_apply_icon_style(btn, top_icons[i])
		if top_actions[i] == "open_pause":
			btn.pressed.connect(_open_pause)
		elif top_actions[i] == "open_settings":
			btn.pressed.connect(_open_settings)
		$UI.add_child(btn)
		menu_buttons.append(btn)
	speed_button = Button.new()
	speed_button.name = "TopBarBtnSpeed"
	speed_button.position = Vector2(1628, 88)
	speed_button.size = Vector2(60, 60)
	speed_button.z_index = 30
	speed_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	speed_button.add_theme_font_override("font", title_font)
	speed_button.add_theme_font_size_override("font_size", 24)
	speed_button.add_theme_color_override("font_color", Color("725c3f"))
	speed_button.add_theme_color_override("font_hover_color", Color("475d36"))
	speed_button.add_theme_color_override("font_pressed_color", Color("475d36"))
	_apply_icon_style(speed_button, null)
	speed_button.text = "1×"
	speed_button.tooltip_text = "当前正常速度 · 点击切换2倍速"
	speed_button.pressed.connect(_toggle_game_speed)
	$UI.add_child(speed_button)
	menu_buttons.append(speed_button)

func _toggle_game_speed() -> void:
	if menu_mode != MenuMode.NONE or phase.phase not in ["DAY", "DUSK", "NIGHT"]:
		return
	game_speed = 2.0 if game_speed == 1.0 else 1.0
	time_scale = game_speed
	speed_button.text = "2×" if game_speed == 2.0 else "1×"
	speed_button.tooltip_text = "当前2倍速 · 点击恢复正常速度" if game_speed == 2.0 else "当前正常速度 · 点击切换2倍速"

func _apply_icon_style(button: Button, icon: Texture2D) -> void:
	_bind_ui_audio(button)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		var idle: bool = state in ["normal", "disabled", "focus"]
		style.bg_color = Color(0.96, 0.93, 0.84, 0.0) if idle else Color(0.96, 0.93, 0.84, 0.25)
		style.border_color = Color("b88f3a") if state == "pressed" else Color("c8c0a6")
		style.set_border_width_all(2 if state == "pressed" else 1)
		style.set_corner_radius_all(12)
		button.add_theme_stylebox_override(state, style)
	if icon != null:
		button.icon = icon
		button.expand_icon = true

func _apply_menu_button_style(button: Button) -> void:
	_bind_ui_audio(button)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		var idle: bool = state in ["normal", "disabled", "focus"]
		if idle:
			style.bg_color = Color(0.96, 0.93, 0.84, 0.85)
		else:
			style.bg_color = Color(0.99, 0.93, 0.65, 0.9) if state == "hover" else Color(0.85, 0.78, 0.55, 0.9)
		style.border_color = Color("b88f3a")
		style.set_border_width_all(2)
		style.set_corner_radius_all(14)
		button.add_theme_stylebox_override(state, style)

func _show_menu(mode: int) -> void:
	if phase.phase in ["PAGE_TURN", "GAMEOVER"]:
		return
	if menu_mode == mode:
		return
	_cancel_animal_drag()
	_clear_menu_action_buttons()
	menu_mode = mode
	time_scale = game_speed if mode == MenuMode.NONE else 0.0
	var opening: bool = mode != MenuMode.NONE
	# Tell overlay to draw menu panel on top; overlay will skip game UI while menu is open.
	overlay.menu_mode = mode
	# Hide gameplay UI buttons so only menu controls remain interactive.
	for btn in buttons:
		btn.visible = not opening and phase.phase == "DAY"
	for btn in menu_buttons:
		if btn.name.begins_with("TopBarBtn"):
			btn.visible = not opening
	cancel_preview()
	if mode == MenuMode.PAUSED:
		_make_menu_action_button("继续", _hide_menu, 0.5, 0.32)
		_make_menu_action_button("重新开始", _confirm_restart, 0.5, 0.47)
		_make_menu_action_button("回到标题", _return_to_title, 0.5, 0.62)
	elif mode == MenuMode.SETTINGS:
		_build_settings_controls()
	elif mode == MenuMode.RESTART_CONFIRM:
		_make_menu_action_button("是的，重新开始", _do_restart, 0.5, 0.55)
		_make_menu_action_button("再想想", _hide_menu, 0.5, 0.72)

func _clear_menu_action_buttons() -> void:
	settings_panel = null
	for control in settings_controls:
		control.queue_free()
	settings_controls.clear()
	for btn in menu_buttons:
		if not btn.name.begins_with("TopBarBtn"):
			btn.queue_free()
	menu_buttons = menu_buttons.filter(func(b): return b.name.begins_with("TopBarBtn"))

func _make_menu_action_button(text: String, callback: Callable, fx: float, fy: float) -> void:
	var btn_w: float = 320.0
	var btn_h: float = 64.0
	var panel_cx: float = 960.0
	var panel_cy: float = 540.0
	var p: Vector2 = Vector2(panel_cx - btn_w * 0.5, panel_cy + (fy - 0.5) * 600.0)
	var btn := Button.new()
	btn.text = text
	btn.position = p
	btn.size = Vector2(btn_w, btn_h)
	btn.z_index = 35
	btn.add_theme_font_override("font", title_font)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color("54654f"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.93, 0.84, 0.85)
	style.border_color = Color("b88f3a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := style.duplicate()
		if state == "hover":
			s.bg_color = Color(0.99, 0.93, 0.65, 0.85)
		elif state == "pressed":
			s.bg_color = Color(0.85, 0.78, 0.55, 0.85)
		btn.add_theme_stylebox_override(state, s)
	_bind_ui_audio(btn)
	btn.pressed.connect(callback)
	$UI.add_child(btn)
	menu_buttons.append(btn)

func _build_settings_controls() -> void:
	settings_panel = preload("res://scripts/settings_panel.gd").new()
	settings_panel.config = config
	settings_panel.closed.connect(_hide_menu)
	$UI.add_child(settings_panel)
	settings_controls.append(settings_panel)

func _hide_menu() -> void:
	_show_menu(MenuMode.NONE)

func _open_pause() -> void:
	_show_menu(MenuMode.PAUSED)

func _open_settings() -> void:
	_show_menu(MenuMode.SETTINGS)

func _confirm_restart() -> void:
	_show_menu(MenuMode.RESTART_CONFIRM)

func _do_restart() -> void:
	get_tree().reload_current_scene()

func _return_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/opening/book_opening.tscn")

func _draw_menu(canvas: Node2D) -> void:
	if menu_mode in [MenuMode.NONE, MenuMode.SETTINGS]:
		return
	# Backdrop
	canvas.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.25, 0.28, 0.22, 0.55))
	# Panel: prefer configured texture, fallback to flat panel
	var panel_rect := Rect2(460, 220, 1000, 640)
	var panel_tex: Texture2D = config.panel_texture
	if panel_tex != null:
		var size: Vector2 = panel_tex.get_size()
		var target: Vector2 = panel_rect.size
		var scale: float = minf(target.x / size.x, target.y / size.y)
		var draw_size: Vector2 = size * scale
		var origin: Vector2 = panel_rect.position + (target - draw_size) * 0.5
		canvas.draw_texture_rect(panel_tex, Rect2(origin, draw_size), false)
	else:
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = Color("faf6e8")
		fallback.set_corner_radius_all(20)
		canvas.draw_style_box(fallback, panel_rect)
	# Title banner
	var title_text: String = "暂停中"
	match menu_mode:
		MenuMode.PAUSED:
			title_text = "暂停中"
		MenuMode.SETTINGS:
			title_text = "设置"
		MenuMode.RESTART_CONFIRM:
			title_text = "再种一棵？"
	var title_tex: Texture2D = config.title_banner_texture
	if title_tex != null:
		var ts: Vector2 = title_tex.get_size()
		var tw: float = 360.0
		var th: float = ts.y * (tw / ts.x)
		var t_origin: Vector2 = panel_rect.position + Vector2((panel_rect.size.x - tw) * 0.5, -th * 0.35)
		canvas.draw_texture_rect(title_tex, Rect2(t_origin, Vector2(tw, th)), false)
		var text_w: float = title_font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		canvas.draw_string(title_font, t_origin + Vector2((tw - text_w) * 0.5, th * 0.7), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("54654f"))
	else:
		var text_w2: float = title_font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		canvas.draw_string(title_font, panel_rect.position + Vector2((panel_rect.size.x - text_w2) * 0.5, 70), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("54654f"))
	if menu_mode == MenuMode.RESTART_CONFIRM:
		var msg: String = "这一页的痕迹会全部消失。"
		var mw: float = title_font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		canvas.draw_string(title_font, panel_rect.position + Vector2((panel_rect.size.x - mw) * 0.5, 280), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("54654f"))

func _select_branch(kind: int) -> void:
	if phase.phase != "DAY" or placement_lock > 0:
		return
	cancel_preview()
	selected_kind = kind
	dragging = true
	preview = growth.SCENES[kind].instantiate()
	preview.preview = true
	preview.grown = false
	preview.z_index = 25
	branches.add_child(preview)
	status = "拖到空闲芽点附近吸附 · 鼠标拖拽旋转方向 · 左键放置 · 右键删除已放置的贴纸"
	_refresh_tray_styles()
	pointer = world_camera.screen_to_world(get_viewport().get_mouse_position())
	_update_preview()

func cancel_preview() -> void:
	if is_instance_valid(preview):
		branches.remove_child(preview)
		preview.queue_free()
	preview = null
	preview_mirrored = false
	preview_angle = 0.0
	candidate = null
	selected_kind = -1
	dragging = false
	_refresh_tray_styles()

func _cancel_animal_drag() -> void:
	animal_drag = {}
	animal_drop_node = null
	overlay.queue_redraw()

func _update_animal_drag(screen_point: Vector2) -> void:
	if animal_drag.is_empty():
		return
	var desired: Vector2 = world_camera.screen_to_world(screen_point) + animal_drag_offset
	animal_drag.position = desired
	animal_drop_node = null
	if not Layout.contains(screen_point) or get_viewport().gui_get_hovered_control() != null:
		return
	var nearest: float = minf(config.snap_radius, 56.0 / maxf(0.01, world_camera.zoom.x))
	for bud in animals.relocation_nodes(animal_drag.id):
		var distance: float = desired.distance_to(bud.global_position)
		if distance < nearest:
			nearest = distance
			animal_drop_node = bud
	if is_instance_valid(animal_drop_node):
		animal_drag.position = animal_drop_node.global_position

func _handle_animal_input(event: InputEvent) -> bool:
	if phase.phase not in ["DUSK", "NIGHT"]:
		return false
	if event is InputEventMouseMotion and not animal_drag.is_empty():
		_update_animal_drag(event.position)
		overlay.queue_redraw()
		return true
	if not event is InputEventMouseButton:
		return false
	if not animal_drag.is_empty():
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_animal_drag()
			return true
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_update_animal_drag(event.position)
			if is_instance_valid(animal_drop_node):
				animals.relocate_companion(animal_drag.id, animal_drop_node)
			_cancel_animal_drag()
			return true
		return event.button_index == MOUSE_BUTTON_LEFT
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return false
	if get_viewport().gui_get_hovered_control() != null:
		return false
	var picked: Dictionary = {}
	var nearest: float = 44.0
	for actor in animals.companions:
		if actor.state != "IDLE":
			continue
		var offset: Vector2 = Vector2(0, -25 if actor.kind == 1 else -32)
		var center: Vector2 = world_camera.world_to_screen(actor.position + offset)
		var distance: float = center.distance_to(event.position)
		if distance < nearest:
			nearest = distance
			picked = actor
	if picked.is_empty():
		return false
	animal_drag = picked.duplicate(true)
	animal_drag.velocity = Vector2.ZERO
	animal_drag_offset = picked.position - world_camera.screen_to_world(event.position)
	world_camera.dragging = false
	_update_animal_drag(event.position)
	overlay.queue_redraw()
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not Engine.is_editor_hint():
		_cancel_animal_drag()

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if phase.phase in ["PAGE_TURN", "GAMEOVER"]:
		world_camera.dragging = false
		return
	if event is InputEventMouse and not Layout.contains(event.position):
		world_camera.dragging = false
		if not animal_drag.is_empty():
			animal_drop_node = null
			if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_cancel_animal_drag()
			elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_animal_drag()
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging:
			cancel_preview()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if menu_mode == MenuMode.SETTINGS and is_instance_valid(settings_panel):
				settings_panel.back()
				get_viewport().set_input_as_handled()
				return
			if not animal_drag.is_empty():
				_cancel_animal_drag()
				return
			if menu_mode != MenuMode.NONE:
				_hide_menu()
			else:
				_open_pause()
			return
	if menu_mode != MenuMode.NONE:
		world_camera.dragging = false
		return
	if _handle_animal_input(event):
		get_viewport().set_input_as_handled()
		return
	if world_camera.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if phase.phase != "DAY" or placement_lock > 0:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		if is_instance_valid(preview):
			pointer = world_camera.screen_to_world(get_viewport().get_mouse_position())
			_update_preview()
			if is_instance_valid(candidate):
				preview_mirrored = not preview_mirrored
				_update_preview()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		pointer = world_camera.screen_to_world(event.position)
		_update_preview()
	if event is InputEventMouseButton:
		pointer = world_camera.screen_to_world(event.position)
		# Fixed controls must not also click the world beneath them after panning.
		if get_viewport().gui_get_hovered_control() != null:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging:
				cancel_preview()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if is_instance_valid(preview):
				cancel_preview()
			elif growth.remove_nearest(pointer, 90.0):
				status = "贴纸已取回，资源返还"
				pocket_shake = 0.4
				hint_time = 2
			else:
				status = "附近没有可移除的枝条"
				hint_time = 2
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and selected_kind < 0:
				var old_sun: int = resources.sunlight
				if resources.collect_at(pointer):
					var kind: int = 0 if resources.sunlight > old_sun else 1
					collection_flights.append({"kind": kind, "start": pointer, "progress": 0.0})
					$Systems/MusicManager.play_effect("sun" if kind == 0 else "water")
			elif not event.pressed and dragging:
				_commit_preview()

func _update_preview() -> void:
	if not is_instance_valid(preview):
		return
	var previous_candidate: Node2D = candidate
	candidate = growth.nearest_bud(pointer)
	if candidate != null:
		if candidate != previous_candidate:
			preview_angle = 0.0
		var mouse_dir: Vector2 = pointer - candidate.global_position
		if mouse_dir.length_squared() > 1.0:
			var bud_up: Vector2 = candidate.global_transform.basis_xform(Vector2.UP).normalized()
			preview_angle = rad_to_deg(bud_up.angle_to(mouse_dir.normalized()))
		growth.align(preview, candidate, preview_angle, preview_mirrored)
		var reason: String = growth.validate(preview, candidate, config.costs[selected_kind], preview_angle)
		preview.modulate = Color(0.8, 1.0, 0.8, 0.8) if reason.is_empty() else Color(1.0, 0.7, 0.65, 0.65)
	else:
		preview.global_position = pointer
		preview.scale = growth.branch_scale() * Vector2(-1 if preview_mirrored else 1, 1)
		preview.rotation = 0.0
		preview.modulate = Color(1, 1, 1, 0.65)
	preview.queue_redraw()

func _commit_preview() -> void:
	var created: Node2D = null
	_update_preview()
	if candidate != null:
		created = growth.place(selected_kind, candidate, preview_angle, preview_mirrored, phase.day)
	if created == null:
		status = growth.last_reason if candidate != null else "没有贴到芽点，枝条已回到托盘"
		pocket_shake = 0.6
		if is_instance_valid(preview):
			var returning: Node2D = preview.duplicate()
			$Effects.add_child(returning)
			var destination: Vector2 = world_camera.screen_to_world(overlay.tray_card_rect(selected_kind).get_center())
			var tween := create_tween().set_parallel(true)
			tween.tween_property(returning, "global_position", destination, 0.25).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(returning, "modulate:a", 0.0, 0.25)
			tween.chain().tween_callback(returning.queue_free)
	else:
		status = "贴好了。翻到明天，新芽点才会打开"
		# Keep the final joint fixed; animate opacity instead of moving anchors.
		created.modulate.a = 0.4
		create_tween().tween_property(created, "modulate:a", 1.0, 0.2)
		placement_lock = 0.2
	cancel_preview()
	hint_time = 4

func _on_branch_placed(branch: Node2D) -> void:
	$Systems/MusicManager.play_effect("place")
	animals.add_growth_omen(branch, branch.placed_day, $World/Branches/Base/Buds/Tip.global_position.y)

func _on_pest_hit() -> void:
	if phase.phase != "NIGHT" or hearts <= 0:
		return
	hearts -= 1
	$Systems/MusicManager.play_effect("hurt")
	damage_marks += 1
	if hearts == 0:
		phase.finish("LOSE")

func _on_phase_changed(next: String) -> void:
	_cancel_animal_drag()
	cancel_preview()
	for button in buttons:
		button.visible = next == "DAY" and menu_mode == MenuMode.NONE
	_refresh_tray_styles()
	if next in ["DAY", "DUSK", "NIGHT"] and next != sky_current:
		sky_previous = sky_current
		sky_current = next
		sky_progress = 0
	match next:
		"DAY":
			if not page_swapped:
				_begin_resources_day()
				animals.begin_day(phase.day)
			page_swapped = false
			status = "点击收集阳光与水滴，再把枝条拖到芽点"
		"DUSK":
			resources.pickups.clear()
			animals.begin_dusk(phase.day)
			status = ""
		"NIGHT":
			animals.begin_night(phase.day - 1)
			status = "让伙伴守护树木，等这一夜安静下来"
		"PAGE_TURN":
			page_swapped = false
			status = "翻过一页，让昨日的枝条长成树"
			page_turn.play(config.page_duration / game_speed, config.swap_progress, config.page_paper_color,
				config.page_curl_strength, config.page_shadow_strength, config.page_grain_strength)
		"GAMEOVER":
			get_node("/root/PageAudio").play_page($Systems/MusicManager)
			world_camera.dragging = false
			get_node("/root/BookFrame").set_mode("reading")
			for menu_button in menu_buttons:
				menu_button.hide()
			var ending := ReadingSpread.new()
			ending.name = "EndingSpread"
			$UI.add_child(ending)
			$UI.move_child(ending, 0)
			var won: bool = phase.result == "WIN"
			var ending_texture: Texture2D = _create_tree_portrait(ending) if won else config.ending_invasion_texture
			ending.show_page(ending_texture,
				config.ending_survival_title if won else config.ending_invasion_title,
				config.ending_survival_text if won else config.ending_invasion_text)
			var retry_btn: Button = $UI/Restart
			retry_btn.visible = true
			retry_btn.position = Layout.NEXT.position
			retry_btn.size = Layout.NEXT.size
			_apply_menu_button_style(retry_btn)
	for branch in branches.get_children():
		branch.show_hints = next == "DAY"
		branch.queue_redraw()

func _create_tree_portrait(owner_node: Node) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.name = "TreePortrait"
	viewport.size = Vector2i(880, 936)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	owner_node.add_child(viewport)
	var drawing := Node2D.new()
	viewport.add_child(drawing)
	var bounds := Rect2()
	var has_bounds: bool = false
	for branch in branches.get_children():
		if branch.preview or branch.is_queued_for_deletion():
			continue
		var texture: Texture2D = branch.grown_texture if branch.grown else branch.sticker_texture
		if texture == null:
			continue
		var copy := Sprite2D.new()
		copy.texture = texture
		copy.centered = false
		copy.transform = branch.global_transform * Transform2D(0.0, branch.texture_rect.size / texture.get_size(), 0.0, branch.texture_rect.position)
		if branch.material != null:
			copy.material = branch.material.duplicate()
		drawing.add_child(copy)
		var rect: Rect2 = copy.transform * copy.get_rect()
		bounds = bounds.merge(rect) if has_bounds else rect
		has_bounds = true
	for layer in foliage.get_children():
		for leaf in layer.get_children():
			if not leaf is Sprite2D or leaf.is_queued_for_deletion() or not leaf.is_visible_in_tree():
				continue
			var copy := Sprite2D.new()
			copy.texture = leaf.texture
			copy.centered = leaf.centered
			copy.offset = leaf.offset
			copy.transform = leaf.global_transform
			copy.modulate = leaf.modulate
			copy.z_index = layer.z_index + leaf.z_index
			drawing.add_child(copy)
			var rect: Rect2 = copy.transform * copy.get_rect()
			bounds = bounds.merge(rect) if has_bounds else rect
			has_bounds = true
	if has_bounds:
		var available: Vector2 = Vector2(viewport.size) - Vector2(96, 96)
		var fit: float = minf(available.x / maxf(1, bounds.size.x), available.y / maxf(1, bounds.size.y))
		drawing.scale = Vector2.ONE * fit
		drawing.position = Vector2(viewport.size) * 0.5 - bounds.get_center() * fit
	return viewport.get_texture()

func _prepare_next_page() -> void:
	if phase.phase != "PAGE_TURN":
		return
	page_swapped = true
	phase.day += 1
	growth.mature(phase.day)
	foliage.refresh()
	animals.pests.clear()
	_begin_resources_day()
	animals.begin_day(phase.day)
	sky_previous = "DAY"
	sky_current = "DAY"
	sky_progress = 1.0
	_draw_land()
	clock_time = 0.0
	status = "点击收集阳光与水滴，再把枝条拖到芽点"
	for branch in branches.get_children():
		branch.show_hints = true
		branch.queue_redraw()
	for button in buttons:
		button.visible = menu_mode == MenuMode.NONE
	queue_redraw()
	overlay.queue_redraw()

func _finish_next_page() -> void:
	if phase.phase == "PAGE_TURN" and page_swapped:
		phase.enter("DAY")
		queue_redraw()
		overlay.queue_redraw()

func _begin_resources_day() -> void:
	var blocked: Array[Rect2] = []
	if phase.day > 1:
		for branch in branches.get_children():
			if not branch.preview:
				blocked.append((branch.global_transform * branch.texture_rect).grow(42))
		for layer in foliage.get_children():
			for leaf in layer.get_children():
				if leaf is Sprite2D and not leaf.is_queued_for_deletion() and leaf.is_visible_in_tree():
					blocked.append((leaf.global_transform * leaf.get_rect()).grow(42))
	resources.begin_day(config, anchors.get_node("ResourceSpawns"), world_camera.visible_world_rect(), phase.day, blocked)

func _process(delta: float) -> void:
	if not is_node_ready():
		return
	if Engine.is_editor_hint():
		sky_current = editor_phase
		sky_previous = editor_phase
		sky_progress = 1.0
		clock_time = 20.0 if editor_phase == "DAY" else (45.0 if editor_phase == "DUSK" else 65.0)
		queue_redraw()
		overlay.queue_redraw()
		return
	# Paper animation owns the transition; no resource, animal or day timers
	# advance until the new page has completely landed.
	if phase.phase == "PAGE_TURN" or menu_mode != MenuMode.NONE:
		return
	if not animal_drag.is_empty() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_cancel_animal_drag()
	if phase.phase in ["DUSK", "NIGHT"] and not animal_drag.is_empty():
		queue_redraw()
		overlay.queue_redraw()
		return
	var dt := delta * time_scale
	placement_lock = maxf(0, placement_lock - dt)
	for flight in collection_flights:
		flight.progress += dt / 0.35
	collection_flights = collection_flights.filter(func(f): return f.progress < 1)
	phase.elapsed += dt
	_update_clock_time()
	sky_progress = minf(1.0, sky_progress + dt / maxf(config.sky_duration, 0.01))
	pocket_shake = maxf(0, pocket_shake - dt)
	hint_time = maxf(0, hint_time - dt)
	match phase.phase:
		"DAY":
			animals.tick_day(dt)
			if phase.elapsed >= config.day_duration:
				phase.enter("DUSK")
		"DUSK":
			animals.tick_dusk(dt)
			if phase.elapsed >= config.dusk_duration:
				phase.enter("NIGHT")
		"NIGHT":
			animals.tick_night(dt)
			if phase.phase == "NIGHT" and phase.elapsed >= config.night_duration:
				animals.end_night()
				if phase.day >= config.night_waves.size():
					phase.finish("WIN")
				else:
					phase.enter("PAGE_TURN")
	queue_redraw()
	overlay.queue_redraw()

func _draw() -> void:
	if not is_node_ready():
		return
	draw_set_transform_matrix(_screen_drawing_transform())
	draw_rect(Rect2(0, 0, 1920, 1080), Color("f5f1e5"))
	if sky_progress >= 1:
		_draw_sky(sky_current, 0)
	else:
		var turn: float = smoothstep(0.0, 1.0, sky_progress)
		# Opposite halves of one wheel: the incoming picture starts upside down
		# below the pivot, while the outgoing picture rotates out with it.
		_draw_sky(sky_previous, -turn * PI)
		_draw_sky(sky_current, (1.0 - turn) * PI)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _land_tint() -> Color:
	var colors := {"DAY": Color.WHITE, "DUSK": Color("e8d2b0"), "NIGHT": Color("607571")}
	return colors[sky_previous].lerp(colors[sky_current], smoothstep(0.0, 1.0, sky_progress))

func _draw_land_texture(texture: Texture2D, rect: Rect2, tint: Color, rise: float = 0.0) -> void:
	var tex_size: Vector2 = texture.get_size()
	var scale: float = rect.size.x / tex_size.x
	var draw_size: Vector2 = tex_size * scale
	var origin: Vector2 = Vector2(rect.position.x, rect.position.y + rect.size.y - draw_size.y - rise)
	draw_texture_rect(texture, Rect2(origin, draw_size), false, tint)

func _draw_land() -> void:
	$World/Landscape.draw_land(config, _land_tint())

func _draw_sky(theme: String, angle: float) -> void:
	var color := Color("e7eedf")
	var texture: Texture2D = config.sky_day
	if theme == "DUSK":
		color = Color("eee0cc")
		texture = config.sky_dusk
	elif theme == "NIGHT":
		color = Color("7e9190")
		texture = config.sky_night
	# Keep the common seam below the page. Both images use exactly the same
	# upper half-plane so oversized artwork cannot overlap the other half.
	var pivot := Vector2(config.sky_pivot.x, maxf(1080.0, config.sky_pivot.y))
	var radius: float = 0.0
	for corner in [Vector2.ZERO, Vector2(1920, 0), Vector2(0, 1080), Vector2(1920, 1080)]:
		radius = maxf(radius, pivot.distance_to(corner))
	radius += 4.0
	var panel := Rect2(-radius, -radius, radius * 2.0, radius)
	draw_set_transform_matrix(_screen_drawing_transform() * Transform2D(angle, pivot))
	if texture != null:
		var texture_size: Vector2 = texture.get_size()
		var fit: float = maxf(config.sky_size.x / texture_size.x, config.sky_size.y / texture_size.y)
		var size: Vector2 = texture_size * fit
		var top_left: Vector2 = config.sky_center - pivot - size * 0.5
		if theme == "DUSK":
			top_left += config.sky_dusk_offset
		# Clamped UVs retain the existing composition and extend the edge color
		# to the shared seam, without wrapping or exposing empty corners.
		var points := PackedVector2Array([panel.position, Vector2(panel.end.x, panel.position.y), panel.end, Vector2(panel.position.x, panel.end.y)])
		var uvs := PackedVector2Array()
		for point in points:
			uvs.append((point - top_left) / size)
		texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, texture)
	else:
		draw_rect(panel, color)
		if theme == "NIGHT":
			for i in range(30):
				draw_circle(Vector2(-820 + fmod(i * 139, 1600), -1020 + fmod(i * 67, 440)), 2, Color("eae8c8"))
		else:
			draw_circle(Vector2(-600, -920), 59, Color("f5e5ad"))
			draw_circle(Vector2(-600, -920), 70, Color(0.98, 0.91, 0.7, 0.15))
	draw_set_transform_matrix(_screen_drawing_transform())

func _screen_drawing_transform() -> Transform2D:
	if Engine.is_editor_hint():
		return Transform2D.IDENTITY
	return get_canvas_transform().affine_inverse()

func debug_snapshot() -> Dictionary:
	return {"phase": phase.phase, "day": phase.day, "hearts": hearts, "sunlight": resources.sunlight, "water": resources.water, "branches": growth.records.duplicate(true), "available_buds": growth.available_buds().size(), "omens": animals.omens.duplicate(true), "companions": animals.companions.duplicate(true), "pests": animals.pests.duplicate(true), "transitions": phase.transitions, "result": phase.result}

func _update_clock_time() -> void:
	match phase.phase:
		"DAY":
			clock_time = minf(phase.elapsed, config.day_duration)
		"DUSK":
			clock_time = config.day_duration + minf(phase.elapsed, config.dusk_duration)
		"NIGHT":
			clock_time = config.day_duration + config.dusk_duration + minf(phase.elapsed, config.night_duration)

func clock_angle() -> float:
	var duration: float = config.day_duration + config.dusk_duration + config.night_duration
	return PI + TAU * clampf(clock_time / duration, 0, 1)
