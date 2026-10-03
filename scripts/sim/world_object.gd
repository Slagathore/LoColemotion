class_name WorldObject
extends RefCounted

## Runtime entities for manipulation tracks: push targets, food, tools, buttons.
## They are plain Godot physics bodies with stable metadata so Track/SimRollout can
## measure object movement without knowing each object's implementation details.

const SimWorldScript := preload("res://scripts/sim/sim_world.gd")


static func make_rigid(kind: StringName, position: Vector3, size := Vector3(0.35, 0.35, 0.35),
		mass := 1.0, graspable := false, friction := 1.0) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.name = "WorldObject_%s" % String(kind)
	rb.position = position
	rb.mass = maxf(mass, 0.001)
	rb.can_sleep = false
	rb.physics_material_override = SimWorldScript.make_physics_material(friction, 0.0)
	rb.set_meta("world_object_kind", kind)
	rb.set_meta("start_pos", position)
	rb.set_meta("graspable", graspable)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color_for(kind)
	mi.material_override = mat
	rb.add_child(mi)
	return rb


static func make_food(position: Vector3) -> RigidBody3D:
	return make_rigid(&"food", position, Vector3(0.28, 0.28, 0.28), 0.6, true, 1.0)


static func make_tool(position: Vector3) -> RigidBody3D:
	return make_rigid(&"tool", position, Vector3(0.18, 0.18, 0.75), 0.8, true, 1.0)


static func make_tool_target(position: Vector3) -> RigidBody3D:
	var rb := make_rigid(&"tool_target", position, Vector3(0.55, 0.20, 0.55), 0.001, false, 1.0)
	rb.freeze = true
	rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	return rb


static func make_push_block(position: Vector3) -> RigidBody3D:
	return make_rigid(&"push_block", position, Vector3(0.45, 0.35, 0.45), 0.35, true, 1.2)


static func make_grasp_joint(parent: Node3D, carrier: RigidBody3D, object: RigidBody3D) -> Generic6DOFJoint3D:
	if parent == null or carrier == null or object == null:
		return null
	var joint := Generic6DOFJoint3D.new()
	joint.name = "GraspJoint"
	joint.position = parent.to_local((carrier.global_position + object.global_position) * 0.5)
	parent.add_child(joint)
	joint.node_a = joint.get_path_to(carrier)
	joint.node_b = joint.get_path_to(object)
	joint.exclude_nodes_from_collision = true
	_lock_axis(joint, 0)
	_lock_axis(joint, 1)
	_lock_axis(joint, 2)
	object.set_meta("grasped", true)
	return joint


static func release_grasp(joint: Joint3D, object: RigidBody3D = null) -> void:
	if object != null:
		object.set_meta("grasped", false)
	if joint != null:
		joint.queue_free()


static func tool_sequence_score(grasped: bool, carried: bool, applied: bool,
		flung: bool, fell: bool) -> Dictionary:
	var progress := (1 if grasped else 0) + (1 if carried else 0) + (1 if applied else 0)
	var credible := grasped and carried and applied and not flung and not fell
	var reasons: Array[String] = []
	if not grasped:
		reasons.append("tool was never grasped")
	if grasped and not carried:
		reasons.append("tool was not carried")
	if carried and not applied:
		reasons.append("tool never touched target")
	if flung:
		reasons.append("tool was flung")
	if fell:
		reasons.append("creature fell")
	return {
		"fitness": float(progress) * 5.0 - (10.0 if flung or fell else 0.0),
		"credible": credible,
		"class": "tool_applied" if credible else "tool_sequence_failed",
		"reasons": reasons,
		"progress": progress,
	}


static func _lock_axis(joint: Generic6DOFJoint3D, axis: int) -> void:
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


static func _color_for(kind: StringName) -> Color:
	match kind:
		&"food":
			return Color(0.26, 0.64, 0.32)
		&"tool":
			return Color(0.28, 0.38, 0.70)
		&"tool_target":
			return Color(0.75, 0.28, 0.24)
		&"push_block":
			return Color(0.62, 0.46, 0.25)
	return Color(0.55, 0.55, 0.55)
