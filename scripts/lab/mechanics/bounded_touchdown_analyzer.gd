class_name LabBoundedTouchdownAnalyzer
extends RefCounted
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Digest-bound L4.6 fixed-root articulated touchdown contract.
##
## The positive result is intentionally narrow: one observed distal sphere
## lands on one known static floor with bounded approach speed and predicted
## local impulse, then supplies enough consecutive evidence for the explicit
## TOUCH -> LOAD -> BEARING coordinator. The local predicted impulse is a unary
## phase witness, not a per-foot load allocation or whole-creature support load.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "bounded_touchdown_configuration_v1"
const SUMMARY_SCHEMA := "bounded_touchdown_summary_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"physics_hz",
	"trial_ticks",
	"target_ramp_ticks",
	"root_height_m",
	"root_mass_kg",
	"link_mass_kg",
	"link_length_m",
	"foot_radius_m",
	"initial_q1_rad",
	"initial_q2_rad",
	"target_q1_rad",
	"target_q2_rad",
	"joint_position_gain_nm_rad",
	"joint_velocity_gain_nm_s_rad",
	"maximum_touchdown_approach_speed_m_s",
	"maximum_predicted_normal_load_n",
	"maximum_final_foot_speed_m_s",
	"maximum_final_horizontal_error_m",
	"maximum_penetration_m",
	"predicted_first_contact_upper_s",
	"contact_confirm_ticks",
	"load_confirm_ticks",
	"bearing_confirm_ticks",
	"load_enter_n",
	"bearing_enter_n",
	"maximum_separating_speed_m_s",
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
		return _failure("BOUNDED_TOUCHDOWN_CONFIGURATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("BOUNDED_TOUCHDOWN_CONFIGURATION_SCHEMA_UNSUPPORTED")
	for field in [
		"physics_hz",
		"trial_ticks",
		"target_ramp_ticks",
		"contact_confirm_ticks",
		"load_confirm_ticks",
		"bearing_confirm_ticks",
	]:
		if not configuration.get(field) is int or int(configuration[field]) <= 0:
			return _failure("BOUNDED_TOUCHDOWN_POSITIVE_INTEGER_INVALID:%s" % field)
	if (
		int(configuration["physics_hz"]) < 60
		or int(configuration["physics_hz"]) > 240
		or int(configuration["target_ramp_ticks"]) >= int(configuration["trial_ticks"])
	):
		return _failure("BOUNDED_TOUCHDOWN_TIMING_INVALID")
	for field in REQUIRED_FIELDS.slice(4, 27):
		if not _finite_number(configuration.get(field)):
			return _failure("BOUNDED_TOUCHDOWN_NONFINITE:%s" % field)
	for field in [
		"root_height_m",
		"root_mass_kg",
		"link_mass_kg",
		"link_length_m",
		"foot_radius_m",
		"joint_position_gain_nm_rad",
		"joint_velocity_gain_nm_s_rad",
		"maximum_touchdown_approach_speed_m_s",
		"maximum_predicted_normal_load_n",
		"maximum_final_foot_speed_m_s",
		"maximum_final_horizontal_error_m",
		"maximum_penetration_m",
		"predicted_first_contact_upper_s",
		"load_enter_n",
		"bearing_enter_n",
	]:
		if float(configuration[field]) <= 0.0:
			return _failure("BOUNDED_TOUCHDOWN_POSITIVE_VALUE_INVALID:%s" % field)
	if (
		float(configuration["foot_radius_m"]) >= 0.25 * float(configuration["link_length_m"])
		or absf(float(configuration["initial_q1_rad"])) >= 0.5 * PI
		or absf(float(configuration["initial_q2_rad"])) >= PI
		or absf(float(configuration["target_q1_rad"])) >= 0.5 * PI
		or absf(float(configuration["target_q2_rad"])) >= PI
		or (float(configuration["bearing_enter_n"]) < float(configuration["load_enter_n"]))
		or float(configuration["maximum_separating_speed_m_s"]) < 0.0
	):
		return _failure("BOUNDED_TOUCHDOWN_GEOMETRY_OR_THRESHOLD_INVALID")
	if (
		configuration.get("root_frozen_scaffold") != true
		or configuration.get("gravity_enabled") != true
		or configuration.get("contact_enabled") != true
	):
		return _failure("BOUNDED_TOUCHDOWN_FIXTURE_MODE_INVALID")
	for forbidden in [
		"built_in_motors_enabled",
		"joint_limits_enabled",
		"root_assist_enabled",
		"foot_pin_enabled",
		"pose_teleport_enabled",
		"automatic_creature_guidance_enabled",
	]:
		if configuration.get(forbidden) != false:
			return _failure("BOUNDED_TOUCHDOWN_FORBIDDEN_ASSIST_OR_AUTHORITY:%s" % forbidden)
	var actuator_sha := String(configuration.get("actuator_spec_sha256", ""))
	if (
		actuator_sha.length() != 71
		or not actuator_sha.begins_with("sha256:")
		or not actuator_sha.trim_prefix("sha256:").is_valid_hex_number(false)
	):
		return _failure("BOUNDED_TOUCHDOWN_ACTUATOR_DIGEST_INVALID")
	var initial_endpoint := _endpoint(
		float(configuration["initial_q1_rad"]),
		float(configuration["initial_q2_rad"]),
		float(configuration["link_length_m"])
	)
	var target_endpoint := _endpoint(
		float(configuration["target_q1_rad"]),
		float(configuration["target_q2_rad"]),
		float(configuration["link_length_m"])
	)
	if (
		(
			float(configuration["root_height_m"]) + float(initial_endpoint[1])
			<= float(configuration["foot_radius_m"]) + 0.05
		)
		or (
			float(configuration["root_height_m"]) + float(target_endpoint[1])
			>= float(configuration["foot_radius_m"])
		)
	):
		return _failure("BOUNDED_TOUCHDOWN_LANDING_GEOMETRY_INVALID")
	var contract := configuration.duplicate(true)
	contract["initial_foot_local_m"] = initial_endpoint
	contract["target_foot_local_m"] = target_endpoint
	contract["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	contract["claim_boundary"] = (
		"Exact gravity-on, fixed-root, sagittal two-link known-floor touchdown only. "
		+ "One semantic distal sphere must make real Jolt contact below the preregistered "
		+ "approach-speed and predicted-local-load ceilings, then independently observed "
		+ "TOUCH, LOAD, and BEARING phases must occur in order. The root freeze is a "
		+ "material scaffold. The local raw predicted impulse is only a unary landing-phase "
		+ "witness: it is not a generalized per-foot allocation or whole-creature support "
		+ "measurement. This proves no reachable catch step, improved support polygon, "
		+ "free-3D bracing or standing, fall arrest, getting up, gait, walking, repair, or guidance."
	)
	return {"ok": true, "contract": FrozenValueScript.snapshot(contract)}


static func analyze(contract: Dictionary, summary: Dictionary) -> Dictionary:
	var verified := _verify_contract(contract)
	if not bool(verified.get("ok", false)):
		return verified
	if String(summary.get("schema_version", "")) != SUMMARY_SCHEMA:
		return _failure("BOUNDED_TOUCHDOWN_SUMMARY_SCHEMA_INVALID")
	if (
		String(summary.get("configuration_sha256", "")) != String(contract["configuration_sha256"])
		or (
			String(summary.get("actuator_spec_sha256", ""))
			!= String(contract["actuator_spec_sha256"])
		)
	):
		return _failure("BOUNDED_TOUCHDOWN_SUMMARY_DIGEST_MISMATCH")
	for field in [
		"executed_ticks",
		"first_touch_tick",
		"first_load_tick",
		"first_bearing_tick",
		"touchdown_approach_speed_m_s",
		"peak_predicted_local_normal_load_n",
		"final_foot_speed_m_s",
		"final_horizontal_error_m",
		"maximum_penetration_m",
		"maximum_applied_torque_nm",
		"maximum_pairing_residual_nm",
		"actuator_saturation_count",
		"non_distal_contact_count",
		"root_assist_operation_count",
		"foot_pin_operation_count",
		"pose_teleport_operation_count",
		"automatic_creature_guidance_operation_count",
	]:
		if not _finite_number(summary.get(field)):
			return _failure("BOUNDED_TOUCHDOWN_SUMMARY_NONFINITE_OR_MISSING:%s" % field)
	for field in [
		"fixture_complete",
		"root_frozen",
		"motors_disabled",
		"limits_disabled",
		"all_receipts_complete",
		"contact_capacity_complete",
		"target_arrival_used_for_phase_transition",
		"local_load_is_generalized_per_foot_allocation",
	]:
		if typeof(summary.get(field)) != TYPE_BOOL:
			return _failure("BOUNDED_TOUCHDOWN_SUMMARY_BOOL_MISSING:%s" % field)
	if not summary.get("phase_trace") is Array:
		return _failure("BOUNDED_TOUCHDOWN_PHASE_TRACE_MISSING")
	var failures: Array[String] = []
	if (
		not bool(summary["fixture_complete"])
		or int(summary["executed_ticks"]) != int(contract["trial_ticks"])
		or not bool(summary["root_frozen"])
		or not bool(summary["motors_disabled"])
		or not bool(summary["limits_disabled"])
		or not bool(summary["all_receipts_complete"])
		or not bool(summary["contact_capacity_complete"])
	):
		failures.append("BOUNDED_TOUCHDOWN_FIXTURE_INTEGRITY")
	if (
		int(summary["first_touch_tick"]) < 0
		or int(summary["first_load_tick"]) <= int(summary["first_touch_tick"])
		or int(summary["first_bearing_tick"]) <= int(summary["first_load_tick"])
		or String(summary.get("final_phase", "")) != "BEARING"
		or summary["phase_trace"] != ["TOUCH", "LOAD", "BEARING"]
		or bool(summary["target_arrival_used_for_phase_transition"])
	):
		failures.append("BOUNDED_TOUCHDOWN_PHASE_ORDER")
	if (
		(
			float(summary["touchdown_approach_speed_m_s"])
			> float(contract["maximum_touchdown_approach_speed_m_s"])
		)
		or (
			float(summary["peak_predicted_local_normal_load_n"])
			> float(contract["maximum_predicted_normal_load_n"])
		)
		or float(summary["final_foot_speed_m_s"]) > float(contract["maximum_final_foot_speed_m_s"])
		or (
			float(summary["final_horizontal_error_m"])
			> float(contract["maximum_final_horizontal_error_m"])
		)
		or float(summary["maximum_penetration_m"]) > float(contract["maximum_penetration_m"])
	):
		failures.append("BOUNDED_TOUCHDOWN_LANDING_ENVELOPE")
	if (
		(
			float(summary["first_touch_tick"]) / float(contract["physics_hz"])
			> float(contract["predicted_first_contact_upper_s"])
		)
		or int(summary["first_touch_tick"]) < int(contract["target_ramp_ticks"]) / 4
	):
		failures.append("BOUNDED_TOUCHDOWN_REACH_CLOCK")
	if (
		int(summary["non_distal_contact_count"]) != 0
		or bool(summary["local_load_is_generalized_per_foot_allocation"])
	):
		failures.append("BOUNDED_TOUCHDOWN_CONTACT_SEMANTICS")
	if (
		float(summary["maximum_pairing_residual_nm"]) > 1.0e-9
		or int(summary["actuator_saturation_count"]) != 0
	):
		failures.append("BOUNDED_TOUCHDOWN_ACTUATOR_ENVELOPE")
	if (
		int(summary["root_assist_operation_count"]) != 0
		or int(summary["foot_pin_operation_count"]) != 0
		or int(summary["pose_teleport_operation_count"]) != 0
		or int(summary["automatic_creature_guidance_operation_count"]) != 0
	):
		failures.append("BOUNDED_TOUCHDOWN_FORBIDDEN_INTERVENTION")
	var result := {
		"schema_version": "bounded_touchdown_analysis_v1",
		"configuration_sha256": contract["configuration_sha256"],
		"accepted": failures.is_empty(),
		"acceptance_failures": failures,
		"first_touch_tick": summary["first_touch_tick"],
		"first_load_tick": summary["first_load_tick"],
		"first_bearing_tick": summary["first_bearing_tick"],
		"measured_first_contact_s":
		float(summary["first_touch_tick"]) / float(contract["physics_hz"]),
		"predicted_first_contact_upper_s": contract["predicted_first_contact_upper_s"],
		"touchdown_approach_speed_m_s": summary["touchdown_approach_speed_m_s"],
		"peak_predicted_local_normal_load_n": summary["peak_predicted_local_normal_load_n"],
		"claim_boundary": contract["claim_boundary"],
		"touchdown_established": failures.is_empty(),
		"known_landing_bearing_established": failures.is_empty(),
		"local_load_is_generalized_per_foot_allocation": false,
		"catch_step_established": false,
		"support_polygon_improvement_established": false,
	}
	result["result_sha256"] = CanonicalJsonScript.sha256(result)
	return {"ok": true, "result": FrozenValueScript.snapshot(result)}


static func _verify_contract(contract: Dictionary) -> Dictionary:
	var raw: Dictionary = {}
	for field in REQUIRED_FIELDS:
		if not contract.has(field):
			return _failure("BOUNDED_TOUCHDOWN_CONTRACT_INCOMPLETE")
		raw[field] = contract[field]
	var rebuilt := build(raw)
	if not bool(rebuilt.get("ok", false)):
		return rebuilt
	if (
		CanonicalJsonScript.stringify(rebuilt["contract"])
		!= CanonicalJsonScript.stringify(contract)
	):
		return _failure("BOUNDED_TOUCHDOWN_CONTRACT_DIGEST_MISMATCH")
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


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
