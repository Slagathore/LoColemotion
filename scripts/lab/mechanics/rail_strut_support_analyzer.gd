class_name LabRailStrutSupportAnalyzer
extends RefCounted

## Digest-bound L4.0 oracle for one rigid compound strut on an explicit
## vertical rail. The rail is a declared scaffold, and the result never
## promotes aggregate external support into a per-foot contact wrench.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "rail_strut_support_configuration_v1"
const REQUIRED_MODES: Array[String] = [
	"freefall_no_floor",
	"supported_floor",
]
const CLAIM_BOUNDARY := (
	"L4.0 rigid compound strut on one explicit Generic6DOF vertical rail only. "
	+ "The no-floor control tests whether the rail leaves world-Y translation free, and the "
	+ "floor cell measures aggregate external support carried by rigid geometry with zero "
	+ "active or passive work. It establishes no joint torque, articulated load-bearing limb, "
	+ "crouch, rise, disturbance recovery, standing, bracing, gait, or walking."
)
const ALLOWED_FIELDS: Array[String] = [
	"schema_version",
	"physics_hz",
	"freefall_ticks",
	"settle_ticks",
	"analysis_ticks",
	"body_mass_kg",
	"maximum_freefall_velocity_error_mps",
	"maximum_freefall_external_load_n",
	"maximum_supported_load_error_n",
	"maximum_supported_vertical_speed_mps",
	"maximum_lateral_drift_m",
	"maximum_tilt_rad",
	"minimum_floor_contact_fraction",
	"built_in_motors_enabled",
	"joint_springs_enabled",
	"passive_tissues_enabled",
	"controller_root_force_enabled",
]


static func build(configuration: Dictionary) -> Dictionary:
	var reasons: Array[String] = []
	for key_value in configuration:
		if String(key_value) not in ALLOWED_FIELDS:
			reasons.append("RAIL_STRUT_CONFIG_UNKNOWN_FIELD:%s" % String(key_value))
	for field in ALLOWED_FIELDS:
		if not configuration.has(field):
			reasons.append("RAIL_STRUT_CONFIG_FIELD_MISSING:%s" % field)
	if not reasons.is_empty():
		return _failure("RAIL_STRUT_CONFIG_INVALID", reasons)
	if String(configuration["schema_version"]) != SCHEMA_VERSION:
		reasons.append("RAIL_STRUT_SCHEMA_INVALID")
	for field in ["physics_hz", "freefall_ticks", "settle_ticks", "analysis_ticks"]:
		if (
			typeof(configuration[field]) not in [TYPE_INT, TYPE_FLOAT]
			or float(configuration[field]) != floorf(float(configuration[field]))
			or int(configuration[field]) <= 0
		):
			reasons.append("RAIL_STRUT_POSITIVE_INTEGER_INVALID:%s" % field)
	for field in [
		"body_mass_kg",
		"maximum_freefall_velocity_error_mps",
		"maximum_freefall_external_load_n",
		"maximum_supported_load_error_n",
		"maximum_supported_vertical_speed_mps",
		"maximum_lateral_drift_m",
		"maximum_tilt_rad",
		"minimum_floor_contact_fraction",
	]:
		if (
			typeof(configuration[field]) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(configuration[field]))
			or float(configuration[field]) < 0.0
		):
			reasons.append("RAIL_STRUT_FINITE_NONNEGATIVE_INVALID:%s" % field)
	if float(configuration["body_mass_kg"]) <= 0.0:
		reasons.append("RAIL_STRUT_BODY_MASS_INVALID")
	if (
		float(configuration["minimum_floor_contact_fraction"]) <= 0.0
		or float(configuration["minimum_floor_contact_fraction"]) > 1.0
	):
		reasons.append("RAIL_STRUT_CONTACT_FRACTION_INVALID")
	for field in [
		"built_in_motors_enabled",
		"joint_springs_enabled",
		"passive_tissues_enabled",
		"controller_root_force_enabled",
	]:
		if typeof(configuration[field]) != TYPE_BOOL or bool(configuration[field]):
			reasons.append("RAIL_STRUT_FORBIDDEN_ASSIST:%s" % field)
	if not reasons.is_empty():
		return _failure("RAIL_STRUT_CONFIG_INVALID", reasons)
	var sealed := configuration.duplicate(true)
	sealed["configuration_sha256"] = CanonicalJsonScript.sha256(sealed)
	return {"ok": true, "configuration": FrozenValueScript.snapshot(sealed)}


static func analyze(configuration: Dictionary, summaries: Array) -> Dictionary:
	var digest_result := _verify_digest(configuration)
	if not bool(digest_result.get("ok", false)):
		return digest_result
	if summaries.size() != REQUIRED_MODES.size():
		return _failure(
			"RAIL_STRUT_SUMMARY_COUNT_MISMATCH",
			["expected=%d actual=%d" % [REQUIRED_MODES.size(), summaries.size()]]
		)
	var reasons: Array[String] = []
	var by_mode: Dictionary = {}
	for summary_value in summaries:
		if summary_value is not Dictionary:
			reasons.append("RAIL_STRUT_SUMMARY_NOT_OBJECT")
			continue
		var summary: Dictionary = summary_value
		var mode := String(summary.get("mode", ""))
		if mode not in REQUIRED_MODES or by_mode.has(mode):
			reasons.append("RAIL_STRUT_MODE_INVALID_OR_DUPLICATE:%s" % mode)
			continue
		if not _summary_finite(summary):
			reasons.append("RAIL_STRUT_SUMMARY_NONFINITE:%s" % mode)
			continue
		by_mode[mode] = summary
	for mode in REQUIRED_MODES:
		if not by_mode.has(mode):
			reasons.append("RAIL_STRUT_MODE_MISSING:%s" % mode)
	if not reasons.is_empty():
		return _failure("RAIL_STRUT_SUMMARY_INVALID", reasons)

	var freefall: Dictionary = by_mode["freefall_no_floor"]
	var supported: Dictionary = by_mode["supported_floor"]
	if int(freefall["valid_sample_count"]) != int(configuration["freefall_ticks"]):
		reasons.append("RAIL_STRUT_FREEFALL_SAMPLE_COUNT")
	if int(supported["valid_sample_count"]) != int(configuration["analysis_ticks"]):
		reasons.append("RAIL_STRUT_SUPPORTED_SAMPLE_COUNT")
	for summary in [freefall, supported]:
		var mode := String(summary["mode"])
		if (
			not bool(summary["rail_contract_exact"])
			or not bool(summary["vertical_axis_unlocked"])
			or not bool(summary["horizontal_axes_locked"])
			or not bool(summary["all_rotations_locked"])
			or not bool(summary["motors_disabled"])
			or not bool(summary["springs_disabled"])
			or int(summary["active_operation_count"]) != 0
			or int(summary["passive_operation_count"]) != 0
			or int(summary["controller_root_force_count"]) != 0
		):
			reasons.append("RAIL_STRUT_SCAFFOLD_OR_ASSIST_INVALID:%s" % mode)
	if bool(freefall["floor_present"]) or float(freefall["floor_contact_fraction"]) != 0.0:
		reasons.append("RAIL_STRUT_FREEFALL_FLOOR_CONTAMINATION")
	if not bool(supported["floor_present"]):
		reasons.append("RAIL_STRUT_SUPPORTED_FLOOR_MISSING")
	if (
		float(freefall["vertical_velocity_error_mps"])
		> float(configuration["maximum_freefall_velocity_error_mps"])
	):
		reasons.append("RAIL_STRUT_FREEFALL_GRAVITY_MISMATCH")
	if (
		absf(float(freefall["mean_reconstructed_external_normal_load_n"]))
		> float(configuration["maximum_freefall_external_load_n"])
	):
		reasons.append("RAIL_STRUT_FREEFALL_RAIL_VERTICAL_REACTION")
	if (
		float(supported["maximum_support_load_error_n"])
		> float(configuration["maximum_supported_load_error_n"])
	):
		reasons.append("RAIL_STRUT_SUPPORTED_LOAD_MISMATCH")
	if (
		absf(float(supported["final_vertical_speed_mps"]))
		> float(configuration["maximum_supported_vertical_speed_mps"])
	):
		reasons.append("RAIL_STRUT_SUPPORTED_VERTICAL_SPEED")
	if (
		float(supported["floor_contact_fraction"])
		< float(configuration["minimum_floor_contact_fraction"])
	):
		reasons.append("RAIL_STRUT_SUPPORTED_CONTACT_INCOMPLETE")
	for summary in [freefall, supported]:
		var mode := String(summary["mode"])
		if (
			float(summary["maximum_lateral_drift_m"])
			> float(configuration["maximum_lateral_drift_m"])
		):
			reasons.append("RAIL_STRUT_LATERAL_DRIFT:%s" % mode)
		if float(summary["maximum_tilt_rad"]) > float(configuration["maximum_tilt_rad"]):
			reasons.append("RAIL_STRUT_TILT:%s" % mode)
	var accepted := reasons.is_empty()
	return {
		"ok": true,
		"accepted": accepted,
		"acceptance_failures": reasons,
		"claim_boundary": CLAIM_BOUNDARY,
		"does_not_establish":
		[
			"joint_torque",
			"articulated_load_bearing_limb",
			"crouch_or_rise",
			"vertical_disturbance_recovery",
			"standing",
			"bracing",
			"gait",
			"walking",
			"per_foot_load_allocation",
			"automatic_creature_guidance",
		],
		"freefall_vertical_velocity_error_mps": freefall["vertical_velocity_error_mps"],
		"freefall_mean_external_normal_load_n":
		freefall["mean_reconstructed_external_normal_load_n"],
		"supported_mean_external_normal_load_n":
		supported["mean_reconstructed_external_normal_load_n"],
		"supported_expected_weight_n": supported["expected_weight_n"],
		"supported_maximum_load_error_n": supported["maximum_support_load_error_n"],
		"supported_floor_contact_fraction": supported["floor_contact_fraction"],
		"rail_scaffold_present": true,
		"motor_or_passive_work_present": false,
	}


static func _verify_digest(configuration: Dictionary) -> Dictionary:
	if String(configuration.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("RAIL_STRUT_CONFIG_DIGEST_MISMATCH", ["schema"])
	var payload := configuration.duplicate(true)
	var recorded := String(payload.get("configuration_sha256", ""))
	payload.erase("configuration_sha256")
	if recorded.is_empty() or recorded != CanonicalJsonScript.sha256(payload):
		return _failure("RAIL_STRUT_CONFIG_DIGEST_MISMATCH", ["digest"])
	var rebuilt := build(payload)
	if (
		not bool(rebuilt.get("ok", false))
		or String((rebuilt["configuration"] as Dictionary)["configuration_sha256"]) != recorded
	):
		return _failure("RAIL_STRUT_CONFIG_DIGEST_MISMATCH", ["semantic"])
	return {"ok": true}


static func _summary_finite(summary: Dictionary) -> bool:
	var required := [
		"mode",
		"valid_sample_count",
		"floor_present",
		"floor_contact_fraction",
		"expected_weight_n",
		"expected_delta_velocity_mps",
		"observed_delta_velocity_mps",
		"vertical_velocity_error_mps",
		"mean_reconstructed_external_normal_load_n",
		"maximum_support_load_error_n",
		"final_vertical_speed_mps",
		"maximum_lateral_drift_m",
		"maximum_tilt_rad",
		"rail_contract_exact",
		"vertical_axis_unlocked",
		"horizontal_axes_locked",
		"all_rotations_locked",
		"motors_disabled",
		"springs_disabled",
		"active_operation_count",
		"passive_operation_count",
		"controller_root_force_count",
	]
	for field in required:
		if not summary.has(field):
			return false
	for field in [
		"floor_contact_fraction",
		"expected_weight_n",
		"expected_delta_velocity_mps",
		"observed_delta_velocity_mps",
		"vertical_velocity_error_mps",
		"mean_reconstructed_external_normal_load_n",
		"maximum_support_load_error_n",
		"final_vertical_speed_mps",
		"maximum_lateral_drift_m",
		"maximum_tilt_rad",
	]:
		if typeof(summary[field]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(summary[field])):
			return false
	return true


static func _failure(code: String, reasons: Array) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"invalid_reasons": reasons,
	}
