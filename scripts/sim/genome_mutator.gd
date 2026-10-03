class_name GenomeMutator
extends RefCounted

## Seeded mutation/crossover operators over the PartGene tree. All randomness
## comes from the caller-owned RandomNumberGenerator.

class Config:
	extends Resource
	var param_rate := 0.75
	var topology_rate := 0.25
	var gait_rate := 0.45
	var crossover_rate := 0.35
	var scale_sigma := 0.12
	var socket_sigma := 0.08
	var angle_sigma := 0.18
	var dial_sigma := 0.10
	var min_scale := 0.08
	var max_scale := 4.0
	var max_parts := 32
	var add_rate := 0.45
	var remove_rate := 0.25
	var duplicate_rate := 0.30


static func mutate(parent: PartGene, cfg, rng: RandomNumberGenerator) -> PartGene:
	if parent == null:
		return null
	var c: Config = cfg as Config
	if c == null:
		c = Config.new()
	var out := GenomeSnapshot.deep_copy(parent)
	if out == null:
		return null
	if rng.randf() < c.param_rate:
		_mutate_params(out, c, rng)
	if rng.randf() < c.gait_rate:
		_mutate_gait(out, c, rng)
	if rng.randf() < c.topology_rate:
		_mutate_topology(out, c, rng)
	_clamp_tree(out, c)
	var chk := GenomeSnapshot.validate_unique(out)
	if bool(chk["ok"]):
		return out
	push_warning("GenomeMutator.mutate rejected invalid child: %s" % chk["error"])
	return GenomeSnapshot.deep_copy(parent)


static func crossover(a: PartGene, b: PartGene, cfg, rng: RandomNumberGenerator) -> PartGene:
	if a == null:
		return null
	if b == null:
		return GenomeSnapshot.deep_copy(a)
	var c: Config = cfg as Config
	if c == null:
		c = Config.new()
	var out := GenomeSnapshot.deep_copy(a)
	if rng.randf() > c.crossover_rate:
		return out
	var a_nodes := _nodes_with_parent(out)
	var b_nodes := _nodes_with_parent(b)
	if a_nodes.size() <= 1 or b_nodes.size() <= 1:
		return out
	var dst := a_nodes[rng.randi_range(1, a_nodes.size() - 1)]
	var src := b_nodes[rng.randi_range(1, b_nodes.size() - 1)]
	var replacement: PartGene = GenomeSnapshot.deep_copy(src["gene"])
	if replacement == null:
		return out
	var old: PartGene = dst["gene"]
	replacement.socket = old.socket.duplicate(true) if old.socket != null else replacement.socket
	replacement.socket_id = old.socket_id
	var parent_gene: PartGene = dst["parent"]
	var child_index := int(dst["child_index"])
	parent_gene.children[child_index] = replacement
	_clamp_tree(out, c)
	var chk := GenomeSnapshot.validate_unique(out)
	if bool(chk["ok"]):
		return out
	push_warning("GenomeMutator.crossover rejected invalid child: %s" % chk["error"])
	return GenomeSnapshot.deep_copy(a)


static func _mutate_params(root: PartGene, cfg: Config, rng: RandomNumberGenerator) -> void:
	var nodes := _nodes(root)
	if nodes.is_empty():
		return
	var g: PartGene = nodes[rng.randi_range(0, nodes.size() - 1)]
	match rng.randi_range(0, 4):
		0:
			g.scale = Vector3(
					g.scale.x * exp(rng.randfn(0.0, cfg.scale_sigma)),
					g.scale.y * exp(rng.randfn(0.0, cfg.scale_sigma)),
					g.scale.z * exp(rng.randfn(0.0, cfg.scale_sigma)))
		1:
			if g.socket != null:
				g.socket.parent_attachment.origin += Vector3(
						rng.randfn(0.0, cfg.socket_sigma),
						rng.randfn(0.0, cfg.socket_sigma),
						rng.randfn(0.0, cfg.socket_sigma))
		2:
			if g.socket != null and not g.socket.hinge_axis.is_zero_approx():
				if g.joint == null:
					g.joint = JointDef.new()
				g.joint.amplitude += rng.randfn(0.0, cfg.angle_sigma)
				g.joint.rest_angle += rng.randfn(0.0, cfg.angle_sigma)
				g.joint.angle_min += rng.randfn(0.0, cfg.angle_sigma)
				g.joint.angle_max += rng.randfn(0.0, cfg.angle_sigma)
		3:
			for key in g.dial_values.keys():
				g.dial_values[key] = float(g.dial_values[key]) + rng.randfn(0.0, cfg.dial_sigma)
		4:
			if g.definition != null:
				var d := g.definition.duplicate(true) as PartDefinition
				d.extents = Vector3(
						d.extents.x * exp(rng.randfn(0.0, cfg.scale_sigma * 0.5)),
						d.extents.y * exp(rng.randfn(0.0, cfg.scale_sigma * 0.5)),
						d.extents.z * exp(rng.randfn(0.0, cfg.scale_sigma * 0.5)))
				g.definition = d


static func _mutate_gait(root: PartGene, _cfg: Config, rng: RandomNumberGenerator) -> void:
	var driven: Array[PartGene] = []
	for g in _nodes(root):
		if g != root and g.socket != null and not g.socket.id.is_empty():
			driven.append(g)
	if driven.is_empty():
		return
	if root.gait == null:
		root.gait = GaitDef.new()
	var g: PartGene = driven[rng.randi_range(0, driven.size() - 1)]
	var current := float(root.gait.assignments.get(g.socket.id, rng.randf()))
	root.gait.assignments[g.socket.id] = wrapf(current + rng.randfn(0.0, 0.12), 0.0, 1.0)


static func _mutate_topology(root: PartGene, cfg: Config, rng: RandomNumberGenerator) -> void:
	var total := _nodes(root).size()
	var roll := rng.randf()
	if total < cfg.max_parts and roll < cfg.add_rate:
		_add_child(root, rng)
	elif total > 1 and roll < cfg.add_rate + cfg.remove_rate:
		_remove_subtree(root, rng)
	elif total < cfg.max_parts:
		_duplicate_subtree(root, rng)


static func _add_child(root: PartGene, rng: RandomNumberGenerator) -> void:
	var nodes := _nodes(root)
	if nodes.is_empty():
		return
	var parent: PartGene = nodes[rng.randi_range(0, nodes.size() - 1)]
	var ids := PartCatalog.template_ids()
	if ids.is_empty():
		return
	var child := PartCatalog.clone_template(ids[rng.randi_range(0, ids.size() - 1)])
	if child == null:
		return
	var sid := _unique_socket_id(parent, child.part_id if child.part_id != &"" else &"mutant")
	child.socket_id = sid
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var hinge := Vector3(1.0, 0.0, 0.0) if child.tags.has(&"locomotor") else Vector3.ZERO
	child.socket = CreatureFrames.spine_socket(parent, sid, rng.randf(), side, hinge)
	if not hinge.is_zero_approx():
		child.joint = JointDef.new()
	parent.children.append(child)


static func _remove_subtree(root: PartGene, rng: RandomNumberGenerator) -> void:
	var nodes := _nodes_with_parent(root)
	if nodes.size() <= 1:
		return
	var victim := nodes[rng.randi_range(1, nodes.size() - 1)]
	var parent: PartGene = victim["parent"]
	parent.children.remove_at(int(victim["child_index"]))


static func _duplicate_subtree(root: PartGene, rng: RandomNumberGenerator) -> void:
	var nodes := _nodes_with_parent(root)
	if nodes.size() <= 1:
		_add_child(root, rng)
		return
	var src := nodes[rng.randi_range(1, nodes.size() - 1)]
	var parent: PartGene = src["parent"]
	var dup: PartGene = GenomeSnapshot.deep_copy(src["gene"])
	if dup == null:
		return
	var sid := _unique_socket_id(parent, dup.socket_id if dup.socket_id != &"" else &"dup")
	dup.socket_id = sid
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var hinge := dup.socket.hinge_axis if dup.socket != null else Vector3.ZERO
	dup.socket = CreatureFrames.spine_socket(parent, sid, rng.randf(), side, hinge)
	parent.children.append(dup)


static func _clamp_tree(root: PartGene, cfg: Config) -> void:
	for g in _nodes(root):
		g.scale = Vector3(
				clampf(g.scale.x, cfg.min_scale, cfg.max_scale),
				clampf(g.scale.y, cfg.min_scale, cfg.max_scale),
				clampf(g.scale.z, cfg.min_scale, cfg.max_scale))
		if g.definition != null:
			g.definition.extents = Vector3(
					maxf(g.definition.extents.x, 0.02),
					maxf(g.definition.extents.y, 0.02),
					maxf(g.definition.extents.z, 0.02))
		if g.joint != null:
			g.joint.amplitude = clampf(g.joint.amplitude, 0.0, 3.0)
			g.joint.rest_angle = clampf(g.joint.rest_angle, -PI, PI)
			g.joint.angle_min = clampf(g.joint.angle_min, -PI, PI)
			g.joint.angle_max = clampf(g.joint.angle_max, -PI, PI)
			if g.joint.angle_max < g.joint.angle_min:
				var t := g.joint.angle_min
				g.joint.angle_min = g.joint.angle_max
				g.joint.angle_max = t
	if root.gait != null:
		var fixed: Dictionary[StringName, float] = {}
		for key in root.gait.assignments.keys():
			fixed[StringName(key)] = wrapf(float(root.gait.assignments[key]), 0.0, 1.0)
		root.gait.assignments = fixed


static func _nodes(root: PartGene) -> Array[PartGene]:
	var out: Array[PartGene] = []
	_walk_nodes(root, out)
	return out


static func _walk_nodes(g: PartGene, out: Array[PartGene]) -> void:
	if g == null:
		return
	out.append(g)
	for child in g.children:
		_walk_nodes(child, out)


static func _nodes_with_parent(root: PartGene) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_walk_with_parent(root, null, -1, out)
	return out


static func _walk_with_parent(g: PartGene, parent: PartGene, child_index: int, out: Array[Dictionary]) -> void:
	if g == null:
		return
	out.append({"gene": g, "parent": parent, "child_index": child_index})
	for i in g.children.size():
		_walk_with_parent(g.children[i], g, i, out)


static func _unique_socket_id(parent: PartGene, base: StringName) -> StringName:
	var used := {}
	for child in parent.children:
		used[child.socket_id] = true
		if child.socket != null:
			used[child.socket.id] = true
	var stem := String(base if base != &"" else &"socket")
	var candidate := StringName(stem)
	var i := 1
	while used.has(candidate):
		candidate = StringName("%s_%d" % [stem, i])
		i += 1
	return candidate
