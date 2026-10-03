class_name AttachLogic
extends RefCounted

## M50 — the data/logic layer for two-point attach + user-placed nubs. Pure genome transforms the
## editor's interactive state machine drives through EditSession (the camera/mouse/gizmo work is
## play-tested; this logic is unit-tested). Nubs serialize on the genome (round-trip), so the exact
## authored anchor survives save/load — without that, the workflow it enables would vanish on reload.


# Place a nub (a user attachment point) at a local position + surface normal on a part.
static func add_nub(gene: PartGene, local_pos: Vector3, normal := Vector3.UP,
		id := &"") -> AttachPoint:
	if gene == null:
		return null
	var ap := AttachPoint.new()
	ap.id = id if id != &"" else StringName("nub_%d" % gene.attach_points.size())
	ap.local_pose = Transform3D(_basis_from_normal(normal), local_pos)
	ap.hinge_axis = Vector3.ZERO          # set when the attach is hinged (consume_nub)
	ap.capacity = 1
	gene.attach_points.append(ap)
	return ap


# Attach `child` to a nub on `parent`, welding it at the nub's EXACT local pose, and CONSUME the nub
# (remove it — the part now occupies that anchor). `proximal` is the child's proximal half-length so
# its END meets the nub (Principle 19). If `hinge_axis` is non-zero the weld is a powered hinge.
static func consume_nub(parent: PartGene, nub_id: StringName, child: PartGene,
		proximal := 0.0, hinge_axis := Vector3.ZERO) -> bool:
	if parent == null or child == null:
		return false
	var idx := -1
	for i in parent.attach_points.size():
		if parent.attach_points[i] != null and parent.attach_points[i].id == nub_id:
			idx = i
			break
	if idx < 0:
		return false
	var nub := parent.attach_points[idx]
	var s := SocketDef.new()
	s.id = nub.id
	s.parent_attachment = nub.local_pose                       # weld at the nub's exact spot
	s.child_anchor = Transform3D(Basis.IDENTITY, Vector3(0.0, -maxf(proximal, 0.0), 0.0))
	s.hinge_axis = hinge_axis
	child.socket = s
	if not hinge_axis.is_zero_approx():
		if child.joint == null:
			child.joint = JointDef.new()
			child.joint.amplitude = 1.0
			child.joint.angle_min = -1.1
			child.joint.angle_max = 1.1
	parent.children.append(child)
	parent.attach_points.remove_at(idx)                        # the nub is consumed
	return true


# M50 rule 4 (Cole): hinge-edit mode opens ONLY when the ACTUATING piece lands on a hinge — never on
# bare hinge creation. The deliberate "Edit hinge" action passes manual=true.
static func opens_hinge_edit(is_actuating_attach: bool, hinge_present: bool, manual := false) -> bool:
	if manual:
		return true
	return is_actuating_attach and hinge_present


# Free attachment slots, for the two-point-attach warnings. A part's PROXIMAL slot is its own socket
# (to its parent); its DISTAL slots are its free nubs. Returns {proximal_free, distal_free, both_free}.
static func slot_state(gene: PartGene) -> Dictionary:
	var proximal_free := gene != null and gene.socket == null
	var distal_free := gene != null and not gene.attach_points.is_empty()
	return {
		"proximal_free": proximal_free,
		"distal_free": distal_free,
		"both_free": proximal_free and distal_free,
		"fully_attached": gene != null and not proximal_free and gene.children.size() > 0,
	}


static func _basis_from_normal(n: Vector3) -> Basis:
	var up := n.normalized()
	if up.is_zero_approx():
		return Basis.IDENTITY
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z)
