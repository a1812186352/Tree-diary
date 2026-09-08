@tool
extends Node2D
@export var bird_textures: Array[Texture2D] = [preload("res://arsset/art/bird_1.png"), preload("res://arsset/art/bird_2.png"), preload("res://arsset/art/bird_3.png")]
@export var ground_texture: Texture2D = preload("res://arsset/art/mouse.png")
@export var sunlight_texture: Texture2D = preload("res://arsset/art/sunlight.png")
@export var water_texture: Texture2D = preload("res://arsset/art/water.png")
@export var heart_texture: Texture2D = preload("res://arsset/art/heart_normal.png")
@export var broken_heart_texture: Texture2D = preload("res://arsset/art/heart_broken.png")
@export var wood_tray: Texture2D = preload("res://arsset/ui/wood_tray.png")
@export var clock_faces: Array[Texture2D] = [preload("res://arsset/ui/clock_day.png"), preload("res://arsset/ui/clock_dusk.png"), preload("res://arsset/ui/clock_night.png")]
@export var clock_leaf: Texture2D = preload("res://arsset/ui/clock_leaf.png")
@export var clock_size: float = 220.0
@export var leaf_pivot_uv: Vector2 = Vector2(0.5, 0.89)
@export var resource_tray_size: Vector2 = Vector2(720, 220)
@export var growth_tray_size: Vector2 = Vector2(820, 235)
@onready var game: Node2D = get_parent().get_parent()
var menu_mode: int = 0
var drawing_space: Transform2D = Transform2D.IDENTITY

func _use_world_space() -> void:
	drawing_space = game.get_viewport().get_canvas_transform()
	draw_set_transform_matrix(drawing_space)

func _use_screen_space() -> void:
	drawing_space = Transform2D.IDENTITY
	draw_set_transform_matrix(drawing_space)

func _picture_transform(origin: Vector2, angle: float = 0.0, stretch: Vector2 = Vector2.ONE) -> void:
	draw_set_transform_matrix(drawing_space * Transform2D(angle, stretch, 0.0, origin))

func display_phase() -> String:
	if Engine.is_editor_hint():
		return game.editor_phase
	if game.phase.phase == "PAGE_TURN" and game.page_swapped:
		return "DAY"
	return game.phase.phase

# Preview uses the same artwork and anchors without starting gameplay systems.
func _draw_editor_preview() -> void:
	if display_phase() == "DAY":
		var points: Array[Node] = game.anchors.get_node("ResourceSpawns").get_children()
		for i in range(points.size()):
			picture(sunlight_texture if i % 2 == 0 else water_texture, to_local(points[i].global_position), 57)
	_draw_clock()
	_draw_pockets()
	_draw_growth_tray()
	for i in range(game.config.max_hearts):
		var origin: Vector2 = to_local(game.anchors.get_node("HeartAnchor").global_position)
		picture(heart_texture, origin + Vector2(i * 49, 0), 44)
	if game.editor_show_actors:
		for point in game.anchors.get_node("GroundAnchors").get_children():
			picture(ground_texture, to_local(point.global_position) + Vector2(0, -25), 75, 0.8)
		var birds: Array[Node] = game.anchors.get_node("BirdAnchors").get_children()
		for i in range(birds.size()):
			picture(bird_textures[i % bird_textures.size()], to_local(birds[i].global_position) + Vector2(0, -25), 80, 0.8)

func label_at(point: Vector2, text: String, size: int = 24, color: Color = Color("52634f")) -> void:
	if game.sky_current == "NIGHT" and display_phase() != "GAMEOVER" and point.y < 760:
		color = Color("f4efda")
	draw_string(game.title_font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func picture(texture: Texture2D, center: Vector2, size: float, alpha: float = 1.0, angle: float = 0.0) -> void:
	if texture == null:
		return
	var dimensions: Vector2 = texture.get_size()
	dimensions *= size / maxf(dimensions.x, dimensions.y)
	_picture_transform(center, angle)
	draw_texture_rect(texture, Rect2(-dimensions * 0.5, dimensions), false, Color(1, 1, 1, alpha))
	_picture_transform(Vector2.ZERO)

func _draw() -> void:
	_use_screen_space()
	if not game.is_node_ready():
		return
	if game.config == null or game.title_font == null:
		return
	if Engine.is_editor_hint():
		_draw_editor_preview()
		return
	if menu_mode != 0:
		game._draw_menu(self)
		return
	var phase: String = game.phase.phase
	if phase == "GAMEOVER":
		return
	_use_world_space()
	for pickup in game.resources.pickups:
		picture(sunlight_texture if pickup.kind == 0 else water_texture, pickup.position, 57)
	_use_screen_space()
	for flight in game.collection_flights:
		var destination: Vector2 = game.get_node("UI/ResourcePocketAnchor").position + Vector2(84, 107 + flight.kind * 58)
		var source: Vector2 = game.world_camera.world_to_screen(flight.start)
		picture(sunlight_texture if flight.kind == 0 else water_texture, source.lerp(destination, flight.progress), 50 - flight.progress * 14)
	_use_world_space()
	for omen in game.animals.omens:
		var p: Vector2 = omen.position
		var omen_tex: Texture2D = game.config.acorn_texture if omen.kind == 0 else game.config.feather_texture
		var omen_size: float = game.config.omen_display_size
		var hover := sin(game.phase.elapsed * 2.2 + omen.id) * 2.5
		if omen_tex != null:
			picture(omen_tex, p + Vector2(0, hover), omen_size)
		else:
			if omen.kind == 0:
				draw_circle(p + Vector2(0, 3), 10, Color("c7ac7c"))
				draw_arc(p + Vector2(0, -2), 10, PI, TAU, 12, Color("8e916f"), 7, true)
				draw_line(p + Vector2(0, -9), p + Vector2(2, -14), Color("8e916f"), 2, true)
			else:
				_picture_transform(p, 0.5, Vector2(0.5, 1))
				draw_circle(Vector2.ZERO, 16, Color("f7f5df"))
				_picture_transform(Vector2.ZERO)
				draw_line(p + Vector2(4, -12), p + Vector2(-8, 20), Color("b2c3b4"), 2, true)
	for actor in game.animals.companions + game.animals.visitors:
		_draw_actor(actor)
	for shot in game.animals.projectiles:
		if game.config.pine_texture != null:
			picture(game.config.pine_texture, shot.position, 20, 1, shot.elapsed * 9)
		else:
			# Small ivory/brown seed placeholder; replace through Pine Texture later.
			_picture_transform(shot.position, shot.elapsed * 9, Vector2(0.6, 1.0))
			draw_circle(Vector2.ZERO, 9, Color("8c6944"))
			draw_circle(Vector2(-1, -1), 6, Color("e8cb91"))
			_picture_transform(Vector2.ZERO)
	for pest in game.animals.pests:
		var p: Vector2 = pest.position
		if pest.kind == 0:
			p.y -= game.config.pest_display_size * 0.42
		var pest_pool: Array[Texture2D] = game.config.pest_ground_textures if pest.kind == 0 else game.config.pest_air_textures
		var pest_size: float = game.config.pest_display_size
		if pest.get("hit_flash", 0.0) > 0:
			draw_arc(p, pest_size * 0.5, 0, TAU, 24, Color("f4cf77"), 3, true)
		if not pest_pool.is_empty():
			var idx: int = pest.id % pest_pool.size()
			picture(pest_pool[idx], p, pest_size)
		else:
			if pest.kind == 0:
				for i in range(3):
					draw_circle(p + Vector2(i * 8 - 8, -8), 9, Color("929b71"))
			else:
				draw_circle(p + Vector2(-8, -8), 9, Color("f5f1dc"))
				draw_circle(p + Vector2(8, -8), 9, Color("f5f1dc"))
				draw_circle(p, 7, Color("7b7763"))
			draw_circle(p + Vector2(-7, -9), 2, Color("4d5547"))
	_use_screen_space()
	for i in range(game.config.max_hearts):
		var origin: Vector2 = game.anchors.get_node("HeartAnchor").global_position
		picture(heart_texture if i < game.hearts else broken_heart_texture, origin + Vector2(i * 49, 0), 44)
	_use_world_space()
	for i in range(game.damage_marks):
		var root: Vector2 = game.branches.get_node("Base/RootAnchor").global_position
		draw_line(root + Vector2(-6, -20 - i * 14), root + Vector2(6, -29 - i * 14), Color("9e8b70"), 3, true)
	_use_screen_space()
	_draw_clock()
	_draw_pockets()
	_draw_growth_tray()
	_use_world_space()
	if phase == "DAY" and game.candidate != null:
		var cp: Vector2 = game.candidate.global_position
		draw_circle(cp, 28, Color("f8c66a", 0.35))
		draw_arc(cp, 26, 0, TAU, 40, Color("f1b94a"), 5, true)
		draw_arc(cp, 18, 0, TAU, 32, Color("f8f3ce"), 2.5, true)
	# Foliage may cross the wood, but usable growth points always remain legible
	# above every leaf layer.
	if phase == "DAY":
		for bud in game.growth.available_buds():
			var bp: Vector2 = bud.global_position
			draw_circle(bp, 13, Color(0.96, 0.95, 0.78, 0.34))
			draw_arc(bp, 12, 0, TAU, 28, Color("819a68"), 2.0, true)
	_use_screen_space()

func _draw_actor(actor: Dictionary) -> void:
	var bird: bool = actor.kind == 1
	var variant: int = actor.variant % bird_textures.size()
	var texture: Texture2D = bird_textures[variant] if bird else ground_texture
	if texture == null:
		return
	var velocity: Vector2 = actor.get("velocity", Vector2.ZERO)
	var moving: bool = actor.state in ["ARRIVING", "BUSY", "RETURNING", "LEAVING", "PASSING"] and velocity.length() > 1
	var t: float = game.animals.animation_time * (13.0 if bird else 10.0) + actor.id
	var facing: float = actor.get("facing", 1.0)
	# Blue bird faces left; yellow and peach birds face right in their source art.
	var source_facing: float = -1.0 if bird and variant == 0 else 1.0
	var stretch := Vector2(facing * source_facing, 1)
	var offset := Vector2(0, -25 if bird else -32)
	var tilt: float = 0.0
	if moving:
		offset.y += sin(t) * 4.0 if bird else 0.0
		stretch.y = 1.0 + sin(t) * (0.06 if bird else 0.025)
		tilt = clampf(velocity.y / 1000.0, -0.18, 0.18) * facing if bird else sin(t) * 0.06
	if actor.state == "EATING":
		stretch.y = 1.0 + sin(t * 1.6) * 0.06
		offset.y += sin(t * 1.6) * 2
	if actor.get("throw_flash", 0.0) > 0:
		tilt = -0.2 * facing * sin(actor.throw_flash / 0.3 * PI)
	var dimensions: Vector2 = texture.get_size()
	dimensions *= (80.0 if bird else 75.0) / maxf(dimensions.x, dimensions.y)
	_picture_transform(actor.position + offset, tilt, stretch)
	draw_texture_rect(texture, Rect2(-dimensions * 0.5, dimensions), false)
	_picture_transform(Vector2.ZERO)

func _draw_gameover_popup() -> void:
	var is_win: bool = game.phase.result == "WIN"
	var illustration: Texture2D = game.config.ending_survival_texture if is_win else game.config.ending_invasion_texture
	if illustration != null:
		_use_screen_space()
		draw_rect(Rect2(0, 0, 1920, 1080), Color("f6f1e6"))
		# Show the whole illustration above a separate footer; no world-camera transform.
		picture(illustration, Vector2(960, 486), 900)
		draw_line(Vector2(80, 960), Vector2(1840, 960), Color("d6cbb4"), 1.5, true)
		label_at(Vector2(80, 1006), "一棵树，一群朋友" if is_win else "这一页，被昆虫占据了", 30)
		label_at(Vector2(80, 1044), "你守住了六个日夜，让这里成为了家。" if is_win else "再种一棵，让伙伴更早来到树的身边。", 22, Color("887960"))
		return
	var title: String = "一棵树，一群朋友" if is_win else "这一页，先休息一下"
	var lines: Array[String] = []
	if is_win:
		lines.append("谢谢你，留下了这些生长的痕迹。")
	else:
		lines.append("试着更早留下橡果，让伙伴赶来守护。")
	lines.append("明天还会有新的阳光，和新的芽点。")
	_draw_popup(Rect2(460, 220, 1000, 640), title, lines)

func _draw_popup(panel_rect: Rect2, title: String, lines: Array[String]) -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.25, 0.3, 0.24, 0.4))
	var panel_tex: Texture2D = game.config.panel_texture
	if panel_tex != null:
		var psize: Vector2 = panel_tex.get_size()
		var pscale: float = minf(panel_rect.size.x / psize.x, panel_rect.size.y / psize.y)
		var draw_size: Vector2 = psize * pscale
		var origin: Vector2 = panel_rect.position + (panel_rect.size - draw_size) * 0.5
		draw_texture_rect(panel_tex, Rect2(origin, draw_size), false)
	else:
		draw_style_box(_panel_style(), panel_rect)
	var title_tex: Texture2D = game.config.title_banner_texture
	var title_base_y: float
	if title_tex != null:
		var ts: Vector2 = title_tex.get_size()
		var tw: float = 360.0
		var th: float = ts.y * (tw / ts.x)
		var t_origin: Vector2 = panel_rect.position + Vector2((panel_rect.size.x - tw) * 0.5, -th * 0.35)
		draw_texture_rect(title_tex, Rect2(t_origin, Vector2(tw, th)), false)
		var text_w: float = game.title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(game.title_font, t_origin + Vector2((tw - text_w) * 0.5, th * 0.7), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("54654f"))
		title_base_y = panel_rect.position.y + 140
	else:
		var text_w: float = game.title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		var t_origin: Vector2 = panel_rect.position + Vector2((panel_rect.size.x - text_w) * 0.5, 70)
		draw_string(game.title_font, t_origin, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("54654f"))
		title_base_y = panel_rect.position.y + 140
	for i in range(lines.size()):
		var line: String = lines[i]
		var size: Vector2 = game.title_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		var pos: Vector2 = panel_rect.position + Vector2((panel_rect.size.x - size.x) * 0.5, title_base_y + i * 46)
		draw_string(game.title_font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("54654f"))

func _panel_style() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("faf6e8")
	panel.set_corner_radius_all(20)
	return panel


func _draw_pockets() -> void:
	var shake: float = sin(game.pocket_shake * 40) * game.pocket_shake * 7
	var p: Vector2 = game.get_node("UI/ResourcePocketAnchor").position + Vector2(shake, 0)
	draw_texture_rect(wood_tray, Rect2(p, resource_tray_size), false)
	for kind in range(2):
		var texture: Texture2D = sunlight_texture if kind == 0 else water_texture
		var count: int = 3 if Engine.is_editor_hint() else (game.resources.sunlight if kind == 0 else game.resources.water)
		for i in range(count):
			picture(texture, p + Vector2(84 + (i % 11) * 49, 107 + kind * 58 - floorf(float(i) / 11) * 8), 48)
		if count == 0:
			picture(texture, p + Vector2(84, 107 + kind * 58), 48, 0.25)

func tray_card_rect(index: int) -> Rect2:
	var slot: Vector2 = game.get_node("UI/TraySlots").get_child(index).position
	return Rect2(slot + Vector2(42, -8), Vector2(136, 190))

func _draw_growth_tray() -> void:
	var origin: Vector2 = game.get_node("UI/GrowthTrayAnchor").position
	draw_texture_rect(wood_tray, Rect2(origin, growth_tray_size), false)
	var names := ["单芽", "双芽", "三芽"]
	var alpha: float = 1.0 if display_phase() == "DAY" else 0.45
	for i in range(3):
		var p: Vector2 = game.get_node("UI/TraySlots").get_child(i).position
		var tray_tex: Texture2D = game.config.tray_textures[i] if game.config.tray_textures.size() > i else null
		if tray_tex != null:
			draw_texture_rect(tray_tex, tray_card_rect(i), false, Color(1, 1, 1, alpha))
		else:
			var texture: Texture2D = load("res://arsset/nature/branch_%dbud.png" % (i + 1))
			picture(texture, p + Vector2(62, 81), 168, alpha, -0.25 + i * 0.25)
			for n in range(game.config.costs[i]):
				picture(sunlight_texture, p + Vector2(108 + n * 28, 88), 26, alpha)
				picture(water_texture, p + Vector2(108 + n * 28, 123), 25, alpha)
			label_at(p + Vector2(101, 47), names[i], 23, Color("746446"))

func _draw_clock() -> void:
	var p: Vector2 = game.get_node("UI/ClockAnchor").position
	var index: int = 0
	if display_phase() == "DUSK":
		index = 1
	elif display_phase() in ["NIGHT", "PAGE_TURN", "GAMEOVER"]:
		index = 2
	var face: Texture2D = clock_faces[index]
	var face_scale: float = clock_size / face.get_width()
	# All supplied faces meet at pixel (250, 244), just above the canvas center.
	draw_texture_rect(face, Rect2(p - Vector2(250, 244) * face_scale, face.get_size() * face_scale), false)
	var leaf_size: Vector2 = clock_leaf.get_size()
	var leaf_scale: float = (clock_size * 0.29) / (leaf_size.y * 0.85)
	var pivot: Vector2 = leaf_size * leaf_pivot_uv
	draw_set_transform(p, game.clock_angle() + PI * 0.5)
	draw_texture_rect(clock_leaf, Rect2(-pivot * leaf_scale, leaf_size * leaf_scale), false)
	draw_set_transform(Vector2.ZERO)
	draw_circle(p, 3.0, Color("779945"))
	var day_number: int = 1 if Engine.is_editor_hint() else game.phase.day
	var day_text: String = "day %d" % day_number
	var text_width: float = game.title_font.get_string_size(day_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	label_at(p + Vector2(-text_width * 0.5, clock_size * 0.5 + 30), day_text, 26)
