extends RefCounted

## Godot/Jolt host implementation of the R23D7 morphology-neutral stance.
## It observes the eight portable joint coordinates, evaluates the frozen
## engine-neutral bounded-PD equation, maps canonical velocity through the
## characterized Godot/Jolt -1 host sign, and writes only hinge motor targets.

const POLICY_ID := "sporespore_morphology_neutral_stance_bounded_pd_v1"
const RECEIPT_SCHEMA := "sporespore_morphology_neutral_stance_bounded_pd_receipt_v1"
const TARGET_POSITION_RAD := 0.0
const POSITION_GAIN_PER_S := 8.0
const RATE_DAMPING := 0.65
const MAXIMUM_JOINT_SPEED_RAD_S := 0.35
const GODOT_HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE := -1.0
const ACTUATOR_COUNT := 8
const TOLERANCE := 1.0e-12

var _activated := false


func reset() -> void:
	_activated = false


func compose_and_apply(
	step_result: Dictionary,
	compiled_morphology: Dictionary,
	_limbs: Array,
	_contacts_by_limb: Dictionary,
	joint_state_by_joint_id: Dictionary,
) -> Dictionary:
	var morphology: Dictionary = compiled_morphology.get("morphology", compiled_morphology)
	var measurements := {}
	for actuator_value in (morphology.get("morphology_spec", {}) as Dictionary).get(
		"actuators", []
	):
		var actuator: Dictionary = actuator_value
		var joint_id := String(actuator.get("joint_id", ""))
		var legacy_joint_id := _legacy_joint_id(joint_id)
		if legacy_joint_id.is_empty() or not joint_state_by_joint_id.has(legacy_joint_id):
			return _failure("R23D7_GJT_NEUTRAL_LIVE_JOINT:%s" % joint_id)
		var state: Dictionary = joint_state_by_joint_id[legacy_joint_id]
		measurements[joint_id] = {
			"position_rad": _joint_angle_rad(state),
			"velocity_rad_s": _joint_rate_rad_s(state),
			"legacy_joint_id": legacy_joint_id,
		}
	var native_output: Dictionary = step_result.get("native_output", {})
	var composition := compose(
		int(step_result.get("semantic_step", -1)),
		compiled_morphology,
		native_output.get("actuation", {}),
		measurements,
		not _activated,
	)
	if not bool(composition.get("ok", false)):
		return composition
	var pending: Array[Dictionary] = []
	for command_value in composition.get("ordered_host_commands", []):
		var command: Dictionary = command_value
		var legacy_joint_id := String(command.get("legacy_joint_id", ""))
		var state: Dictionary = joint_state_by_joint_id.get(legacy_joint_id, {})
		var joint: HingeJoint3D = state.get("joint")
		if joint == null:
			return _failure("R23D7_GJT_NEUTRAL_HINGE_MISSING:%s" % legacy_joint_id)
		pending.append(
			{
				"joint": joint,
				"target_velocity_rad_s": float(command["host_target_velocity_rad_s"]),
			}
		)
	for application in pending:
		var joint: HingeJoint3D = application["joint"]
		joint.set_param(
			HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,
			float(application["target_velocity_rad_s"]),
		)
	_activated = true
	composition["applied_command_count"] = pending.size()
	composition["actuation_authority"] = true
	return composition


static func compose(
	semantic_step: int,
	compiled_morphology: Dictionary,
	base_actuation: Dictionary,
	joint_measurements_by_id: Dictionary,
	first_activation: bool,
) -> Dictionary:
	var morphology: Dictionary = compiled_morphology.get("morphology", compiled_morphology)
	var morphology_spec: Dictionary = morphology.get("morphology_spec", {})
	var ordered_actuator_ids: Array = morphology.get("ordered_actuator_ids", [])
	var base_commands: Array = base_actuation.get("ordered_commands", [])
	var actuators: Array = morphology_spec.get("actuators", [])
	if (
		semantic_step < 0
		or bool(base_actuation.get("safe_no_actuation", true))
		or ordered_actuator_ids.size() != ACTUATOR_COUNT
		or base_commands.size() != ACTUATOR_COUNT
		or actuators.size() != ACTUATOR_COUNT
	):
		return _failure("R23D7_GJT_NEUTRAL_INPUT_CARDINALITY")
	var ordered_solutions: Array[Dictionary] = []
	var ordered_host_commands: Array[Dictionary] = []
	var maximum_speed := 0.0
	var maximum_position_error := 0.0
	for index in range(ACTUATOR_COUNT):
		var actuator: Dictionary = actuators[index]
		var command: Dictionary = base_commands[index]
		var actuator_id := String(ordered_actuator_ids[index])
		var joint_id := String(actuator.get("joint_id", ""))
		if (
			String(actuator.get("actuator_id", "")) != actuator_id
			or String(command.get("actuator_id", "")) != actuator_id
			or not joint_measurements_by_id.has(joint_id)
			or float(actuator.get("minimum_target_position_rad", INF)) > TARGET_POSITION_RAD
			or float(actuator.get("maximum_target_position_rad", -INF)) < TARGET_POSITION_RAD
		):
			return _failure("R23D7_GJT_NEUTRAL_ACTUATOR_IDENTITY:%s" % actuator_id)
		var measurement: Dictionary = joint_measurements_by_id[joint_id]
		var measured_position := float(measurement.get("position_rad", NAN))
		var measured_velocity := float(measurement.get("velocity_rad_s", NAN))
		var equation := bounded_neutral_velocity(measured_position, measured_velocity)
		if not bool(equation.get("ok", false)):
			return equation
		var desired_canonical := float(equation["bounded_velocity_rad_s"])
		var host_target := GODOT_HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE * desired_canonical
		maximum_speed = maxf(maximum_speed, absf(desired_canonical))
		maximum_position_error = maxf(
			maximum_position_error,
			absf(float(equation["position_error_rad"])),
		)
		ordered_solutions.append(
			{
				"actuator_id": actuator_id,
				"joint_id": joint_id,
				"minimum_target_position_rad": float(
					actuator["minimum_target_position_rad"]
				),
				"maximum_target_position_rad": float(
					actuator["maximum_target_position_rad"]
				),
				"target_position_rad": TARGET_POSITION_RAD,
				"measured_position_rad": measured_position,
				"measured_velocity_rad_s": measured_velocity,
				"position_error_rad": float(equation["position_error_rad"]),
				"unbounded_velocity_rad_s": float(equation["unbounded_velocity_rad_s"]),
				"bounded_velocity_rad_s": desired_canonical,
				"desired_joint_velocity_rad_s": desired_canonical,
				"host_target_velocity_rad_s": host_target,
				"native_target_position_rad": null,
				"neutral_target_activated": true,
				"pose_capture_activated": first_activation,
			}
		)
		ordered_host_commands.append(
			{
				"actuator_id": actuator_id,
				"joint_id": joint_id,
				"legacy_joint_id": String(measurement.get("legacy_joint_id", joint_id)),
				"host_target_velocity_rad_s": host_target,
				"native_target_position_rad": null,
			}
		)
	var receipt := {
		"schema_version": RECEIPT_SCHEMA,
		"semantic_step": semantic_step,
		"policy_id": POLICY_ID,
		"target_source": "morphology_joint_coordinate_neutral_zero_v1",
		"position_gain_per_s": POSITION_GAIN_PER_S,
		"measured_rate_damping": RATE_DAMPING,
		"maximum_absolute_joint_velocity_rad_s": MAXIMUM_JOINT_SPEED_RAD_S,
		"neutral_target_activation_count": ACTUATOR_COUNT,
		"atomic_activation_transition": first_activation,
		"ordered_actuator_ids": ordered_actuator_ids.duplicate(),
		"ordered_actuator_solutions": ordered_solutions,
		"physics_state_modified": false,
		"command_not_measurement": true,
		"physical_acceptance_authority": false,
	}
	# compose() is deliberately stateless so it can be exercised independently.
	# Model an already-completed atomic activation when validating later stance
	# ticks; the live runner performs a second validation against its persistent
	# memory and therefore still proves the real first/later transition sequence.
	var composition_validation_memory := {}
	if not first_activation:
		for actuator_id in ordered_actuator_ids:
			composition_validation_memory[String(actuator_id)] = TARGET_POSITION_RAD
	var validation := validate_receipt(
		receipt,
		semantic_step,
		composition_validation_memory,
	)
	if not bool(validation.get("ok", false)):
		return validation
	return {
		"ok": true,
		"failure_code": "",
		"semantic_step": semantic_step,
		"ordered_host_commands": ordered_host_commands,
		"maximum_absolute_joint_velocity_rad_s": maximum_speed,
		"maximum_absolute_joint_position_error_rad": maximum_position_error,
		"neutral_target_activation_count": ACTUATOR_COUNT,
		"receipt": receipt,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func bounded_neutral_velocity(
	measured_position_rad: float,
	measured_velocity_rad_s: float,
) -> Dictionary:
	if not is_finite(measured_position_rad) or not is_finite(measured_velocity_rad_s):
		return _failure("R23D7_GJT_NEUTRAL_NONFINITE")
	var position_error := TARGET_POSITION_RAD - measured_position_rad
	var unbounded := (
		POSITION_GAIN_PER_S * position_error - RATE_DAMPING * measured_velocity_rad_s
	)
	return {
		"ok": true,
		"failure_code": "",
		"position_error_rad": position_error,
		"unbounded_velocity_rad_s": unbounded,
		"bounded_velocity_rad_s": clampf(
			unbounded, -MAXIMUM_JOINT_SPEED_RAD_S, MAXIMUM_JOINT_SPEED_RAD_S
		),
	}


static func validate_receipt(
	receipt: Dictionary,
	expected_semantic_step: int,
	independent_memory: Dictionary,
) -> Dictionary:
	var solutions: Array = receipt.get("ordered_actuator_solutions", [])
	var expected_actuator_ids: Array = receipt.get("ordered_actuator_ids", [])
	if (
		String(receipt.get("schema_version", "")) != RECEIPT_SCHEMA
		or String(receipt.get("policy_id", "")) != POLICY_ID
		or String(receipt.get("target_source", ""))
		!= "morphology_joint_coordinate_neutral_zero_v1"
		or int(receipt.get("semantic_step", -1)) != expected_semantic_step
		or float(receipt.get("position_gain_per_s", NAN)) != POSITION_GAIN_PER_S
		or float(receipt.get("measured_rate_damping", NAN)) != RATE_DAMPING
		or float(receipt.get("maximum_absolute_joint_velocity_rad_s", NAN))
		!= MAXIMUM_JOINT_SPEED_RAD_S
		or int(receipt.get("neutral_target_activation_count", -1)) != ACTUATOR_COUNT
		or solutions.size() != ACTUATOR_COUNT
		or expected_actuator_ids.size() != ACTUATOR_COUNT
		or bool(receipt.get("physics_state_modified", true))
		or not bool(receipt.get("command_not_measurement", false))
		or bool(receipt.get("physical_acceptance_authority", true))
	):
		return _failure("R23D7_GJT_NEUTRAL_RECEIPT_IDENTITY")
	var first_activation := independent_memory.is_empty()
	if bool(receipt.get("atomic_activation_transition", false)) != first_activation:
		return _failure("R23D7_GJT_NEUTRAL_ATOMIC_TRANSITION")
	var transition_count := 0
	var seen := {}
	for solution_index in range(solutions.size()):
		var solution_value: Variant = solutions[solution_index]
		var solution: Dictionary = solution_value
		var actuator_id := String(solution.get("actuator_id", ""))
		if (
			actuator_id.is_empty()
			or seen.has(actuator_id)
			or actuator_id != String(expected_actuator_ids[solution_index])
		):
			return _failure("R23D7_GJT_NEUTRAL_ACTUATOR_ORDER")
		seen[actuator_id] = true
		var position := float(solution.get("measured_position_rad", NAN))
		var velocity := float(solution.get("measured_velocity_rad_s", NAN))
		var expected := bounded_neutral_velocity(position, velocity)
		if not bool(expected.get("ok", false)):
			return expected
		for field in [
			"position_error_rad",
			"unbounded_velocity_rad_s",
			"bounded_velocity_rad_s",
		]:
			if (
				not is_finite(float(solution.get(field, NAN)))
				or absf(float(solution[field]) - float(expected[field])) > TOLERANCE
			):
				return _failure("R23D7_GJT_NEUTRAL_EQUATION:%s:%s" % [actuator_id, field])
		var desired := float(solution.get("bounded_velocity_rad_s", NAN))
		if (
			float(solution.get("target_position_rad", NAN)) != TARGET_POSITION_RAD
			or not bool(solution.get("neutral_target_activated", false))
			or float(solution.get("desired_joint_velocity_rad_s", NAN)) != desired
			or float(solution.get("host_target_velocity_rad_s", NAN))
			!= GODOT_HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE * desired
			or solution.get("native_target_position_rad", 0.0) != null
			or bool(solution.get("pose_capture_activated", false)) != first_activation
		):
			return _failure("R23D7_GJT_NEUTRAL_SOLUTION:%s" % actuator_id)
		if first_activation:
			independent_memory[actuator_id] = TARGET_POSITION_RAD
			transition_count += 1
		elif not independent_memory.has(actuator_id):
			return _failure("R23D7_GJT_NEUTRAL_MEMORY:%s" % actuator_id)
	return {
		"ok": true,
		"failure_code": "",
		"neutral_target_transition_count": transition_count,
		"pose_capture_transition_count": transition_count,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func run_zero_world_preflight() -> Dictionary:
	var canaries := [
		[0.05, 0.0, -0.4, -0.35],
		[-0.02, 0.1, 0.095, 0.095],
		[0.0, -0.2, 0.13, 0.13],
		[0.01, 0.5, -0.405, -0.35],
		[-0.04, -0.1, 0.385, 0.35],
	]
	for canary in canaries:
		var result := bounded_neutral_velocity(float(canary[0]), float(canary[1]))
		if (
			not bool(result.get("ok", false))
			or absf(float(result["unbounded_velocity_rad_s"]) - float(canary[2])) > TOLERANCE
			or absf(float(result["bounded_velocity_rad_s"]) - float(canary[3])) > TOLERANCE
		):
			return _failure("R23D7_GJT_NEUTRAL_CANARY")
	var fixture := _synthetic_fixture(canaries)
	var composed := compose(2992, fixture["morphology"], fixture["actuation"], fixture["measurements"], true)
	if not bool(composed.get("ok", false)):
		return composed
	var mutation_rejection_count := 0
	for mutation_index in range(10):
		var receipt: Dictionary = (composed["receipt"] as Dictionary).duplicate(true)
		var solutions: Array = receipt["ordered_actuator_solutions"]
		match mutation_index:
			0: solutions[0]["position_error_rad"] = -float(solutions[0]["position_error_rad"])
			1: solutions[1]["unbounded_velocity_rad_s"] = POSITION_GAIN_PER_S * float(solutions[1]["position_error_rad"])
			2: solutions[1]["unbounded_velocity_rad_s"] = POSITION_GAIN_PER_S * float(solutions[1]["position_error_rad"]) + RATE_DAMPING * float(solutions[1]["measured_velocity_rad_s"])
			3: solutions[0]["target_position_rad"] = solutions[0]["measured_position_rad"]
			4: solutions[0]["target_position_rad"] = 0.1
			5: solutions[0]["bounded_velocity_rad_s"] = solutions[0]["unbounded_velocity_rad_s"]
			6: solutions.resize(2)
			7: solutions.pop_back()
			8:
				var temporary: Variant = solutions[0]
				solutions[0] = solutions[1]
				solutions[1] = temporary
			9: solutions[0]["target_position_rad"] = 0.01
		if not bool(validate_receipt(receipt, 2992, {}).get("ok", false)):
			mutation_rejection_count += 1
	if mutation_rejection_count != 10:
		return _failure("R23D7_GJT_NEUTRAL_MUTATION_ACCEPTED")
	return {
		"schema_version": "sporespore_qsdk_r23d7_neutral_stance_godot_preflight_v1",
		"ok": true,
		"failure_code": "",
		"policy_id": POLICY_ID,
		"algebra_canary_count": 5,
		"mutation_control_count": 10,
		"all_mutation_controls_rejected": true,
		"real_shaped_actuator_count": ACTUATOR_COUNT,
		"canonical_command_count": ACTUATOR_COUNT,
		"host_command_count": ACTUATOR_COUNT,
		"world_build_count": 0,
		"model_construction_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _synthetic_fixture(canaries: Array) -> Dictionary:
	var ordered_actuator_ids: Array[String] = []
	var actuators: Array[Dictionary] = []
	var commands: Array[Dictionary] = []
	var measurements := {}
	for limb_id in ["front_left", "front_right", "rear_left", "rear_right"]:
		for suffix in ["hip", "knee"]:
			var joint_id := "%s_%s" % [limb_id, suffix]
			var actuator_id := "%s_motor" % joint_id
			var canary: Array = canaries[ordered_actuator_ids.size() % canaries.size()]
			ordered_actuator_ids.append(actuator_id)
			actuators.append({"actuator_id": actuator_id, "joint_id": joint_id, "minimum_target_position_rad": -1.5, "maximum_target_position_rad": 1.5})
			commands.append({"actuator_id": actuator_id, "target_velocity_rad_s": 0.0})
			measurements[joint_id] = {"position_rad": float(canary[0]), "velocity_rad_s": float(canary[1]), "legacy_joint_id": joint_id}
	return {
		"morphology": {"morphology": {"ordered_actuator_ids": ordered_actuator_ids, "morphology_spec": {"actuators": actuators}}},
		"actuation": {"safe_no_actuation": false, "ordered_commands": commands},
		"measurements": measurements,
	}


static func _legacy_joint_id(joint_id: String) -> String:
	if joint_id.ends_with("_hip"):
		return "%s.hip_pitch" % joint_id.trim_suffix("_hip")
	if joint_id.ends_with("_knee"):
		return "%s.knee_pitch" % joint_id.trim_suffix("_knee")
	return ""


static func _joint_angle_rad(state: Dictionary) -> float:
	var parent: RigidBody3D = state["parent"]
	var child: RigidBody3D = state["child"]
	var rest_relative: Basis = state["rest_relative_basis"]
	var current_relative := (parent.global_basis.inverse() * child.global_basis).orthonormalized()
	var delta := (current_relative * rest_relative.inverse()).orthonormalized()
	var rotation := delta.get_rotation_quaternion()
	var angle_rad := rotation.get_angle()
	if angle_rad <= 1.0e-9:
		return 0.0
	return angle_rad * signf(rotation.get_axis().dot(state["axis_parent_local"]))


static func _joint_rate_rad_s(state: Dictionary) -> float:
	var parent: RigidBody3D = state["parent"]
	var child: RigidBody3D = state["child"]
	var axis := (parent.global_basis * (state["axis_parent_local"] as Vector3)).normalized()
	return (child.angular_velocity - parent.angular_velocity).dot(axis)


static func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"applied_command_count": 0,
		"world_build_count": 0,
		"model_construction_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
