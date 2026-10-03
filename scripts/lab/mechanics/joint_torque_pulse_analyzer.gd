class_name LabJointTorquePulseAnalyzer
extends RefCounted

## L2.1 free-floating coaxial two-rotor torque-pulse oracle.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_SCHEMA_VERSION := "joint_torque_pulse_configuration_v1"
const RESULT_SCHEMA_VERSION := "joint_torque_pulse_analysis_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"trial_id",
	"physics_hz",
	"pulse_ticks",
	"coast_ticks",
	"requested_torque_nm",
	"pulse_direction",
	"parent_mass_kg",
	"parent_size_m",
	"child_mass_kg",
	"child_size_m",
	"gravity_enabled",
	"linear_damp_s_inv",
	"angular_damp_s_inv",
	"contact_enabled",
	"built_in_motor_enabled",
	"limit_enabled",
]


static func build(configuration: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var keys: Array = configuration.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		errors.append("TORQUE_PULSE_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA_VERSION:
		errors.append("TORQUE_PULSE_SCHEMA_UNSUPPORTED")
	if not _is_stable_id(String(configuration.get("trial_id", ""))):
		errors.append("TORQUE_PULSE_TRIAL_ID_INVALID")
	var physics_hz := _exact_positive_integer(configuration.get("physics_hz"))
	var pulse_ticks := _exact_positive_integer(configuration.get("pulse_ticks"))
	var coast_ticks := _exact_positive_integer(configuration.get("coast_ticks"))
	if physics_hz < 60 or physics_hz > 240:
		errors.append("TORQUE_PULSE_PHYSICS_HZ_INVALID")
	if pulse_ticks < 8 or pulse_ticks > 120:
		errors.append("TORQUE_PULSE_TICK_COUNT_INVALID")
	if coast_ticks < 4 or coast_ticks > 120:
		errors.append("TORQUE_COAST_TICK_COUNT_INVALID")
	var direction := String(configuration.get("pulse_direction", ""))
	if direction not in ["positive", "negative", "zero"]:
		errors.append("TORQUE_PULSE_DIRECTION_INVALID")
	var torque := float(configuration.get("requested_torque_nm", NAN))
	if not is_finite(torque) or torque < 0.0 or torque > 1.0:
		errors.append("TORQUE_PULSE_MAGNITUDE_INVALID")
	elif (direction == "zero" and torque != 0.0) or (direction != "zero" and torque <= 0.0):
		errors.append("TORQUE_PULSE_DIRECTION_MAGNITUDE_MISMATCH")
	var parent_mass := float(configuration.get("parent_mass_kg", NAN))
	var child_mass := float(configuration.get("child_mass_kg", NAN))
	var parent_size := _vector3(configuration.get("parent_size_m"))
	var child_size := _vector3(configuration.get("child_size_m"))
	if (
		not is_finite(parent_mass)
		or parent_mass <= 0.0
		or not is_finite(child_mass)
		or child_mass <= 0.0
		or not parent_size.is_finite()
		or parent_size.x <= 0.0
		or parent_size.y <= 0.0
		or parent_size.z <= 0.0
		or not child_size.is_finite()
		or child_size.x <= 0.0
		or child_size.y <= 0.0
		or child_size.z <= 0.0
	):
		errors.append("TORQUE_PULSE_BODY_PARAMETER_INVALID")
	for field in ["linear_damp_s_inv", "angular_damp_s_inv"]:
		if not _finite_number(configuration.get(field)) or float(configuration[field]) != 0.0:
			errors.append("%s_MUST_BE_ZERO" % String(field).to_upper())
	for forbidden_flag in [
		"gravity_enabled",
		"contact_enabled",
		"built_in_motor_enabled",
		"limit_enabled",
	]:
		if configuration.get(forbidden_flag) != false:
			errors.append("%s_FORBIDDEN" % forbidden_flag.to_upper())
	if not errors.is_empty():
		return {
			"ok": false,
			"failure_code": "JOINT_TORQUE_PULSE_CONFIGURATION_INVALID",
			"errors": errors,
		}
	var parent_inertia := (
		parent_mass * (parent_size.x * parent_size.x + parent_size.y * parent_size.y) / 12.0
	)
	var child_inertia := (
		child_mass * (child_size.x * child_size.x + child_size.y * child_size.y) / 12.0
	)
	var payload := configuration.duplicate(true)
	payload["expected_sample_count"] = pulse_ticks + coast_ticks
	payload["analytic_parent_axis_inertia_kg_m2"] = parent_inertia
	payload["analytic_child_axis_inertia_kg_m2"] = child_inertia
	payload["analytic_parent_axis_inverse_inertia"] = 1.0 / parent_inertia
	payload["analytic_child_axis_inverse_inertia"] = 1.0 / child_inertia
	payload["claim_boundary"] = (
		"Exact gravity-off coaxial free-hinge paired-torque fixture only; "
		+ "no load-bearing, contact, standing, bracing, recovery, gait, or "
		+ "walking claim."
	)
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {
		"ok": true,
		"contract": FrozenValueScript.snapshot(payload),
	}


static func analyze(contract: Dictionary, samples: Array) -> Dictionary:
	var contract_check := _verify_contract(contract)
	if not bool(contract_check.get("ok", false)):
		return contract_check
	if samples.size() != int(contract["expected_sample_count"]):
		return _failure("JOINT_TORQUE_PULSE_SAMPLE_COUNT_MISMATCH")
	var pulse_ticks := int(contract["pulse_ticks"])
	var direction := String(contract["pulse_direction"])
	var signed_request := float(contract["requested_torque_nm"])
	if direction == "negative":
		signed_request = -signed_request
	var max_driven_error_fraction := 0.0
	var max_coast_delta_rad_s := 0.0
	var max_momentum_abs := 0.0
	var max_pairing_residual_nm := 0.0
	var max_parent_inertia_error := 0.0
	var max_child_inertia_error := 0.0
	var max_anchor_error_m := 0.0
	var max_axis_error_rad := 0.0
	var max_swing_residual_rad := 0.0
	var max_off_axis_rate_rad_s := 0.0
	var every_receipt_complete := true
	var every_joint_sample_valid := true
	var applied_impulse_nm_s := 0.0
	var first_relative_rate := 0.0
	var final_relative_rate := 0.0
	var step_s := 1.0 / float(contract["physics_hz"])
	for index in samples.size():
		if not samples[index] is Dictionary:
			return _failure("JOINT_TORQUE_PULSE_SAMPLE_INVALID")
		var sample: Dictionary = samples[index]
		for field in [
			"requested_torque_nm",
			"applied_torque_nm",
			"parent_rate_before_rad_s",
			"child_rate_before_rad_s",
			"parent_rate_after_rad_s",
			"child_rate_after_rad_s",
			"engine_parent_axis_inverse_inertia",
			"engine_child_axis_inverse_inertia",
			"pairing_residual_nm",
			"anchor_error_m",
			"axis_error_rad",
			"swing_residual_rad",
			"off_axis_rate_rad_s",
		]:
			if not _finite_number(sample.get(field)):
				return _failure(
					"JOINT_TORQUE_PULSE_SAMPLE_NONFINITE", {"sample": index, "field": field}
				)
		for norm_field in [
			"pairing_residual_nm",
			"anchor_error_m",
			"axis_error_rad",
			"swing_residual_rad",
			"off_axis_rate_rad_s",
		]:
			if float(sample[norm_field]) < 0.0:
				return _failure(
					"JOINT_TORQUE_PULSE_NEGATIVE_NORM_CHANNEL",
					{"sample": index, "field": norm_field}
				)
		if int(sample.get("tick", -1)) != index:
			return _failure("JOINT_TORQUE_PULSE_TICK_MISMATCH")
		var expected_request := signed_request if index < pulse_ticks else 0.0
		if absf(float(sample["requested_torque_nm"]) - expected_request) > 1.0e-12:
			return _failure("JOINT_TORQUE_PULSE_REQUEST_SCHEDULE_MISMATCH")
		var applied := float(sample["applied_torque_nm"])
		if (
			absf(applied) > absf(expected_request) + 1.0e-6
			or (absf(applied) > 1.0e-9 and signf(applied) != signf(expected_request))
		):
			return _failure("JOINT_TORQUE_PULSE_APPLIED_SIGN_OR_CAP_INVALID")
		var parent_before := float(sample["parent_rate_before_rad_s"])
		var child_before := float(sample["child_rate_before_rad_s"])
		var parent_after := float(sample["parent_rate_after_rad_s"])
		var child_after := float(sample["child_rate_after_rad_s"])
		var inverse_parent := float(sample["engine_parent_axis_inverse_inertia"])
		var inverse_child := float(sample["engine_child_axis_inverse_inertia"])
		if inverse_parent <= 0.0 or inverse_child <= 0.0:
			return _failure("JOINT_TORQUE_PULSE_ENGINE_INERTIA_INVALID")
		var relative_before := child_before - parent_before
		var relative_after := child_after - parent_after
		if index == 0:
			first_relative_rate = relative_before
		final_relative_rate = relative_after
		var measured_delta := relative_after - relative_before
		var expected_delta := applied * (inverse_child + inverse_parent) * step_s
		if absf(applied) > 1.0e-9:
			max_driven_error_fraction = maxf(
				max_driven_error_fraction,
				absf(measured_delta - expected_delta) / maxf(absf(expected_delta), 1.0e-9)
			)
		else:
			max_coast_delta_rad_s = maxf(max_coast_delta_rad_s, absf(measured_delta))
		var momentum_before := parent_before / inverse_parent + child_before / inverse_child
		var momentum_after := parent_after / inverse_parent + child_after / inverse_child
		max_momentum_abs = maxf(max_momentum_abs, maxf(absf(momentum_before), absf(momentum_after)))
		max_pairing_residual_nm = maxf(
			max_pairing_residual_nm, float(sample["pairing_residual_nm"])
		)
		max_parent_inertia_error = maxf(
			max_parent_inertia_error,
			(
				absf(inverse_parent - float(contract["analytic_parent_axis_inverse_inertia"]))
				/ float(contract["analytic_parent_axis_inverse_inertia"])
			)
		)
		max_child_inertia_error = maxf(
			max_child_inertia_error,
			(
				absf(inverse_child - float(contract["analytic_child_axis_inverse_inertia"]))
				/ float(contract["analytic_child_axis_inverse_inertia"])
			)
		)
		max_anchor_error_m = maxf(max_anchor_error_m, float(sample["anchor_error_m"]))
		max_axis_error_rad = maxf(max_axis_error_rad, float(sample["axis_error_rad"]))
		max_swing_residual_rad = maxf(max_swing_residual_rad, float(sample["swing_residual_rad"]))
		max_off_axis_rate_rad_s = maxf(
			max_off_axis_rate_rad_s, float(sample["off_axis_rate_rad_s"])
		)
		every_receipt_complete = (
			int(sample.get("receipt_count", -1)) == 2
			and bool(sample.get("receipts_match_command", false))
			and every_receipt_complete
		)
		every_joint_sample_valid = (
			bool(sample.get("joint_observation_valid", false)) and every_joint_sample_valid
		)
		applied_impulse_nm_s += applied * step_s
	var acceptance_failures: Array[String] = []
	if max_driven_error_fraction > 0.02:
		acceptance_failures.append("ANGULAR_ACCELERATION_ERROR_EXCEEDED")
	if max_coast_delta_rad_s > 1.0e-5:
		acceptance_failures.append("COAST_RATE_DRIFT_EXCEEDED")
	if max_momentum_abs > 1.0e-4:
		acceptance_failures.append("TOTAL_ANGULAR_MOMENTUM_DRIFT_EXCEEDED")
	if max_pairing_residual_nm > 1.0e-9:
		acceptance_failures.append("TORQUE_PAIRING_RESIDUAL_EXCEEDED")
	if max_parent_inertia_error > 1.0e-4 or max_child_inertia_error > 1.0e-4:
		acceptance_failures.append("ENGINE_ANALYTIC_INERTIA_MISMATCH")
	if not every_receipt_complete:
		acceptance_failures.append("EXECUTION_RECEIPT_INCOMPLETE")
	if not every_joint_sample_valid:
		acceptance_failures.append("JOINT_OBSERVATION_INVALID")
	if (
		max_anchor_error_m > 5.0e-3
		or max_axis_error_rad > 2.0e-2
		or max_swing_residual_rad > 2.0e-2
		or max_off_axis_rate_rad_s > 5.0e-2
	):
		acceptance_failures.append("JOINT_GEOMETRY_ENVELOPE_EXCEEDED")
	if absf(first_relative_rate) > 1.0e-5:
		acceptance_failures.append("INITIAL_RATE_NOT_ZERO")
	if direction == "zero":
		if absf(final_relative_rate) > 1.0e-5:
			acceptance_failures.append("ZERO_CONTROL_MOVED")
	elif absf(final_relative_rate) < 0.25:
		acceptance_failures.append("TORQUE_PULSE_RESPONSE_TOO_SMALL")
	var result := {
		"schema_version": RESULT_SCHEMA_VERSION,
		"trial_id": contract["trial_id"],
		"configuration_sha256": contract["configuration_sha256"],
		"pulse_direction": direction,
		"sample_count": samples.size(),
		"applied_angular_impulse_nm_s": applied_impulse_nm_s,
		"first_relative_rate_rad_s": first_relative_rate,
		"final_relative_rate_rad_s": final_relative_rate,
		"max_driven_relative_delta_error_fraction": max_driven_error_fraction,
		"max_coast_relative_delta_rad_s": max_coast_delta_rad_s,
		"max_total_axis_angular_momentum_abs_n_m_s": max_momentum_abs,
		"max_pairing_residual_nm": max_pairing_residual_nm,
		"max_parent_inverse_inertia_error_fraction": max_parent_inertia_error,
		"max_child_inverse_inertia_error_fraction": max_child_inertia_error,
		"max_anchor_error_m": max_anchor_error_m,
		"max_axis_error_rad": max_axis_error_rad,
		"max_swing_residual_rad": max_swing_residual_rad,
		"max_off_axis_rate_rad_s": max_off_axis_rate_rad_s,
		"all_execution_receipts_complete": every_receipt_complete,
		"all_joint_observations_valid": every_joint_sample_valid,
		"accepted": acceptance_failures.is_empty(),
		"acceptance_failures": acceptance_failures,
		"claim_boundary": contract["claim_boundary"],
	}
	result["result_sha256"] = CanonicalJsonScript.sha256(result)
	return {
		"ok": true,
		"result": FrozenValueScript.snapshot(result),
	}


static func _verify_contract(contract: Dictionary) -> Dictionary:
	var configuration: Dictionary = {}
	for field in REQUIRED_FIELDS:
		if not contract.has(field):
			return _failure("JOINT_TORQUE_PULSE_CONTRACT_INCOMPLETE")
		configuration[field] = contract[field]
	var rebuilt := build(configuration)
	if not bool(rebuilt.get("ok", false)):
		return _failure("JOINT_TORQUE_PULSE_CONTRACT_INVALID", rebuilt)
	if (
		CanonicalJsonScript.stringify(rebuilt["contract"])
		!= CanonicalJsonScript.stringify(contract)
	):
		return _failure("JOINT_TORQUE_PULSE_CONTRACT_DIGEST_MISMATCH")
	return {"ok": true}


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() == 3:
		var raw: Array = value
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3(INF, INF, INF)


static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _exact_positive_integer(value: Variant) -> int:
	if value is int and int(value) > 0:
		return int(value)
	if (
		value is float
		and is_finite(float(value))
		and float(value) == floor(float(value))
		and float(value) > 0.0
	):
		return int(value)
	return -1


static func _is_stable_id(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[A-Za-z][A-Za-z0-9._-]{0,159}$")
	return expression.search(value) != null


static func _failure(code: String, details: Variant = null) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"details": details,
	}
