class_name SocketCatalog
extends RefCounted

## Default authoring attachment points and legality checks. Socket ids encode
## occupancy: capacity 1 uses the point id directly; multi-slot points use
## "<point_id>__NN".


static func points_for(defn: PartDefinition) -> Array[AttachPoint]:
	var out: Array[AttachPoint] = []
	var e := Vector3.ONE if defn == null else defn.extents
	var part_type := &"box" if defn == null else defn.part_type
	match part_type:
		&"capsule", &"cylinder":
			out.append(_point(&"end_top", Vector3(0.0, e.y, 0.0), Vector3.RIGHT,
					[&"spine", &"tail", &"attack", &"sensor", &"manipulator", &"muscle", &"tendon"], 1))
			out.append(_point(&"end_bottom", Vector3(0.0, -e.y, 0.0), Vector3.RIGHT,
					[&"spine", &"locomotor", &"ground_contact", &"manipulator", &"muscle", &"tendon"], 1))
			out.append(_point(&"mid_left", Vector3(-e.x, 0.0, 0.0), Vector3.RIGHT,
					[&"locomotor", &"manipulator", &"sensor", &"attack", &"muscle", &"tendon", &"armor", &"fat"], 1))
			out.append(_point(&"mid_right", Vector3(e.x, 0.0, 0.0), Vector3.RIGHT,
					[&"locomotor", &"manipulator", &"sensor", &"attack", &"muscle", &"tendon", &"armor", &"fat"], 1))
		&"sphere":
			out.append(_point(&"head_front", Vector3(0.0, 0.0, -e.z), Vector3.ZERO, [&"brain", &"sensor", &"attack"], 1))
			out.append(_point(&"organ_core", Vector3.ZERO, Vector3.ZERO, [&"heart", &"brain", &"lung", &"fat", &"muscle"], 2))
			out.append(_point(&"sensor_top", Vector3(0.0, e.y, 0.0), Vector3.ZERO,
					[&"sensor", &"attack", &"armor", &"fat"], 2))
			out.append(_point(&"jaw", Vector3(0.0, -e.y * 0.6, -e.z * 0.6), Vector3.RIGHT,
					[&"attack", &"sensor", &"manipulator"], 1))
		_:
			out.append(_point(&"body_front", Vector3(0.0, 0.0, -e.z), Vector3.UP,
					[&"spine", &"brain", &"sensor", &"attack", &"muscle", &"tendon", &"armor", &"fat"], 1))
			out.append(_point(&"body_back", Vector3(0.0, 0.0, e.z), Vector3.UP,
					[&"spine", &"tail", &"attack", &"muscle", &"tendon", &"armor", &"fat"], 1))
			out.append(_point(&"limb_left_front", Vector3(-e.x, -e.y, -e.z * 0.55), Vector3.RIGHT, [&"locomotor", &"ground_contact"], 1))
			out.append(_point(&"limb_right_front", Vector3(e.x, -e.y, -e.z * 0.55), Vector3.RIGHT, [&"locomotor", &"ground_contact"], 1))
			out.append(_point(&"limb_left_back", Vector3(-e.x, -e.y, e.z * 0.55), Vector3.RIGHT, [&"locomotor", &"ground_contact"], 1))
			out.append(_point(&"limb_right_back", Vector3(e.x, -e.y, e.z * 0.55), Vector3.RIGHT, [&"locomotor", &"ground_contact"], 1))
			out.append(_point(&"limb_left_upper", Vector3(-e.x, e.y * 0.4, 0.0), Vector3.RIGHT,
					[&"locomotor", &"manipulator", &"muscle", &"tendon"], 1))
			out.append(_point(&"limb_right_upper", Vector3(e.x, e.y * 0.4, 0.0), Vector3.RIGHT,
					[&"locomotor", &"manipulator", &"muscle", &"tendon"], 1))
			out.append(_point(&"organ_core", Vector3.ZERO, Vector3.ZERO,
					[&"heart", &"brain", &"lung", &"muscle", &"fat"], 2))
			out.append(_point(&"organ_top", Vector3(0.0, e.y, 0.0), Vector3.ZERO,
					[&"heart", &"brain", &"lung", &"muscle", &"tendon", &"armor", &"fat"], 3))
			# Dense extra slots: a part (leg, arm, sensor, ...) can attach on ANY face, edge, or corner of
			# the root body — top, sides, back — not just the belly. 3x3x3 grid minus the centre = 26 points
			# on the box surface, each broadly tag-accepting so you can, e.g., stick legs out of the top.
			var anywhere: Array[StringName] = [&"locomotor", &"ground_contact", &"manipulator", &"sensor",
					&"attack", &"muscle", &"tendon", &"armor", &"fat", &"spine", &"tail"]
			var n := 0
			for sx in [-1, 0, 1]:
				for sy in [-1, 0, 1]:
					for sz in [-1, 0, 1]:
						if sx == 0 and sy == 0 and sz == 0:
							continue
						var pos := Vector3(float(sx) * e.x, float(sy) * e.y, float(sz) * e.z)
						var hax := Vector3.FORWARD if absf(float(sx)) > 0.5 else Vector3.RIGHT
						out.append(_point(StringName("edge_%02d" % n), pos, hax, anywhere, 1))
						n += 1
	return out


static func point_for(parent_gene: PartGene, point_id: StringName) -> AttachPoint:
	if parent_gene == null:
		return null
	for p in points_for(parent_gene.definition):
		if p.id == point_id:
			return p
	return null


static func can_attach(parent_gene: PartGene, point_id: StringName,
		child_tags: Array[StringName]) -> Dictionary:
	if parent_gene == null:
		return {"ok": false, "reason": "missing parent"}
	var p := point_for(parent_gene, point_id)
	if p == null:
		return {"ok": false, "reason": "unknown attach point"}
	if not p.accepts_tags(child_tags):
		return {"ok": false, "reason": "tag mismatch", "point": p}
	var occupied := occupancy(parent_gene, point_id)
	if occupied >= max(1, p.capacity):
		return {"ok": false, "reason": "attach point occupied", "point": p, "occupied": occupied}
	return {"ok": true, "reason": "", "point": p, "occupied": occupied}


static func occupancy(parent_gene: PartGene, point_id: StringName) -> int:
	if parent_gene == null:
		return 0
	var n := 0
	for child in parent_gene.children:
		if point_id_for_socket_id(child.socket_id) == point_id:
			n += 1
	return n


static func next_socket_id(parent_gene: PartGene, point_id: StringName) -> StringName:
	var p := point_for(parent_gene, point_id)
	if p == null:
		return point_id
	var slot := occupancy(parent_gene, point_id)
	return socket_id_for_point(point_id, slot, p.capacity)


static func socket_id_for_point(point_id: StringName, slot_index := 0, capacity := 1) -> StringName:
	if capacity <= 1:
		return point_id
	return StringName("%s__%02d" % [String(point_id), maxi(slot_index, 0)])


static func point_id_for_socket_id(socket_id: StringName) -> StringName:
	var s := String(socket_id)
	var marker := s.find("__")
	if marker < 0:
		return socket_id
	return StringName(s.substr(0, marker))


static func socket_for_point(point: AttachPoint, socket_id: StringName) -> SocketDef:
	var s := SocketDef.new()
	s.id = socket_id
	s.display_name = String(socket_id)
	s.parent_attachment = point.local_pose
	s.child_anchor = Transform3D.IDENTITY
	s.hinge_axis = point.hinge_axis
	return s


static func socket_for_child(point: AttachPoint, socket_id: StringName,
		child_gene: PartGene, anchor := &"top") -> SocketDef:
	var s := socket_for_point(point, socket_id)
	s.child_anchor = child_anchor_for(child_gene, anchor)
	return s


static func child_anchor_for(child_gene: PartGene, anchor := &"top") -> Transform3D:
	if child_gene == null or child_gene.definition == null:
		return Transform3D.IDENTITY
	var e := child_gene.definition.extents * child_gene.scale
	var p := Vector3.ZERO
	match anchor:
		&"top":
			p = Vector3(0.0, -e.y, 0.0)
		&"bottom":
			p = Vector3(0.0, e.y, 0.0)
		&"center":
			p = Vector3.ZERO
	return Transform3D(Basis.IDENTITY, p)


static func _point(id: StringName, local_pos: Vector3, hinge: Vector3,
		accepts: Array[StringName], capacity := 1) -> AttachPoint:
	var p := AttachPoint.new()
	p.id = id
	p.local_pose = Transform3D(Basis.IDENTITY, local_pos)
	p.hinge_axis = hinge
	p.accepts = accepts
	p.capacity = maxi(capacity, 1)
	return p
