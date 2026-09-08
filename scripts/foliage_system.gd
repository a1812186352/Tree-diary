extends Node2D
## Builds three deterministic foliage layers from sprite sheets. Leaves only
## appear on mature branches, so the page turn also reveals visible growth.

var config: Resource
var branch_root: Node2D
var back_layer: Node2D
var middle_layer: Node2D
var front_layer: Node2D
var animation_time: float = 0.0

func _ready() -> void:
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
	_clear_layer(back_layer)
	_clear_layer(middle_layer)
	_clear_layer(front_layer)
	var mature_branches: Array[Node] = []
	for branch in branch_root.get_children():
		if branch.grown and not branch.preview:
			mature_branches.append(branch)
	for branch in mature_branches:
		_add_branch_foliage(branch)

func _make_layer(layer_name: String, draw_order: int) -> Node2D:
	var result := Node2D.new()
	result.name = layer_name
	result.z_index = draw_order
	add_child(result)
	return result

func _clear_layer(layer_node: Node2D) -> void:
	for child in layer_node.get_children():
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
	_sway_layer(back_layer, 0.006)
	_sway_layer(middle_layer, 0.018)
	_sway_layer(front_layer, 0.026)

func _sway_layer(layer_node: Node2D, amount: float) -> void:
	for sprite in layer_node.get_children():
		var phase: float = sprite.get_meta("sway_phase", 0.0)
		var resting: float = sprite.get_meta("rest_rotation", 0.0)
		sprite.rotation = resting + sin(animation_time * 1.15 + phase) * amount
