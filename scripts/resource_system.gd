extends Node
signal changed
var sunlight: int = 0
var water: int = 0
var carried: Vector2i = Vector2i.ZERO
var daily_supply: Vector2i = Vector2i.ZERO
var pickups: Array[Dictionary] = []
var pending: Array[Dictionary] = []
var day_time: float = 0.0
var current_day: int = 1
var next_pickup_id: int = 1
var previous_supply: Vector2i = Vector2i(-1, -1)
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func begin_day(config: Resource, markers: Node, visible_area: Rect2 = Rect2(), day: int = 1, _blocked: Array[Rect2] = []) -> void:
	current_day = day
	carried = Vector2i(mini(sunlight, config.resource_carry_limit), mini(water, config.resource_carry_limit)) if day > 1 and config.resource_carry_over else Vector2i.ZERO
	sunlight = carried.x
	water = carried.y
	pickups.clear()
	pending.clear()
	day_time = 0
	if day == 1:
		daily_supply = Vector2i(config.sunlight_per_day, config.water_per_day)
		var spots := markers.get_children()
		for kind in range(2):
			for i in range(daily_supply[kind]):
				var index: int = i + (daily_supply.x if kind == 1 else 0)
				var p := Vector2(350 + (index % 6) * 200, 350 + (index / 6) * 160)
				if not spots.is_empty():
					p = spots[index % spots.size()].global_position
					p += Vector2(0, -50 * floorf(float(index) / spots.size()))
				if visible_area.has_area():
					var uv: Vector2 = (p / Vector2(1920,1080)).clamp(Vector2(0.12,0.23), Vector2(0.84,0.66))
					p = visible_area.position + uv * visible_area.size
				pickups.append({"kind": kind, "position": p})
	else:
		for kind in range(2):
			var limits: Vector2i = config.sunlight_range if kind == 0 else config.water_range
			var amount: int = rng.randi_range(limits.x, limits.y)
			daily_supply[kind] = amount
			for i in range(amount):
				# Two of each are immediate; all remaining pickups spawn before midday.
				var at: float = 0 if i < 2 else config.day_duration * 0.48 * (float(i - 2) + rng.randf_range(0.15, 0.95)) / maxf(1, amount - 2)
				pending.append({"time": at, "kind": kind})
		pending.sort_custom(func(a, b): return a.time < b.time)
	previous_supply = daily_supply
	changed.emit()

func tick_day(delta: float, camera: Camera2D) -> void:
	if current_day == 1:
		return
	day_time += delta
	while not pending.is_empty() and pending[0].time <= day_time:
		var event: Dictionary = pending.pop_front()
		var spot := Vector2(rng.randf_range(210, 1680), rng.randf_range(315, 405))
		for attempt in range(16):
			var clear: bool = true
			for pickup in pickups:
				if camera.world_to_screen(pickup.position).distance_to(spot) < 68:
					clear = false
					break
			if clear:
				break
			spot = Vector2(rng.randf_range(210, 1680), rng.randf_range(320, 510))
		pickups.append({"kind": event.kind, "position": camera.screen_to_world(spot), "drift": Vector2(rng.randf_range(7, 14) * (-1 if next_pickup_id % 2 == 0 else 1), rng.randf_range(12, 20)), "settled": false, "id": next_pickup_id, "backing": true})
		next_pickup_id += 1
	for pickup in pickups:
		var screen: Vector2 = camera.world_to_screen(pickup.position)
		if not pickup.get("settled", false):
			screen += pickup.drift * delta
			if screen.y >= 720:
				pickup.settled = true
		# Keep the uncollected supply accessible when the player pans or zooms.
		screen = screen.clamp(Vector2(180, 310), Vector2(1720, 725))
		pickup.position = camera.screen_to_world(screen)

func end_day() -> void:
	pickups.clear()
	pending.clear()

func collect_at(point: Vector2, radius: float = 42.0) -> bool:
	for i in range(pickups.size() - 1, -1, -1):
		if point.distance_to(pickups[i].position) < radius:
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
