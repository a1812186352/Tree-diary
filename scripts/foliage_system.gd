extends Node2D
## Builds three deterministic foliage layers from sprite sheets. Leaves only
## appear on mature branches, so the page turn also reveals visible growth.

var config: Resource
var branch_root: Node2D
var soft_layer: Node2D
var soft_material: ShaderMaterial
var back_layer: Node2D
var middle_layer: Node2D
var front_layer: Node2D
var animation_time: float = 0.0

func _ready() -> void:
	soft_layer = _make_layer("SoftCanopyBackground", -7)
	soft_material = ShaderMaterial.new()
	soft_material.shader = preload("res://shaders/soft_canopy.gdshader")
	back_layer = _make_layer("RearCanopy", -4)
	middle_layer = _make_layer("MiddleLeaves", 2)
	front_layer = _make_layer("FrontSprays", 4)

func setup(game_config: Resource, branches: Node2D) -> void:
	config = game_config
	branch_root = branches
	refresh()

func refresh() -> void:
	if config == null or branch_root == null:
		return
	_clear_layer(soft_layer)
	_clear_layer(back_layer)
	_clear_layer(middle_layer)
	_clear_layer(front_layer)
	var mature_branches: Array[Node] = []
	for branch in branch_root.get_children():
		if branch.grown and not branch.preview:
			mature_branches.append(branch)
	_build_soft_canopy(mature_branches)
	for branch in mature_branches:
		_add_branch_foliage(branch)
		if config.current_season == 3 and not branch.is_base and absi(branch.branch_id.hash()) % 3 == 0:
			var cap := Sprite2D.new()
			cap.texture = config.seasonal_snow[absi(branch.branch_id.hash()) % config.seasonal_snow.size()]
			cap.position = to_local(branch.root_position().lerp(branch.tip_position(), 0.6)) + Vector2(0, -12)
			cap.scale = Vector2.ONE * (65.0 / maxf(1, cap.texture.get_width()))
			front_layer.add_child(cap)

func _make_layer(layer_name: String, draw_order: int) -> Node2D:
	var result := Node2D.new()
	result.name = layer_name
	result.z_index = draw_order
	add_child(result)
	return result

func _clear_layer(layer_node: Node2D) -> void:
	for child in layer_node.get_children():
		child.hide()
		child.queue_free()

func _add_branch_foliage(branch: Node2D) -> void:
	var seed_value: int = absi(branch.branch_id.hash())
	var start: Vector2 = branch.root_position()
	var finish: Vector2 = branch.tip_position()
	var direction: Vector2 = (finish - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var branch_angle: float = Vector2.UP.angle_to(direction)

	# Rear masses overlap into one canopy. The trunk starts with the small young
	# crown; later branches use varied silhouettes and gradually fill the tree.
	var rear_index: int = 4 if branch.is_base else seed_value % 6
	var rear_position: Vector2 = finish + direction * 8.0
	var rear_scale: float = 0.78 if branch.is_base else 0.62 + minf(branch.depth, 3) * 0.055
	var rear := _make_sprite(config.foliage_rear_atlas, 3, 2, rear_index,
		rear_position, branch_angle * 0.10, rear_scale, config.foliage_rear_opacity)
	back_layer.add_child(rear)

	# Two readable clusters sit beside the wood, away from the root and tip buds.
	var leaf_count: int = 2 if branch.is_base else config.foliage_middle_per_branch
	for i in range(leaf_count):
		var side: float = -1.0 if ((seed_value + i) & 1) == 0 else 1.0
		var along: float = 0.42 + i * 0.25
		var offset: float = (23.0 + (seed_value + i * 7) % 13) * side
		var position_on_branch: Vector2 = start.lerp(finish, along) + normal * offset
		var texture_index: int = (seed_value + i * 5) % 12
		var rotation_offset: float = deg_to_rad(float((seed_value + i * 17) % 25 - 12))
		var leaf := _make_sprite(config.foliage_middle_atlas, 4, 3, texture_index,
			position_on_branch, branch_angle + rotation_offset, config.foliage_middle_scale, 1.0)
		middle_layer.add_child(leaf)

	# Only some branches receive a foreground spray. It crosses the middle of
	# the wood while leaving tip buds clear.
	if branch.is_base or float(seed_value % 100) / 100.0 < config.foliage_front_chance:
		var front_index: int = (seed_value * 3 + branch.depth) % 8
		var front_position: Vector2 = start.lerp(finish, 0.57) + normal * (8.0 if seed_value % 2 == 0 else -8.0)
		var spray := _make_sprite(config.foliage_front_atlas, 4, 2, front_index,
			front_position, branch_angle, config.foliage_front_scale, config.foliage_front_opacity)
		front_layer.add_child(spray)

func _make_sprite(sheet: Texture2D, columns: int, rows: int, index: int,
		world_position: Vector2, angle: float, size_scale: float, opacity: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	var cell := Vector2(sheet.get_width() / float(columns), sheet.get_height() / float(rows))
	atlas.atlas = sheet
	atlas.region = Rect2(Vector2(index % columns, index / columns) * cell, cell)
	if config.current_season >= 0:
		atlas = null
		sprite.texture = sheet
		var reference_size: float = 245.0 if sheet == config.foliage_rear_atlas else (100.0 if sheet == config.foliage_middle_atlas else 120.0)
		size_scale *= reference_size / maxf(1, sheet.get_width())
		if config.current_season == 3:
			size_scale *= 0.80
	else:
		sprite.texture = atlas
	sprite.position = to_local(world_position)
	sprite.rotation = angle
	sprite.scale = Vector2.ONE * size_scale
	sprite.modulate.a = opacity
	sprite.set_meta("rest_rotation", angle)
	sprite.set_meta("sway_phase", float(index) * 0.83 + world_position.x * 0.007)
	return sprite

func _process(delta: float) -> void:
	if config == null:
		return
	animation_time += delta
	_sway_layer(soft_layer, 0.003)
	_sway_layer(back_layer, 0.006)
	_sway_layer(middle_layer, 0.018)
	_sway_layer(front_layer, 0.026)

func _sway_layer(layer_node: Node2D, amount: float) -> void:
	for sprite in layer_node.get_children():
		var phase: float = sprite.get_meta("sway_phase", 0.0)
		var resting: float = sprite.get_meta("rest_rotation", 0.0)
		sprite.rotation = resting + sin(animation_time * 1.15 + phase) * amount

func _build_soft_canopy(mature_branches: Array[Node]) -> void:
	var season: int = clampi(config.current_season, 0, 3)
	var tints: Array[Color] = [Color("c8d9a7"), Color("bbd0a2"), Color("e4cfaa"), Color("d9dfd9")]
	soft_material.set_shader_parameter("leaf_tint", tints[season])
	var centers: Array[Vector2] = []
	var fill_centers: Array[Vector2] = []
	for branch in mature_branches:
		# Do not fill the exposed lower trunk or any uncommitted sticker.
		if branch.is_base:
			continue
		var start: Vector2 = branch.root_position()
		var finish: Vector2 = branch.tip_position()
		var center: Vector2 = start.lerp(finish, 0.62)
		centers.append(center)
		var length: float = start.distance_to(finish)
		_add_soft_mass(center, Vector2(clampf(length + 140, 220, 330), 205), 0.68, absi(branch.branch_id.hash()))
	_fill_inner_canopy(mature_branches)
	# Join only neighboring crowns: retain large deliberate openings in the tree.
	for i in range(centers.size()):
		var neighbors: Array[int] = []
		for j in range(i + 1, centers.size()):
			var distance: float = centers[i].distance_to(centers[j])
			if distance > 90 and distance < 390:
				neighbors.append(j)
		neighbors.sort_custom(func(a, b): return centers[i].distance_squared_to(centers[a]) < centers[i].distance_squared_to(centers[b]))
		for k in range(mini(2, neighbors.size())):
			var other: Vector2 = centers[neighbors[k]]
			var middle: Vector2 = centers[i].lerp(other, 0.5)
			if fill_centers.any(func(point): return point.distance_to(middle) < 100):
				continue
			fill_centers.append(middle)
			var span: float = centers[i].distance_to(other)
			_add_soft_mass(middle, Vector2(clampf(span * 0.8, 180, 290), 190), 0.55, i * 31 + k)

func _add_soft_mass(world_position: Vector2, extent: Vector2, opacity: float, seed_value: int) -> void:
	var sprite: Sprite2D = _make_sprite(config.foliage_rear_atlas, 3, 2, seed_value % 6, world_position, 0.0, 1.0, opacity)
	var size: Vector2 = sprite.texture.get_size()
	var winter_scale: float = 0.82 if config.current_season == 3 else 1.0
	sprite.scale = extent * winter_scale / size
	sprite.flip_h = seed_value % 2 == 0
	sprite.material = soft_material
	soft_layer.add_child(sprite)

# Trace the mature branch silhouette in horizontal bands, filling the forks
# while leaving the roots and lower trunk exposed.
func _fill_inner_canopy(mature_branches: Array[Node]) -> void:
	if mature_branches.size() < 4:
		return
	var base_y: float = -INF
	var top_y: float = INF
	for branch in mature_branches:
		if branch.is_base:
			base_y = branch.root_position().y
		top_y = minf(top_y, branch.tip_position().y)
	if not is_finite(base_y) or base_y - top_y < 350.0:
		return
	var bottom_y: float = base_y - 220.0
	var y: float = bottom_y
	var band: int = 0
	while y > top_y + 80.0:
		var crossings: Array[float] = []
		for branch in mature_branches:
			var start: Vector2 = branch.root_position()
			var finish: Vector2 = branch.tip_position()
			if absf(finish.y - start.y) < 1.0:
				continue
			var along: float = (y - start.y) / (finish.y - start.y)
			if along >= 0.0 and along <= 1.0:
				crossings.append(start.lerp(finish, along).x)
		crossings.sort()
		for i in range(crossings.size()):
			_add_soft_mass(Vector2(crossings[i], y), Vector2(210, 180), 0.58, band * 17 + i)
			if i == 0:
				continue
			var span: float = crossings[i] - crossings[i - 1]
			if span < 130.0 or span > 650.0:
				continue
			var pieces: int = ceili(span / 150.0)
			for j in range(1, pieces):
				var x: float = lerpf(crossings[i - 1], crossings[i], float(j) / pieces)
				_add_soft_mass(Vector2(x, y - 10.0), Vector2(230, 190), 0.50, band * 31 + j)
		y -= 125.0
		band += 1
