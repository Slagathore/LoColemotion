class_name R24D158GodotJoltRotationIntegrationEnergyRig
extends RefCounted

## Minimal native observation fixture for the v6 rotation-integration channel.
## One anisotropic dynamic box is pinned at its center to a static parent, so a
## constrained island exists while off-principal-axis rotation remains free.

const FIXTURE_ID := "QSDK.R24D158.godot_jolt.rotation_integration_energy.v1"
const CHILD_MASS_KG := 1.0
const CHILD_INERTIA_DIAGONAL_KG_M2 := Vector3(0.031, 0.047, 0.083)
const INITIAL_ANGULAR_VELOCITY_WORLD_RAD_S := Vector3(1.25, -0.75, 2.0)
const MAXIMUM_OUTER_SOLVER_STEPS := 2


static func describe() -> Dictionary:
	return {
		"fixture_id": FIXTURE_ID,
		"world_count": 1,
		"dynamic_body_count": 1,
		"static_parent_count": 1,
		"pin_joint_count": 1,
		"child_mass_kg": CHILD_MASS_KG,
		"child_inertia_diagonal_kg_m2": _vector(CHILD_INERTIA_DIAGONAL_KG_M2),
		"initial_angular_velocity_world_rad_s": _vector(
			INITIAL_ANGULAR_VELOCITY_WORLD_RAD_S
		),
		"off_principal_axis_rotation": true,
		"gravity_scale": 0.0,
		"linear_damping": 0.0,
		"angular_damping": 0.0,
		"collision_layer": 0,
		"collision_mask": 0,
		"maximum_outer_solver_steps": MAXIMUM_OUTER_SOLVER_STEPS,
		"direct_force_write_count": 0,
		"direct_torque_write_count": 0,
		"direct_impulse_write_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
	}


static func build() -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "QsdkR24D158RotationIntegrationEnergyViewport"
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	var world := Node3D.new()
	world.name = "QsdkR24D158RotationIntegrationEnergyWorld"
	viewport.add_child(world)

	var pivot := Vector3(0.0, 2.0, 0.0)
	var parent := RigidBody3D.new()
	parent.name = "RotationParent"
	parent.position = pivot
	parent.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	parent.freeze = true
	parent.can_sleep = false
	parent.gravity_scale = 0.0
	parent.collision_layer = 0
	parent.collision_mask = 0
	world.add_child(parent)

	var child := RigidBody3D.new()
	child.name = "RotationChild"
	child.position = pivot
	child.mass = CHILD_MASS_KG
	child.inertia = CHILD_INERTIA_DIAGONAL_KG_M2
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
	shape.size = Vector3(0.20, 0.30, 0.40)
	collision.shape = shape
	child.add_child(collision)
	world.add_child(child)

	var joint := PinJoint3D.new()
	joint.name = "RotationPin"
	joint.position = pivot
	world.add_child(joint)
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)

	return {
		"ok": true,
		"viewport": viewport,
		"world": world,
		"parent": parent,
		"child": child,
		"joint": joint,
		"model_construction_count": 1,
		"world_attempt_count": 1,
		"world_build_count": 1,
	}


static func activate(rig: Dictionary) -> void:
	var child: RigidBody3D = rig["child"]
	child.freeze = false
	child.can_sleep = false
	child.angular_velocity = INITIAL_ANGULAR_VELOCITY_WORLD_RAD_S
	child.sleeping = false


static func parameter_readback(rig: Dictionary) -> Dictionary:
	var child: RigidBody3D = rig["child"]
	return {
		"child_mass_kg": child.mass,
		"child_inertia_diagonal_kg_m2": _vector(child.inertia),
		"initial_angular_velocity_world_rad_s": _vector(child.angular_velocity),
		"gravity_scale": child.gravity_scale,
		"linear_damping": child.linear_damp,
		"angular_damping": child.angular_damp,
		"can_sleep": child.can_sleep,
	}


static func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
