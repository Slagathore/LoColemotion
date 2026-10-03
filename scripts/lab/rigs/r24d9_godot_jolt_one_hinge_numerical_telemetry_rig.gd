class_name R24D9GodotJoltOneHingeNumericalTelemetryRig
extends RefCounted

## Prospectively frozen QSDK-R24D9 isolated one-hinge numerical fixture.
##
## All nine cells coexist in one zero-gravity world. Each has one frozen parent,
## one plain RigidBody3D child, and one center-of-mass hinge. In particular, the
## child has no _integrate_forces callback: completed-step sampling is performed
## only by the worker at the next SceneTree.physics_frame boundary, using the
## native v2 current-step tokens established by R24D8.

const FIXTURE_ID := "QSDK.R24D9.godot_jolt_one_hinge_numerical_telemetry.v1"
const CHILD_MASS_KG := 1.0
const CHILD_INERTIA_KG_M2 := Vector3(0.05, 0.05, 0.05)
const CANONICAL_AXIS_PARENT_LOCAL := Vector3.BACK
const MAXIMUM_PHYSICS_STEP_COUNT := 20
const RETAINED_SAMPLE_COUNT := 68
const CELL_SPECS := [
	{
		"cell_id": "drive_positive",
		"family": "signed_drive",
		"motor_enabled": true,
		"canonical_target_velocity_rad_s": 1.0,
		"initial_canonical_rate_rad_s": 0.0,
		"public_maximum_motor_impulse_nms": 0.002,
		"joint_limits_enabled": false,
		"lower_limit_rad": -1.0,
		"upper_limit_rad": 1.0,
		"retained_step_count": 4,
	},
	{
		"cell_id": "drive_negative",
		"family": "signed_drive",
		"motor_enabled": true,
		"canonical_target_velocity_rad_s": -1.0,
		"initial_canonical_rate_rad_s": 0.0,
		"public_maximum_motor_impulse_nms": 0.002,
		"joint_limits_enabled": false,
		"lower_limit_rad": -1.0,
		"upper_limit_rad": 1.0,
		"retained_step_count": 4,
	},
	{
		"cell_id": "brake_positive",
		"family": "signed_braking",
		"motor_enabled": true,
		"canonical_target_velocity_rad_s": 0.0,
		"initial_canonical_rate_rad_s": 0.4,
		"public_maximum_motor_impulse_nms": 0.002,
		"joint_limits_enabled": false,
		"lower_limit_rad": -1.0,
		"upper_limit_rad": 1.0,
		"retained_step_count": 4,
	},
	{
		"cell_id": "brake_negative",
		"family": "signed_braking",
		"motor_enabled": true,
		"canonical_target_velocity_rad_s": 0.0,
		"initial_canonical_rate_rad_s": -0.4,
		"public_maximum_motor_impulse_nms": 0.002,
		"joint_limits_enabled": false,
		"lower_limit_rad": -1.0,
		"upper_limit_rad": 1.0,
		"retained_step_count": 4,
	},
	{
		"cell_id": "disabled_positive",
		"family": "motor_disabled",
		"motor_enabled": false,
		"canonical_target_velocity_rad_s": 0.0,
		"initial_canonical_rate_rad_s": 0.4,
		"public_maximum_motor_impulse_nms": 0.002,
		"joint_limits_enabled": false,
		"lower_limit_rad": -1.0,
		"upper_limit_rad": 1.0,
		"retained_step_count": 4,
	},
	{
		"cell_id": "disabled_negative",
		"family": "motor_disabled",
		"motor_enabled": false,
		"canonical_target_velocity_rad_s": 0.0,
		"initial_canonical_rate_rad_s": -0.4,
		"public_maximum_motor_impulse_nms": 0.002,
		"joint_limits_enabled": false,
		"lower_limit_rad": -1.0,
		"upper_limit_rad": 1.0,
		"retained_step_count": 4,
	},
	{
		"cell_id": "limit_positive",
		"family": "limit_active_separation",
		"motor_enabled": true,
		"canonical_target_velocity_rad_s": 2.0,
		"initial_canonical_rate_rad_s": 0.0,
		"public_maximum_motor_impulse_nms": 0.01,
		"joint_limits_enabled": true,
		"lower_limit_rad": -0.02,
		"upper_limit_rad": 0.02,
		"retained_step_count": 20,
	},
	{
		"cell_id": "limit_negative",
		"family": "limit_active_separation",
		"motor_enabled": true,
		"canonical_target_velocity_rad_s": -2.0,
		"initial_canonical_rate_rad_s": 0.0,
		"public_maximum_motor_impulse_nms": 0.01,
		"joint_limits_enabled": true,
		"lower_limit_rad": -0.02,
		"upper_limit_rad": 0.02,
		"retained_step_count": 20,
	},
	{
		"cell_id": "sleep_stale",
		"family": "sleeping_freshness",
		"motor_enabled": true,
		"canonical_target_velocity_rad_s": 0.0,
		"initial_canonical_rate_rad_s": 0.0,
		"public_maximum_motor_impulse_nms": 0.002,
		"joint_limits_enabled": false,
		"lower_limit_rad": -1.0,
		"upper_limit_rad": 1.0,
		"retained_step_count": 4,
	},
]


static func describe() -> Dictionary:
	var ids: Array[String] = []
	for spec_value in CELL_SPECS:
		var spec: Dictionary = spec_value
		ids.append(String(spec["cell_id"]))
	return {
		"fixture_id": FIXTURE_ID,
		"world_count": 1,
		"isolated_cell_count": CELL_SPECS.size(),
		"cell_ids_in_order": ids,
		"hinges_per_cell": 1,
		"dynamic_bodies_per_cell": 1,
		"static_parents_per_cell": 1,
		"child_mass_kg": CHILD_MASS_KG,
		"child_inertia_diagonal_kg_m2": _vector(CHILD_INERTIA_KG_M2),
		"hinge_axis_parent_local": _vector(CANONICAL_AXIS_PARENT_LOCAL),
		"maximum_physics_step_count": MAXIMUM_PHYSICS_STEP_COUNT,
		"retained_sample_count": RETAINED_SAMPLE_COUNT,
		"gravity_scale": 0.0,
		"linear_damping": 0.0,
		"angular_damping": 0.0,
		"collision_layer": 0,
		"collision_mask": 0,
		"contact_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
	}


static func declared_cell_specs() -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	for spec_value in CELL_SPECS:
		var spec: Dictionary = spec_value
		copies.append(spec.duplicate(true))
	return copies


static func build() -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "QsdkR24D9OneHingeNumericalTelemetryViewport"
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var world := Node3D.new()
	world.name = "QsdkR24D9OneHingeNumericalTelemetryWorld"
	viewport.add_child(world)

	var cells: Array[Dictionary] = []
	var pre_tree_refusals := {}
	for index in range(CELL_SPECS.size()):
		var cell := _build_cell(world, index, CELL_SPECS[index])
		var joint: HingeJoint3D = cell["joint"]
		var pre_tree_value: Variant = (
			JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(joint.get_rid())
		)
		cell["pre_tree_read_refused"] = pre_tree_value == null
		pre_tree_refusals[String(cell["cell_id"])] = pre_tree_value == null
		cells.append(cell)
	return {
		"ok": true,
		"fixture_id": FIXTURE_ID,
		"viewport": viewport,
		"world": world,
		"cells": cells,
		"pre_tree_refusals": pre_tree_refusals,
		"world_attempt_count": 1,
		"world_build_count": 1,
	}


static func activate(cell: Dictionary) -> int:
	var child: RigidBody3D = cell["child"]
	var initial_rate := float(cell["initial_canonical_rate_rad_s"])
	var write_count := 0
	if not is_zero_approx(initial_rate):
		child.angular_velocity = canonical_axis_world(cell) * initial_rate
		write_count = 1
	child.freeze = false
	child.can_sleep = false
	child.sleeping = false
	return write_count


static func force_declared_sleep(cell: Dictionary) -> void:
	var child: RigidBody3D = cell["child"]
	child.can_sleep = true
	child.sleeping = true


static func canonical_axis_world(cell: Dictionary) -> Vector3:
	var parent: RigidBody3D = cell["parent"]
	return (parent.global_basis * CANONICAL_AXIS_PARENT_LOCAL).normalized()


static func canonical_rate_rad_s(cell: Dictionary) -> float:
	var parent: RigidBody3D = cell["parent"]
	var child: RigidBody3D = cell["child"]
	return (child.angular_velocity - parent.angular_velocity).dot(
		canonical_axis_world(cell)
	)


static func inverse_inertia_axis_kg_inv_m2(cell: Dictionary) -> float:
	var child: RigidBody3D = cell["child"]
	var axis_world := canonical_axis_world(cell)
	var inverse_tensor := child.get_inverse_inertia_tensor()
	return axis_world.dot(inverse_tensor * axis_world)


static func parameter_readback(cell: Dictionary) -> Dictionary:
	var child: RigidBody3D = cell["child"]
	var joint: HingeJoint3D = cell["joint"]
	var parent: RigidBody3D = cell["parent"]
	var parent_axis := canonical_axis_world(cell)
	var joint_axis := (joint.global_basis * Vector3.BACK).normalized()
	return {
		"child_mass_kg": child.mass,
		"child_inertia_diagonal_kg_m2": _vector(child.inertia),
		"gravity_scale": child.gravity_scale,
		"linear_damping": child.linear_damp,
		"angular_damping": child.angular_damp,
		"collision_layer": child.collision_layer,
		"collision_mask": child.collision_mask,
		"motor_enabled": joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR),
		"joint_limits_enabled": joint.get_flag(HingeJoint3D.FLAG_USE_LIMIT),
		"host_target_velocity_rad_s": joint.get_param(
			HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY
		),
		"public_maximum_motor_impulse_nms": joint.get_param(
			HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE
		),
		"lower_limit_rad": joint.get_param(HingeJoint3D.PARAM_LIMIT_LOWER),
		"upper_limit_rad": joint.get_param(HingeJoint3D.PARAM_LIMIT_UPPER),
		"anchor_error_m": parent.global_position.distance_to(child.global_position),
		"axis_error_rad": acos(
			clampf(absf(parent_axis.dot(joint_axis)), 0.0, 1.0)
		),
	}


static func _build_cell(
	world: Node3D,
	cell_index: int,
	spec_value: Dictionary,
) -> Dictionary:
	var spec := spec_value.duplicate(true)
	var column := cell_index % 5
	var row := cell_index / 5
	var pivot := Vector3(float(column) * 2.0, 2.0 + float(row) * 2.0, 0.0)
	var cell_id := String(spec["cell_id"])

	var parent := RigidBody3D.new()
	parent.name = "%sParent" % cell_id
	parent.position = pivot
	parent.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	parent.freeze = true
	parent.can_sleep = false
	parent.gravity_scale = 0.0
	parent.collision_layer = 0
	parent.collision_mask = 0
	world.add_child(parent)

	var child := RigidBody3D.new()
	child.name = "%sChild" % cell_id
	child.position = pivot
	child.mass = CHILD_MASS_KG
	child.inertia = CHILD_INERTIA_KG_M2
	child.gravity_scale = 0.0
	child.can_sleep = false
	child.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	child.freeze = true
	child.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	child.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	child.linear_damp = 0.0
	child.angular_damp = 0.0
	child.collision_layer = 0
	child.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.10, 0.10, 0.10)
	collision.shape = shape
	child.add_child(collision)
	world.add_child(child)

	var joint := HingeJoint3D.new()
	joint.name = "%sHinge" % cell_id
	joint.position = pivot
	joint.basis = Basis(Vector3.DOWN, Vector3.RIGHT, Vector3.BACK)
	joint.set_param(
		HingeJoint3D.PARAM_LIMIT_LOWER,
		float(spec["lower_limit_rad"]),
	)
	joint.set_param(
		HingeJoint3D.PARAM_LIMIT_UPPER,
		float(spec["upper_limit_rad"]),
	)
	joint.set_flag(
		HingeJoint3D.FLAG_USE_LIMIT,
		bool(spec["joint_limits_enabled"]),
	)
	joint.set_param(
		HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,
		-float(spec["canonical_target_velocity_rad_s"]),
	)
	joint.set_param(
		HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE,
		float(spec["public_maximum_motor_impulse_nms"]),
	)
	joint.set_flag(
		HingeJoint3D.FLAG_ENABLE_MOTOR,
		bool(spec["motor_enabled"]),
	)
	world.add_child(joint)
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)

	spec["parent"] = parent
	spec["child"] = child
	spec["joint"] = joint
	spec["pre_tree_read_refused"] = false
	return spec


static func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
