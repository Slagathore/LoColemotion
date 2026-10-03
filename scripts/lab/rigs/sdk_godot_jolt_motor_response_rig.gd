class_name LabSdkGodotJoltMotorResponseRig
extends RefCounted

## Prospective P5I.2 isolated one-hinge Godot/Jolt response fixture.
##
## Every stimulus cell owns a frozen parent, one dynamic child, and one
## center-of-mass hinge. Cells have no gravity, damping, collision, contact,
## gait, or shared body. The only post-activation write is the documented
## HingeJoint3D motor target velocity.

const FIXTURE_ID := "SDK.P5I.2.godot_jolt_isolated_hinge_response.v1"
const CHILD_MASS_KG := 1.0
const CHILD_INERTIA_KG_M2 := Vector3(0.05, 0.05, 0.05)
const CANONICAL_AXIS_PARENT_LOCAL := Vector3.BACK
const LOCAL_TARGETS_RAD_S := [
	-0.075,
	-0.050,
	-0.025,
	-0.010,
	-0.0025,
	0.0025,
	0.010,
	0.025,
	0.050,
	0.075,
]
const LEGACY_IMPULSE_CAPS_NMS := [0.045, 0.055]
const IMPULSE_CAPS_NMS := [0.00005, 0.0005, 0.005, 0.045, 0.055]
const SATURATION_TARGETS_RAD_S := [-2.0, -1.0, -0.5, -0.25, 0.25, 0.5, 1.0, 2.0]
const LOCAL_HOLD_TICKS := 12
const IMPULSE_HOLD_TICKS := 4
const REVERSAL_HALF_TICKS := 12


static func build(repetition_index: int, requested: Dictionary = {}) -> Dictionary:
	if repetition_index < 1 or repetition_index > 3:
		return _configuration_failure(
			"SDK_MOTOR_RESPONSE_REPETITION_INVALID",
			"/repetition_index",
		)
	if not requested.is_empty():
		return _configuration_failure(
			"SDK_MOTOR_RESPONSE_FIXTURE_IMMUTABLE",
			"/requested",
		)

	var viewport := SubViewport.new()
	viewport.name = "SdkP5I2MotorResponseViewportR%d" % repetition_index
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var world := Node3D.new()
	world.name = "SdkP5I2MotorResponseWorldR%d" % repetition_index
	viewport.add_child(world)

	var cells: Array[Dictionary] = []
	var cell_index := 0
	cells.append(
		_build_cell(
			world,
			cell_index,
			"zero",
			"zero",
			0.0,
			0.055,
			LOCAL_HOLD_TICKS,
		)
	)
	cell_index += 1
	for impulse_cap_value in LEGACY_IMPULSE_CAPS_NMS:
		var impulse_cap := float(impulse_cap_value)
		for target_value in LOCAL_TARGETS_RAD_S:
			var target := float(target_value)
			cells.append(
				_build_cell(
					world,
					cell_index,
					"local",
					"local_%s_cap_%s" % [_number_id(target), _number_id(impulse_cap)],
					target,
					impulse_cap,
					LOCAL_HOLD_TICKS,
				)
			)
			cell_index += 1
	for impulse_target in [-1.0, 1.0]:
		for impulse_cap_value in IMPULSE_CAPS_NMS:
			var impulse_cap := float(impulse_cap_value)
			cells.append(
				_build_cell(
					world,
					cell_index,
					"impulse",
					"impulse_%s_cap_%s"
					% [_number_id(float(impulse_target)), _number_id(impulse_cap)],
					float(impulse_target),
					impulse_cap,
					IMPULSE_HOLD_TICKS,
				)
			)
			cell_index += 1
	for saturation_target_value in SATURATION_TARGETS_RAD_S:
		var saturation_target := float(saturation_target_value)
		cells.append(
			_build_cell(
				world,
				cell_index,
				"saturation",
				"saturation_%s" % _number_id(saturation_target),
				saturation_target,
				0.0005,
				1,
			)
		)
		cell_index += 1
	for impulse_cap_value in LEGACY_IMPULSE_CAPS_NMS:
		var impulse_cap := float(impulse_cap_value)
		for first_sign in [-1.0, 1.0]:
			var first_target := 0.075 * float(first_sign)
			cells.append(
				_build_cell(
					world,
					cell_index,
					"reversal",
					"reversal_%s_cap_%s"
					% [_number_id(first_target), _number_id(impulse_cap)],
					first_target,
					impulse_cap,
					2 * REVERSAL_HALF_TICKS,
					-first_target,
					REVERSAL_HALF_TICKS + 1,
				)
			)
			cell_index += 1

	return {
		"ok": true,
		"configuration_valid": true,
		"fixture_id": FIXTURE_ID,
		"repetition_index": repetition_index,
		"viewport": viewport,
		"world": world,
		"cells": cells,
		"fixture_contract":
		{
			"child_mass_kg": CHILD_MASS_KG,
			"child_inertia_kg_m2": _vector(CHILD_INERTIA_KG_M2),
			"canonical_axis_parent_local": _vector(CANONICAL_AXIS_PARENT_LOCAL),
			"cell_count": cells.size(),
			"gravity_scale": 0.0,
			"linear_damp": 0.0,
			"angular_damp": 0.0,
			"collision_layer": 0,
			"collision_mask": 0,
			"joint_limits_enabled": false,
			"joint_motor_enabled": true,
			"joint_at_child_center_of_mass": true,
			"post_activation_transform_or_velocity_writes": 0,
			"direct_force_torque_or_impulse_writes": 0,
		},
		"world_build_count": 1,
	}


static func activate(cell: Dictionary) -> void:
	var child: RigidBody3D = cell["child"]
	child.freeze = false
	child.sleeping = false
	cell["activated"] = true


static func set_canonical_target(cell: Dictionary, canonical_target_rad_s: float) -> void:
	var joint: HingeJoint3D = cell["joint"]
	joint.set_param(
		HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,
		-canonical_target_rad_s,
	)
	cell["current_canonical_target_rad_s"] = canonical_target_rad_s
	cell["motor_target_write_count"] = int(cell["motor_target_write_count"]) + 1


static func canonical_rate_rad_s(cell: Dictionary) -> float:
	var parent: RigidBody3D = cell["parent"]
	var child: RigidBody3D = cell["child"]
	var axis_world := (
		parent.global_basis * (cell["axis_parent_local"] as Vector3)
	).normalized()
	return (child.angular_velocity - parent.angular_velocity).dot(axis_world)


static func parameter_round_trip(cell: Dictionary) -> Dictionary:
	var parent: RigidBody3D = cell["parent"]
	var child: RigidBody3D = cell["child"]
	var joint: HingeJoint3D = cell["joint"]
	var geometry := _joint_geometry(cell)
	var requested_impulse := float(cell["maximum_impulse_nms"])
	var realized_impulse := joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE)
	var requested_host_target := -float(cell["current_canonical_target_rad_s"])
	var realized_host_target := joint.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY)
	var impulse_tolerance := 1.0e-9 if requested_impulse < 1.0e-4 else 1.0e-7
	var ok := (
		absf(child.mass - CHILD_MASS_KG) <= 1.0e-7
		and child.inertia.distance_to(CHILD_INERTIA_KG_M2) <= 1.0e-7
		and child.gravity_scale == 0.0
		and child.linear_damp_mode == RigidBody3D.DAMP_MODE_REPLACE
		and child.angular_damp_mode == RigidBody3D.DAMP_MODE_REPLACE
		and absf(child.linear_damp) <= 1.0e-7
		and absf(child.angular_damp) <= 1.0e-7
		and not child.can_sleep
		and child.collision_layer == 0
		and child.collision_mask == 0
		and parent.freeze
		and not joint.get_flag(HingeJoint3D.FLAG_USE_LIMIT)
		and joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
		and float(geometry["anchor_error_m"]) <= 1.0e-7
		and float(geometry["axis_error_rad"]) <= 1.0e-7
		and absf(realized_impulse - requested_impulse) <= impulse_tolerance
		and absf(realized_host_target - requested_host_target) <= 1.0e-7
	)
	return {
		"ok": ok,
		"realized_child_mass_kg": child.mass,
		"realized_child_inertia_kg_m2": _vector(child.inertia),
		"realized_maximum_impulse_nms": realized_impulse,
		"realized_host_target_velocity_rad_s": realized_host_target,
		"anchor_error_m": float(geometry["anchor_error_m"]),
		"axis_error_rad": float(geometry["axis_error_rad"]),
	}


static func _build_cell(
	world: Node3D,
	cell_index: int,
	family: String,
	cell_id: String,
	initial_canonical_target_rad_s: float,
	maximum_impulse_nms: float,
	duration_ticks: int,
	reversal_canonical_target_rad_s: Variant = null,
	reversal_start_tick: int = -1,
) -> Dictionary:
	var column := cell_index % 11
	var row := cell_index / 11
	var pivot := Vector3(float(column) * 2.0, 2.0 + float(row) * 2.0, 0.0)
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
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, false)
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, maximum_impulse_nms)
	world.add_child(joint)
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)

	return {
		"cell_id": cell_id,
		"family": family,
		"parent": parent,
		"child": child,
		"joint": joint,
		"axis_parent_local": CANONICAL_AXIS_PARENT_LOCAL,
		"initial_canonical_target_rad_s": initial_canonical_target_rad_s,
		"current_canonical_target_rad_s": 0.0,
		"maximum_impulse_nms": maximum_impulse_nms,
		"duration_ticks": duration_ticks,
		"reversal_canonical_target_rad_s": reversal_canonical_target_rad_s,
		"reversal_start_tick": reversal_start_tick,
		"activated": false,
		"motor_target_write_count": 0,
	}


static func _joint_geometry(cell: Dictionary) -> Dictionary:
	var parent: RigidBody3D = cell["parent"]
	var child: RigidBody3D = cell["child"]
	var joint: HingeJoint3D = cell["joint"]
	var parent_axis := (
		parent.global_basis * (cell["axis_parent_local"] as Vector3)
	).normalized()
	var joint_axis := (joint.global_basis * Vector3.BACK).normalized()
	return {
		"anchor_error_m": parent.global_position.distance_to(child.global_position),
		"axis_error_rad": acos(clampf(absf(parent_axis.dot(joint_axis)), 0.0, 1.0)),
	}


static func _configuration_failure(code: String, path: String) -> Dictionary:
	return {
		"ok": false,
		"configuration_valid": false,
		"fixture_id": FIXTURE_ID,
		"configuration_errors":
		[
			{
				"code": code,
				"path": path,
				"message": "The P5I.2 fixture is immutable",
			}
		],
		"world_build_count": 0,
	}


static func _number_id(value: float) -> String:
	var prefix := "n" if value < 0.0 else "p"
	return "%s%d" % [prefix, int(round(absf(value) * 100000.0))]


static func _vector(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}
