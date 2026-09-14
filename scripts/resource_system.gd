extends Node
signal changed
var sunlight: int = 0
var water: int = 0
var pickups: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func begin_day(config: Resource, markers: Node, visible_area: Rect2 = Rect2(), day: int = 1, blocked: Array[Rect2] = []) -> void:
	if not config.resource_carry_over:
		sunlight = 0
		water = 0
	pickups.clear()
	if day > 1:
		_spawn_random(config, visible_area, blocked)
		changed.emit()
		return
	var spots := markers.get_children()
	for kind in range(2):
		var count: int = config.sunlight_per_day if kind == 0 else config.water_per_day
		for i in range(count):
			var index: int = (0 if kind == 0 else config.sunlight_per_day) + i
			var p := Vector2(350 + (index % 6) * 200, 350 + (index / 6) * 160)
			if not spots.is_empty():
				p = spots[index % spots.size()].global_position
				p += Vector2(0, -50 * floorf(float(index) / spots.size()))
			if visible_area.has_area():
				# Preserve the marker layout in screen proportions, then freeze world positions.
				var uv: Vector2 = (p / Vector2(1920, 1080)).clamp(Vector2(0.12, 0.23), Vector2(0.84, 0.66))
				p = visible_area.position + uv * visible_area.size
			pickups.append({"kind": kind, "position": p})
	changed.emit()

func _spawn_random(config: Resource, visible_area: Rect2, blocked: Array[Rect2]) -> void:
	var count: int = maxi(0, config.sunlight_per_day) + maxi(0, config.water_per_day)
	if count == 0:
		return
	var area := Rect2(250, 310, 1300, 410)
	var columns: int = maxi(1, ceili(sqrt(count * area.size.x / area.size.y)))
	var rows: int = maxi(1, ceili(float(count) / columns))
	var cell_size: Vector2 = area.size / Vector2(columns, rows)
	var cells: Array[Vector2i] = []
	for row in range(rows):
		for column in range(columns):
			cells.append(Vector2i(column, row))
	var world_area: Rect2 = visible_area if visible_area.has_area() else Rect2(0, 0, 1920, 1080)
	var open_points: Array[Vector2] = []
	for row in range(12):
		for column in range(32):
			var uv := Vector2((column + rng.randf_range(0.2, 0.8)) / 32.0, (row + rng.randf_range(0.2, 0.8)) / 12.0)
			var screen_point: Vector2 = area.position + uv * area.size
			var p: Vector2 = world_area.position + screen_point / Vector2(1920, 1080) * world_area.size
			if not blocked.any(func(rect): return rect.has_point(p)):
				open_points.append(p)
	for i in range(count):
		var index: int = rng.randi_range(0, cells.size() - 1)
		var cell: Vector2i = cells[index]
		cells.remove_at(index)
		var offset := Vector2(rng.randf_range(0.35, 0.65), rng.randf_range(0.35, 0.65))
		var screen_point: Vector2 = area.position + (Vector2(cell) + offset) * cell_size
		var p: Vector2 = world_area.position + screen_point / Vector2(1920, 1080) * world_area.size
		var crowded: bool = blocked.any(func(rect): return rect.has_point(p))
		var spacing: float = maxf(90, 100 * world_area.size.x / 1920.0)
		if crowded or pickups.any(func(pickup): return pickup.position.distance_to(p) < spacing):
			var best: int = -1
			var best_score: float = -INF
			for candidate in range(open_points.size()):
				var point: Vector2 = open_points[candidate]
				var clearance: float = spacing
				for pickup in pickups:
					clearance = minf(clearance, point.distance_to(pickup.position))
				var score: float = clearance * 1000 - point.distance_to(p)
				if score > best_score:
					best_score = score
					best = candidate
			if best >= 0:
				p = open_points[best]
				open_points.remove_at(best)
				crowded = false
		pickups.append({"kind": 0 if i < config.sunlight_per_day else 1, "position": p, "backing": crowded})

func collect_at(point: Vector2) -> bool:
	for i in range(pickups.size() - 1, -1, -1):
		if point.distance_to(pickups[i].position) < 42:
			if pickups[i].kind == 0:
				sunlight += 1
			else:
				water += 1
			pickups.remove_at(i)
			changed.emit()
			return true
	return false

func can_pay(cost: int) -> bool:
	return cost > 0 and sunlight >= cost and water >= cost

func pay(cost: int) -> bool:
	if not can_pay(cost):
		return false
	sunlight -= cost
	water -= cost
	changed.emit()
	return true

func refund(cost: int) -> void:
	if cost <= 0:
		return
	sunlight += cost
	water += cost
	changed.emit()
