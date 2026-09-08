extends Node
signal placed(branch: Node2D)
const SCENES = [preload("res://scenes/branches/one_bud.tscn"), preload("res://scenes/branches/two_bud.tscn"), preload("res://scenes/branches/three_bud.tscn")]
var config: Resource
var branch_root: Node2D
var resources: Node
var animals: Node
var next_id: int = 1
var records: Array[Dictionary] = []
var last_reason: String = ""

func available_buds() -> Array:
	var result: Array = []
	for branch in branch_root.get_children():
		if branch.preview or not branch.grown:
			continue
		for bud in branch.buds():
			if not bud.get_meta("occupied", false):
				result.append(bud)
	return result

func nearest_bud(point: Vector2) -> Node2D:
	var nearest: Node2D = null
	var distance: float = config.snap_radius
	for bud in available_buds():
		var d: float = point.distance_to(bud.global_position)
		if d < distance:
			nearest = bud
			distance = d
	return nearest

func branch_scale() -> Vector2:
	# Every segment follows the base, without compounding scale each generation.
	return branch_root.get_node("Base").scale.abs()

func align(branch: Node2D, bud: Node2D, angle: float, mirrored: bool) -> void:
	branch.scale = branch_scale() * Vector2(-1 if mirrored else 1, 1)
	# Derive world facing from the full transform, including a mirrored parent.
	var direction: Vector2 = bud.global_transform.basis_xform(Vector2.UP).normalized()
	branch.rotation = Vector2.UP.angle_to(direction) + deg_to_rad(angle)
	branch.global_position = bud.global_position - branch.global_transform.basis_xform(branch.get_node("RootAnchor").position)

func validate(branch: Node2D, bud: Node2D, cost: int, angle: float = 0) -> String:
	if bud == null or not available_buds().has(bud):
		return "请连接一个空闲芽点"
	if not resources.can_pay(cost):
		return "阳光或水滴不够，先收集一些"
	if absf(angle) > config.rotation_limit_degrees:
		return "转得太远了，靠近芽点生长方向试试"
	if records.size() >= config.max_branches or bud.get_parent().get_parent().depth >= config.max_depth:
		return "这棵树已达到本次试作的生长上限"
	var start: Vector2 = branch.root_position()
	var end: Vector2 = branch.tip_position()
	if not config.allow_downward and end.y >= start.y:
		return "本次试作先向上方生长"
	for slot in branch.buds():
		if not config.growth_bounds.has_point(slot.global_position):
			return "枝条超出纸页，请换个角度"
	for other in branch_root.get_children():
		if other == branch or other.preview:
			continue
		var a: Vector2 = other.root_position()
		var b: Vector2 = other.tip_position()
		# Permit overlap only at the joint; keep the rest of each branch clear.
		for fraction in [0.35, 0.5, 0.7, 0.85, 1.0]:
			var sample := start.lerp(end, fraction)
			if sample.distance_to(Geometry2D.get_closest_point_to_segment(sample, a, b)) < config.collision_clearance:
				return "枝条相碰了，旋转后再试试"
		if Geometry2D.segment_intersects_segment(start.lerp(end, 0.25), end, a, b) != null:
			return "枝条相碰了，旋转后再试试"
	return ""

func place(kind: int, bud: Node2D, angle: float, mirrored: bool, day: int) -> Node2D:
	if kind < 0 or kind >= SCENES.size() or bud == null:
		return null
	var branch: Node2D = SCENES[kind].instantiate()
	branch_root.add_child(branch)
	align(branch, bud, angle, mirrored)
	var cost: int = config.costs[kind]
	last_reason = validate(branch, bud, cost, angle)
	if not last_reason.is_empty():
		branch_root.remove_child(branch)
		branch.queue_free()
		return null
	if not resources.pay(cost):
		branch.queue_free()
		return null
	var parent_branch: Node2D = bud.get_parent().get_parent()
	branch.branch_id = "branch_%04d" % next_id
	next_id += 1
	branch.parent_bud_id = parent_branch.branch_id + "/" + str(bud.name)
	branch.depth = parent_branch.depth + 1
	branch.grown = false
	branch.placed_day = day
	bud.set_meta("occupied", true)
	bud.set_meta("child_branch_id", branch.branch_id)
	parent_branch.queue_redraw()
	branch.queue_redraw()
	records.append({"id": branch.branch_id, "parent_bud_id": branch.parent_bud_id, "kind": kind, "rotation": branch.rotation, "mirrored": mirrored, "placed_day": day, "activated_day": 0, "state": "sticker"})
	placed.emit(branch)
	return branch

func mature(day: int) -> void:
	for branch in branch_root.get_children():
		if not branch.grown and not branch.preview:
			branch.mature(day)
	for record in records:
		if record.state == "sticker":
			record.state = "grown"
			record.activated_day = day

func remove_nearest(point: Vector2, max_distance: float) -> bool:
	var best: Node2D = null
	var best_dist: float = max_distance
	for branch in branch_root.get_children():
		if branch.preview or branch.is_base or branch.grown:
			continue
		var d: float = branch.root_position().distance_to(point)
		if d <= best_dist:
			best = branch
			best_dist = d
	if best == null:
		return false
	var bud_id: String = best.parent_bud_id
	var slash: int = bud_id.find("/")
	var refund_kind: int = -1
	if slash >= 0:
		var parent_id: String = bud_id.substr(0, slash)
		var bud_name: String = bud_id.substr(slash + 1)
		var parent_branch: Node2D = _find_branch(parent_id)
		if parent_branch != null:
			var bud: Node = parent_branch.get_node_or_null("Buds/" + bud_name)
			if bud != null:
				bud.set_meta("occupied", false)
				bud.remove_meta("child_branch_id")
				parent_branch.queue_redraw()
	# Look up the kind from records so we can refund the original cost.
	for record in records:
		if record.id == best.branch_id:
			refund_kind = record.kind
			break
	records = records.filter(func(r): return r.id != best.branch_id)
	if refund_kind >= 0 and refund_kind < config.costs.size():
		resources.refund(config.costs[refund_kind])
	# Clean up any omen that was registered for this branch and revoke the companion
	# it summoned, so removing a sticker never leaves a dangling anchor.
	if animals != null:
		var removed_omen_ids: Array[int] = []
		for o in animals.omens:
			if o.branch_id == best.branch_id:
				removed_omen_ids.append(o.id)
		animals.omens = animals.omens.filter(func(o): return o.branch_id != best.branch_id)
		if not removed_omen_ids.is_empty():
			animals.companions = animals.companions.filter(func(c):
				return not removed_omen_ids.has(c.get("omen_id", -1)))
			animals.refresh_homes()
	best.queue_free()
	return true

func _find_branch(branch_id: String) -> Node2D:
	for branch in branch_root.get_children():
		if branch.branch_id == branch_id:
			return branch
	return null
