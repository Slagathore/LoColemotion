class_name LabTwoLinkChainAnalyzer
extends RefCounted

## L2.6 two-joint planar chain analyzer for fixed and free roots.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_SCHEMA_VERSION := "two_link_chain_configuration_v1"
const RESULT_SCHEMA_VERSION := "two_link_chain_analysis_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"trial_id",
	"root_mode",
	"physics_hz",
	"pulse_ticks",
	"coast_ticks",
	"joint_1_torque_nm",
	"joint_2_torque_nm",
	"root_mass_kg",
	"root_size_m",
	"link_1_mass_kg",
	"link_1_size_m",
	"link_2_mass_kg",
	"link_2_size_m",
	"gravity_enabled",
	"contact_enabled",
	"built_in_motors_enabled",
	"limits_enabled",
	"root_assistance_enabled",
]
const CLAIM_BOUNDARY := (
	"Exact gravity-off, contact-free planar two-joint chain fixtures only; the "
	+ "fixed-root case has an explicit frozen scaffold and the free-root case uses "
	+ "only paired internal torques. This proves no contact load bearing, standing, "
	+ "bracing, recovery, gait, or walking."
)


static func build(configuration: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var keys: Array = configuration.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		errors.append("TWO_LINK_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA_VERSION:
		errors.append("TWO_LINK_SCHEMA_UNSUPPORTED")
	if not _stable_id(String(configuration.get("trial_id", ""))):
		errors.append("TWO_LINK_TRIAL_ID_INVALID")
	if String(configuration.get("root_mode", "")) not in ["fixed", "free"]:
		errors.append("TWO_LINK_ROOT_MODE_INVALID")
	var hz := _positive_integer(configuration.get("physics_hz"))
	var pulse := _positive_integer(configuration.get("pulse_ticks"))
	var coast := _positive_integer(configuration.get("coast_ticks"))
	if hz < 60 or hz > 240 or pulse < 8 or coast < 4 or pulse + coast > hz:
		errors.append("TWO_LINK_SCHEDULE_INVALID")
	for field in [
		"joint_1_torque_nm",
		"joint_2_torque_nm",
	]:
		if not _finite_number(configuration.get(field)) or absf(float(configuration[field])) > 0.2:
			errors.append("%s_INVALID" % String(field).to_upper())
	for field in ["root_mass_kg", "link_1_mass_kg", "link_2_mass_kg"]:
		if not _finite_number(configuration.get(field)) or float(configuration[field]) <= 0.0:
			errors.append("%s_INVALID" % String(field).to_upper())
	for field in ["root_size_m", "link_1_size_m", "link_2_size_m"]:
		if not _positive_vector(_vector3(configuration.get(field))):
			errors.append("%s_INVALID" % String(field).to_upper())
	for flag in [
		"gravity_enabled",
		"contact_enabled",
		"built_in_motors_enabled",
		"limits_enabled",
		"root_assistance_enabled",
	]:
		if configuration.get(flag) != false:
			errors.append("%s_FORBIDDEN" % flag.to_upper())
	if not errors.is_empty():
		return {
			"ok": false,
			"failure_code": "TWO_LINK_CONFIGURATION_INVALID",
			"errors": errors,
		}
	var payload := configuration.duplicate(true)
	payload["expected_sample_count"] = pulse + coast
	payload["claim_boundary"] = CLAIM_BOUNDARY
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {"ok": true, "contract": FrozenValueScript.snapshot(payload)}


static func analyze(contract: Dictionary, samples: Array) -> Dictionary:
	var check := _verify_contract(contract)
	if not bool(check.get("ok", false)):
		return check
	if samples.size() != int(contract["expected_sample_count"]):
		return _failure("TWO_LINK_SAMPLE_COUNT_MISMATCH")
	var max_angle_1 := 0.0
	var max_angle_2 := 0.0
	var max_rate_1 := 0.0
	var max_rate_2 := 0.0
	var max_geometry_error := 0.0
	var max_pairing_residual := 0.0
	var max_total_momentum := 0.0
	var max_system_com_displacement := 0.0
	var final_root_displacement := 0.0
	var every_receipt_complete := true
	var every_joint_observation_valid := true
	var any_saturation := false
	var pulse_ticks := int(contract["pulse_ticks"])
	for index in samples.size():
		var value: Variant = samples[index]
		if not value is Dictionary:
			return _failure("TWO_LINK_SAMPLE_INVALID")
		var sample: Dictionary = value
		if int(sample.get("tick", -1)) != index:
			return _failure("TWO_LINK_TICK_MISMATCH")
		for field in [
			"requested_joint_1_nm",
			"applied_joint_1_nm",
			"requested_joint_2_nm",
			"applied_joint_2_nm",
			"joint_1_angle_rad",
			"joint_1_rate_rad_s",
			"joint_2_angle_rad",
			"joint_2_rate_rad_s",
			"joint_1_geometry_error",
			"joint_2_geometry_error",
			"max_pairing_residual_nm",
			"total_axis_angular_momentum_n_m_s",
			"system_com_displacement_m",
			"root_displacement_m",
		]:
			if not _finite_number(sample.get(field)):
				return _failure("TWO_LINK_SAMPLE_NONFINITE", {"sample": index, "field": field})
		var expected_1 := float(contract["joint_1_torque_nm"]) if index < pulse_ticks else 0.0
		var expected_2 := float(contract["joint_2_torque_nm"]) if index < pulse_ticks else 0.0
		if (
			absf(float(sample["requested_joint_1_nm"]) - expected_1) > 1.0e-12
			or absf(float(sample["requested_joint_2_nm"]) - expected_2) > 1.0e-12
			or absf(float(sample["applied_joint_1_nm"]) - expected_1) > 1.0e-6
			or absf(float(sample["applied_joint_2_nm"]) - expected_2) > 1.0e-6
		):
			return _failure("TWO_LINK_TORQUE_SCHEDULE_MISMATCH")
		max_angle_1 = maxf(max_angle_1, absf(float(sample["joint_1_angle_rad"])))
		max_angle_2 = maxf(max_angle_2, absf(float(sample["joint_2_angle_rad"])))
		max_rate_1 = maxf(max_rate_1, absf(float(sample["joint_1_rate_rad_s"])))
		max_rate_2 = maxf(max_rate_2, absf(float(sample["joint_2_rate_rad_s"])))
		max_geometry_error = maxf(
			max_geometry_error,
			maxf(float(sample["joint_1_geometry_error"]), float(sample["joint_2_geometry_error"]))
		)
		max_pairing_residual = maxf(max_pairing_residual, float(sample["max_pairing_residual_nm"]))
		max_total_momentum = maxf(
			max_total_momentum, absf(float(sample["total_axis_angular_momentum_n_m_s"]))
		)
		max_system_com_displacement = maxf(
			max_system_com_displacement, float(sample["system_com_displacement_m"])
		)
		final_root_displacement = float(sample["root_displacement_m"])
		every_receipt_complete = (
			int(sample.get("receipt_count", -1)) == 4
			and bool(sample.get("receipts_match_commands", false))
			and every_receipt_complete
		)
		every_joint_observation_valid = (
			bool(sample.get("joint_1_observation_valid", false))
			and bool(sample.get("joint_2_observation_valid", false))
			and every_joint_observation_valid
		)
		any_saturation = bool(sample.get("any_actuator_saturation", false)) or any_saturation
		if (
			int(sample.get("root_assistance_operation_count", -1)) != 0
			or String(sample.get("root_operation_class", "")) != "joint_1_pair_reaction"
		):
			return _failure("TWO_LINK_ROOT_ASSISTANCE_OR_CLASSIFICATION_INVALID")
	var acceptance_failures: Array[String] = []
	if not every_receipt_complete:
		acceptance_failures.append("EXECUTION_RECEIPT_INCOMPLETE")
	if not every_joint_observation_valid:
		acceptance_failures.append("JOINT_OBSERVATION_INVALID")
	if max_pairing_residual > 1.0e-9:
		acceptance_failures.append("TORQUE_PAIRING_RESIDUAL_EXCEEDED")
	if any_saturation:
		acceptance_failures.append("ACTUATOR_ENVELOPE_SATURATED")
	if max_geometry_error > 5.0e-3:
		acceptance_failures.append("TWO_LINK_GEOMETRY_ENVELOPE_EXCEEDED")
	if max_angle_1 > 1.5 or max_angle_2 > 1.5 or max_rate_1 > 20.0 or max_rate_2 > 20.0:
		acceptance_failures.append("TWO_LINK_STATE_ENVELOPE_EXCEEDED")
	if max_angle_1 < 0.01 or max_angle_2 < 0.01:
		acceptance_failures.append("TWO_LINK_RESPONSE_TOO_SMALL")
	if String(contract["root_mode"]) == "fixed":
		if final_root_displacement > 1.0e-6:
			acceptance_failures.append("FIXED_ROOT_MOVED")
	else:
		if max_total_momentum > 2.0e-4:
			acceptance_failures.append("FREE_ROOT_ANGULAR_MOMENTUM_DRIFT_EXCEEDED")
		if max_system_com_displacement > 2.0e-4:
			acceptance_failures.append("FREE_ROOT_CENTER_OF_MASS_DRIFT_EXCEEDED")
		if final_root_displacement < 1.0e-5:
			acceptance_failures.append("FREE_ROOT_DID_NOT_REACT")
	var result := {
		"schema_version": RESULT_SCHEMA_VERSION,
		"trial_id": contract["trial_id"],
		"configuration_sha256": contract["configuration_sha256"],
		"root_mode": contract["root_mode"],
		"sample_count": samples.size(),
		"max_joint_1_abs_angle_rad": max_angle_1,
		"max_joint_2_abs_angle_rad": max_angle_2,
		"max_joint_1_abs_rate_rad_s": max_rate_1,
		"max_joint_2_abs_rate_rad_s": max_rate_2,
		"max_joint_geometry_error": max_geometry_error,
		"max_pairing_residual_nm": max_pairing_residual,
		"max_total_axis_angular_momentum_abs_n_m_s": max_total_momentum,
		"max_system_com_displacement_m": max_system_com_displacement,
		"final_root_displacement_m": final_root_displacement,
		"all_execution_receipts_complete": every_receipt_complete,
		"all_joint_observations_valid": every_joint_observation_valid,
		"root_assistance_operation_count": 0,
		"root_operation_class": "joint_1_pair_reaction",
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
			return _failure("TWO_LINK_CONTRACT_INCOMPLETE")
		configuration[field] = contract[field]
	var rebuilt := build(configuration)
	if not bool(rebuilt.get("ok", false)):
		return _failure("TWO_LINK_CONTRACT_INVALID", rebuilt)
	if (
		CanonicalJsonScript.stringify(rebuilt["contract"])
		!= CanonicalJsonScript.stringify(contract)
	):
		return _failure("TWO_LINK_CONTRACT_DIGEST_MISMATCH")
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
