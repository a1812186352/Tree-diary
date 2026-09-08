@tool
extends Node2D
## Update retained land geometry before drawing, not from Main._draw().
const LAND_SHADER = preload("res://shaders/land_extend.gdshader")
var layers: Array[Polygon2D] = []

func _ensure_layers() -> void:
	if not layers.is_empty():
		return
	for index in range(2):
		var layer := Polygon2D.new()
		layer.name = "DistantHills" if index == 0 else "Soil"
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		var land_material := ShaderMaterial.new()
		land_material.shader = LAND_SHADER
		land_material.set_shader_parameter("top_fade", Vector2(0.56, 0.70) if index == 0 else Vector2(0.40, 0.54))
		layer.material = land_material
		add_child(layer)
		layers.append(layer)

func _process(_delta: float) -> void:
	var game: Node = get_parent().get_parent()
	if game.is_node_ready() and game.config != null:
		draw_land(game.config, game._land_tint())

func draw_land(config: Resource, tint: Color) -> void:
	_ensure_layers()
	var visible := Rect2(0, 0, 1920, 1080)
	if not Engine.is_editor_hint():
		var inverse := get_canvas_transform().affine_inverse()
		var viewport_size := get_viewport_rect().size
		var top_left: Vector2 = inverse * Vector2.ZERO
		visible = Rect2(top_left, inverse * viewport_size - top_left).grow(8.0)
	var corners := PackedVector2Array([visible.position,
		Vector2(visible.end.x, visible.position.y), visible.end,
		Vector2(visible.position.x, visible.end.y)])
	for index in range(layers.size()):
		var layer: Polygon2D = layers[index]
		var texture: Texture2D = config.ground_texture if index == 0 else config.hill_texture
		layer.visible = texture != null
		if texture == null:
			continue
		var geometry_changed: bool = layer.texture != texture or layer.polygon != corners
		if layer.texture != texture:
			layer.texture = texture
		if layer.modulate != tint:
			layer.modulate = tint
		if not geometry_changed:
			continue
		var texture_size: Vector2 = texture.get_size()
		var size: Vector2 = texture_size * (1844.0 / texture_size.x)
		var rise: float = 100.0 if index == 0 else 0.0
		var origin := Vector2(38.0, 1242.0 - size.y - rise)
		var coordinates := PackedVector2Array()
		for corner in corners:
			coordinates.append((corner - origin) / size * texture_size)
		# Polygon2D binds TEXTURE and converts its pixel UVs for the shader.
		layer.uv = coordinates
		layer.polygon = corners
