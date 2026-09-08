extends Node
signal changed
var sunlight: int = 0
var water: int = 0
var pickups: Array[Dictionary] = []

func begin_day(config: Resource, markers: Node, visible_area: Rect2 = Rect2()) -> void:
	if not config.resource_carry_over:
		sunlight = 0
		water = 0
	pickups.clear()
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
