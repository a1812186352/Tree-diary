extends Node
signal pest_hit
signal sound_requested(event: String)
var config: Resource
var anchors: Node2D
var branch_root: Node2D
var companions: Array[Dictionary] = []
var pests: Array[Dictionary] = []
var omens: Array[Dictionary] = []
var wave: PackedInt32Array = PackedInt32Array()
var spawned: int = 0
var spawn_elapsed: float = 0
var night_time: float = 0
var dusk_time: float = 0
var next_omen_id: int = 1
var next_pest_id: int = 1
var projectiles: Array[Dictionary] = []
var visitors: Array[Dictionary] = []
var visit_timer: float = 5.0
var animation_time: float = 0.0
var next_actor_id: int = 1
var rng := RandomNumberGenerator.new()
# Cache the random draw, not the guarantee: moving the guaranteed acorn must
# not turn several buds into permanent guaranteed successes after undoing.
var acorn_rolls: Dictionary = {}

func _ready() -> void:
	rng.randomize()

func add_growth_omen(branch: Node2D, day: int, base_junction_y: float) -> void:
	var height: float = maxf(0, base_junction_y - branch.tip_position().y)
	var layer: int = maxi(1, ceili((height - 0.01) / config.vertical_layer_height))
	var kind: int = 0 if layer <= config.ground_omen_max_layer else 1
	if kind == 0:
		if not _can_add_acorn(branch.parent_bud_id, day):
			return
	elif rng.randf() >= clampf(config.feather_probability, 0.0, 1.0):
		return
	var fraction := rng.randf_range(0.4, 0.7)
	var p: Vector2 = branch.get_node("OmenAnchor").global_position + (branch.tip_position() - branch.root_position()) * (fraction - 0.5)
	omens.append({"id": next_omen_id, "kind": kind, "position": p, "eligible_day": day + 1, "branch_id": branch.branch_id, "layer": layer, "assigned": false})
	next_omen_id += 1

func _can_add_acorn(parent_bud_id: String, day: int) -> bool:
	var maximum: int = maxi(0, config.acorn_daily_max)
	var minimum: int = clampi(config.acorn_daily_min, 0, maximum)
	var count: int = 0
	# Today's omens cannot be eaten until tomorrow. Counting the remaining
	# records automatically releases a slot when a sticker is taken back.
	for omen in omens:
		if omen.kind == 0 and omen.eligible_day == day + 1:
			count += 1
	if count >= maximum:
		return false
	var key: String = "%d/%s" % [day, parent_bud_id]
	if not acorn_rolls.has(key):
		acorn_rolls[key] = rng.randf()
	var roll: float = acorn_rolls[key]
	return count < minimum or roll < clampf(config.acorn_probability, 0.0, 1.0)

func home_positions(kind: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var group: Node = anchors.get_node("GroundAnchors" if kind == 0 else "BirdAnchors")
	for marker in group.get_children():
		result.append(marker.global_position)
	if kind == 1:
		result.clear()
		for branch in branch_root.get_children():
			if branch.grown and not branch.is_base and not branch.preview:
				for marker in branch.get_node("BirdAnchors").get_children():
					result.append(marker.global_position)
		# Manual fallback positions are configurable in the main scene.
		for marker in group.get_children():
			result.append(marker.global_position)
	return result

func refresh_homes() -> void:
	# Keep tree-top homes and departure routes; maturation must not teleport actors.
	pass

func tree_route(branch_id: String, destination: Vector2) -> Array[Vector2]:
	var chain: Array[Vector2] = [destination]
	var current: String = branch_id
	for step in range(32):
		var found: Node2D = null
		for branch in branch_root.get_children():
			if branch.branch_id == current:
				found = branch
				break
		if found == null:
			break
		chain.push_front(found.root_position())
		if found.is_base:
			break
		current = found.parent_bud_id.get_slice("/", 0)
	var root: Vector2 = branch_root.get_node("Base").root_position()
	if chain[0].distance_to(root) > 1:
		chain.push_front(root)
	return chain

func ground_y(x: float) -> float:
	return branch_root.get_parent().get_node("GroundSurface").height_at(x)

func entry_position(kind: int, left: bool, pest: bool = false) -> Vector2:
	var root: Vector2 = branch_root.get_node("Base").root_position()
	var center: Vector2 = root if kind == 0 else air_target()
	var distance: float = config.pest_entry_distance if pest else config.companion_entry_distance
	var x: float = center.x + (-distance if left else distance)
	return Vector2(x, ground_y(x) if kind == 0 else center.y - config.air_entry_height)

func move_actor(actor: Dictionary, destination: Vector2, speed: float, delta: float) -> bool:
	var before: Vector2 = actor.position
	var grounded: bool = actor.get("kind", 1) == 0 and (actor.state == "PASSING" or (actor.state == "ARRIVING" and actor.route.size() > actor.climb_route.size()) or (actor.state == "LEAVING" and actor.route.size() == 1))
	if grounded:
		var x: float = move_toward(before.x, destination.x, config.hamster_walk_speed * actor.get("speed_factor", 1.0) * delta)
		actor.position = Vector2(x, ground_y(x))
	else:
		actor.position = before.move_toward(destination, speed * delta)
	var movement: Vector2 = actor.position - before
	actor.velocity = movement / maxf(delta, 0.0001)
	if absf(movement.x) > 0.01:
		actor.facing = signf(movement.x)
	return absf(actor.position.x - destination.x) < 1.0 if grounded else actor.position.distance_to(destination) < 1.0

func tick_arrivals(delta: float) -> void:
	for actor in companions:
		if actor.state == "EATING":
			actor.eat_time -= delta
			if actor.eat_time <= 0:
				actor.state = "IDLE"
				omens = omens.filter(func(o): return o.id != actor.omen_id)
		elif actor.state == "ARRIVING" and dusk_time >= actor.delay:
			var route: Array = actor.route
			var target: Vector2 = route[0] if not route.is_empty() else actor.home
			var speed: float = config.hamster_climb_speed if actor.kind == 0 and route.size() <= actor.climb_route.size() else config.companion_speed
			if move_actor(actor, target, speed, delta):
				if not route.is_empty():
					route.pop_front()
				if route.is_empty():
					actor.state = "EATING"
					actor.eat_time = config.hamster_eat_seconds if actor.kind == 0 else 0.1

func _too_close(point: Vector2, occupied: Array[Vector2]) -> bool:
	for other in occupied:
		if point.distance_to(other) < config.actor_spacing:
			return true
	return false

func begin_dusk(day: int) -> void:
	dusk_time = 0
	visitors.clear()
	for omen in omens:
		if omen.eligible_day > day or omen.assigned:
			continue
		var count := 0
		for actor in companions:
			if actor.kind == omen.kind:
				count += 1
		if count >= config.companion_max_per_type:
			continue
		var spots := home_positions(omen.kind)
		if spots.is_empty():
			continue
		var p: Vector2 = omen.position if omen.kind == 0 else spots[count % spots.size()]
		var occupied: Array[Vector2] = []
		for actor in companions:
			occupied.append(actor.home)
		while omen.kind != 0 and _too_close(p, occupied):
			p.x += config.actor_spacing
		var entry: Vector2 = entry_position(omen.kind, count % 2 == 0)
		# Construct both routes with the same element type. A bare [p] in the
		# conditional expression can produce an untyped Array for the first bird.
		var route: Array[Vector2] = []
		if omen.kind == 0:
			route = tree_route(omen.branch_id, p)
		else:
			route.append(p)
		var climb_route: Array[Vector2] = route.duplicate()
		if omen.kind == 0:
			route.push_front(Vector2(route[0].x, ground_y(route[0].x)))
		companions.append({"route": route, "climb_route": climb_route, "exit": entry, "facing": 1.0 if entry.x < p.x else -1.0, "velocity": Vector2.ZERO, "speed_factor": rng.randf_range(0.9, 1.1), "cooldown": 0.0, "throw_flash": 0.0, "id": next_actor_id, "kind": omen.kind, "variant": count % 3, "position": entry, "home": p, "state": "ARRIVING", "target": -1, "omen_id": omen.id, "delay": config.arrival_interval * count})
		next_actor_id += 1
		omen.assigned = true

func tick_dusk(delta: float) -> bool:
	dusk_time += delta
	animation_time += delta
	tick_arrivals(delta)
	return companions.all(func(a): return a.state == "IDLE")

func begin_night(index: int) -> void:
	wave = config.night_waves[index]
	spawned = 0
	night_time = 0
	spawn_elapsed = 0
	pests.clear()

func air_target() -> Vector2:
	var target: Vector2 = anchors.get_node("PestAirAnchor").global_position
	var found: bool = false
	for branch in branch_root.get_children():
		if branch.grown and not branch.preview and not branch.is_base:
			var candidate: Vector2 = branch.get_node("PestAirAnchor").global_position
			if not found or candidate.y < target.y:
				target = candidate
				found = true
	return target

func tick_night(delta: float) -> bool:
	night_time += delta
	dusk_time += delta
	animation_time += delta
	tick_arrivals(delta)
	spawn_elapsed += delta
	var interval: float = maxf(0.3, config.pest_interval)
	if not wave.is_empty() and (spawned == 0 or spawn_elapsed >= interval):
		spawn_elapsed = 0
		var kind: int = wave[spawned % wave.size()]
		var root: Vector2 = branch_root.get_node("Base").root_position()
		var target: Vector2 = Vector2(root.x, ground_y(root.x)) if kind == 0 else air_target()
		pests.append({"id": next_pest_id, "kind": kind, "position": entry_position(kind, spawned % 2 == 0, true), "target": target, "speed_factor": rng.randf_range(config.ground_speed_variation.x, config.ground_speed_variation.y), "hp": 2 if kind == 0 else 1, "hit_flash": 0.0, "locked_by": -1, "state": "MOVING"})
		next_pest_id += 1
		spawned += 1
	for actor in companions:
		actor.throw_flash = maxf(0, actor.throw_flash - delta)
		if actor.kind == 0:
			actor.cooldown = maxf(0, actor.cooldown - delta)
			if actor.state == "IDLE" and actor.cooldown <= 0:
				var closest: Dictionary = {}
				var nearest_distance: float = INF
				for pest in pests:
					if pest.kind == 0 and pest.state == "MOVING":
						var distance: float = actor.position.distance_squared_to(pest.position)
						if distance < nearest_distance:
							nearest_distance = distance
							closest = pest
				if not closest.is_empty():
					projectiles.append({"position": actor.position + Vector2(0, -25), "start": actor.position + Vector2(0, -25), "target": closest.id, "elapsed": 0.0})
					sound_requested.emit("throw")
					actor.facing = signf(closest.position.x - actor.position.x)
					actor.cooldown = config.pine_throw_interval
					actor.throw_flash = 0.3
			continue
		if actor.state == "IDLE":
			var best: Dictionary = {}
			var distance := INF
			for pest in pests:
				if pest.kind == actor.kind and pest.locked_by == -1 and pest.state == "MOVING":
					var d: float = actor.position.distance_to(pest.position)
					if d < distance:
						best = pest
						distance = d
			if not best.is_empty():
				best.locked_by = actor.id
				actor.target = best.id
				actor.state = "BUSY"
		if actor.state == "BUSY":
			var target: Dictionary = {}
			for pest in pests:
				if pest.id == actor.target and pest.state == "MOVING":
					target = pest
			if target.is_empty():
				actor.state = "RETURNING"
			else:
				move_actor(actor, target.position, config.companion_speed, delta)
				if actor.position.distance_to(target.position) <= config.hit_distance:
					target.state = "REMOVED"
					sound_requested.emit("death")
					actor.state = "RETURNING"
		elif actor.state == "RETURNING":
			move_actor(actor, actor.home, config.companion_speed, delta)
			if actor.position.distance_to(actor.home) < 1:
				actor.state = "IDLE"
				actor.target = -1
	tick_projectiles(delta)
	for pest in pests:
		pest.hit_flash = maxf(0, pest.hit_flash - delta)
		if pest.state != "MOVING":
			continue
		var speed: float = config.pest_speeds.x if pest.kind == 0 else config.pest_speeds.y
		if pest.kind == 0:
			speed *= pest.get("speed_factor", 1.0)
			var x: float = move_toward(pest.position.x, pest.target.x, speed * delta)
			pest.position = Vector2(x, ground_y(x))
			pest.target.y = ground_y(pest.target.x)
		else:
			pest.position = pest.position.move_toward(pest.target, speed * delta)
		if pest.position.distance_to(pest.target) < config.hit_distance:
			pest.state = "HIT_TREE"
			pest_hit.emit()
	pests = pests.filter(func(p): return p.state == "MOVING")
	return spawned == wave.size() and pests.is_empty()

func finish_arrivals() -> void:
	# Long hand-configured routes continue into night without teleporting or eating early.
	pass

func end_night() -> void:
	pests.clear()
	projectiles.clear()
	for actor in companions:
		actor.target = -1
		if actor.state in ["BUSY", "RETURNING"]:
			actor.state = "IDLE"

func tick_projectiles(delta: float) -> void:
	for shot in projectiles:
		var target: Dictionary = {}
		for pest in pests:
			if pest.id == shot.target and pest.state == "MOVING":
				target = pest
		if target.is_empty():
			shot.elapsed = config.pine_flight_seconds
			continue
		shot.elapsed += delta
		var t: float = clampf(shot.elapsed / config.pine_flight_seconds, 0, 1)
		shot.position = shot.start.lerp(target.position, t) + Vector2(0, -sin(t * PI) * 75)
		if t >= 1:
			target.hp -= 1
			target.hit_flash = 0.2
			if target.hp <= 0:
				target.state = "REMOVED"
				sound_requested.emit("death")
	projectiles = projectiles.filter(func(s): return s.elapsed < config.pine_flight_seconds)

func begin_day() -> void:
	visit_timer = rng.randf_range(config.visit_interval_min, config.visit_interval_max)
	for actor in companions:
		var route: Array = []
		if actor.kind == 0:
			route = actor.climb_route.duplicate()
			route.reverse()
			# If an arrival was interrupted, do not jump upward to its uneaten acorn.
			while not route.is_empty() and route[0].y < actor.position.y - 1:
				route.pop_front()
			route.append(Vector2(branch_root.get_node("Base").root_position().x, ground_y(branch_root.get_node("Base").root_position().x)))
		var center_x: float = branch_root.get_node("Base").root_position().x if actor.kind == 0 else actor.home.x
		var exit: Vector2 = actor.exit + Vector2(-160 if actor.exit.x < center_x else 160, 0)
		if actor.kind == 0:
			exit.y = ground_y(exit.x)
		route.append(exit)
		actor.route = route
		actor.state = "LEAVING"
	omens = omens.filter(func(o): return not o.assigned)

func tick_day(delta: float) -> void:
	animation_time += delta
	for actor in companions:
		if actor.state == "LEAVING" and not actor.route.is_empty():
			var speed: float = config.hamster_climb_speed if actor.kind == 0 and actor.route.size() > 1 else config.companion_speed
			if move_actor(actor, actor.route[0], speed, delta):
				actor.route.pop_front()
	companions = companions.filter(func(a): return a.state != "LEAVING" or not a.route.is_empty())
	visit_timer -= delta
	if visit_timer <= 0:
		visit_timer = rng.randf_range(config.visit_interval_min, config.visit_interval_max)
		if omens.any(func(o): return o.kind == 0) and visitors.size() < 2:
			var kind: int = rng.randi_range(0, 1)
			var left: bool = rng.randf() < 0.5
			var start: Vector2 = entry_position(kind, left)
			var end: Vector2 = entry_position(kind, not left)
			start.x += -160 if left else 160
			end.x += 160 if left else -160
			if kind == 0:
				start.y = ground_y(start.x)
				end.y = ground_y(end.x)
			visitors.append({"id": next_actor_id, "kind": kind, "variant": rng.randi_range(0, 2), "position": start, "home": end, "state": "PASSING", "speed_factor": rng.randf_range(0.9, 1.1), "facing": 1.0 if left else -1.0, "velocity": Vector2.ZERO})
			next_actor_id += 1
	for actor in visitors:
		move_actor(actor, actor.home, config.companion_speed * 0.8, delta)
	visitors = visitors.filter(func(a): return absf(a.position.x - a.home.x) > 1)
