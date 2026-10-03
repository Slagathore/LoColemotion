class_name GenomeSnapshot
extends RefCounted

## F4 — the genome snapshot/restore contract (used by editor undo/redo AND by F5's live
## re-score dispatch). One primitive, `deep_copy`, produces a fully isolated copy of a PartGene
## tree; `validate_unique` enforces the sharing rule that makes that copy unambiguous.
##
## SHARING RULE (decided — the genome is a STRICT TREE of uniquely-owned nodes):
##
##   PartGene .................. UNIQUE. A reused PartGene instance is already broken upstream:
##                              CharacteristicsEvaluator.fold_graph's cycle guard (visited[gene])
##                              treats the second reference as a cycle and SKIPS it, mis-scoring
##                              the creature. So sharing was never valid — validate_unique rejects
##                              it at author time with a clear error.
##   SocketDef / JointDef / SpringDef / WeaponDef /
##   GaitDef / PhysicsDescriptor  UNIQUE per gene. These hold per-part MUTABLE state (pose, hinge,
##                              RoM, measured physics). Sharing them would make "edit one move
##                              both" and alias undo state. Deep-copied here; sharing rejected.
##   PartDefinition ............ SHARED-IMMUTABLE catalog data (the "sacred input"), referenced by
##                              stable part_id. Many genes legitimately point at one definition
##                              (e.g. four identical legs). Never mutated in place, so it is shared
##                              by reference across snapshots — NOT duplicated, NOT uniqueness-checked.
##
## deep_copy is used for BOTH "take a snapshot" and "restore a snapshot", so the live tree and
## every stored copy are isolated in BOTH directions (no later edit can reach into a stored copy,
## and installing a stored copy can't be corrupted by future edits). Cost: one pass, O(genome size).
##
## NOTE: _copy_gene reconstructs PartGene field-by-field on purpose (no reliance on
## Resource.duplicate's array-of-subresource recursion, which is version-sensitive). When PartGene
## gains a field, add a line here — the structural round-trip test (test_genome_snapshot.gd) guards
## against a missed field.


## Returns a fully isolated deep copy of the genome rooted at `root` (null -> null).
static func deep_copy(root: PartGene) -> PartGene:
	if root == null:
		return null
	return _copy_gene(root, {})


## JSON-safe full-tree snapshot. This is the disk/corpus/training provenance
## contract: unlike feature vectors or gait settings, it can reconstruct the
## actual creature body later.
static func to_dictionary(root: PartGene) -> Dictionary:
	return _gene_to_dict(root) if root != null else {}


## Reconstructs a PartGene tree from `to_dictionary`. Returns null on empty/bad
## input so callers can keep existing fallback behavior.
static func from_dictionary(data: Dictionary) -> PartGene:
	if data.is_empty():
		return null
	return _gene_from_dict(data)


static func _copy_gene(g: PartGene, seen: Dictionary) -> PartGene:
	if g == null:
		return null
	var gid := g.get_instance_id()
	if seen.has(gid):
		push_warning("GenomeSnapshot.deep_copy: repeated/cyclic PartGene skipped; validate_unique should reject this genome before editing")
		return null
	seen[gid] = true
	var c := PartGene.new()
	c.definition = g.definition                                                 # SHARED-IMMUTABLE
	c.descriptor = (g.descriptor.duplicate(true) as PhysicsDescriptor) if g.descriptor != null else null
	c.socket = (g.socket.duplicate(true) as SocketDef) if g.socket != null else null
	c.joint = (g.joint.duplicate(true) as JointDef) if g.joint != null else null
	c.gait = (g.gait.duplicate(true) as GaitDef) if g.gait != null else null
	c.spring = (g.spring.duplicate(true) as SpringDef) if g.spring != null else null
	c.weapon = (g.weapon.duplicate(true) as WeaponDef) if g.weapon != null else null
	c.tendon = (g.tendon.duplicate(true) as TendonDef) if g.tendon != null else null
	var aps: Array[AttachPoint] = []
	for ap in g.attach_points:
		aps.append((ap.duplicate(true) as AttachPoint) if ap != null else null)
	c.attach_points = aps
	var tags2: Array[StringName] = []
	tags2.assign(g.tags)
	c.tags = tags2
	c.scale = g.scale
	c.part_id = g.part_id
	c.socket_id = g.socket_id
	var dv: Dictionary[StringName, float] = {}
	for k in g.dial_values:
		dv[k] = g.dial_values[k]
	c.dial_values = dv
	var kids: Array[PartGene] = []
	for child in g.children:
		var copied := _copy_gene(child, seen)
		if copied != null:
			kids.append(copied)
	c.children = kids
	seen.erase(gid)
	return c


static func _gene_to_dict(g: PartGene) -> Dictionary:
	if g == null:
		return {}
	var kids: Array = []
	for child in g.children:
		var packed := _gene_to_dict(child)
		if not packed.is_empty():
			kids.append(packed)
	var out := {
		"part_id": String(g.part_id),
		"socket_id": String(g.socket_id),
		"tags": _string_array(g.tags),
		"scale": _vec3(g.scale),
		"dial_values": _string_keyed_float_dict(g.dial_values),
		"definition": _definition_to_dict(g.definition),
		"descriptor": _descriptor_to_dict(g.descriptor),
		"socket": _socket_to_dict(g.socket),
		"joint": _joint_to_dict(g.joint),
		"gait": _gait_to_dict(g.gait),
		"spring": _spring_to_dict(g.spring),
		"weapon": _weapon_to_dict(g.weapon),
		"tendon": _tendon_to_dict(g.tendon),
		"attach_points": _attach_points_to_arr(g.attach_points),
		"children": kids,
	}
	return out


static func _gene_from_dict(data: Dictionary) -> PartGene:
	var g := PartGene.new()
	g.part_id = StringName(String(data.get("part_id", "")))
	g.socket_id = StringName(String(data.get("socket_id", "")))
	g.tags = _string_names(data.get("tags", []))
	g.scale = _vec3_from(data.get("scale", [1.0, 1.0, 1.0]), Vector3.ONE)
	g.dial_values = _float_dict_from(data.get("dial_values", {}))
	g.definition = _definition_from_dict(data.get("definition", {}))
	g.descriptor = _descriptor_from_dict(data.get("descriptor", {}))
	g.socket = _socket_from_dict(data.get("socket", {}))
	g.joint = _joint_from_dict(data.get("joint", {}))
	g.gait = _gait_from_dict(data.get("gait", {}))
	g.spring = _spring_from_dict(data.get("spring", {}))
	g.weapon = _weapon_from_dict(data.get("weapon", {}))
	g.tendon = _tendon_from_dict(data.get("tendon", {}))
	g.attach_points = _attach_points_from(data.get("attach_points", []))
	var kids: Array[PartGene] = []
	for child_data in data.get("children", []):
		if child_data is Dictionary:
			var child := _gene_from_dict(child_data)
			if child != null:
				kids.append(child)
	g.children = kids
	return g


static func _definition_to_dict(d: PartDefinition) -> Dictionary:
	if d == null:
		return {}
	return {
		"part_type": String(d.part_type),
		"density": d.density,
		"extents": _vec3(d.extents),
		"centroid_offset": _vec3(d.centroid_offset),
	}


static func _definition_from_dict(data) -> PartDefinition:
	if not (data is Dictionary) or (data as Dictionary).is_empty():
		return null
	var d := PartDefinition.new()
	d.part_type = StringName(String(data.get("part_type", "box")))
	d.density = float(data.get("density", 1000.0))
	d.extents = _vec3_from(data.get("extents", [1.0, 1.0, 1.0]), Vector3.ONE)
	d.centroid_offset = _vec3_from(data.get("centroid_offset", [0.0, 0.0, 0.0]), Vector3.ZERO)
	return d


static func _descriptor_to_dict(d: PhysicsDescriptor) -> Dictionary:
	if d == null:
		return {}
	return {
		"total_volume": d.total_volume,
		"metabolic_volume": d.metabolic_volume,
		"total_surface_area": d.total_surface_area,
		"surface_metabolic": d.surface_metabolic,
		"enclosed_void_volume": d.enclosed_void_volume,
		"center_of_mass": _vec3(d.center_of_mass),
		"bounds": _aabb(d.bounds),
		"bounding_radius": d.bounding_radius,
		"mass": d.mass,
		"inertia_tensor": Array(d.inertia_tensor),
	}


static func _descriptor_from_dict(data) -> PhysicsDescriptor:
	if not (data is Dictionary) or (data as Dictionary).is_empty():
		return null
	var d := PhysicsDescriptor.new()
	d.total_volume = float(data.get("total_volume", 0.0))
	d.metabolic_volume = float(data.get("metabolic_volume", 0.0))
	d.total_surface_area = float(data.get("total_surface_area", 0.0))
	d.surface_metabolic = float(data.get("surface_metabolic", 0.0))
	d.enclosed_void_volume = float(data.get("enclosed_void_volume", 0.0))
	d.center_of_mass = _vec3_from(data.get("center_of_mass", [0.0, 0.0, 0.0]), Vector3.ZERO)
	d.bounds = _aabb_from(data.get("bounds", {}))
	d.bounding_radius = float(data.get("bounding_radius", 0.0))
	d.mass = float(data.get("mass", 0.0))
	var inertia := PackedFloat64Array()
	for v in data.get("inertia_tensor", []):
		inertia.append(float(v))
	d.inertia_tensor = inertia
	return d


static func _socket_to_dict(s: SocketDef) -> Dictionary:
	if s == null:
		return {}
	return {
		"id": String(s.id),
		"display_name": s.display_name,
		"parent_attachment": _xform(s.parent_attachment),
		"child_anchor": _xform(s.child_anchor),
		"hinge_axis": _vec3(s.hinge_axis),
		"hinge_axis_2": _vec3(s.hinge_axis_2),
	}


static func _socket_from_dict(data) -> SocketDef:
	if not (data is Dictionary) or (data as Dictionary).is_empty():
		return null
	var s := SocketDef.new()
	s.id = StringName(String(data.get("id", "")))
	s.display_name = String(data.get("display_name", ""))
	s.parent_attachment = _xform_from(data.get("parent_attachment", {}))
	s.child_anchor = _xform_from(data.get("child_anchor", {}))
	s.hinge_axis = _vec3_from(data.get("hinge_axis", [0.0, 0.0, 0.0]), Vector3.ZERO)
	s.hinge_axis_2 = _vec3_from(data.get("hinge_axis_2", [0.0, 0.0, 0.0]), Vector3.ZERO)
	return s


static func _joint_to_dict(j: JointDef) -> Dictionary:
	if j == null:
		return {}
	return {
		"amplitude": j.amplitude,
		"rest_angle": j.rest_angle,
		"angle_min": j.angle_min,
		"angle_max": j.angle_max,
	}


static func _joint_from_dict(data) -> JointDef:
	if not (data is Dictionary) or (data as Dictionary).is_empty():
		return null
	var j := JointDef.new()
	j.amplitude = float(data.get("amplitude", 1.0))
	j.rest_angle = float(data.get("rest_angle", 0.0))
	j.angle_min = float(data.get("angle_min", 0.0))
	j.angle_max = float(data.get("angle_max", 0.0))
	return j


static func _gait_to_dict(g: GaitDef) -> Dictionary:
	if g == null:
		return {}
	return {
		"pattern": String(g.pattern),
		"assignments": _string_keyed_float_dict(g.assignments),
		"amplitude_scale": g.amplitude_scale,
		"frequency_scale": g.frequency_scale,
		"gain_scale": g.gain_scale,
		"turn_rate": g.turn_rate,
		"traction_scale": g.traction_scale,
		"posture_scale": g.posture_scale,
		"locomotion_mode": String(g.locomotion_mode),
	}


static func _gait_from_dict(data) -> GaitDef:
	if not (data is Dictionary) or (data as Dictionary).is_empty():
		return null
	var g := GaitDef.new()
	g.pattern = StringName(String(data.get("pattern", "trot")))
	g.assignments = _float_dict_from(data.get("assignments", {}))
	g.amplitude_scale = float(data.get("amplitude_scale", 1.0))
	g.frequency_scale = float(data.get("frequency_scale", 1.0))
	g.gain_scale = float(data.get("gain_scale", 1.0))
	g.turn_rate = float(data.get("turn_rate", 0.0))
	g.traction_scale = float(data.get("traction_scale", 0.0))
	g.posture_scale = float(data.get("posture_scale", 0.0))
	g.locomotion_mode = StringName(String(data.get("locomotion_mode", "")))
	return g


static func _spring_to_dict(s: SpringDef) -> Dictionary:
	if s == null:
		return {}
	return {
		"enabled": s.enabled,
		"stiffness": s.stiffness,
		"damping": s.damping,
		"max_compression": s.max_compression,
		"release_threshold": s.release_threshold,
		"axis": _vec3(s.axis),
		"efficiency": s.efficiency,
	}


static func _spring_from_dict(data) -> SpringDef:
	if not (data is Dictionary) or (data as Dictionary).is_empty():
		return null
	var s := SpringDef.new()
	s.enabled = bool(data.get("enabled", true))
	s.stiffness = float(data.get("stiffness", 180.0))
	s.damping = float(data.get("damping", 0.20))
	s.max_compression = float(data.get("max_compression", 0.18))
	s.release_threshold = float(data.get("release_threshold", 0.20))
	s.axis = _vec3_from(data.get("axis", [0.0, 1.0, 0.0]), Vector3.UP)
	s.efficiency = float(data.get("efficiency", 0.65))
	return s


static func _weapon_to_dict(w: WeaponDef) -> Dictionary:
	if w == null:
		return {}
	return {
		"kind": String(w.kind),
		"sharpness": w.sharpness,
		"penetration": w.penetration,
		"impact_multiplier": w.impact_multiplier,
		"bleed": w.bleed,
		"venom": w.venom,
		"reach": w.reach,
	}


static func _weapon_from_dict(data) -> WeaponDef:
	if not (data is Dictionary) or (data as Dictionary).is_empty():
		return null
	var w := WeaponDef.new()
	w.kind = StringName(String(data.get("kind", "bludgeon")))
	w.sharpness = float(data.get("sharpness", 0.0))
	w.penetration = float(data.get("penetration", 0.0))
	w.impact_multiplier = float(data.get("impact_multiplier", 1.0))
	w.bleed = float(data.get("bleed", 0.0))
	w.venom = float(data.get("venom", 0.0))
	w.reach = float(data.get("reach", 0.0))
	return w


static func _attach_points_to_arr(points: Array) -> Array:
	var out: Array = []
	for ap in points:
		if ap == null:
			continue
		out.append({
			"id": String(ap.id),
			"local_pose": _xform(ap.local_pose),
			"hinge_axis": _vec3(ap.hinge_axis),
			"accepts": _stringname_array_to_strings(ap.accepts),
			"capacity": ap.capacity,
		})
	return out


static func _attach_points_from(data) -> Array[AttachPoint]:
	var out: Array[AttachPoint] = []
	if not (data is Array):
		return out
	for entry in data:
		if not (entry is Dictionary):
			continue
		var ap := AttachPoint.new()
		ap.id = StringName(String(entry.get("id", "")))
		ap.local_pose = _xform_from(entry.get("local_pose", {}))
		ap.hinge_axis = _vec3_from(entry.get("hinge_axis", [0.0, 0.0, 0.0]), Vector3.ZERO)
		var accepts: Array[StringName] = []
		for a in entry.get("accepts", []):
			accepts.append(StringName(String(a)))
		ap.accepts = accepts
		ap.capacity = int(entry.get("capacity", 1))
		out.append(ap)
	return out


static func _stringname_array_to_strings(arr: Array) -> Array:
	var out: Array = []
	for a in arr:
		out.append(String(a))
	return out


static func _tendon_to_dict(t: TendonDef) -> Dictionary:
	if t == null:
		return {}
	return {
		"enabled": t.enabled,
		"partner_part_id": String(t.partner_part_id),
		"stiffness": t.stiffness,
		"efficiency": t.efficiency,
		"rest_offset": t.rest_offset,
	}


static func _tendon_from_dict(data) -> TendonDef:
	if not (data is Dictionary) or (data as Dictionary).is_empty():
		return null
	var t := TendonDef.new()
	t.enabled = bool(data.get("enabled", true))
	t.partner_part_id = StringName(String(data.get("partner_part_id", "")))
	t.stiffness = float(data.get("stiffness", 120.0))
	t.efficiency = float(data.get("efficiency", 0.85))
	t.rest_offset = float(data.get("rest_offset", 0.0))
	return t


static func _vec3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _vec3_from(v, fallback: Vector3) -> Vector3:
	if v is Array and (v as Array).size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return fallback


static func _xform(t: Transform3D) -> Dictionary:
	return {
		"x": _vec3(t.basis.x),
		"y": _vec3(t.basis.y),
		"z": _vec3(t.basis.z),
		"origin": _vec3(t.origin),
	}


static func _xform_from(data) -> Transform3D:
	if not (data is Dictionary):
		return Transform3D.IDENTITY
	var d: Dictionary = data
	var b := Basis(
			_vec3_from(d.get("x", [1.0, 0.0, 0.0]), Vector3.RIGHT),
			_vec3_from(d.get("y", [0.0, 1.0, 0.0]), Vector3.UP),
			_vec3_from(d.get("z", [0.0, 0.0, 1.0]), Vector3.BACK))
	return Transform3D(b, _vec3_from(d.get("origin", [0.0, 0.0, 0.0]), Vector3.ZERO))


static func _aabb(a: AABB) -> Dictionary:
	return {"position": _vec3(a.position), "size": _vec3(a.size)}


static func _aabb_from(data) -> AABB:
	if not (data is Dictionary):
		return AABB()
	return AABB(_vec3_from(data.get("position", [0.0, 0.0, 0.0]), Vector3.ZERO),
			_vec3_from(data.get("size", [0.0, 0.0, 0.0]), Vector3.ZERO))


static func _string_array(values: Array) -> Array:
	var out: Array = []
	for v in values:
		out.append(String(v))
	return out


static func _string_names(values) -> Array[StringName]:
	var out: Array[StringName] = []
	if values is Array:
		for v in values:
			out.append(StringName(String(v)))
	return out


static func _string_keyed_float_dict(values: Dictionary) -> Dictionary:
	var out := {}
	for k in values:
		out[String(k)] = float(values[k])
	return out


static func _float_dict_from(values) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	if values is Dictionary:
		for k in values:
			out[StringName(String(k))] = float(values[k])
	return out


## Enforces the sharing rule: every PartGene and every per-part mutable sub-resource
## (SocketDef/JointDef/GaitDef/PhysicsDescriptor) must appear at most once in the tree.
## PartDefinition is exempt (shared-immutable catalog). Returns {ok: bool, error: String}.
static func validate_unique(root: PartGene) -> Dictionary:
	var seen_genes := {}
	var seen_sub := {}
	var err := _walk_unique(root, seen_genes, seen_sub)
	return {"ok": err == "", "error": err}


static func _walk_unique(g: PartGene, seen_genes: Dictionary, seen_sub: Dictionary) -> String:
	if g == null:
		return ""
	var gid := g.get_instance_id()
	if seen_genes.has(gid):
		return "shared PartGene instance (id %d) referenced by more than one parent — the genome must be a strict tree" % gid
	seen_genes[gid] = true

	for entry in [["SocketDef", g.socket], ["JointDef", g.joint], ["SpringDef", g.spring], ["WeaponDef", g.weapon], ["TendonDef", g.tendon], ["GaitDef", g.gait], ["PhysicsDescriptor", g.descriptor]]:
		var res: Resource = entry[1]
		if res != null:
			var rid := res.get_instance_id()
			if seen_sub.has(rid):
				return "shared %s instance (id %d) referenced by two genes — per-part state must be unique" % [entry[0], rid]
			seen_sub[rid] = entry[0]

	for child in g.children:
		var e := _walk_unique(child, seen_genes, seen_sub)
		if e != "":
			return e
	return ""
