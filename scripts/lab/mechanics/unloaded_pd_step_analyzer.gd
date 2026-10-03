class_name LabUnloadedPdStepAnalyzer
extends RefCounted

## L2.2 free-floating unloaded PD-step contract and trace analyzer.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_SCHEMA_VERSION := "unloaded_pd_step_configuration_v1"
const RESULT_SCHEMA_VERSION := "unloaded_pd_step_analysis_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"trial_id",
	"physics_hz",
	"sample_ticks",
	"target_angle_rad",
	"parent_mass_kg",
	"parent_size_m",
	"child_mass_kg",
	"child_size_m",
	"natural_frequency_rad_s",
	"damping_ratio",
	"gravity_enabled",
	"linear_damp_s_inv",
	"angular_damp_s_inv",
	"contact_enabled",
	"built_in_motor_enabled",
	"limit_enabled",
]
const CLAIM_BOUNDARY := (
	"Exact gravity-off, contact-free, coaxial free-hinge unloaded PD fixture only; "
	+ "no load-bearing, standing, bracing, recovery, gait, or walking claim."
)


static func build(configuration: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var keys: Array = configuration.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		errors.append("UNLOADED_PD_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA_VERSION:
		errors.append("UNLOADED_PD_SCHEMA_UNSUPPORTED")
	if not _is_stable_id(String(configuration.get("trial_id", ""))):
		errors.append("UNLOADED_PD_TRIAL_ID_INVALID")
	var physics_hz := _exact_positive_integer(configuration.get("physics_hz"))
	var sample_ticks := _exact_positive_integer(configuration.get("sample_ticks"))
	if physics_hz < 60 or physics_hz > 240:
		errors.append("UNLOADED_PD_PHYSICS_HZ_INVALID")
	if sample_ticks < physics_hz or sample_ticks > physics_hz * 5:
		errors.append("UNLOADED_PD_SAMPLE_COUNT_INVALID")
	var target := float(configuration.get("target_angle_rad", NAN))
	if not is_finite(target) or absf(target) > 0.5:
		errors.append("UNLOADED_PD_TARGET_INVALID")
	var parent_mass := float(configuration.get("parent_mass_kg", NAN))
	var child_mass := float(configuration.get("child_mass_kg", NAN))
	var parent_size := _vector3(configuration.get("parent_size_m"))
	var child_size := _vector3(configuration.get("child_size_m"))
	if (
		not is_finite(parent_mass)
		or parent_mass <= 0.0
		or not is_finite(child_mass)
		or child_mass <= 0.0
		or not _positive_vector(parent_size)
		or not _positive_vector(child_size)
	):
		errors.append("UNLOADED_PD_BODY_PARAMETER_INVALID")
	for field in ["natural_frequency_rad_s", "damping_ratio"]:
		if not _finite_number(configuration.get(field)) or float(configuration[field]) <= 0.0:
			errors.append("%s_INVALID" % String(field).to_upper())
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
			"failure_code": "UNLOADED_PD_CONFIGURATION_INVALID",
			"errors": errors,
		}
	var parent_inertia := (
		parent_mass * (parent_size.x * parent_size.x + parent_size.y * parent_size.y) / 12.0
	)
	var child_inertia := (
		child_mass * (child_size.x * child_size.x + child_size.y * child_size.y) / 12.0
	)
	var reflected_inertia := 1.0 / (1.0 / parent_inertia + 1.0 / child_inertia)
	var wn := float(configuration["natural_frequency_rad_s"])
	var zeta := float(configuration["damping_ratio"])
	var payload := configuration.duplicate(true)
	payload["analytic_parent_axis_inertia_kg_m2"] = parent_inertia
	payload["analytic_child_axis_inertia_kg_m2"] = child_inertia
	payload["analytic_reflected_inertia_kg_m2"] = reflected_inertia
	payload["kp_nm_per_rad"] = reflected_inertia * wn * wn
	payload["kd_nm_s_per_rad"] = 2.0 * zeta * reflected_inertia * wn
	payload["claim_boundary"] = CLAIM_BOUNDARY
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {
		"ok": true,
		"contract": FrozenValueScript.snapshot(payload),
	}


static func analyze(contract: Dictionary, samples: Array) -> Dictionary:
	var contract_check := _verify_contract(contract)
	if not bool(contract_check.get("ok", false)):
		return contract_check
	if samples.size() != int(contract["sample_ticks"]):
		return _failure("UNLOADED_PD_SAMPLE_COUNT_MISMATCH")
	var target := float(contract["target_angle_rad"])
	var initial_angle := 0.0
	var final_angle := 0.0
	var final_rate := 0.0
	var peak_directional_angle := 0.0
	var max_abs_error := 0.0
	var max_abs_rate := 0.0
	var max_momentum_abs := 0.0
	var max_pairing_residual := 0.0
	var max_anchor_error := 0.0
	var max_axis_error := 0.0
	var max_swing_residual := 0.0
	var max_off_axis_rate := 0.0
	var max_controller_identity_error := 0.0
	var every_receipt_complete := true
	var every_observation_valid := true
	var any_active_saturation := false
	var any_structural_saturation := false
	var settling_tick := -1
	var rise_tick := -1
	var target_sign := signf(target)
	for index in samples.size():
		var sample_value: Variant = samples[index]
		if not sample_value is Dictionary:
			return _failure("UNLOADED_PD_SAMPLE_INVALID")
		var sample: Dictionary = sample_value
		if int(sample.get("tick", -1)) != index:
			return _failure("UNLOADED_PD_TICK_MISMATCH")
		for field in [
			"target_angle_rad",
			"measured_angle_before_rad",
			"measured_angle_after_rad",
			"measured_rate_before_rad_s",
			"measured_rate_after_rad_s",
			"position_error_rad",
			"proportional_torque_nm",
			"derivative_torque_nm",
			"requested_torque_nm",
			"actuator_requested_torque_nm",
			"applied_torque_nm",
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
				return _failure("UNLOADED_PD_SAMPLE_NONFINITE", {"sample": index, "field": field})
		if absf(float(sample["target_angle_rad"]) - target) > 1.0e-12:
			return _failure("UNLOADED_PD_TARGET_TRACE_MISMATCH")
		var angle_before := float(sample["measured_angle_before_rad"])
		var angle_after := float(sample["measured_angle_after_rad"])
		var rate_before := float(sample["measured_rate_before_rad_s"])
		var rate_after := float(sample["measured_rate_after_rad_s"])
		var error := target - angle_before
		var expected_p := float(contract["kp_nm_per_rad"]) * error
		var expected_d := -float(contract["kd_nm_s_per_rad"]) * rate_before
		for identity_error in [
			absf(float(sample["position_error_rad"]) - error),
			absf(float(sample["proportional_torque_nm"]) - expected_p),
			absf(float(sample["derivative_torque_nm"]) - expected_d),
			absf(float(sample["requested_torque_nm"]) - expected_p - expected_d),
			absf(
				float(sample["actuator_requested_torque_nm"]) - float(sample["requested_torque_nm"])
			),
		]:
			max_controller_identity_error = maxf(
				max_controller_identity_error, float(identity_error)
			)
		if index == 0:
			initial_angle = angle_before
		final_angle = angle_after
		final_rate = rate_after
		max_abs_error = maxf(max_abs_error, absf(target - angle_after))
		max_abs_rate = maxf(max_abs_rate, maxf(absf(rate_before), absf(rate_after)))
		if target_sign != 0.0:
			peak_directional_angle = maxf(peak_directional_angle, target_sign * angle_after)
			if rise_tick < 0 and target_sign * angle_after >= 0.9 * absf(target):
				rise_tick = index
		var inverse_parent := float(sample["engine_parent_axis_inverse_inertia"])
		var inverse_child := float(sample["engine_child_axis_inverse_inertia"])
		if inverse_parent <= 0.0 or inverse_child <= 0.0:
			return _failure("UNLOADED_PD_ENGINE_INERTIA_INVALID")
		var momentum := (
			float(sample["parent_rate_after_rad_s"]) / inverse_parent
			+ float(sample["child_rate_after_rad_s"]) / inverse_child
		)
		max_momentum_abs = maxf(max_momentum_abs, absf(momentum))
		max_pairing_residual = maxf(max_pairing_residual, float(sample["pairing_residual_nm"]))
		max_anchor_error = maxf(max_anchor_error, float(sample["anchor_error_m"]))
		max_axis_error = maxf(max_axis_error, float(sample["axis_error_rad"]))
		max_swing_residual = maxf(max_swing_residual, float(sample["swing_residual_rad"]))
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
	var settle_error := maxf(0.0025, absf(target) * 0.02)
	var settle_rate := 0.015
	for candidate in samples.size():
		var settled := true
		for tail in range(candidate, samples.size()):
			var tail_sample: Dictionary = samples[tail]
			if (
				absf(target - float(tail_sample["measured_angle_after_rad"])) > settle_error
				or absf(float(tail_sample["measured_rate_after_rad_s"])) > settle_rate
			):
				settled = false
				break
		if settled:
			settling_tick = candidate
			break
	var overshoot_fraction := 0.0
	if absf(target) > 1.0e-12:
		overshoot_fraction = maxf(0.0, (peak_directional_angle - absf(target)) / absf(target))
	var acceptance_failures: Array[String] = []
	if absf(initial_angle) > 1.0e-5:
		acceptance_failures.append("INITIAL_ANGLE_NOT_ZERO")
	if max_controller_identity_error > 1.0e-9:
		acceptance_failures.append("PD_IDENTITY_MISMATCH")
	if max_momentum_abs > 1.0e-4:
		acceptance_failures.append("TOTAL_ANGULAR_MOMENTUM_DRIFT_EXCEEDED")
	if max_pairing_residual > 1.0e-9:
		acceptance_failures.append("TORQUE_PAIRING_RESIDUAL_EXCEEDED")
	if not every_receipt_complete:
		acceptance_failures.append("EXECUTION_RECEIPT_INCOMPLETE")
	if not every_observation_valid:
		acceptance_failures.append("JOINT_OBSERVATION_INVALID")
	if (
		max_anchor_error > 5.0e-3
		or max_axis_error > 2.0e-2
		or max_swing_residual > 2.0e-2
		or max_off_axis_rate > 5.0e-2
	):
		acceptance_failures.append("JOINT_GEOMETRY_ENVELOPE_EXCEEDED")
	if any_active_saturation:
		acceptance_failures.append("ACTIVE_ENVELOPE_SATURATED")
	if any_structural_saturation:
		acceptance_failures.append("STRUCTURAL_GUARD_SATURATED")
	if target == 0.0:
		if absf(final_angle) > 1.0e-5 or absf(final_rate) > 1.0e-5:
			acceptance_failures.append("ZERO_CONTROL_MOVED")
	else:
		if rise_tick < 0:
			acceptance_failures.append("NINETY_PERCENT_RISE_NOT_REACHED")
		if settling_tick < 0:
			acceptance_failures.append("SETTLING_NOT_REACHED")
		if overshoot_fraction > 0.05:
			acceptance_failures.append("OVERSHOOT_EXCEEDED")
		if absf(target - final_angle) > settle_error:
			acceptance_failures.append("FINAL_POSITION_ERROR_EXCEEDED")
		if absf(final_rate) > settle_rate:
			acceptance_failures.append("FINAL_RATE_EXCEEDED")
	var result := {
		"schema_version": RESULT_SCHEMA_VERSION,
		"trial_id": contract["trial_id"],
		"configuration_sha256": contract["configuration_sha256"],
		"sample_count": samples.size(),
		"target_angle_rad": target,
		"initial_angle_rad": initial_angle,
		"final_angle_rad": final_angle,
		"final_rate_rad_s": final_rate,
		"rise_tick_90_percent": rise_tick,
		"settling_tick": settling_tick,
		"overshoot_fraction": overshoot_fraction,
		"max_abs_tracking_error_rad": max_abs_error,
		"max_abs_rate_rad_s": max_abs_rate,
		"max_controller_identity_error": max_controller_identity_error,
		"max_total_axis_angular_momentum_abs_n_m_s": max_momentum_abs,
		"max_pairing_residual_nm": max_pairing_residual,
		"max_anchor_error_m": max_anchor_error,
		"max_axis_error_rad": max_axis_error,
		"max_swing_residual_rad": max_swing_residual,
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
	return {
		"ok": true,
		"result": FrozenValueScript.snapshot(result),
	}


static func _verify_contract(contract: Dictionary) -> Dictionary:
	var configuration: Dictionary = {}
	for field in REQUIRED_FIELDS:
		if not contract.has(field):
			return _failure("UNLOADED_PD_CONTRACT_INCOMPLETE")
		configuration[field] = contract[field]
	var rebuilt := build(configuration)
	if not bool(rebuilt.get("ok", false)):
		return _failure("UNLOADED_PD_CONTRACT_INVALID", rebuilt)
	if (
		CanonicalJsonScript.stringify(rebuilt["contract"])
		!= CanonicalJsonScript.stringify(contract)
	):
		return _failure("UNLOADED_PD_CONTRACT_DIGEST_MISMATCH")
	return {"ok": true}


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() == 3:
		var raw: Array = value
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3(INF, INF, INF)


static func _positive_vector(value: Vector3) -> bool:
	return value.is_finite() and value.x > 0.0 and value.y > 0.0 and value.z > 0.0


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
