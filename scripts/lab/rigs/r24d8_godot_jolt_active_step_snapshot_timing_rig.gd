class_name R24D8GodotJoltActiveStepSnapshotTimingRig
extends RefCounted

## Prospectively frozen QSDK-R24D8 timing-control fixture.
##
## The fixture contains one static parent, one spherical-inertia child, and one
## center-of-mass hinge. It deliberately makes no numerical impulse/work claim:
## four awake solver steps test fresh native snapshot tokens, then one declared
## sleep input and four further space steps test preservation of a stale token.

const FIXTURE_ID := "QSDK.R24D8.godot_jolt_active_step_snapshot_timing.v1"
const CHILD_MASS_KG := 1.0
const CHILD_INERTIA_KG_M2 := Vector3(0.05, 0.05, 0.05)
const CANONICAL_AXIS_PARENT_LOCAL := Vector3.BACK
const PUBLIC_MAXIMUM_MOTOR_IMPULSE_NMS := 0.002
const CANONICAL_TARGET_VELOCITY_RAD_S := 0.0
const FRESH_ACTIVE_SAMPLE_COUNT := 4
const SLEEPING_STALE_SAMPLE_COUNT := 4
const MAXIMUM_PHYSICS_STEP_COUNT := 8


static func describe() -> Dictionary:
	return {
		"fixture_id": FIXTURE_ID,
		"world_count": 1,
		"isolated_hinge_count": 1,
		"dynamic_body_count": 1,
		"static_parent_count": 1,
		"child_mass_kg": CHILD_MASS_KG,
		"child_inertia_diagonal_kg_m2": _vector(CHILD_INERTIA_KG_M2),
		"hinge_axis_parent_local": _vector(CANONICAL_AXIS_PARENT_LOCAL),
		"motor_enabled": true,
		"canonical_target_velocity_rad_s": CANONICAL_TARGET_VELOCITY_RAD_S,
		"public_maximum_motor_impulse_nms": PUBLIC_MAXIMUM_MOTOR_IMPULSE_NMS,
		"joint_limits_enabled": false,
		"fresh_active_sample_count": FRESH_ACTIVE_SAMPLE_COUNT,
		"sleeping_stale_sample_count": SLEEPING_STALE_SAMPLE_COUNT,
		"maximum_physics_step_count": MAXIMUM_PHYSICS_STEP_COUNT,
		"retained_sample_count": (
			FRESH_ACTIVE_SAMPLE_COUNT + SLEEPING_STALE_SAMPLE_COUNT
		),
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


static func build() -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "QsdkR24D8ActiveStepSnapshotTimingViewport"
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	var world := Node3D.new()
	world.name = "QsdkR24D8ActiveStepSnapshotTimingWorld"
	viewport.add_child(world)

	var pivot := Vector3(0.0, 2.0, 0.0)
	var parent := RigidBody3D.new()
	parent.name = "TimingParent"
	parent.position = pivot
	parent.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	parent.freeze = true
	parent.can_sleep = false
	parent.gravity_scale = 0.0
	parent.collision_layer = 0
	parent.collision_mask = 0
	world.add_child(parent)

	var child := RigidBody3D.new()
	child.name = "TimingChild"
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
	joint.name = "TimingHinge"
	joint.position = pivot
	joint.basis = Basis(Vector3.DOWN, Vector3.RIGHT, Vector3.BACK)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -1.0)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, 1.0)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	joint.set_param(
		HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,
		-CANONICAL_TARGET_VELOCITY_RAD_S,
	)
	joint.set_param(
		HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE,
		PUBLIC_MAXIMUM_MOTOR_IMPULSE_NMS,
	)
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	world.add_child(joint)
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)

	var pre_tree_value: Variant = (
		JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(joint.get_rid())
	)
	return {
		"ok": true,
		"viewport": viewport,
		"world": world,
		"parent": parent,
		"child": child,
		"joint": joint,
		"pre_tree_read_refused": pre_tree_value == null,
		"world_attempt_count": 1,
		"world_build_count": 1,
	}


static func activate(rig: Dictionary) -> void:
	var child: RigidBody3D = rig["child"]
	child.freeze = false
	child.can_sleep = false
	child.angular_velocity = Vector3.ZERO
	child.sleeping = false


static func force_declared_sleep(rig: Dictionary) -> void:
	var child: RigidBody3D = rig["child"]
	child.can_sleep = true
	child.sleeping = true


static func parameter_readback(rig: Dictionary) -> Dictionary:
	var child: RigidBody3D = rig["child"]
	var joint: HingeJoint3D = rig["joint"]
	return {
		"child_mass_kg": child.mass,
		"child_inertia_diagonal_kg_m2": _vector(child.inertia),
		"host_target_velocity_readback_rad_s": joint.get_param(
			HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY
		),
		"public_maximum_motor_impulse_readback_nms": joint.get_param(
			HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE
		),
		"motor_enabled_readback": joint.get_flag(
			HingeJoint3D.FLAG_ENABLE_MOTOR
		),
		"joint_limits_enabled_readback": joint.get_flag(
			HingeJoint3D.FLAG_USE_LIMIT
		),
	}


static func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
