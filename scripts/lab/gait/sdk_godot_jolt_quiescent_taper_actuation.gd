extends RefCounted
# gdlint: disable=max-line-length

## Godot/Jolt actuation implementation for the QSDK-R23D10 terminal policy.
##
## The bounded neutral-stance velocity is calculated in canonical coordinates,
## multiplied by the prospectively frozen taper fraction, and only then mapped
## through the characterized Godot/Jolt host sign.  This component writes hinge
## motor velocity targets only; the scheduler and the physical runner retain
## ownership of mode transitions and post-step observations.

const NeutralStance := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_neutral_stance.gd"
)

const POLICY_ID := "sporespore_support_pose_confirmed_quiescent_taper_v1"
const RECEIPT_SCHEMA := "sporespore_qsdk_r23d10_godot_jolt_taper_actuation_receipt_v1"
const ACTUATOR_COUNT := 8
const SCALE_DENOMINATOR := 120
const TOLERANCE := 1.0e-12

var _activated := false
var _velocity_scale_numerator := SCALE_DENOMINATOR


func reset() -> void:
	_activated = false
	_velocity_scale_numerator = SCALE_DENOMINATOR


func set_velocity_scale(numerator: int, denominator: int) -> Dictionary:
	if numerator < 1 or numerator > SCALE_DENOMINATOR or denominator != SCALE_DENOMINATOR:
		return _failure("R23D10_GJT_TAPER_SCALE_INVALID")
	_velocity_scale_numerator = numerator
	return {
		"ok": true,
		"failure_code": "",
		"velocity_scale_numerator": numerator,
		"velocity_scale_denominator": denominator,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func compose_and_apply(
	step_result: Dictionary,
	compiled_morphology: Dictionary,
	_limbs: Array,
	_contacts_by_limb: Dictionary,
	joint_state_by_joint_id: Dictionary,
) -> Dictionary:
	var measurements_result := measurements_from_live_joints(
		compiled_morphology,
		joint_state_by_joint_id,
	)
	if not bool(measurements_result.get("ok", false)):
		return measurements_result
	var native_output: Dictionary = step_result.get("native_output", {})
	var composition := compose(
		int(step_result.get("semantic_step", -1)),
		compiled_morphology,
		native_output.get("actuation", {}),
		measurements_result["measurements"],
		_velocity_scale_numerator,
		SCALE_DENOMINATOR,
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
			return _failure("R23D10_GJT_TAPER_HINGE_MISSING:%s" % legacy_joint_id)
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
	velocity_scale_numerator: int,
	velocity_scale_denominator: int,
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
		or velocity_scale_numerator < 1
		or velocity_scale_numerator > SCALE_DENOMINATOR
		or velocity_scale_denominator != SCALE_DENOMINATOR
	):
		return _failure("R23D10_GJT_TAPER_INPUT_INVALID")
	var scale := float(velocity_scale_numerator) / float(velocity_scale_denominator)
	var ordered_solutions: Array[Dictionary] = []
	var ordered_host_commands: Array[Dictionary] = []
	var maximum_scaled_speed := 0.0
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
			or float(actuator.get("minimum_target_position_rad", INF))
			> NeutralStance.TARGET_POSITION_RAD
			or float(actuator.get("maximum_target_position_rad", -INF))
			< NeutralStance.TARGET_POSITION_RAD
		):
			return _failure("R23D10_GJT_TAPER_ACTUATOR_IDENTITY:%s" % actuator_id)
		var measurement: Dictionary = joint_measurements_by_id[joint_id]
		var measured_position := float(measurement.get("position_rad", NAN))
		var measured_velocity := float(measurement.get("velocity_rad_s", NAN))
		var equation := NeutralStance.bounded_neutral_velocity(
			measured_position,
			measured_velocity,
		)
		if not bool(equation.get("ok", false)):
			return equation
		var base_canonical := float(equation["bounded_velocity_rad_s"])
		var scaled_canonical := base_canonical * scale
		var host_target := (
			NeutralStance.GODOT_HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE
			* scaled_canonical
		)
		maximum_scaled_speed = maxf(maximum_scaled_speed, absf(scaled_canonical))
		maximum_position_error = maxf(
			maximum_position_error,
			absf(float(equation["position_error_rad"])),
		)
		ordered_solutions.append(
			{
				"actuator_id": actuator_id,
				"joint_id": joint_id,
				"measured_position_rad": measured_position,
				"measured_velocity_rad_s": measured_velocity,
				"position_error_rad": float(equation["position_error_rad"]),
				"unbounded_velocity_rad_s": float(equation["unbounded_velocity_rad_s"]),
				"base_bounded_canonical_velocity_rad_s": base_canonical,
				"scaled_canonical_velocity_rad_s": scaled_canonical,
				"host_target_velocity_rad_s": host_target,
				"native_target_position_rad": null,
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
		"velocity_scale_numerator": velocity_scale_numerator,
		"velocity_scale_denominator": velocity_scale_denominator,
		"scale_applied_to_canonical_velocity_before_host_mapping": true,
		"first_activation": first_activation,
		"ordered_actuator_ids": ordered_actuator_ids.duplicate(),
		"ordered_actuator_solutions": ordered_solutions,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	var validation := validate_receipt(receipt, semantic_step)
	if not bool(validation.get("ok", false)):
		return validation
	return {
		"ok": true,
		"failure_code": "",
		"semantic_step": semantic_step,
		"ordered_host_commands": ordered_host_commands,
		"maximum_absolute_joint_velocity_rad_s": maximum_scaled_speed,
		"maximum_absolute_joint_position_error_rad": maximum_position_error,
		"neutral_target_activation_count": ACTUATOR_COUNT,
		"receipt": receipt,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func validate_receipt(receipt: Dictionary, expected_semantic_step: int) -> Dictionary:
	var solutions: Array = receipt.get("ordered_actuator_solutions", [])
	var ordered_ids: Array = receipt.get("ordered_actuator_ids", [])
	var numerator := int(receipt.get("velocity_scale_numerator", -1))
	var denominator := int(receipt.get("velocity_scale_denominator", -1))
	if (
		String(receipt.get("schema_version", "")) != RECEIPT_SCHEMA
		or String(receipt.get("policy_id", "")) != POLICY_ID
		or int(receipt.get("semantic_step", -1)) != expected_semantic_step
		or numerator < 1
		or numerator > SCALE_DENOMINATOR
		or denominator != SCALE_DENOMINATOR
		or not bool(
			receipt.get("scale_applied_to_canonical_velocity_before_host_mapping", false)
		)
		or ordered_ids.size() != ACTUATOR_COUNT
		or solutions.size() != ACTUATOR_COUNT
		or bool(receipt.get("physics_state_modified", true))
		or bool(receipt.get("physical_acceptance_authority", true))
	):
		return _failure("R23D10_GJT_TAPER_RECEIPT_IDENTITY")
	var scale := float(numerator) / float(denominator)
	for index in range(ACTUATOR_COUNT):
		var solution: Dictionary = solutions[index]
		if String(solution.get("actuator_id", "")) != String(ordered_ids[index]):
			return _failure("R23D10_GJT_TAPER_RECEIPT_ORDER")
		var equation := NeutralStance.bounded_neutral_velocity(
			float(solution.get("measured_position_rad", NAN)),
			float(solution.get("measured_velocity_rad_s", NAN)),
		)
		if not bool(equation.get("ok", false)):
			return equation
		var base := float(equation["bounded_velocity_rad_s"])
		var scaled := base * scale
		var host := (
			NeutralStance.GODOT_HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE * scaled
		)
		for pair in [
			["position_error_rad", float(equation["position_error_rad"])],
			["unbounded_velocity_rad_s", float(equation["unbounded_velocity_rad_s"])],
			["base_bounded_canonical_velocity_rad_s", base],
			["scaled_canonical_velocity_rad_s", scaled],
			["host_target_velocity_rad_s", host],
		]:
			if (
				not is_finite(float(solution.get(String(pair[0]), NAN)))
				or absf(float(solution[String(pair[0])]) - float(pair[1])) > TOLERANCE
			):
				return _failure("R23D10_GJT_TAPER_RECEIPT_EQUATION:%s" % pair[0])
		if solution.get("native_target_position_rad", 0.0) != null:
			return _failure("R23D10_GJT_TAPER_NATIVE_POSITION_PRESENT")
	return {
		"ok": true,
		"failure_code": "",
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func measurements_from_live_joints(
	compiled_morphology: Dictionary,
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
			return _failure("R23D10_GJT_TAPER_LIVE_JOINT:%s" % joint_id)
		var state: Dictionary = joint_state_by_joint_id[legacy_joint_id]
		measurements[joint_id] = {
			"position_rad": NeutralStance._joint_angle_rad(state),
			"velocity_rad_s": NeutralStance._joint_rate_rad_s(state),
			"legacy_joint_id": legacy_joint_id,
		}
	return {
		"ok": true,
		"failure_code": "",
		"measurements": measurements,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func maximum_absolute_joint_position_error_rad(
	compiled_morphology: Dictionary,
	joint_state_by_joint_id: Dictionary,
) -> Dictionary:
	var measurements_result := measurements_from_live_joints(
		compiled_morphology,
		joint_state_by_joint_id,
	)
	if not bool(measurements_result.get("ok", false)):
		return measurements_result
	var maximum_error := 0.0
	for measurement_value in (measurements_result["measurements"] as Dictionary).values():
		var measurement: Dictionary = measurement_value
		maximum_error = maxf(
			maximum_error,
			absf(
				NeutralStance.TARGET_POSITION_RAD
				- float(measurement["position_rad"])
			),
		)
	return {
		"ok": true,
		"failure_code": "",
		"maximum_absolute_joint_position_error_rad": maximum_error,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func run_zero_world_preflight() -> Dictionary:
	var fixture := _synthetic_fixture()
	var checks := [[120, 1.0], [60, 0.5], [1, 1.0 / 120.0]]
	for check in checks:
		var composed := compose(
			2992,
			fixture["morphology"],
			fixture["actuation"],
			fixture["measurements"],
			int(check[0]),
			120,
			true,
		)
		if not bool(composed.get("ok", false)):
			return composed
		var solution: Dictionary = (composed["receipt"]["ordered_actuator_solutions"] as Array)[0]
		if (
			absf(
				float(solution["scaled_canonical_velocity_rad_s"])
				- float(solution["base_bounded_canonical_velocity_rad_s"]) * float(check[1])
			) > TOLERANCE
			or absf(
				float(solution["host_target_velocity_rad_s"])
				+ float(solution["scaled_canonical_velocity_rad_s"])
			) > TOLERANCE
		):
			return _failure("R23D10_GJT_TAPER_SCALE_ORDER_CANARY")
	if bool(
		compose(
			2992,
			fixture["morphology"],
			fixture["actuation"],
			fixture["measurements"],
			0,
			120,
			true,
		).get("ok", false)
	):
		return _failure("R23D10_GJT_TAPER_ZERO_SCALE_ACCEPTED")
	return {
		"ok": true,
		"failure_code": "",
		"scale_order_canary_count": checks.size(),
		"invalid_scale_rejection_count": 1,
		"world_build_count": 0,
		"model_construction_count": 0,
		"physical_acceptance_authority": false,
	}


static func _synthetic_fixture() -> Dictionary:
	var ordered_actuator_ids: Array[String] = []
	var actuators: Array[Dictionary] = []
	var commands: Array[Dictionary] = []
	var measurements := {}
	for limb_id in ["front_left", "front_right", "rear_left", "rear_right"]:
		for suffix in ["hip", "knee"]:
			var joint_id := "%s_%s" % [limb_id, suffix]
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
			commands.append({"actuator_id": actuator_id, "target_velocity_rad_s": 0.0})
			measurements[joint_id] = {
				"position_rad": 0.05,
				"velocity_rad_s": 0.0,
				"legacy_joint_id": joint_id,
			}
	return {
		"morphology": {
			"morphology": {
				"ordered_actuator_ids": ordered_actuator_ids,
				"morphology_spec": {"actuators": actuators},
			}
		},
		"actuation": {"safe_no_actuation": false, "ordered_commands": commands},
		"measurements": measurements,
	}


static func _legacy_joint_id(joint_id: String) -> String:
	if joint_id.ends_with("_hip"):
		return "%s.hip_pitch" % joint_id.trim_suffix("_hip")
	if joint_id.ends_with("_knee"):
		return "%s.knee_pitch" % joint_id.trim_suffix("_knee")
	return ""


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
