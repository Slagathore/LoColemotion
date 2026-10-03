class_name LabGravityHoldAnalyzer
extends RefCounted

## L2.3 fixed-base horizontal-link gravity compensation oracle.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_SCHEMA_VERSION := "gravity_hold_configuration_v1"
const RESULT_SCHEMA_VERSION := "gravity_hold_analysis_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"trial_id",
	"physics_hz",
	"sample_ticks",
	"compensation_ratio",
	"child_mass_kg",
	"link_length_m",
	"link_width_m",
	"link_depth_m",
	"gravity_m_s2",
	"fixed_parent",
	"contact_enabled",
	"built_in_motor_enabled",
	"limit_enabled",
]
const CLAIM_BOUNDARY := (
	"Exact single-link fixed-scaffold horizontal gravity-hold fixture only; "
	+ "no free-root load bearing, articulated limb, standing, bracing, recovery, "
	+ "gait, or walking claim."
)


static func build(configuration: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var keys: Array = configuration.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		errors.append("GRAVITY_HOLD_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA_VERSION:
		errors.append("GRAVITY_HOLD_SCHEMA_UNSUPPORTED")
	if not _is_stable_id(String(configuration.get("trial_id", ""))):
		errors.append("GRAVITY_HOLD_TRIAL_ID_INVALID")
	var physics_hz := _positive_integer(configuration.get("physics_hz"))
	var sample_ticks := _positive_integer(configuration.get("sample_ticks"))
	if physics_hz < 60 or physics_hz > 240:
		errors.append("GRAVITY_HOLD_PHYSICS_HZ_INVALID")
	if sample_ticks < physics_hz / 8 or sample_ticks > physics_hz * 3:
		errors.append("GRAVITY_HOLD_SAMPLE_COUNT_INVALID")
	for field in [
		"child_mass_kg",
		"link_length_m",
		"link_width_m",
		"link_depth_m",
		"gravity_m_s2",
	]:
		if not _finite_number(configuration.get(field)) or float(configuration[field]) <= 0.0:
			errors.append("%s_INVALID" % String(field).to_upper())
	var ratio := float(configuration.get("compensation_ratio", NAN))
	if not is_finite(ratio) or ratio < 0.0 or ratio > 1.5:
		errors.append("GRAVITY_HOLD_COMPENSATION_RATIO_INVALID")
	if configuration.get("fixed_parent") != true:
		errors.append("GRAVITY_HOLD_FIXED_PARENT_REQUIRED")
	for flag in ["contact_enabled", "built_in_motor_enabled", "limit_enabled"]:
		if configuration.get(flag) != false:
			errors.append("%s_FORBIDDEN" % flag.to_upper())
	if not errors.is_empty():
		return {
			"ok": false,
			"failure_code": "GRAVITY_HOLD_CONFIGURATION_INVALID",
			"errors": errors,
		}
	var mass := float(configuration["child_mass_kg"])
	var length := float(configuration["link_length_m"])
	var width := float(configuration["link_width_m"])
	var gravity := float(configuration["gravity_m_s2"])
	var gravity_torque := mass * gravity * length * 0.5
	var com_inertia := mass * (length * length + width * width) / 12.0
	var pivot_inertia := com_inertia + mass * length * length * 0.25
	var payload := configuration.duplicate(true)
	payload["analytic_gravity_torque_nm"] = gravity_torque
	# The LabJointState scalar axis is Vector3.BACK for this fixture. Godot's
	# constrained horizontal link accelerates in the negative scalar direction
	# under gravity, so the opposing compensation request is positive.
	payload["analytic_requested_compensation_nm"] = ratio * gravity_torque
	payload["analytic_initial_residual_torque_nm"] = -(1.0 - ratio) * gravity_torque
	payload["analytic_pivot_inertia_kg_m2"] = pivot_inertia
	payload["analytic_initial_acceleration_rad_s2"] = (
		-(1.0 - ratio) * gravity_torque / pivot_inertia
	)
	payload["claim_boundary"] = CLAIM_BOUNDARY
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {"ok": true, "contract": FrozenValueScript.snapshot(payload)}


static func analyze(contract: Dictionary, samples: Array) -> Dictionary:
	var check := _verify_contract(contract)
	if not bool(check.get("ok", false)):
		return check
	if samples.size() != int(contract["sample_ticks"]):
		return _failure("GRAVITY_HOLD_SAMPLE_COUNT_MISMATCH")
	var max_request_error := 0.0
	var max_pairing_residual := 0.0
	var max_anchor_error := 0.0
	var max_axis_error := 0.0
	var max_swing := 0.0
	var max_off_axis_rate := 0.0
	var every_receipt_complete := true
	var every_observation_valid := true
	var any_active_saturation := false
	var any_structural_saturation := false
	var first_rate_before := 0.0
	var first_rate_after := 0.0
	var final_angle := 0.0
	var final_rate := 0.0
	for index in samples.size():
		var value: Variant = samples[index]
		if not value is Dictionary:
			return _failure("GRAVITY_HOLD_SAMPLE_INVALID")
		var sample: Dictionary = value
		if int(sample.get("tick", -1)) != index:
			return _failure("GRAVITY_HOLD_TICK_MISMATCH")
		for field in [
			"requested_torque_nm",
			"applied_torque_nm",
			"angle_before_rad",
			"angle_after_rad",
			"rate_before_rad_s",
			"rate_after_rad_s",
			"pairing_residual_nm",
			"anchor_error_m",
			"axis_error_rad",
			"swing_residual_rad",
			"off_axis_rate_rad_s",
		]:
			if not _finite_number(sample.get(field)):
				return _failure("GRAVITY_HOLD_SAMPLE_NONFINITE", {"sample": index, "field": field})
		max_request_error = maxf(
			max_request_error,
			maxf(
				absf(
					(
						float(sample["requested_torque_nm"])
						- float(contract["analytic_requested_compensation_nm"])
					)
				),
				absf(
					(
						float(sample["applied_torque_nm"])
						- float(contract["analytic_requested_compensation_nm"])
					)
				)
			)
		)
		if index == 0:
			first_rate_before = float(sample["rate_before_rad_s"])
			first_rate_after = float(sample["rate_after_rad_s"])
		final_angle = float(sample["angle_after_rad"])
		final_rate = float(sample["rate_after_rad_s"])
		max_pairing_residual = maxf(max_pairing_residual, float(sample["pairing_residual_nm"]))
		max_anchor_error = maxf(max_anchor_error, float(sample["anchor_error_m"]))
		max_axis_error = maxf(max_axis_error, float(sample["axis_error_rad"]))
		max_swing = maxf(max_swing, float(sample["swing_residual_rad"]))
		max_off_axis_rate = maxf(max_off_axis_rate, float(sample["off_axis_rate_rad_s"]))
		every_receipt_complete = (
			int(sample.get("receipt_count", -1)) == 2
			and bool(sample.get("receipts_match_command", false))
			and every_receipt_complete
		)
		every_observation_valid = (
			bool(sample.get("joint_observation_valid", false)) and every_observation_valid
		)
		any_active_saturation = (
			bool(sample.get("active_saturated", false))
			or bool(sample.get("torque_rate_limited", false))
			or any_active_saturation
		)
		any_structural_saturation = (
			bool(sample.get("structural_saturated", false)) or any_structural_saturation
		)
	var step_s := 1.0 / float(contract["physics_hz"])
	var measured_initial_acceleration := (first_rate_after - first_rate_before) / step_s
	var expected_initial_acceleration := float(contract["analytic_initial_acceleration_rad_s2"])
	var initial_acceleration_error_fraction := (
		(
			absf(measured_initial_acceleration - expected_initial_acceleration)
			/ maxf(absf(expected_initial_acceleration), 1.0e-6)
		)
		if absf(expected_initial_acceleration) > 1.0e-6
		else absf(measured_initial_acceleration)
	)
	var ratio := float(contract["compensation_ratio"])
	var acceptance_failures: Array[String] = []
	if max_request_error > 1.0e-6:
		acceptance_failures.append("GRAVITY_COMPENSATION_TORQUE_MISMATCH")
	if max_pairing_residual > 1.0e-9:
		acceptance_failures.append("TORQUE_PAIRING_RESIDUAL_EXCEEDED")
	if not every_receipt_complete:
		acceptance_failures.append("EXECUTION_RECEIPT_INCOMPLETE")
	if not every_observation_valid:
		acceptance_failures.append("JOINT_OBSERVATION_INVALID")
	if (
		max_anchor_error > 5.0e-3
		or max_axis_error > 2.0e-2
		or max_swing > 2.0e-2
		or max_off_axis_rate > 5.0e-2
	):
		acceptance_failures.append("JOINT_GEOMETRY_ENVELOPE_EXCEEDED")
	if any_active_saturation:
		acceptance_failures.append("ACTIVE_ENVELOPE_SATURATED")
	if any_structural_saturation:
		acceptance_failures.append("STRUCTURAL_GUARD_SATURATED")
	if absf(ratio - 1.0) <= 1.0e-9:
		if absf(final_angle) > 0.01 or absf(final_rate) > 0.02:
			acceptance_failures.append("EXACT_COMPENSATION_DID_NOT_HOLD")
		if absf(measured_initial_acceleration) > 0.05:
			acceptance_failures.append("EXACT_COMPENSATION_INITIAL_ACCELERATION_NONZERO")
	else:
		if initial_acceleration_error_fraction > 0.08:
			acceptance_failures.append("INITIAL_ACCELERATION_ORACLE_MISMATCH")
		if ratio < 1.0 and (final_angle > -0.05 or final_rate >= 0.0):
			acceptance_failures.append("UNDERCOMPENSATION_FAILURE_DIRECTION_WRONG")
		if ratio > 1.0 and (final_angle < 0.05 or final_rate <= 0.0):
			acceptance_failures.append("OVERCOMPENSATION_FAILURE_DIRECTION_WRONG")
	var result := {
		"schema_version": RESULT_SCHEMA_VERSION,
		"trial_id": contract["trial_id"],
		"configuration_sha256": contract["configuration_sha256"],
		"compensation_ratio": ratio,
		"analytic_gravity_torque_nm": contract["analytic_gravity_torque_nm"],
		"requested_compensation_nm": contract["analytic_requested_compensation_nm"],
		"expected_initial_acceleration_rad_s2": expected_initial_acceleration,
		"measured_initial_acceleration_rad_s2": measured_initial_acceleration,
		"initial_acceleration_error_fraction": initial_acceleration_error_fraction,
		"final_angle_rad": final_angle,
		"final_rate_rad_s": final_rate,
		"max_request_error_nm": max_request_error,
		"max_pairing_residual_nm": max_pairing_residual,
		"max_anchor_error_m": max_anchor_error,
		"max_axis_error_rad": max_axis_error,
		"max_swing_residual_rad": max_swing,
		"max_off_axis_rate_rad_s": max_off_axis_rate,
		"all_execution_receipts_complete": every_receipt_complete,
		"all_joint_observations_valid": every_observation_valid,
		"active_envelope_saturated": any_active_saturation,
		"structural_guard_saturated": any_structural_saturation,
		"accepted": acceptance_failures.is_empty(),
		"acceptance_failures": acceptance_failures,
		"claim_boundary": contract["claim_boundary"],
	}
	result["result_sha256"] = CanonicalJsonScript.sha256(result)
	return {"ok": true, "result": FrozenValueScript.snapshot(result)}


static func _verify_contract(contract: Dictionary) -> Dictionary:
	var configuration: Dictionary = {}
	for field in REQUIRED_FIELDS:
		if not contract.has(field):
			return _failure("GRAVITY_HOLD_CONTRACT_INCOMPLETE")
		configuration[field] = contract[field]
	var rebuilt := build(configuration)
	if not bool(rebuilt.get("ok", false)):
		return _failure("GRAVITY_HOLD_CONTRACT_INVALID", rebuilt)
	if (
		CanonicalJsonScript.stringify(rebuilt["contract"])
		!= CanonicalJsonScript.stringify(contract)
	):
		return _failure("GRAVITY_HOLD_CONTRACT_DIGEST_MISMATCH")
	return {"ok": true}


static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _positive_integer(value: Variant) -> int:
	if value is int and int(value) > 0:
		return int(value)
	if value is float and is_finite(value) and value > 0.0 and value == floor(value):
		return int(value)
	return -1


static func _is_stable_id(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[A-Za-z][A-Za-z0-9._-]{0,159}$")
	return expression.search(value) != null


static func _failure(code: String, details: Variant = null) -> Dictionary:
	return {"ok": false, "failure_code": code, "details": details}
