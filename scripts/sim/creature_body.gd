class_name CreatureBody
extends Node3D

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const SimWorldScript := preload("res://scripts/sim/sim_world.gd")
const AnisotropicBodyScript := preload("res://scripts/sim/anisotropic_body.gd")
const WingBodyScript := preload("res://scripts/sim/wing_body.gd")
const PartMeshProviderScript := preload("res://scripts/creature/part_mesh_provider.gd")

const ANISOTROPIC_LATERAL_DAMP := 9.0   # M40/M59: lateral grip for &"anisotropic_ventral". Tuned so
	# the belly grips sideways enough to rectify the body-wave into forward thrust, but not so hard it
	# locks the body and kills the wave (swept headless: ~9 gives the strongest assist-free forward).

## Runtime physics body built from the evaluator fold. M4 keeps the simple
## one-RigidBody3D-per-ResolvedPart topology so construction parity is explicit.

var _part_bodies: Array[RigidBody3D] = []
var _parts: Array = []
var _joints: Array[Joint3D] = []
var _drive_joints: Array[Dictionary] = []
var _params: BuildParams
var _torn_joints := 0


class BuildParams:
	var foot_friction := 1.0
	var body_friction := 0.8
	var enforce_rom := true
	var collision_layer := 1
	var collision_mask := 1
	var creature_id := &"creature"
	var contact_monitor := false
	var max_contacts_reported := 8
	var use_authored_colliders := false   # M45: derive collision from authored meshes (convex hull)
	var disable_self_collision := false   # M59: ragdoll-style — parts of THIS creature don't collide
		# with each other (they still collide with the floor + opponents). Right model for a dense
		# articulated body (e.g. a many-legged centipede) where limbs would otherwise spike at spawn.


static func build(root: PartGene, root_xform := Transform3D.IDENTITY, params: BuildParams = null) -> Node3D:
	var body := new()
	body._params = params if params != null else BuildParams.new()
	# M60: a creature can opt into authored-mesh collision via a root tag (set by the editor's .glb
	# import) so imported meshes drive collision without a manual BuildParams toggle. Additive: only
	# turns the flag ON when present, never off, so explicit params still win.
	if root != null and root.tags.has(&"authored_colliders"):
		body._params.use_authored_colliders = true
	if root != null and root.tags.has(&"no_self_collision"):
		body._params.disable_self_collision = true
	body._build_from_root(root, root_xform)
	return body


func part_bodies() -> Array[RigidBody3D]:
	return _part_bodies.duplicate()


# Lowest bottom of any ground_contact (foot) part, in world Y. Used by the rollout to detect a real
# FLIGHT phase (all feet clear of the floor) — a jump/step discriminator that a body-shift or
# front-leg-push cheat cannot fake. Returns 0.0 if the creature has no feet.
func min_foot_bottom_y() -> float:
	var lowest := INF
	for i in range(mini(_parts.size(), _part_bodies.size())):
		if not _parts[i].tags.has(&"ground_contact"):
			continue
		var b := _part_bodies[i]
		lowest = minf(lowest, b.global_position.y - _parts[i].dims.y * 0.5)
	return lowest if lowest != INF else 0.0


func parts() -> Array:
	return _parts.duplicate()


func joints() -> Array[Joint3D]:
	return _joints.duplicate()


func drive_joints() -> Array[Dictionary]:
	return _drive_joints.duplicate()


func torn_joints() -> int:
	return _torn_joints


func tear_joint(part_index: int, reason := "overstress") -> bool:
	for i in range(_drive_joints.size() - 1, -1, -1):
		var meta: Dictionary = _drive_joints[i]
		if int(meta.get("part_index", -1)) != part_index:
			continue
		var joint := meta.get("hinge_node") as Joint3D
		if joint != null:
			joint.set_meta("torn", true)
			joint.set_meta("tear_reason", reason)
			joint.queue_free()
		_drive_joints.remove_at(i)
		_torn_joints += 1
		return true
	return false


func measure() -> Dictionary:
	var total_mass := 0.0
	var weighted := Vector3.ZERO
	var finite := true
	for b in _part_bodies:
		total_mass += b.mass
		weighted += b.global_position * b.mass
		finite = finite and _finite_vec3(b.global_position)
	var cog := weighted / maxf(total_mass, 0.000001)
	return {
		"part_count": _part_bodies.size(),
		"joint_count": _joints.size(),
		"total_mass": total_mass,
		"cog": cog,
		"torn_joints": _torn_joints,
		"finite": finite and _finite_vec3(cog) and is_finite(total_mass),
	}


func _build_from_root(root_gene: PartGene, root_xform: Transform3D) -> void:
	var fold := CE.fold_graph(root_gene, root_xform)
	_parts = fold["parts"]
	for p in _parts:
		var rb: RigidBody3D
		if p.tags.has(&"wing"):
			# M52: aero surface — lift/drag at the wing from its own airflow (no root shove).
			var wb := WingBodyScript.new()
			wb.wing_area = maxf(p.dims.x * p.dims.z, 0.001)   # planform footprint
			wb.normal_local = Vector3.UP
			rb = wb
		elif p.tags.has(&"anisotropic_ventral"):
			# M40/M59: belly segment with directional ground friction. The serpent is built as an
			# identity-frame box chain along world Z (yaw hinge = vertical = lateral bend), so the
			# body/slither axis is local +Z.
			var ab := AnisotropicBodyScript.new()
			ab.axial_axis_local = Vector3(0.0, 0.0, 1.0)
			ab.lateral_damp_coeff = ANISOTROPIC_LATERAL_DAMP
			rb = ab
		else:
			rb = RigidBody3D.new()
		rb.name = "Part_%02d" % int(p.index)
		rb.transform = p.xform
		rb.mass = maxf(float(p.mass), 0.001)
		rb.can_sleep = false   # actuated bodies must stay awake or the gait freezes
		rb.collision_layer = _params.collision_layer
		rb.collision_mask = _params.collision_mask
		if _params.contact_monitor:
			rb.contact_monitor = true
			rb.max_contacts_reported = _params.max_contacts_reported
		rb.physics_material_override = SimWorldScript.make_physics_material(
				_params.foot_friction if p.tags.has(&"ground_contact") else _params.body_friction, 0.0)
		rb.set_meta("part_index", int(p.index))
		rb.set_meta("creature_id", _params.creature_id)
		var cs := CollisionShape3D.new()
		cs.shape = _collider_for(p)
		rb.add_child(cs)
		add_child(rb)
		_part_bodies.append(rb)

	# M59: ragdoll self-collision off — exclude every intra-creature pair so a dense articulated
	# body (many close limbs) doesn't spike at spawn. Floor + opponent collisions are untouched.
	if _params.disable_self_collision:
		for i in _part_bodies.size():
			for j in range(i + 1, _part_bodies.size()):
				_part_bodies[i].add_collision_exception_with(_part_bodies[j])
				_part_bodies[j].add_collision_exception_with(_part_bodies[i])

	for p in _parts:
		if int(p.parent) < 0:
			continue
		var child_body := _part_bodies[int(p.index)]
		var parent_body := _part_bodies[int(p.parent)]
		parent_body.add_collision_exception_with(child_body)
		child_body.add_collision_exception_with(parent_body)
		var joint := _joint_for(p, parent_body, child_body)
		add_child(joint)
		joint.node_a = joint.get_path_to(parent_body)
		joint.node_b = joint.get_path_to(child_body)
		joint.exclude_nodes_from_collision = true
		_joints.append(joint)
		if joint is HingeJoint3D:
			var axis_world := _joint_axis_world(p, parent_body)
			_drive_joints.append({
				"part_index": int(p.index),
				"parent_body": parent_body,
				"child_body": child_body,
				"hinge_node": joint,
				"axis_world": axis_world,
				"axis_parent_local": (parent_body.transform.basis.inverse() * axis_world).normalized(),
				"rest_rel": parent_body.transform.basis.inverse() * child_body.transform.basis,
				"limits": {
					"enabled": _params.enforce_rom and p.joint != null and p.joint.angle_max > p.joint.angle_min,
					"lower": p.joint.angle_min if p.joint != null else 0.0,
					"upper": p.joint.angle_max if p.joint != null else 0.0,
				},
			})


# M45: a part's collision shape. With use_authored_colliders, a part that has a registered
# authored mesh gets a convex hull of that mesh DRIVING physics; otherwise the primitive box/
# sphere/etc. (Convex-hull fallback inside collider_for_mesh guarantees a valid shape.)
func _collider_for(p) -> Shape3D:
	if _params.use_authored_colliders and PartMeshProviderScript.has_authored(p.part_id):
		var mesh := PartMeshProviderScript.mesh_for_part_id(p.part_id, p.dims)
		if mesh != null:
			return PartMeshProviderScript.collider_for_mesh(mesh, p.dims)
	return _shape_for(p.definition.part_type, p.dims)


func _shape_for(part_type: StringName, dims: Vector3) -> Shape3D:
	match part_type:
		&"sphere":
			var s := SphereShape3D.new()
			s.radius = maxf(maxf(dims.x, maxf(dims.y, dims.z)) * 0.5, 0.001)
			return s
		&"cylinder":
			var s := CylinderShape3D.new()
			s.radius = maxf((dims.x + dims.z) * 0.25, 0.001)
			s.height = maxf(dims.y, 0.001)
			return s
		&"capsule":
			var s := CapsuleShape3D.new()
			s.radius = maxf((dims.x + dims.z) * 0.25, 0.001)
			s.height = maxf(dims.y, s.radius * 2.0)
			return s
		_:
			var s := BoxShape3D.new()
			s.size = Vector3(maxf(dims.x, 0.001), maxf(dims.y, 0.001), maxf(dims.z, 0.001))
			return s


func _joint_for(p, parent_body: RigidBody3D, _child_body: RigidBody3D) -> Joint3D:
	var socket: SocketDef = p.socket
	var joint_xform := parent_body.transform
	if socket != null:
		joint_xform = parent_body.transform * socket.parent_attachment
	if not p.hinge_axis.is_zero_approx():
		var h := HingeJoint3D.new()
		h.name = "Hinge_%02d" % int(p.index)
		h.transform = Transform3D(_basis_from_z_axis(_joint_axis_world(p, parent_body)),
				joint_xform.origin)
		if _params.enforce_rom and p.joint != null and p.joint.angle_max > p.joint.angle_min:
			h.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
			h.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, p.joint.angle_min)
			h.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, p.joint.angle_max)
		return h
	var fixed := Generic6DOFJoint3D.new()
	fixed.name = "Fixed_%02d" % int(p.index)
	fixed.transform = joint_xform
	_lock_axis(fixed, 0)
	_lock_axis(fixed, 1)
	_lock_axis(fixed, 2)
	return fixed


func _joint_axis_world(p, parent_body: RigidBody3D) -> Vector3:
	var socket: SocketDef = p.socket
	var basis := parent_body.transform.basis
	if socket != null:
		basis = (parent_body.transform * socket.parent_attachment).basis
	return (basis * p.hinge_axis.normalized()).normalized()


func _lock_axis(joint: Generic6DOFJoint3D, axis: int) -> void:
	match axis:
		0:
			joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
			joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
			joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
			joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
			joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 0.0)
			joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)
		1:
			joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
			joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
			joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
			joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
			joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 0.0)
			joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)
		2:
			joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
			joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
			joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
			joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
			joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 0.0)
			joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)


# Godot's HingeJoint3D frees rotation about its LOCAL Z axis, so the hinge frame
# must put the desired rotation axis on Z (not X) or the joint locks the very axis
# the controller drives.
static func _basis_from_z_axis(axis: Vector3) -> Basis:
	var z := axis.normalized()
	if z.is_zero_approx():
		return Basis.IDENTITY
	var up := Vector3.UP
	if absf(z.dot(up)) > 0.95:
		up = Vector3.FORWARD
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)


static func _finite_vec3(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)
