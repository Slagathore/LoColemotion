extends RefCounted

## Engine-local host implementation of the portable R23D4 terminal contact
## acquisition and captured-pose hold policy. The policy only writes hinge
## motor target velocities; it never writes body transforms, velocities, or
## impulses.

const POLICY_ID := (
	"sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_v1"
)
const RECEIPT_SCHEMA := (
	"sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_receipt_v1"
)
const DOWNWARD_SPEED_M_S := 0.02
const DAMPED_LEAST_SQUARES_LAMBDA_M := 0.04
const MAXIMUM_JOINT_SPEED_RAD_S := 0.35
const POSE_HOLD_POSITION_GAIN_PER_S := 8.0
const POSE_HOLD_RATE_DAMPING := 0.65
const MAXIMUM_ABSOLUTE_STEERING_FRACTION := 0.40
const ACTUATOR_COUNT := 8

var _memory := _initial_memory()


func reset() -> void:
	_memory = _initial_memory()


func compose_and_apply(
	step_result: Dictionary,
	compiled_morphology: Dictionary,
	limbs: Array,
	contacts_by_limb: Dictionary,
	joint_state_by_joint_id: Dictionary,
) -> Dictionary:
	var live_inputs := _live_inputs(
		compiled_morphology,
		limbs,
		joint_state_by_joint_id,
	)
	if not bool(live_inputs.get("ok", false)):
		return live_inputs
	var native_output: Dictionary = step_result.get("native_output", {})
	var actuation: Dictionary = native_output.get("actuation", {})
	var composition := compose(
		int(step_result.get("semantic_step", -1)),
		compiled_morphology,
		actuation,
		contacts_by_limb,
		live_inputs["ordered_kinematics"],
		live_inputs["joint_measurements_by_id"],
		_memory,
	)
	if not bool(composition.get("ok", false)):
		return composition
	var pending: Array[Dictionary] = []
	for command_value in composition.get("ordered_host_commands", []):
		var command: Dictionary = command_value
		var joint_id := String(command.get("joint_id", ""))
		if not joint_state_by_joint_id.has(joint_id):
			return _failure("R23D4_GJT_RESTORATION_JOINT_MISSING:%s" % joint_id)
		var state: Dictionary = joint_state_by_joint_id[joint_id]
		var joint: HingeJoint3D = state.get("joint")
		if joint == null:
			return _failure("R23D4_GJT_RESTORATION_HINGE_MISSING:%s" % joint_id)
		pending.append(
			{
				"joint": joint,
				"target_velocity_rad_s":
				float(command["host_target_velocity_rad_s"]),
			}
		)
	for application in pending:
		var joint: HingeJoint3D = application["joint"]
		joint.set_param(
			HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,
			float(application["target_velocity_rad_s"]),
		)
	composition["applied_command_count"] = pending.size()
	composition["actuation_authority"] = true
	return composition


static func compose(
	semantic_step: int,
	compiled_morphology: Dictionary,
	base_actuation: Dictionary,
	contacts_by_limb: Dictionary,
	ordered_kinematics: Array,
	joint_measurements_by_id: Dictionary,
	memory: Dictionary,
) -> Dictionary:
	var morphology: Dictionary = compiled_morphology.get("morphology", compiled_morphology)
	var morphology_spec: Dictionary = morphology.get("morphology_spec", {})
	var ordered_actuator_ids: Array = morphology.get("ordered_actuator_ids", [])
	var base_commands: Array = base_actuation.get("ordered_commands", [])
	if (
		semantic_step < 0
		or bool(base_actuation.get("safe_no_actuation", true))
		or ordered_actuator_ids.size() != ACTUATOR_COUNT
		or base_commands.size() != ACTUATOR_COUNT
		or ordered_kinematics.size() != ACTUATOR_COUNT
	):
		return _failure("R23D4_GJT_RESTORATION_INPUT_CARDINALITY")
	var command_by_actuator := {}
	var kinematics_by_actuator := {}
	for index in range(ACTUATOR_COUNT):
		var expected_id := String(ordered_actuator_ids[index])
		var command: Dictionary = base_commands[index]
		var kinematics: Dictionary = ordered_kinematics[index]
		if (
			String(command.get("actuator_id", "")) != expected_id
			or String(kinematics.get("actuator_id", "")) != expected_id
		):
			return _failure("R23D4_GJT_RESTORATION_ACTUATOR_ORDER")
		command_by_actuator[expected_id] = command
		kinematics_by_actuator[expected_id] = kinematics
	var actuator_by_id := {}
	for actuator_value in morphology_spec.get("actuators", []):
		var actuator: Dictionary = actuator_value
		actuator_by_id[String(actuator.get("actuator_id", ""))] = actuator
	var receipt: Dictionary = base_actuation.get("receipt", {})
	var current_held := float(receipt.get("held_steering_fraction", NAN))
	if (
		not is_finite(current_held)
		or absf(current_held) > MAXIMUM_ABSOLUTE_STEERING_FRACTION
	):
		return _failure("R23D4_GJT_RESTORATION_STEERING_INVALID")
	if memory.get("activation_held_steering_fraction", null) == null:
		memory["activation_held_steering_fraction"] = current_held
	var activation_held := float(memory["activation_held_steering_fraction"])
	var neutral_by_actuator: Dictionary = memory["neutral_joint_position_by_actuator"]
	var desired_by_actuator := {}
	var ordered_limb_solutions: Array[Dictionary] = []
	var maximum_speed := 0.0
	for limb_value in morphology_spec.get("limbs", []):
		var limb: Dictionary = limb_value
		var limb_id := String(limb.get("limb_id", ""))
		var joint_ids: Array = limb.get("ordered_joint_ids", [])
		var contact_ids: Array = limb.get("ordered_contact_site_ids", [])
		if (
			joint_ids.size() != 2
			or contact_ids.size() != 1
			or not contacts_by_limb.has(limb_id)
		):
			return _failure("R23D4_GJT_RESTORATION_LIMB_INPUT:%s" % limb_id)
		var contact := bool(contacts_by_limb[limb_id])
		var limb_kinematics: Array[Dictionary] = []
		var limb_actuator_ids: Array[String] = []
		for actuator_id_value in ordered_actuator_ids:
			var actuator_id := String(actuator_id_value)
			if not actuator_by_id.has(actuator_id):
				return _failure("R23D4_GJT_RESTORATION_ACTUATOR_SPEC:%s" % actuator_id)
			var actuator: Dictionary = actuator_by_id[actuator_id]
			if joint_ids.has(String(actuator.get("joint_id", ""))):
				limb_actuator_ids.append(actuator_id)
				limb_kinematics.append(kinematics_by_actuator[actuator_id])
		if limb_actuator_ids.size() != 2:
			return _failure("R23D4_GJT_RESTORATION_LIMB_ACTUATORS:%s" % limb_id)
		var columns: Array[Vector3] = []
		for kinematics in limb_kinematics:
			var axis := _vector3(kinematics.get("joint_axis_world_unit", {}))
			var anchor := _vector3(kinematics.get("joint_anchor_world_m", {}))
			var endpoint := _vector3(kinematics.get("endpoint_world_m", {}))
			if not axis.is_finite() or not anchor.is_finite() or not endpoint.is_finite():
				return _failure("R23D4_GJT_RESTORATION_KINEMATICS:%s" % limb_id)
			columns.append(axis.cross(endpoint - anchor))
		var missing_solution: Array[float] = []
		if not contact:
			var lambda_squared := (
				DAMPED_LEAST_SQUARES_LAMBDA_M * DAMPED_LEAST_SQUARES_LAMBDA_M
			)
			var desired_foot_velocity := Vector3(0.0, -DOWNWARD_SPEED_M_S, 0.0)
			var a00 := columns[0].dot(columns[0]) + lambda_squared
			var a01 := columns[0].dot(columns[1])
			var a11 := columns[1].dot(columns[1]) + lambda_squared
			var b0 := columns[0].dot(desired_foot_velocity)
			var b1 := columns[1].dot(desired_foot_velocity)
			var determinant := a00 * a11 - a01 * a01
			if not is_finite(determinant) or determinant <= 0.0:
				return _failure("R23D4_GJT_RESTORATION_DLS_SINGULAR:%s" % limb_id)
			missing_solution = [
				(b0 * a11 - a01 * b1) / determinant,
				(a00 * b1 - a01 * b0) / determinant,
			]
		var actuator_solutions: Array[Dictionary] = []
		for index in range(2):
			var actuator_id := limb_actuator_ids[index]
			var actuator: Dictionary = actuator_by_id[actuator_id]
			var joint_id := String(actuator.get("joint_id", ""))
			if not joint_measurements_by_id.has(joint_id):
				return _failure("R23D4_GJT_RESTORATION_MEASUREMENT:%s" % joint_id)
			var measurement: Dictionary = joint_measurements_by_id[joint_id]
			var measured_position := float(measurement.get("position_rad", NAN))
			var measured_velocity := float(measurement.get("velocity_rad_s", NAN))
			if not is_finite(measured_position) or not is_finite(measured_velocity):
				return _failure("R23D4_GJT_RESTORATION_NONFINITE:%s" % joint_id)
			var base_command: Dictionary = command_by_actuator[actuator_id]
			var heading := _portable_heading_delta(
				base_actuation,
				base_command,
				limb_id,
				joint_id,
				activation_held,
			)
			if not bool(heading.get("ok", false)):
				return heading
			var capture_activated := false
			var neutral: Variant = null
			var requested: Variant = null
			var clamped: Variant = null
			var unbounded := 0.0
			var desired := 0.0
			if contact:
				capture_activated = not neutral_by_actuator.has(actuator_id)
				if capture_activated:
					neutral_by_actuator[actuator_id] = (
						measured_position - float(heading["delta_rad"])
					)
				neutral = float(neutral_by_actuator[actuator_id])
				requested = float(neutral) + float(heading["delta_rad"])
				clamped = clampf(
					float(requested),
					float(actuator.get("minimum_target_position_rad", NAN)),
					float(actuator.get("maximum_target_position_rad", NAN)),
				)
				unbounded = (
					POSE_HOLD_POSITION_GAIN_PER_S * (float(clamped) - measured_position)
					- POSE_HOLD_RATE_DAMPING * measured_velocity
				)
				desired = clampf(
					unbounded,
					-MAXIMUM_JOINT_SPEED_RAD_S,
					MAXIMUM_JOINT_SPEED_RAD_S,
				)
			else:
				neutral_by_actuator.erase(actuator_id)
				unbounded = float(missing_solution[index])
				desired = clampf(
					unbounded,
					-MAXIMUM_JOINT_SPEED_RAD_S,
					MAXIMUM_JOINT_SPEED_RAD_S,
				)
			desired_by_actuator[actuator_id] = desired
			maximum_speed = maxf(maximum_speed, absf(desired))
			actuator_solutions.append(
				{
					"actuator_id": actuator_id,
					"joint_id": joint_id,
					"kinematics": limb_kinematics[index].duplicate(true),
					"linear_jacobian_column_world_m": _vector_dictionary(columns[index]),
					"measured_joint_position_rad": measured_position,
					"measured_joint_velocity_rad_s": measured_velocity,
					"pose_capture_activated": capture_activated,
					"neutral_joint_position_rad": neutral,
					"portable_lateral_side_sign": heading["lateral_side_sign"],
					"portable_forward_velocity_hip_target_correction_rad":
					heading["forward_velocity_correction_rad"],
					"portable_nominal_unsteered_hip_target_rad":
					heading["nominal_unsteered_hip_target_rad"],
					"portable_heading_target_delta_rad": float(heading["delta_rad"]),
					"requested_pose_target_position_rad": requested,
					"clamped_pose_target_position_rad": clamped,
					"unbounded_joint_velocity_rad_s": unbounded,
					"desired_joint_velocity_rad_s": desired,
				}
			)
		ordered_limb_solutions.append(
			{
				"limb_id": limb_id,
				"contact_site_id": String(contact_ids[0]),
				"pre_step_contact": contact,
				"desired_foot_velocity_world_m_s":
				_vector_dictionary(Vector3.ZERO if contact else Vector3(0.0, -0.02, 0.0)),
				"ordered_actuator_solutions": actuator_solutions,
			}
		)
	var ordered_host_commands: Array[Dictionary] = []
	for actuator_id_value in ordered_actuator_ids:
		var actuator_id := String(actuator_id_value)
		var joint_id := String((actuator_by_id[actuator_id] as Dictionary)["joint_id"])
		ordered_host_commands.append(
			{
				"actuator_id": actuator_id,
				"joint_id": joint_id,
				"host_target_velocity_rad_s": float(desired_by_actuator[actuator_id]),
				"native_target_position_rad": null,
			}
		)
	return {
		"ok": true,
		"failure_code": "",
		"semantic_step": semantic_step,
		"ordered_host_commands": ordered_host_commands,
		"maximum_absolute_joint_velocity_rad_s": maximum_speed,
		"receipt":
		{
			"schema_version": RECEIPT_SCHEMA,
			"semantic_step": semantic_step,
			"policy_id": POLICY_ID,
			"missing_limb_desired_foot_velocity_world_m_s":
			_vector_dictionary(Vector3(0.0, -DOWNWARD_SPEED_M_S, 0.0)),
			"contacting_limb_target_joint_velocity_mode":
			"captured_pose_proportional_derivative_velocity_v1",
			"pose_hold_position_gain_per_s": POSE_HOLD_POSITION_GAIN_PER_S,
			"pose_hold_rate_damping": POSE_HOLD_RATE_DAMPING,
			"maximum_absolute_pose_hold_joint_velocity_rad_s":
			MAXIMUM_JOINT_SPEED_RAD_S,
			"heading_correction_mode":
			"registered_portable_yaw_only_hip_target_delta_from_activation_v1",
			"activation_held_steering_fraction": activation_held,
			"current_held_steering_fraction": current_held,
			"registered_steering_stride_transform_id": null,
			"damped_least_squares_lambda_m": DAMPED_LEAST_SQUARES_LAMBDA_M,
			"maximum_absolute_search_joint_velocity_rad_s": MAXIMUM_JOINT_SPEED_RAD_S,
			"ordered_limb_solutions": ordered_limb_solutions,
			"pose_memory_actuator_count": neutral_by_actuator.size(),
			"world_build_count": 0,
			"physics_state_modified": false,
			"command_not_measurement": true,
			"physical_acceptance_authority": false,
		},
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func run_zero_world_preflight() -> Dictionary:
	var fixture := _synthetic_fixture()
	var positive := compose(
		2992,
		fixture["morphology"],
		fixture["actuation"],
		fixture["contacts"],
		fixture["kinematics"],
		fixture["measurements"],
		_initial_memory(),
	)
	var positive_validation := validate_receipt(
		positive.get("receipt", {}),
		2992,
		{},
	)
	var controls: Array[bool] = []
	var invalid := fixture.duplicate(true)
	(invalid["actuation"]["ordered_commands"] as Array).pop_back()
	controls.append(
		not bool(
			_compose_fixture(invalid).get("ok", false)
		)
	)
	invalid = fixture.duplicate(true)
	(invalid["kinematics"] as Array).pop_back()
	controls.append(not bool(_compose_fixture(invalid).get("ok", false)))
	invalid = fixture.duplicate(true)
	(invalid["contacts"] as Dictionary).erase("front_left")
	controls.append(not bool(_compose_fixture(invalid).get("ok", false)))
	invalid = fixture.duplicate(true)
	invalid["measurements"]["front_left_hip"]["position_rad"] = NAN
	controls.append(not bool(_compose_fixture(invalid).get("ok", false)))
	invalid = fixture.duplicate(true)
	invalid["actuation"]["receipt"]["held_steering_fraction"] = 0.5
	controls.append(not bool(_compose_fixture(invalid).get("ok", false)))
	var ok := (
		bool(positive.get("ok", false))
		and bool(positive_validation.get("ok", false))
		and int((positive.get("ordered_host_commands", []) as Array).size()) == ACTUATOR_COUNT
		and float(positive.get("maximum_absolute_joint_velocity_rad_s", INF))
		<= MAXIMUM_JOINT_SPEED_RAD_S
		and controls.all(func(value: bool) -> bool: return value)
	)
	return {
		"schema_version": "sporespore_qsdk_r23d4_godot_terminal_restoration_preflight_v1",
		"ok": ok,
		"failure_code": "" if ok else "R23D4_GJT_RESTORATION_PREFLIGHT_INVALID",
		"real_shaped_actuator_count": ACTUATOR_COUNT,
		"negative_control_count": controls.size(),
		"all_negative_controls_rejected": controls.all(func(value: bool) -> bool: return value),
		"maximum_absolute_joint_velocity_rad_s":
		float(positive.get("maximum_absolute_joint_velocity_rad_s", INF)),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func validate_receipt(
	receipt: Dictionary,
	expected_semantic_step: int,
	independent_pose_memory: Dictionary,
) -> Dictionary:
	if (
		String(receipt.get("schema_version", "")) != RECEIPT_SCHEMA
		or int(receipt.get("semantic_step", -1)) != expected_semantic_step
		or String(receipt.get("policy_id", "")) != POLICY_ID
		or float(receipt.get("pose_hold_position_gain_per_s", NAN))
		!= POSE_HOLD_POSITION_GAIN_PER_S
		or float(receipt.get("pose_hold_rate_damping", NAN)) != POSE_HOLD_RATE_DAMPING
		or float(receipt.get("maximum_absolute_pose_hold_joint_velocity_rad_s", NAN))
		!= MAXIMUM_JOINT_SPEED_RAD_S
		or float(receipt.get("damped_least_squares_lambda_m", NAN))
		!= DAMPED_LEAST_SQUARES_LAMBDA_M
		or float(receipt.get("maximum_absolute_search_joint_velocity_rad_s", NAN))
		!= MAXIMUM_JOINT_SPEED_RAD_S
		or String(receipt.get("contacting_limb_target_joint_velocity_mode", ""))
		!= "captured_pose_proportional_derivative_velocity_v1"
		or String(receipt.get("heading_correction_mode", ""))
		!= "registered_portable_yaw_only_hip_target_delta_from_activation_v1"
		or not bool(receipt.get("command_not_measurement", false))
		or bool(receipt.get("physics_state_modified", true))
		or int(receipt.get("world_build_count", -1)) != 0
		or bool(receipt.get("physical_acceptance_authority", true))
	):
		return _failure("R23D4_GJT_RESTORATION_RECEIPT_IDENTITY")
	var missing_velocity := _vector3(
		receipt.get("missing_limb_desired_foot_velocity_world_m_s", {})
	)
	if missing_velocity != Vector3(0.0, -DOWNWARD_SPEED_M_S, 0.0):
		return _failure("R23D4_GJT_RESTORATION_RECEIPT_SEARCH_VELOCITY")
	var limb_solutions: Array = receipt.get("ordered_limb_solutions", [])
	if limb_solutions.size() != 4:
		return _failure("R23D4_GJT_RESTORATION_RECEIPT_LIMB_COUNT")
	var observed_limbs := {}
	var observed_actuators := {}
	var capture_count := 0
	var maximum_speed := 0.0
	for limb_value in limb_solutions:
		var limb: Dictionary = limb_value
		var limb_id := String(limb.get("limb_id", ""))
		if limb_id.is_empty() or observed_limbs.has(limb_id):
			return _failure("R23D4_GJT_RESTORATION_RECEIPT_LIMB_ORDER")
		observed_limbs[limb_id] = true
		var contact := bool(limb.get("pre_step_contact", false))
		var desired_foot_velocity := _vector3(
			limb.get("desired_foot_velocity_world_m_s", {})
		)
		if desired_foot_velocity != (
			Vector3.ZERO if contact else Vector3(0.0, -DOWNWARD_SPEED_M_S, 0.0)
		):
			return _failure("R23D4_GJT_RESTORATION_RECEIPT_LIMB_VELOCITY")
		var actuator_solutions: Array = limb.get("ordered_actuator_solutions", [])
		if actuator_solutions.size() != 2:
			return _failure("R23D4_GJT_RESTORATION_RECEIPT_ACTUATOR_COUNT")
		for solution_value in actuator_solutions:
			var solution: Dictionary = solution_value
			var actuator_id := String(solution.get("actuator_id", ""))
			if actuator_id.is_empty() or observed_actuators.has(actuator_id):
				return _failure("R23D4_GJT_RESTORATION_RECEIPT_ACTUATOR_ORDER")
			observed_actuators[actuator_id] = true
			var desired_speed := float(
				solution.get("desired_joint_velocity_rad_s", NAN)
			)
			if (
				not is_finite(desired_speed)
				or absf(desired_speed) > MAXIMUM_JOINT_SPEED_RAD_S
			):
				return _failure("R23D4_GJT_RESTORATION_RECEIPT_JOINT_SPEED")
			maximum_speed = maxf(maximum_speed, absf(desired_speed))
			var expected_capture := contact and not independent_pose_memory.has(actuator_id)
			if bool(solution.get("pose_capture_activated", false)) != expected_capture:
				return _failure("R23D4_GJT_RESTORATION_RECEIPT_POSE_TRANSITION")
			if contact:
				var neutral := float(solution.get("neutral_joint_position_rad", NAN))
				if not is_finite(neutral):
					return _failure("R23D4_GJT_RESTORATION_RECEIPT_POSE_NONFINITE")
				if expected_capture:
					independent_pose_memory[actuator_id] = neutral
					capture_count += 1
				elif (
					absf(float(independent_pose_memory[actuator_id]) - neutral) > 1.0e-12
				):
					return _failure("R23D4_GJT_RESTORATION_RECEIPT_POSE_DRIFT")
			else:
				if solution.get("neutral_joint_position_rad", null) != null:
					return _failure("R23D4_GJT_RESTORATION_RECEIPT_POSE_WHILE_MISSING")
				independent_pose_memory.erase(actuator_id)
	if observed_actuators.size() != ACTUATOR_COUNT:
		return _failure("R23D4_GJT_RESTORATION_RECEIPT_TOTAL_ACTUATOR_COUNT")
	if int(receipt.get("pose_memory_actuator_count", -1)) != independent_pose_memory.size():
		return _failure("R23D4_GJT_RESTORATION_RECEIPT_MEMORY_COUNT")
	return {
		"ok": true,
		"failure_code": "",
		"pose_capture_transition_count": capture_count,
		"maximum_absolute_joint_velocity_rad_s": maximum_speed,
		"physical_acceptance_authority": false,
	}


static func _compose_fixture(fixture: Dictionary) -> Dictionary:
	return compose(
		2992,
		fixture["morphology"],
		fixture["actuation"],
		fixture["contacts"],
		fixture["kinematics"],
		fixture["measurements"],
		_initial_memory(),
	)


static func _portable_heading_delta(
	base_actuation: Dictionary,
	command: Dictionary,
	limb_id: String,
	joint_id: String,
	activation_held: float,
) -> Dictionary:
	if not joint_id.ends_with("_hip"):
		return {
			"ok": true,
			"delta_rad": 0.0,
			"lateral_side_sign": null,
			"forward_velocity_correction_rad": null,
			"nominal_unsteered_hip_target_rad": null,
		}
	var receipt: Dictionary = base_actuation.get("receipt", {})
	var current_held := float(receipt.get("held_steering_fraction", NAN))
	var forward: Dictionary = receipt.get("forward_velocity_foot_placement", {})
	var correction: Dictionary = {}
	for value in forward.get("ordered_limb_corrections", []):
		var candidate: Dictionary = value
		if String(candidate.get("limb_id", "")) == limb_id:
			if not correction.is_empty():
				return _failure("R23D4_GJT_RESTORATION_FORWARD_DUPLICATE:%s" % limb_id)
			correction = candidate
	if correction.is_empty():
		return _failure("R23D4_GJT_RESTORATION_FORWARD_MISSING:%s" % limb_id)
	var side_sign := 1.0 if limb_id.ends_with("_right") else -1.0
	var denominator := 1.0 + side_sign * current_held
	var applied_correction := float(correction.get("applied_hip_target_correction_rad", NAN))
	var requested := float(command.get("requested_target_position_rad", NAN))
	if (
		not is_finite(denominator)
		or denominator <= 0.0
		or not is_finite(applied_correction)
		or not is_finite(requested)
	):
		return _failure("R23D4_GJT_RESTORATION_HEADING_INPUT:%s" % limb_id)
	var nominal := (requested - applied_correction) / denominator
	var delta := nominal * side_sign * (current_held - activation_held)
	if not is_finite(nominal) or not is_finite(delta):
		return _failure("R23D4_GJT_RESTORATION_HEADING_NONFINITE:%s" % limb_id)
	return {
		"ok": true,
		"delta_rad": delta,
		"lateral_side_sign": side_sign,
		"forward_velocity_correction_rad": applied_correction,
		"nominal_unsteered_hip_target_rad": nominal,
	}


static func _live_inputs(
	compiled_morphology: Dictionary,
	limbs: Array,
	joint_state_by_joint_id: Dictionary,
) -> Dictionary:
	var morphology: Dictionary = compiled_morphology.get("morphology", compiled_morphology)
	var morphology_spec: Dictionary = morphology.get("morphology_spec", {})
	var actuator_by_id := {}
	for actuator_value in morphology_spec.get("actuators", []):
		var actuator: Dictionary = actuator_value
		actuator_by_id[String(actuator.get("actuator_id", ""))] = actuator
	var limb_by_joint_id := {}
	for limb_value in morphology_spec.get("limbs", []):
		var limb: Dictionary = limb_value
		for joint_id_value in limb.get("ordered_joint_ids", []):
			limb_by_joint_id[String(joint_id_value)] = limb
	var live_limb_by_id := {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		live_limb_by_id[String(limb.get("limb_id", ""))] = limb
	var kinematics: Array[Dictionary] = []
	var measurements := {}
	for actuator_id_value in morphology.get("ordered_actuator_ids", []):
		var actuator_id := String(actuator_id_value)
		if not actuator_by_id.has(actuator_id):
			return _failure("R23D4_GJT_RESTORATION_LIVE_ACTUATOR:%s" % actuator_id)
		var actuator: Dictionary = actuator_by_id[actuator_id]
		var joint_id := String(actuator.get("joint_id", ""))
		if not limb_by_joint_id.has(joint_id) or not joint_state_by_joint_id.has(joint_id):
			return _failure("R23D4_GJT_RESTORATION_LIVE_JOINT:%s" % joint_id)
		var limb: Dictionary = limb_by_joint_id[joint_id]
		var limb_id := String(limb.get("limb_id", ""))
		if not live_limb_by_id.has(limb_id):
			return _failure("R23D4_GJT_RESTORATION_LIVE_LIMB:%s" % limb_id)
		var live_limb: Dictionary = live_limb_by_id[limb_id]
		var state: Dictionary = joint_state_by_joint_id[joint_id]
		var parent: RigidBody3D = state["parent"]
		var axis := (
			parent.global_basis * (state["axis_parent_local"] as Vector3)
		).normalized()
		var foot: RigidBody3D = live_limb["foot"]
		kinematics.append(
			{
				"actuator_id": actuator_id,
				"contact_site_id": String((limb["ordered_contact_site_ids"] as Array)[0]),
				"joint_anchor_world_m":
				_vector_dictionary(parent.to_global(state["anchor_parent_local"])),
				"joint_axis_world_unit": _vector_dictionary(axis),
				"endpoint_world_m": _vector_dictionary(foot.global_position),
			}
		)
		measurements[joint_id] = {
			"position_rad": _joint_angle_rad(state),
			"velocity_rad_s": _joint_rate_rad_s(state),
		}
	return {
		"ok": true,
		"failure_code": "",
		"ordered_kinematics": kinematics,
		"joint_measurements_by_id": measurements,
	}


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


static func _initial_memory() -> Dictionary:
	return {
		"activation_held_steering_fraction": null,
		"neutral_joint_position_by_actuator": {},
	}


static func _vector3(value: Variant) -> Vector3:
	if typeof(value) == TYPE_VECTOR3:
		return value
	if typeof(value) != TYPE_DICTIONARY:
		return Vector3(INF, INF, INF)
	var dictionary: Dictionary = value
	return Vector3(
		float(dictionary.get("x", INF)),
		float(dictionary.get("y", INF)),
		float(dictionary.get("z", INF)),
	)


static func _vector_dictionary(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


static func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"applied_command_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _synthetic_fixture() -> Dictionary:
	var limb_ids: Array[String] = ["front_left", "front_right", "rear_left", "rear_right"]
	var ordered_actuator_ids: Array[String] = []
	var actuators: Array[Dictionary] = []
	var limbs: Array[Dictionary] = []
	var commands: Array[Dictionary] = []
	var kinematics: Array[Dictionary] = []
	var measurements := {}
	var corrections: Array[Dictionary] = []
	for limb_index in range(limb_ids.size()):
		var limb_id: String = limb_ids[limb_index]
		var joint_ids: Array[String] = ["%s_hip" % limb_id, "%s_knee" % limb_id]
		limbs.append(
			{
				"limb_id": limb_id,
				"ordered_joint_ids": joint_ids,
				"ordered_contact_site_ids": ["%s_foot" % limb_id],
			}
		)
		corrections.append(
			{"limb_id": limb_id, "applied_hip_target_correction_rad": 0.01}
		)
		for joint_index in range(2):
			var joint_id := String(joint_ids[joint_index])
			var actuator_id := "%s_motor" % joint_id
			ordered_actuator_ids.append(actuator_id)
			actuators.append(
				{
					"actuator_id": actuator_id,
					"joint_id": joint_id,
					"minimum_target_position_rad": -1.5,
					"maximum_target_position_rad": 1.5,
				}
			)
			commands.append(
				{
					"actuator_id": actuator_id,
					"requested_target_position_rad": 0.1,
					"target_velocity_rad_s": 0.0,
				}
			)
			var anchor := Vector3(float(limb_index), 0.2 - 0.1 * joint_index, 0.0)
			var axis := Vector3.BACK if joint_index == 0 else Vector3.RIGHT
			kinematics.append(
				{
					"actuator_id": actuator_id,
					"contact_site_id": "%s_foot" % limb_id,
					"joint_anchor_world_m": _vector_dictionary(anchor),
					"joint_axis_world_unit": _vector_dictionary(axis),
					"endpoint_world_m": _vector_dictionary(Vector3(float(limb_index), 0.0, 0.2)),
				}
			)
			measurements[joint_id] = {"position_rad": 0.05, "velocity_rad_s": 0.0}
	return {
		"morphology":
		{
			"ordered_actuator_ids": ordered_actuator_ids,
			"morphology_spec": {"limbs": limbs, "actuators": actuators},
		},
		"actuation":
		{
			"safe_no_actuation": false,
			"ordered_commands": commands,
			"receipt":
			{
				"held_steering_fraction": 0.1,
				"forward_velocity_foot_placement":
				{"ordered_limb_corrections": corrections},
			},
		},
		"contacts": {
			"front_left": false,
			"front_right": true,
			"rear_left": false,
			"rear_right": true,
		},
		"kinematics": kinematics,
		"measurements": measurements,
	}
