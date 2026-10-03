class_name LabActuatorEnvelopeAnalyzer
extends RefCounted

## L2.4 one-transition torque/speed/power feasibility oracle.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_SCHEMA_VERSION := "actuator_envelope_case_configuration_v1"
const RESULT_SCHEMA_VERSION := "actuator_envelope_case_analysis_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"case_id",
	"physics_hz",
	"requested_torque_nm",
	"initial_relative_rate_rad_s",
	"max_isometric_torque_nm",
	"no_load_speed_rad_s",
	"max_positive_power_w",
	"max_absorption_power_w",
	"max_eccentric_multiplier",
	"parent_mass_kg",
	"parent_size_m",
	"child_mass_kg",
	"child_size_m",
	"gravity_enabled",
	"contact_enabled",
	"built_in_motor_enabled",
	"limit_enabled",
]
const CLAIM_BOUNDARY := (
	"Exact one-transition, gravity-off, contact-free free-hinge actuator-envelope "
	+ "fixture only; no endurance, load bearing, standing, bracing, recovery, "
	+ "gait, or walking claim."
)


static func build(configuration: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var keys: Array = configuration.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		errors.append("ACTUATOR_ENVELOPE_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA_VERSION:
		errors.append("ACTUATOR_ENVELOPE_SCHEMA_UNSUPPORTED")
	if not _stable_id(String(configuration.get("case_id", ""))):
		errors.append("ACTUATOR_ENVELOPE_CASE_ID_INVALID")
	var physics_hz := _positive_integer(configuration.get("physics_hz"))
	if physics_hz < 60 or physics_hz > 240:
		errors.append("ACTUATOR_ENVELOPE_PHYSICS_HZ_INVALID")
	for field in [
		"max_isometric_torque_nm",
		"no_load_speed_rad_s",
		"max_positive_power_w",
		"max_absorption_power_w",
		"parent_mass_kg",
		"child_mass_kg",
	]:
		if not _finite_number(configuration.get(field)) or float(configuration[field]) <= 0.0:
			errors.append("%s_INVALID" % String(field).to_upper())
	for field in ["requested_torque_nm", "initial_relative_rate_rad_s"]:
		if not _finite_number(configuration.get(field)):
			errors.append("%s_INVALID" % String(field).to_upper())
	if absf(float(configuration.get("requested_torque_nm", INF))) > 5.0:
		errors.append("ACTUATOR_ENVELOPE_REQUEST_OUTSIDE_DOMAIN")
	if absf(float(configuration.get("initial_relative_rate_rad_s", INF))) > 20.0:
		errors.append("ACTUATOR_ENVELOPE_RATE_OUTSIDE_DOMAIN")
	var eccentric := float(configuration.get("max_eccentric_multiplier", NAN))
	if not is_finite(eccentric) or eccentric < 1.0 or eccentric > 3.0:
		errors.append("ACTUATOR_ENVELOPE_ECCENTRIC_MULTIPLIER_INVALID")
	var parent_size := _vector3(configuration.get("parent_size_m"))
	var child_size := _vector3(configuration.get("child_size_m"))
	if not _positive_vector(parent_size) or not _positive_vector(child_size):
		errors.append("ACTUATOR_ENVELOPE_BODY_SIZE_INVALID")
	for flag in [
		"gravity_enabled",
		"contact_enabled",
		"built_in_motor_enabled",
		"limit_enabled",
	]:
		if configuration.get(flag) != false:
			errors.append("%s_FORBIDDEN" % flag.to_upper())
	if not errors.is_empty():
		return {
			"ok": false,
			"failure_code": "ACTUATOR_ENVELOPE_CONFIGURATION_INVALID",
			"errors": errors,
		}
	var request := float(configuration["requested_torque_nm"])
	var rate := float(configuration["initial_relative_rate_rad_s"])
	var max_iso := float(configuration["max_isometric_torque_nm"])
	var speed_ratio := absf(rate) / float(configuration["no_load_speed_rad_s"])
	var negative_work := request * rate < -1.0e-9
	var work_regime := "isometric"
	if request * rate > 1.0e-9:
		work_regime = "positive_work"
	elif negative_work:
		work_regime = "negative_work"
	var speed_factor := clampf(1.0 - speed_ratio, 0.0, 1.0)
	if negative_work:
		speed_factor = minf(eccentric, 1.0 + 0.25 * speed_ratio)
	var speed_cap := max_iso * speed_factor
	var selected_power := (
		float(configuration["max_absorption_power_w"])
		if negative_work
		else float(configuration["max_positive_power_w"])
	)
	var power_cap := max_iso
	if absf(rate) > 0.001:
		power_cap = selected_power / absf(rate)
	var direction_cap := minf(speed_cap, power_cap)
	if work_regime == "isometric":
		direction_cap = max_iso
	var expected_applied := clampf(request, -direction_cap, direction_cap)
	var parent_inertia := (
		float(configuration["parent_mass_kg"])
		* (parent_size.x * parent_size.x + parent_size.y * parent_size.y)
		/ 12.0
	)
	var child_inertia := (
		float(configuration["child_mass_kg"])
		* (child_size.x * child_size.x + child_size.y * child_size.y)
		/ 12.0
	)
	var payload := configuration.duplicate(true)
	payload["expected_work_regime"] = work_regime
	payload["expected_speed_cap_nm"] = speed_cap
	payload["expected_power_cap_nm"] = power_cap
	payload["expected_direction_cap_nm"] = direction_cap
	payload["expected_applied_torque_nm"] = expected_applied
	payload["expected_speed_limited"] = (
		work_regime != "isometric" and speed_cap <= power_cap + 1.0e-9 and absf(request) > speed_cap
	)
	payload["expected_power_limited"] = (
		work_regime != "isometric" and power_cap <= speed_cap + 1.0e-9 and absf(request) > power_cap
	)
	payload["analytic_parent_axis_inertia_kg_m2"] = parent_inertia
	payload["analytic_child_axis_inertia_kg_m2"] = child_inertia
	payload["claim_boundary"] = CLAIM_BOUNDARY
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {"ok": true, "contract": FrozenValueScript.snapshot(payload)}


static func analyze(contract: Dictionary, sample: Dictionary) -> Dictionary:
	var check := _verify_contract(contract)
	if not bool(check.get("ok", false)):
		return check
	for field in [
		"initial_relative_rate_rad_s",
		"requested_torque_nm",
		"applied_torque_nm",
		"relative_rate_after_rad_s",
		"pairing_residual_nm",
		"anchor_error_m",
		"axis_error_rad",
		"swing_residual_rad",
		"off_axis_rate_rad_s",
	]:
		if not _finite_number(sample.get(field)):
			return _failure("ACTUATOR_ENVELOPE_SAMPLE_NONFINITE", {"field": field})
	var initial_rate := float(sample["initial_relative_rate_rad_s"])
	var applied := float(sample["applied_torque_nm"])
	var step_s := 1.0 / float(contract["physics_hz"])
	var expected_delta := (
		applied
		* (
			1.0 / float(contract["analytic_parent_axis_inertia_kg_m2"])
			+ 1.0 / float(contract["analytic_child_axis_inertia_kg_m2"])
		)
		* step_s
	)
	var measured_delta := float(sample["relative_rate_after_rad_s"]) - initial_rate
	var delta_error_fraction := (
		absf(measured_delta - expected_delta) / maxf(absf(expected_delta), 1.0e-9)
		if absf(expected_delta) > 1.0e-9
		else absf(measured_delta)
	)
	var acceptance_failures: Array[String] = []
	if (
		absf(initial_rate - float(contract["initial_relative_rate_rad_s"])) > 1.0e-5
		or (
			absf(float(sample["requested_torque_nm"]) - float(contract["requested_torque_nm"]))
			> 1.0e-9
		)
	):
		acceptance_failures.append("ACTUATOR_ENVELOPE_INPUT_TRACE_MISMATCH")
	if absf(applied - float(contract["expected_applied_torque_nm"])) > 1.0e-5:
		acceptance_failures.append("ACTUATOR_ENVELOPE_APPLIED_CAP_MISMATCH")
	if String(sample.get("selected_work_regime", "")) != String(contract["expected_work_regime"]):
		acceptance_failures.append("ACTUATOR_ENVELOPE_WORK_REGIME_MISMATCH")
	if bool(sample.get("speed_limited", false)) != bool(contract["expected_speed_limited"]):
		acceptance_failures.append("ACTUATOR_ENVELOPE_SPEED_LIMIT_CLASS_MISMATCH")
	if bool(sample.get("power_limited", false)) != bool(contract["expected_power_limited"]):
		acceptance_failures.append("ACTUATOR_ENVELOPE_POWER_LIMIT_CLASS_MISMATCH")
	if delta_error_fraction > 0.02:
		acceptance_failures.append("ACTUATOR_ENVELOPE_ACCELERATION_MISMATCH")
	if (
		int(sample.get("receipt_count", -1)) != 2
		or not bool(sample.get("receipts_match_command", false))
	):
		acceptance_failures.append("EXECUTION_RECEIPT_INCOMPLETE")
	if float(sample["pairing_residual_nm"]) > 1.0e-9:
		acceptance_failures.append("TORQUE_PAIRING_RESIDUAL_EXCEEDED")
	if not bool(sample.get("joint_observation_valid", false)):
		acceptance_failures.append("JOINT_OBSERVATION_INVALID")
	if (
		float(sample["anchor_error_m"]) > 5.0e-3
		or float(sample["axis_error_rad"]) > 2.0e-2
		or float(sample["swing_residual_rad"]) > 2.0e-2
		or float(sample["off_axis_rate_rad_s"]) > 5.0e-2
	):
		acceptance_failures.append("JOINT_GEOMETRY_ENVELOPE_EXCEEDED")
	var result := {
		"schema_version": RESULT_SCHEMA_VERSION,
		"case_id": contract["case_id"],
		"configuration_sha256": contract["configuration_sha256"],
		"initial_relative_rate_rad_s": initial_rate,
		"requested_torque_nm": sample["requested_torque_nm"],
		"expected_applied_torque_nm": contract["expected_applied_torque_nm"],
		"applied_torque_nm": applied,
		"expected_speed_cap_nm": contract["expected_speed_cap_nm"],
		"expected_power_cap_nm": contract["expected_power_cap_nm"],
		"selected_work_regime": sample["selected_work_regime"],
		"speed_limited": sample["speed_limited"],
		"power_limited": sample["power_limited"],
		"measured_relative_rate_delta_rad_s": measured_delta,
		"expected_relative_rate_delta_rad_s": expected_delta,
		"relative_rate_delta_error_fraction": delta_error_fraction,
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
			return _failure("ACTUATOR_ENVELOPE_CONTRACT_INCOMPLETE")
		configuration[field] = contract[field]
	var rebuilt := build(configuration)
	if not bool(rebuilt.get("ok", false)):
		return _failure("ACTUATOR_ENVELOPE_CONTRACT_INVALID", rebuilt)
	if (
		CanonicalJsonScript.stringify(rebuilt["contract"])
		!= CanonicalJsonScript.stringify(contract)
	):
		return _failure("ACTUATOR_ENVELOPE_CONTRACT_DIGEST_MISMATCH")
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


static func _positive_integer(value: Variant) -> int:
	if value is int and int(value) > 0:
		return int(value)
	if value is float and is_finite(value) and value > 0.0 and value == floor(value):
		return int(value)
	return -1


static func _stable_id(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[A-Za-z][A-Za-z0-9._-]{0,159}$")
	return expression.search(value) != null


static func _failure(code: String, details: Variant = null) -> Dictionary:
	return {"ok": false, "failure_code": code, "details": details}
