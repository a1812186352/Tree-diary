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
var night_time: float = 0
var spawn_clock: float = 0
var spawn_events: Array[Dictionary] = []
var last_spawn_times: Vector2 = Vector2(-100, -100)
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
var feather_rolls: Dictionary = {}

func _ready() -> void:
	rng.randomize()

func _branch_layer(branch: Node2D, base_junction_y: float) -> int:
	var height: float = maxf(0, base_junction_y - branch.tip_position().y)
	return maxi(1, ceili((height - 0.01) / maxf(1.0, config.vertical_layer_height)))

func _omen_stock(kind: int) -> int:
	var count: int = 0
	for omen in omens:
		if omen.kind == kind and not omen.assigned:
			count += 1
	return count

func _append_omen(branch: Node2D, kind: int, eligible_day: int, layer: int) -> void:
	var fraction: float = rng.randf_range(0.4, 0.7)
	var p: Vector2 = branch.get_node("OmenAnchor").global_position + (branch.tip_position() - branch.root_position()) * (fraction - 0.5)
	omens.append({"id": next_omen_id, "kind": kind, "position": p, "eligible_day": eligible_day, "branch_id": branch.branch_id, "layer": layer, "assigned": false})
	next_omen_id += 1

func add_growth_omen(branch: Node2D, day: int, base_junction_y: float) -> void:
	var layer: int = _branch_layer(branch, base_junction_y)
	var kind: int = 0 if layer <= config.ground_omen_max_layer else 1
	if not _can_add_growth_omen(branch.parent_bud_id, day, kind):
		return
	_append_omen(branch, kind, day + 1, layer)

func _can_add_growth_omen(parent_bud_id: String, day: int, kind: int) -> bool:
	var maximum: int = maxi(0, config.acorn_daily_max if kind == 0 else config.feather_daily_max)
	var minimum: int = clampi(config.acorn_daily_min if kind == 0 else config.feather_daily_min, 0, maximum)
	var stock_max: int = maxi(0, config.acorn_stock_max if kind == 0 else config.feather_stock_max)
	if _omen_stock(kind) >= stock_max:
		return false
	var count: int = 0
	for omen in omens:
		if omen.kind == kind and omen.eligible_day == day + 1:
			count += 1
	if count >= maximum:
		return false
	var rolls: Dictionary = acorn_rolls if kind == 0 else feather_rolls
	var key: String = "%d/%s" % [day, parent_bud_id]
	if not rolls.has(key):
		rolls[key] = rng.randf()
	var probability: float = config.acorn_probability if kind == 0 else config.feather_probability
	return count < minimum or float(rolls[key]) < clampf(probability, 0.0, 1.0)

func _replenish_acorns(day: int) -> void:
	if config.acorn_replenish_targets.is_empty():
		return
	var target: int = clampi(config.acorn_replenish_targets[clampi(day - 1, 0, config.acorn_replenish_targets.size() - 1)], 0, mini(config.acorn_daily_max, config.companion_max_per_type))
	var ready: int = 0
	for omen in omens:
		if omen.kind == 0 and not omen.assigned and omen.eligible_day <= day:
			ready += 1
	var base_y: float = branch_root.get_node("Base/Buds/Tip").global_position.y
	for branch in branch_root.get_children():
		if ready >= target or _omen_stock(0) >= config.acorn_stock_max:
			break
		if branch.is_base or branch.preview or not branch.grown:
			continue
		var layer: int = _branch_layer(branch, base_y)
		if layer > config.ground_omen_max_layer:
			continue
		if omens.any(func(o): return o.kind == 0 and o.branch_id == branch.branch_id):
			continue
		_append_omen(branch, 0, day, layer)
		ready += 1

func _replenish_feathers(day: int) -> void:
	if config.feather_replenish_targets.is_empty():
		return
	var target: int = clampi(config.feather_replenish_targets[clampi(day - 1, 0, config.feather_replenish_targets.size() - 1)], 0, mini(config.feather_daily_max, config.companion_max_per_type))
	var ready: int = 0
	for omen in omens:
		if omen.kind == 1 and not omen.assigned and omen.eligible_day <= day:
			ready += 1
	var base_y: float = branch_root.get_node("Base/Buds/Tip").global_position.y
	for branch in branch_root.get_children():
		if ready >= target or _omen_stock(1) >= config.feather_stock_max:
			break
		if branch.is_base or branch.preview or not branch.grown:
			continue
		var layer: int = _branch_layer(branch, base_y)
		if layer <= config.ground_omen_max_layer:
			continue
		if omens.any(func(o): return o.kind == 1 and o.branch_id == branch.branch_id):
			continue
		_append_omen(branch, 1, day, layer)
		ready += 1

func hamster_can_reach(origin: Vector2, destination: Vector2) -> bool:
	var offset: Vector2 = destination - origin
	var radius: Vector2 = config.hamster_attack_range
	return Vector2(offset.x / maxf(1, radius.x), offset.y / maxf(1, radius.y)).length_squared() <= 1.0

func _time_to_tree(pest: Dictionary) -> float:
	var speed: float = (config.pest_speeds.x if pest.kind == 0 else config.pest_speeds.y) * pest.speed_factor
	return maxf(0, pest.position.distance_to(pest.target) - config.hit_distance) / maxf(1, speed)

func relocation_nodes(actor_id: int) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for branch in branch_root.get_children():
		if not branch.grown or branch.preview:
			continue
		for bud in branch.buds():
			var free: bool = true
			for actor in companions:
				if actor.id == actor_id or actor.state == "LEAVING":
					continue
				if bud.global_position.distance_to(actor.home) < config.actor_spacing:
					free = false
					break
			if free:
				result.append(bud)
	return result

func relocate_companion(actor_id: int, bud: Node2D) -> bool:
	if not is_instance_valid(bud) or not relocation_nodes(actor_id).has(bud):
		return false
	for actor in companions:
		if actor.id != actor_id or actor.state != "IDLE":
			continue
		var branch: Node2D = bud.get_parent().get_parent()
		var destination: Vector2 = bud.global_position
		actor.home = destination
		actor.position = destination
		actor.velocity = Vector2.ZERO
		actor.target = -1
		actor.route.clear()
		var route: Array[Vector2] = []
		if actor.kind == 0:
			route = tree_route(branch.branch_id, destination)
		else:
			route.append(destination)
		actor.climb_route = route
		return true
	return false

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
		var p: Vector2 = omen.position
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
		companions.append({"route": route, "climb_route": climb_route, "exit": entry, "facing": 1.0 if entry.x < p.x else -1.0, "velocity": Vector2.ZERO, "speed_factor": rng.randf_range(0.9, 1.1), "cooldown": 0.0, "throw_flash": 0.0, "id": next_actor_id, "kind": omen.kind, "variant": (day + count + 1) % 3, "position": entry, "home": p, "state": "ARRIVING", "target": -1, "omen_id": omen.id, "delay": config.arrival_interval * count})
		next_actor_id += 1
		omen.assigned = true

func tick_dusk(delta: float) -> void:
	dusk_time += delta
	animation_time += delta
	tick_arrivals(delta)

func begin_night(index: int) -> void:
	wave = config.night_waves[index]
	night_time = 0
	spawn_clock = 0
	last_spawn_times = Vector2(-100, -100)
	pests.clear()
	projectiles.clear()
	spawn_events.clear()
	var times: PackedFloat32Array = PackedFloat32Array()
	if index < config.night_spawn_times.size():
		times = config.night_spawn_times[index]
	var counts: Vector2i = Vector2i.ZERO
	for i in range(mini(wave.size(), times.size())):
		var kind: int = wave[i]
		var ordinal: int = counts[kind]
		counts[kind] += 1
		# Tough insects precede fast ones, using the existing three variants.
		var variant: int = 0 if index <= 1 else [0, 2, 1][ordinal % 3]
		spawn_events.append({"time": times[i], "kind": kind, "variant": variant, "left": ordinal % 2 == 0, "done": false})
	for actor in companions:
		actor.chain_count = 0

func _spawn_pest(event: Dictionary) -> void:
	var kind: int = event.kind
	var variant: int = event.variant
	var root: Vector2 = branch_root.get_node("Base").root_position()
	var target: Vector2 = Vector2(root.x, ground_y(root.x)) if kind == 0 else air_target()
	var health: float = config.ground_pest_health[variant] if kind == 0 else config.air_pest_health[variant]
	var speed_factor: float = config.pest_variant_speed[variant]
	if kind == 0:
		speed_factor *= rng.randf_range(config.ground_speed_variation.x, config.ground_speed_variation.y)
	pests.append({"id": next_pest_id, "kind": kind, "variant": variant, "position": entry_position(kind, event.left, true), "target": target, "speed_factor": speed_factor, "hp": health, "hit_flash": 0.0, "locked_by": -1, "state": "MOVING"})
	next_pest_id += 1

func _tick_spawns() -> void:
	for event in spawn_events:
		if event.done or spawn_clock < event.time:
			continue
		var kind: int = event.kind
		var root: Vector2 = branch_root.get_node("Base").root_position()
		var target: Vector2 = Vector2(root.x, ground_y(root.x)) if kind == 0 else air_target()
		var speed: float = (config.pest_speeds.x if kind == 0 else config.pest_speeds.y) * config.pest_variant_speed[event.variant]
		if kind == 0:
			speed *= minf(config.ground_speed_variation.x, config.ground_speed_variation.y)
		var travel: float = maxf(0, entry_position(kind, event.left, true).distance_to(target) - config.hit_distance) / maxf(1, speed)
		# Expire delayed entries instead of spawning enemies that dawn will erase.
		if night_time + travel > config.night_duration - config.night_cleanup_seconds:
			event.done = true
			continue
		if night_time - last_spawn_times[kind] < config.pest_min_spawn_gaps[kind]:
			continue
		var active: int = 0
		for pest in pests:
			if pest.kind == kind and pest.state == "MOVING":
				active += 1
		if active >= config.pest_active_limits[kind]:
			continue
		_spawn_pest(event)
		event.done = true
		last_spawn_times[kind] = night_time

func _damage_pest(pest: Dictionary, damage: float) -> void:
	pest.hp -= damage
	pest.hit_flash = 0.2
	if pest.hp <= 0:
		pest.state = "REMOVED"
		sound_requested.emit("death")

func _incoming_damage(pest_id: int) -> float:
	var damage: float = 0.0
	for shot in projectiles:
		if shot.target == pest_id:
			damage += shot.damage
	return damage

func _bird_target(actor: Dictionary, chain: bool = false) -> Dictionary:
	var air_pending: bool = pests.any(func(p): return p.kind == 1 and p.state == "MOVING")
	for kind in [1, 0]:
		if kind == 0 and air_pending:
			break
		var best: Dictionary = {}
		var nearest_danger: float = INF
		var nearest_flight: float = INF
		for pest in pests:
			if pest.kind != kind or pest.state != "MOVING" or (pest.locked_by != -1 and pest.locked_by != actor.id):
				continue
			if _incoming_damage(pest.id) >= pest.hp:
				continue
			if pest.position.distance_to(pest.target) > config.bird_guard_radius:
				continue
			var flight: float = actor.position.distance_to(pest.position)
			if chain and flight > config.bird_chain_radius:
				continue
			var danger: float = _time_to_tree(pest)
			# A reachable point near the tree is a conservative interception bound.
			var intercept: float = maxf(0, actor.position.distance_to(pest.target) - config.hit_distance) / maxf(1, config.companion_speed)
			if intercept + maxf(0, actor.cooldown) > danger:
				continue
			if danger < nearest_danger or (is_equal_approx(danger, nearest_danger) and flight < nearest_flight):
				best = pest
				nearest_danger = danger
				nearest_flight = flight
		if not best.is_empty():
			return best
	return {}

func _tick_bird(actor: Dictionary, delta: float) -> void:
	actor.cooldown = maxf(0, actor.cooldown - delta)
	if actor.state == "IDLE" or (actor.state == "RETURNING" and actor.get("chain_count", 0) < config.bird_max_chain):
		if actor.cooldown <= 0:
			var best: Dictionary = _bird_target(actor, actor.state == "RETURNING")
			if not best.is_empty():
				best.locked_by = actor.id
				actor.target = best.id
				actor.state = "BUSY"
	if actor.state == "BUSY":
		var target: Dictionary = {}
		for pest in pests:
			if pest.id == actor.target and pest.state == "MOVING":
				target = pest
				break
		var urgent: Dictionary = _bird_target(actor)
		if not urgent.is_empty() and (target.is_empty() or (urgent.kind == 1 and target.kind == 0) or (urgent.kind == target.kind and _time_to_tree(urgent) + 0.8 < _time_to_tree(target))):
			if not target.is_empty():
				target.locked_by = -1
			target = urgent
			target.locked_by = actor.id
			actor.target = target.id
		if target.is_empty():
			actor.state = "RETURNING"
			actor.target = -1
		else:
			move_actor(actor, target.position, config.companion_speed, delta)
			if actor.position.distance_to(target.position) <= config.hit_distance and actor.cooldown <= 0:
				_damage_pest(target, target.hp if target.kind == 1 else config.bird_ground_damage)
				target.locked_by = -1
				actor.cooldown = maxf(0, config.bird_attack_interval)
				actor.chain_count = actor.get("chain_count", 0) + 1
				actor.target = -1
				actor.state = "RETURNING"
	elif actor.state == "RETURNING":
		if move_actor(actor, actor.home, config.companion_speed, delta):
			actor.state = "IDLE"
			actor.target = -1
			actor.chain_count = 0
			actor.cooldown = maxf(actor.cooldown, config.bird_rest_seconds)

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

func tick_night(delta: float) -> void:
	var spawn_delta: float = minf(delta, maxf(0, config.night_duration - night_time))
	night_time += delta
	dusk_time += delta
	animation_time += delta
	tick_arrivals(delta)
	spawn_clock += spawn_delta * clampf(config.pest_spawn_multiplier, 0.5, 2.0)
	if spawn_delta > 0:
		_tick_spawns()
	for actor in companions:
		actor.throw_flash = maxf(0, actor.throw_flash - delta)
		if actor.kind == 0:
			actor.cooldown = maxf(0, actor.cooldown - delta)
			if actor.state == "IDLE" and actor.cooldown <= 0:
				var closest: Dictionary = {}
				var nearest_distance: float = INF
				for pest in pests:
					if pest.kind == 0 and pest.state == "MOVING" and _incoming_damage(pest.id) < pest.hp:
						if not hamster_can_reach(actor.position, pest.position):
							continue
						var distance: float = _time_to_tree(pest)
						if distance < nearest_distance:
							nearest_distance = distance
							closest = pest
				if not closest.is_empty():
					projectiles.append({"position": actor.position + Vector2(0, -25), "start": actor.position + Vector2(0, -25), "target": closest.id, "elapsed": 0.0, "duration": clampf(actor.position.distance_to(closest.position) / maxf(1, config.pine_projectile_speed), 0.25, 1.2), "damage": config.hamster_damage})
					sound_requested.emit("throw")
					actor.facing = signf(closest.position.x - actor.position.x)
					actor.cooldown = config.pine_throw_interval
					actor.throw_flash = 0.3
			continue
		_tick_bird(actor, delta)
	tick_projectiles(delta)
	for pest in pests:
		pest.hit_flash = maxf(0, pest.hit_flash - delta)
		if pest.state != "MOVING":
			continue
		var speed: float = (config.pest_speeds.x if pest.kind == 0 else config.pest_speeds.y) * pest.speed_factor
		if pest.kind == 0:
			var x: float = move_toward(pest.position.x, pest.target.x, speed * delta)
			pest.position = Vector2(x, ground_y(x))
			pest.target.y = ground_y(pest.target.x)
		else:
			pest.position = pest.position.move_toward(pest.target, speed * delta)
		if pest.position.distance_to(pest.target) < config.hit_distance:
			pest.state = "HIT_TREE"
			pest_hit.emit()
	pests = pests.filter(func(p): return p.state == "MOVING")

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
			shot.elapsed = shot.duration
			continue
		shot.elapsed += delta
		var t: float = clampf(shot.elapsed / shot.duration, 0, 1)
		shot.position = shot.start.lerp(target.position, t) + Vector2(0, -sin(t * PI) * 75)
		if t >= 1:
			_damage_pest(target, shot.damage)
	projectiles = projectiles.filter(func(s): return s.elapsed < s.duration)

func begin_day(day: int = 1) -> void:
	visit_timer = rng.randf_range(config.visit_interval_min, config.visit_interval_max)
	for actor in companions:
		var route: Array = []
		if actor.kind == 0:
			route = actor.climb_route.duplicate()
			if actor.state == "ARRIVING":
				var reached: int = clampi(actor.climb_route.size() - actor.route.size(), 0, actor.climb_route.size())
				route = route.slice(0, reached)
			route.reverse()
			route.append(Vector2(branch_root.get_node("Base").root_position().x, ground_y(branch_root.get_node("Base").root_position().x)))
		var center_x: float = branch_root.get_node("Base").root_position().x if actor.kind == 0 else actor.home.x
		var exit: Vector2 = actor.exit + Vector2(-160 if actor.exit.x < center_x else 160, 0)
		if actor.kind == 0:
			exit.y = ground_y(exit.x)
		route.append(exit)
		actor.route = route
		actor.state = "LEAVING"
	omens = omens.filter(func(o): return not o.assigned)
	acorn_rolls.clear()
	feather_rolls.clear()
	_replenish_acorns(day)
	_replenish_feathers(day)

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
