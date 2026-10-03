class_name LabSuspendedSwingAnalyzer
extends RefCounted
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Digest-bound L4.2/L4.5 fixed-root two-link swing contract.
##
## The root is materially frozen and no floor exists. The positive result is
## finite-actuator free-space endpoint placement with measured virtual-ground
## clearance and no collision contact. It is a prerequisite for BR10, not a
## catch step or support result.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "suspended_swing_configuration_v1"
const SUMMARY_SCHEMA := "suspended_swing_summary_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"physics_hz",
	"trial_ticks",
	"root_height_m",
	"root_mass_kg",
	"link_mass_kg",
	"link_length_m",
	"foot_radius_m",
	"initial_q1_rad",
	"target_q1_rad",
	"target_q2_rad",
	"joint_position_gain_nm_rad",
	"joint_velocity_gain_nm_s_rad",
	"target_position_tolerance_m",
	"target_rate_tolerance_m_s",
	"minimum_clearance_m",
	"predicted_reach_upper_s",
	"actuator_spec_sha256",
	"root_frozen_scaffold",
	"gravity_enabled",
	"contact_enabled",
	"built_in_motors_enabled",
	"joint_limits_enabled",
	"root_assist_enabled",
	"foot_pin_enabled",
	"pose_teleport_enabled",
	"automatic_creature_guidance_enabled",
]


static func build(configuration: Dictionary) -> Dictionary:
	if not _field_set_matches(configuration, REQUIRED_FIELDS):
		return _failure("SUSPENDED_SWING_CONFIGURATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("SUSPENDED_SWING_CONFIGURATION_SCHEMA_UNSUPPORTED")
	for field in ["physics_hz", "trial_ticks"]:
		if not configuration.get(field) is int or int(configuration[field]) <= 0:
			return _failure("SUSPENDED_SWING_POSITIVE_INTEGER_INVALID:%s" % field)
	if int(configuration["physics_hz"]) < 60 or int(configuration["physics_hz"]) > 240:
		return _failure("SUSPENDED_SWING_PHYSICS_HZ_INVALID")
	if int(configuration["trial_ticks"]) < int(configuration["physics_hz"]):
		return _failure("SUSPENDED_SWING_TRIAL_TOO_SHORT")
	for field in [
		"root_height_m",
		"root_mass_kg",
		"link_mass_kg",
		"link_length_m",
		"foot_radius_m",
		"initial_q1_rad",
		"target_q1_rad",
		"target_q2_rad",
		"joint_position_gain_nm_rad",
		"joint_velocity_gain_nm_s_rad",
		"target_position_tolerance_m",
		"target_rate_tolerance_m_s",
		"minimum_clearance_m",
		"predicted_reach_upper_s",
	]:
		if not _finite_number(configuration.get(field)):
			return _failure("SUSPENDED_SWING_NONFINITE:%s" % field)
	for field in [
		"root_height_m",
		"root_mass_kg",
		"link_mass_kg",
		"link_length_m",
		"foot_radius_m",
		"joint_position_gain_nm_rad",
		"joint_velocity_gain_nm_s_rad",
		"target_position_tolerance_m",
		"target_rate_tolerance_m_s",
		"minimum_clearance_m",
		"predicted_reach_upper_s",
	]:
		if float(configuration[field]) <= 0.0:
			return _failure("SUSPENDED_SWING_POSITIVE_VALUE_INVALID:%s" % field)
	if (
		float(configuration["foot_radius_m"]) >= 0.25 * float(configuration["link_length_m"])
		or absf(float(configuration["initial_q1_rad"])) >= 0.5 * PI
		or absf(float(configuration["target_q1_rad"])) >= 0.5 * PI
		or absf(float(configuration["target_q2_rad"])) >= PI
	):
		return _failure("SUSPENDED_SWING_GEOMETRY_OR_TARGET_INVALID")
	if (
		configuration.get("root_frozen_scaffold") != true
		or configuration.get("gravity_enabled") != true
		or configuration.get("contact_enabled") != false
	):
		return _failure("SUSPENDED_SWING_FIXTURE_MODE_INVALID")
	for forbidden in [
		"built_in_motors_enabled",
		"joint_limits_enabled",
		"root_assist_enabled",
		"foot_pin_enabled",
		"pose_teleport_enabled",
		"automatic_creature_guidance_enabled",
	]:
		if configuration.get(forbidden) != false:
			return _failure("SUSPENDED_SWING_FORBIDDEN_ASSIST_OR_AUTHORITY:%s" % forbidden)
	var actuator_sha := String(configuration.get("actuator_spec_sha256", ""))
	if (
		actuator_sha.length() != 71
		or not actuator_sha.begins_with("sha256:")
		or not actuator_sha.trim_prefix("sha256:").is_valid_hex_number(false)
	):
		return _failure("SUSPENDED_SWING_ACTUATOR_DIGEST_INVALID")
	var contract := configuration.duplicate(true)
	contract["initial_q2_rad"] = -2.0 * float(configuration["initial_q1_rad"])
	contract["target_foot_local_m"] = _endpoint(
		float(configuration["target_q1_rad"]),
		float(configuration["target_q2_rad"]),
		float(configuration["link_length_m"])
	)
	contract["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	contract["claim_boundary"] = (
		"Exact gravity-on, fixed-root, contact-free, two-link suspended swing only. "
		+ "Finite paired joint torques must place the endpoint inside the target tolerance "
		+ "while measured virtual-ground clearance remains positive. The root freeze is a "
		+ "material scaffold. This proves no touchdown, load, bearing, catch step, stance, "
		+ "free-3D bracing or standing, fall arrest, getting up, gait, walking, repair, or guidance."
	)
	return {"ok": true, "contract": FrozenValueScript.snapshot(contract)}


static func analyze(contract: Dictionary, summary: Dictionary) -> Dictionary:
	var verified := _verify_contract(contract)
	if not bool(verified.get("ok", false)):
		return verified
	if String(summary.get("schema_version", "")) != SUMMARY_SCHEMA:
		return _failure("SUSPENDED_SWING_SUMMARY_SCHEMA_INVALID")
	if (
		String(summary.get("configuration_sha256", "")) != String(contract["configuration_sha256"])
		or (
			String(summary.get("actuator_spec_sha256", ""))
			!= String(contract["actuator_spec_sha256"])
		)
	):
		return _failure("SUSPENDED_SWING_SUMMARY_DIGEST_MISMATCH")
	for field in [
		"executed_ticks",
		"first_target_tick",
		"final_target_error_m",
		"final_foot_speed_m_s",
		"minimum_clearance_m",
		"maximum_applied_torque_nm",
		"maximum_pairing_residual_nm",
		"actuator_saturation_count",
		"contact_observation_count",
		"root_assist_operation_count",
		"foot_pin_operation_count",
		"pose_teleport_operation_count",
		"automatic_creature_guidance_operation_count",
	]:
		if not _finite_number(summary.get(field)):
			return _failure("SUSPENDED_SWING_SUMMARY_NONFINITE_OR_MISSING:%s" % field)
	for field in [
		"fixture_complete",
		"root_frozen",
		"motors_disabled",
		"limits_disabled",
		"all_receipts_complete",
	]:
		if typeof(summary.get(field)) != TYPE_BOOL:
			return _failure("SUSPENDED_SWING_SUMMARY_BOOL_MISSING:%s" % field)
	var failures: Array[String] = []
	if (
		not bool(summary["fixture_complete"])
		or int(summary["executed_ticks"]) != int(contract["trial_ticks"])
		or not bool(summary["root_frozen"])
		or not bool(summary["motors_disabled"])
		or not bool(summary["limits_disabled"])
		or not bool(summary["all_receipts_complete"])
	):
		failures.append("SUSPENDED_SWING_FIXTURE_INTEGRITY")
	if (
		int(summary["first_target_tick"]) < 0
		or (
			float(summary["first_target_tick"]) / float(contract["physics_hz"])
			> float(contract["predicted_reach_upper_s"])
		)
		or float(summary["final_target_error_m"]) > float(contract["target_position_tolerance_m"])
		or float(summary["final_foot_speed_m_s"]) > float(contract["target_rate_tolerance_m_s"])
	):
		failures.append("SUSPENDED_SWING_TARGET_TRACKING")
	if (
		float(summary["minimum_clearance_m"]) < float(contract["minimum_clearance_m"])
		or int(summary["contact_observation_count"]) != 0
	):
		failures.append("SUSPENDED_SWING_CLEARANCE_OR_SCUFF")
	if (
		float(summary["maximum_pairing_residual_nm"]) > 1.0e-9
		or int(summary["actuator_saturation_count"]) != 0
	):
		failures.append("SUSPENDED_SWING_ACTUATOR_ENVELOPE")
	if (
		int(summary["root_assist_operation_count"]) != 0
		or int(summary["foot_pin_operation_count"]) != 0
		or int(summary["pose_teleport_operation_count"]) != 0
		or int(summary["automatic_creature_guidance_operation_count"]) != 0
	):
		failures.append("SUSPENDED_SWING_FORBIDDEN_INTERVENTION")
	var result := {
		"schema_version": "suspended_swing_analysis_v1",
		"configuration_sha256": contract["configuration_sha256"],
		"accepted": failures.is_empty(),
		"acceptance_failures": failures,
		"first_target_tick": summary["first_target_tick"],
		"measured_reach_time_s":
		(
			float(summary["first_target_tick"]) / float(contract["physics_hz"])
			if int(summary["first_target_tick"]) >= 0
			else -1.0
		),
		"predicted_reach_upper_s": contract["predicted_reach_upper_s"],
		"final_target_error_m": summary["final_target_error_m"],
		"minimum_clearance_m": summary["minimum_clearance_m"],
		"maximum_applied_torque_nm": summary["maximum_applied_torque_nm"],
		"claim_boundary": contract["claim_boundary"],
		"touchdown_established": false,
		"bearing_established": false,
		"catch_step_established": false,
	}
	result["result_sha256"] = CanonicalJsonScript.sha256(result)
	return {"ok": true, "result": FrozenValueScript.snapshot(result)}


static func _verify_contract(contract: Dictionary) -> Dictionary:
	var raw: Dictionary = {}
	for field in REQUIRED_FIELDS:
		if not contract.has(field):
			return _failure("SUSPENDED_SWING_CONTRACT_INCOMPLETE")
		raw[field] = contract[field]
	var rebuilt := build(raw)
	if not bool(rebuilt.get("ok", false)):
		return rebuilt
	if (
		CanonicalJsonScript.stringify(rebuilt["contract"])
		!= CanonicalJsonScript.stringify(contract)
	):
		return _failure("SUSPENDED_SWING_CONTRACT_DIGEST_MISMATCH")
	return {"ok": true}


static func _endpoint(q1: float, q2: float, length: float) -> Array:
	var q12 := q1 + q2
	return [
		length * sin(q1) + length * sin(q12),
		-length * cos(q1) - length * cos(q12),
	]


static func _field_set_matches(value: Dictionary, fields: Array[String]) -> bool:
	var actual: Array = value.keys()
	actual.sort()
	var expected: Array = fields.duplicate()
	expected.sort()
	return actual == expected


static func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _failure(code: String, details: Variant = null) -> Dictionary:
	return {"ok": false, "failure_code": code, "details": details}
