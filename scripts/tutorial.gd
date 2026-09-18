extends Control
## Teaching owns phase time, while normal placement and visual feedback keep running.
var game: Node
var step: int = 0
var skipped: bool = false
var facts: Dictionary = {}
var placements: int = 0
var undo_pending: bool = false
var last_zoom: float = 1.0
var last_position: Vector2
var companion_tip: int = -1
var companion_seen: Dictionary = {}
var pulse: float = 0.0
var panel: PanelContainer
var heading: Label
var body: Label
var action: Button
var last_key: String = ""
var stage_seconds: float = 0.0
var night_tip: bool = false
var night_seen: bool = false
# 0 introduction, 1 attack demonstration, 2 clock explanation, 3 hands-on clock.
var demo_stage: int = 0
var demo_pest_id: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1920, 1080)
	z_index = 45
	last_zoom = game.world_camera.zoom.x
	last_position = game.world_camera.position
	panel = PanelContainer.new()
	panel.position = Vector2(460, 118)
	panel.size = Vector2(980, 206)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f5f1e5")
	paper.border_color = Color("b7b997")
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(14)
	paper.shadow_color = Color(0.25, 0.22, 0.15, 0.12)
	paper.shadow_size = 5
	panel.add_theme_stylebox_override("panel", paper)
	add_child(panel)
	# An ordinary Control keeps the hand-placed typography out of container sizing.
	var content := Control.new()
	content.custom_minimum_size = Vector2(980, 206)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	heading = _label(content, Vector2(24, 14), Vector2(930, 32), 24)
	body = _label(content, Vector2(24, 54), Vector2(930, 92), 22)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action = _button(content, Vector2(890, 150), Vector2(65, 44), _advance)
	action.text = "▶"
	action.tooltip_text = "继续"
	action.add_theme_font_size_override("font_size", 32)
	for state in ["normal", "hover", "pressed", "focus"]:
		action.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	action.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	game.growth.placed.connect(_placed)
	game.phase.changed.connect(_on_phase_changed)
	# Keep first-day pickups clear of the teaching card; their world positions then stay fixed.
	for pickup in game.resources.pickups:
		var screen: Vector2 = game.world_camera.world_to_screen(pickup.position)
		if Rect2(panel.position, panel.size).grow(24).has_point(screen):
			screen.y = panel.position.y + panel.size.y + 55
			pickup.position = game.world_camera.screen_to_world(screen)
	_refresh()

func _label(owner: Control, pos: Vector2, extent: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = extent
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", game.title_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("54654f"))
	owner.add_child(label)
	return label

func _button(owner: Control, pos: Vector2, extent: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = extent
	button.add_theme_font_override("font", game.title_font)
	button.add_theme_font_size_override("font_size", 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e7e9d7")
	style.set_corner_radius_all(9)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", Color("54654f"))
	button.pressed.connect(callback)
	owner.add_child(button)
	return button

func record(event: String) -> void:
	facts[event] = true
	if event == "undo":
		undo_pending = true
	if event == "relocate" and companion_tip == 0:
		companion_tip = -1

func _placed(branch: Node2D) -> void:
	placements += 1
	if undo_pending:
		facts["replaced"] = true
		undo_pending = false
	if game.preview_mirrored:
		facts["mirrored"] = true
	if absf(game.preview_angle) >= 12:
		facts["rotated"] = true

func freezes_clock() -> bool:
	return not skipped and ((game.phase.day == 1 and not game.night_fast_forward) or step == 8 or companion_tip >= 0 or night_tip)

func freezes_actors() -> bool:
	return not skipped and (step == 8 or companion_tip >= 0 or night_tip or (step == 7 and demo_stage == 0))

func _on_phase_changed(phase: String) -> void:
	if not skipped and game.phase.day == 2 and phase == "DAY" and step < 8:
		step = 8
		_refresh()

func _check_companion_tip() -> void:
	if step != 9 or companion_tip >= 0 or game.phase.phase not in ["DUSK", "NIGHT"]:
		return
	if game.clock_dragging or game.night_fast_forward or not game.animal_drag.is_empty():
		return
	for actor in game.animals.companions:
		if actor.state != "IDLE" or actor.get("tutorial_demo", false) or companion_seen.has(actor.kind):
			continue
		companion_tip = actor.kind
		companion_seen[actor.kind] = true
		game.clock_forward_seconds = 0.0
		return

func _process(delta: float) -> void:
	if not skipped and game.menu_mode == 0:
		_check_companion_tip()
	pulse += delta
	visible = not skipped and game.menu_mode == 0 and game.phase.phase not in ["PAGE_TURN", "GAMEOVER"] and (step < 9 or companion_tip >= 0 or night_tip) and not game.night_fast_forward and not (step == 7 and demo_stage in [1, 3])
	if skipped or game.menu_mode != 0 or game.phase.phase in ["PAGE_TURN", "GAMEOVER"]:
		return
	stage_seconds += delta
	if not is_equal_approx(game.world_camera.zoom.x, last_zoom):
		facts["zoom"] = true
		last_zoom = game.world_camera.zoom.x
	# Only middle-button dragging counts as panning, not zoom's cursor anchoring.
	if game.world_camera.dragging and game.world_camera.position.distance_to(last_position) > 8:
		facts["pan"] = true
	last_position = game.world_camera.position
	if step == 0 and facts.has("sun") and facts.has("water"):
		step = 1
	if step == 1 and placements > 0:
		step = 2
	if step == 2 and (facts.has("zoom") or facts.has("pan") or stage_seconds >= 8.0):
		step = 3
	if step == 3 and ((placements >= 2 and (facts.has("mirrored") or facts.has("rotated"))) or (stage_seconds >= 10.0 and not game.dragging)):
		step = 4
	if step == 4 and (facts.has("replaced") or (stage_seconds >= 8.0 and not game.dragging)):
		step = 5
	if step == 5 and game.phase.phase == "DUSK":
		step = 6
	if step == 6 and game.phase.phase == "NIGHT":
		step = 7
	if step == 7 and demo_stage == 0 and stage_seconds >= 6.0:
		_advance()
	if step == 7 and demo_stage == 2 and game.clock_dragging:
		demo_stage = 3
	if step == 7 and demo_stage == 1 and demo_pest_id >= 0:
		if not game.animals.pests.any(func(p): return p.id == demo_pest_id):
			demo_stage = 2
			night_seen = true
	_refresh()
	queue_redraw()

func _refresh() -> void:
	var key: String = "%d/%d/%s/%d" % [step, companion_tip, night_tip, demo_stage]
	if key == last_key:
		return
	last_key = key
	stage_seconds = 0.0
	if night_tip:
		heading.text = "夜晚 · 让伙伴守护小树"
		body.text = "仓鼠投掷松子，小鸟拦截飞虫；漏过的虫会扣爱心。可拖动空闲伙伴调整站位，也可顺时针拨动叶片指针推进时间。快进时战斗仍会正常进行。"
		action.visible = true
		action.tooltip_text = "继续守护"
		return
	action.visible = true
	action.tooltip_text = "稍后再试"
	if companion_tip >= 0:
		heading.text = "新的伙伴 · 时间已暂停"
		if companion_tip == 0:
			body.text = "小仓鼠到位了！黄昏、夜晚可拖动空闲仓鼠到发亮芽点，查看射程是否覆盖地面。也可以点击继续，稍后再调整。"
		else:
			body.text = "小鸟到位了！它优先拦截飞虫，空中安全时也会帮忙守地面。黄昏、夜晚可拖动空闲小鸟调整站位；放在树冠附近，能减少往返。点击继续后恢复时间。"
		action.tooltip_text = "知道了，继续"
		return
	var titles: Array[String] = ["第一天 · 收集养分", "第一天 · 贴上枝条", "靠近看看", "枝条的姿态", "可以放心修改", "自由生长", "黄昏 · 认识一天", "夜晚 · 守护树苗", "第二天 · 新芽打开了"]
	var texts: Array[String] = [
		"小树将经历 12 天：春、夏、秋、冬各 3 天。先点击收集一束阳光和一滴水，今天的时间会停下来等你。",
		"按住右侧托盘的单芽贴纸，拖到发亮的芽点附近，松开左键贴上。单芽消耗阳光和水各 1 份；双芽各 2 份，三芽各 3 份。",
		"滚轮可以拉近或拉远视野，按住鼠标中键可以移动画面，双击中键回到小树身边。需要时再用就好，枝条本身的大小不会改变。",
		"枝条吸附芽点后，会跟着鼠标改变方向。按 F 可以翻个面，右键可以取消。你可以继续贴出喜欢的形状，不必每种操作都试一遍。",
		"如果想换个位置，右键点今天贴纸的连接处，就能取回贴纸和养分。已经长成的枝条会留在树上。现在不需要取回，继续生长也可以。",
		"试着用剩余养分，贴出你喜欢的样子。第二天起，养分会缓缓斜向飘落；未用完的阳光和水各最多保留 2 份到明天。准备好后，就可以迎接黄昏。也可以按住时钟的叶片指针顺时针推进时间。",
		"橡果吸引仓鼠，羽毛吸引小鸟，伙伴会长期留下。黄昏和夜晚都能拖动空闲伙伴调整站位，拖动时战斗暂停。仓鼠守地面，小鸟守空中；树越大，能容纳的伙伴越多。",
		"到了夜晚，会有小昆虫入侵树苗，小仓鼠会帮你守护树。看看这位小伙伴怎样赶走昆虫。",
		"昨天的枝条成熟，新芽已开放！点击继续后恢复计时，养分会陆续飘落。未用完的阳光和水各最多保留 2 份；新伙伴到位时会再提示站位操作。"]
	if step < titles.size():
		heading.text = titles[step]
		body.text = texts[step]
	action.visible = step >= 2
	if step == 5:
		action.tooltip_text = "迎接黄昏"
	elif step == 6:
		action.tooltip_text = "看看夜晚"
	elif step == 7:
		action.visible = demo_stage in [0, 2]
		action.tooltip_text = "开始演示" if demo_stage == 0 else "试着拨动指针"
		if demo_stage >= 2:
			heading.text = "夜晚 · 拨动时间"
			body.text = "小昆虫被赶走了！黑夜结束后就是第二天，白天贴上的贴纸会长成真正的枝条，新芽点也会开放。按住时钟的叶片指针顺时针拨动，就能推进时间、结束今天；时间不能倒退。"
	elif step == 8:
		action.tooltip_text = "开始第二天"

func _advance() -> void:
	if game.menu_mode != 0 or game.phase.phase == "PAGE_TURN":
		return
	if night_tip:
		night_tip = false
	elif companion_tip >= 0:
		companion_tip = -1
	elif step in [2, 3, 4]:
		step += 1
	elif step == 5:
		if game.growth.records.is_empty():
			body.text = "请先留下一根枝条，再迎接黄昏。取回的养分还在口袋里，可以重新贴上。"
			return
		game.cancel_preview()
		game.world_camera.reset_view()
		step = 6
		game.phase.enter("DUSK")
	elif step == 6:
		step = 7
		game.phase.enter("NIGHT")
	elif step == 7:
		if demo_stage == 0:
			game.world_camera.reset_view()
			demo_pest_id = game.animals.begin_tutorial_attack()
			demo_stage = 1
		elif demo_stage == 2:
			demo_stage = 3
	elif step == 8:
		step = 9
	_refresh()

func _skip() -> void:
	skipped = true
	game.animals.cancel_tutorial_attack()
	game.cancel_preview()
	game._cancel_animal_drag()
	hide()

func _draw() -> void:
	if not visible:
		return
	var points: Array[Vector2] = []
	if step == 7 and demo_stage == 2:
		var center: Vector2 = game.get_node("UI/ClockAnchor").position
		var tip: Vector2 = center + Vector2.from_angle(game.clock_angle()) * game.overlay.clock_size * 0.29
		draw_arc(tip, 20 + sin(pulse * 3) * 3, 0, TAU, 40, Color("a99250"), 2.5, true)
	if step == 0:
		for pickup in game.resources.pickups:
			if (pickup.kind == 0 and not facts.has("sun")) or (pickup.kind == 1 and not facts.has("water")):
				points.append(game.world_camera.world_to_screen(pickup.position))
	elif step in [1, 3, 5, 8]:
		for bud in game.growth.available_buds():
			points.append(game.world_camera.world_to_screen(bud.global_position))
	elif step == 4:
		for branch in game.branches.get_children():
			if not branch.grown and not branch.preview:
				points.append(game.world_camera.world_to_screen(branch.root_position()))
	if companion_tip >= 0:
		for actor in game.animals.companions:
			if actor.kind == companion_tip and actor.state == "IDLE":
				points.append(game.world_camera.world_to_screen(actor.position + Vector2(0, -25)))
	for point in points:
		if Rect2(100, 100, 1720, 850).has_point(point):
			draw_arc(point, 29 + sin(pulse * 3) * 3, 0, TAU, 40, Color(0.67, 0.57, 0.29, 0.8), 2.5, true)

func clock_input_allowed() -> bool:
	if skipped:
		return true
	return step != 8 and companion_tip < 0 and not night_tip and (step == 5 or step >= 9 or (step == 7 and demo_stage in [2, 3]))
