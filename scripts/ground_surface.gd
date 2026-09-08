@tool
extends StaticBody2D
const LAND_LEFT: float = 38.0
const LAND_WIDTH: float = 1844.0
const FLOOR_DEPTH: float = 5000.0
## Surface follows the solid hill edge (below the decorative grass tips).
@export var surface_points := PackedVector2Array([Vector2(-160, 845), Vector2(38, 845), Vector2(222, 821), Vector2(499, 793), Vector2(960, 772), Vector2(1421, 794), Vector2(1698, 821), Vector2(1882, 845), Vector2(2080, 845)]):
	set(value):
		surface_points = value
		if is_inside_tree():
			_rebuild()

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	var shape = get_node_or_null("CollisionPolygon2D")
	if shape == null or surface_points.size() < 2:
		return
	var polygon := PackedVector2Array()
	# Match the mirrored artwork while keeping the central hand-placed surface.
	var inner_xs: Array[float] = [LAND_LEFT]
	for point in surface_points:
		if point.x > LAND_LEFT and point.x < LAND_LEFT + LAND_WIDTH:
			inner_xs.append(point.x)
	inner_xs.append(LAND_LEFT + LAND_WIDTH)
	inner_xs.sort()
	for tile in range(-6, 7):
		var tile_xs: Array[float] = []
		for source_x in inner_xs:
			var offset: float = source_x - LAND_LEFT
			if posmod(tile, 2) == 1:
				offset = LAND_WIDTH - offset
			tile_xs.append(LAND_LEFT + tile * LAND_WIDTH + offset)
		tile_xs.sort()
		for x in tile_xs:
			if not polygon.is_empty() and is_equal_approx(polygon[-1].x, x):
				continue
			polygon.append(Vector2(x, _local_height(x)))
	polygon.append(Vector2(polygon[-1].x, FLOOR_DEPTH))
	polygon.append(Vector2(polygon[0].x, FLOOR_DEPTH))
	shape.polygon = polygon

func height_at(world_x: float) -> float:
	var x: float = to_local(Vector2(world_x, 0)).x
	return to_global(Vector2(x, _local_height(x))).y

func _local_height(x: float) -> float:
	var offset: float = fposmod(x - LAND_LEFT, LAND_WIDTH * 2.0)
	if offset > LAND_WIDTH:
		offset = LAND_WIDTH * 2.0 - offset
	x = LAND_LEFT + offset
	if surface_points.is_empty():
		return 800.0
	for i in range(1, surface_points.size()):
		var a := surface_points[i - 1]
		var b := surface_points[i]
		if x <= b.x:
			return a.lerp(b, clampf((x - a.x) / maxf(0.01, b.x - a.x), 0, 1)).y
	return surface_points[-1].y
