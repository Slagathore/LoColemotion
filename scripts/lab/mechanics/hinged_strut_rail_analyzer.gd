class_name LabHingedStrutRailAnalyzer
extends RefCounted
# gdlint: disable=max-line-length

## Digest-bound L4.1 static loaded-hinge curve on the explicit vertical rail.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "hinged_strut_rail_configuration_v1"
const REQUIRED_ANGLES_DEG := [0.0, 15.0, 30.0, 45.0]
const CLAIM_BOUNDARY := (
	"L4.1 one-hinge strut on an explicit vertical rail with an ordinary frictionless "
	+ "distal floor contact only. A declared feedforward moment and separately tagged "
	+ "joint-space stabilization term are applied as equal-and-opposite finite actuator "
	+ "torques; the settled total is compared with static moment balance at four exact "
	+ "angles and with a zero-torque negative control. This establishes no two-link leg, "
	+ "free-root balance, crouch, rise, disturbance recovery, standing, bracing, gait, "
	+ "or walking."
)
const ALLOWED_FIELDS: Array[String] = [
	"schema_version",
	"physics_hz",
	"settle_ticks",
	"analysis_ticks",
	"angles_deg",
	"control_angle_deg",
	"carriage_mass_kg",
	"link_mass_kg",
	"link_length_m",
	"maximum_torque_error_nm",
	"maximum_support_load_error_n",
	"maximum_angle_error_rad",
	"maximum_height_drift_m",
	"maximum_joint_rate_rad_s",
	"minimum_floor_contact_fraction",
	"maximum_abs_hold_work_j",
	"minimum_control_angle_error_rad",
	"hold_position_gain_nm_rad",
	"hold_velocity_gain_nm_s_rad",
	"built_in_motor_enabled",
	"hinge_limit_enabled",
	"passive_tissues_enabled",
	"controller_root_force_enabled",
]


static func build(configuration: Dictionary) -> Dictionary:
	var reasons: Array[String] = []
	for key_value in configuration:
		if String(key_value) not in ALLOWED_FIELDS:
			reasons.append("HINGED_STRUT_CONFIG_UNKNOWN_FIELD:%s" % String(key_value))
	for field in ALLOWED_FIELDS:
		if not configuration.has(field):
			reasons.append("HINGED_STRUT_CONFIG_FIELD_MISSING:%s" % field)
	if not reasons.is_empty():
		return _failure("HINGED_STRUT_CONFIG_INVALID", reasons)
	if String(configuration["schema_version"]) != SCHEMA_VERSION:
		reasons.append("HINGED_STRUT_SCHEMA_INVALID")
	var angles_value: Variant = configuration["angles_deg"]
	if angles_value is not Array or angles_value != REQUIRED_ANGLES_DEG:
		reasons.append("HINGED_STRUT_ANGLE_GRID_INVALID")
	for field in ["physics_hz", "settle_ticks", "analysis_ticks"]:
		if (
			typeof(configuration[field]) not in [TYPE_INT, TYPE_FLOAT]
			or float(configuration[field]) != floorf(float(configuration[field]))
			or int(configuration[field]) <= 0
		):
			reasons.append("HINGED_STRUT_POSITIVE_INTEGER_INVALID:%s" % field)
	for field in [
		"control_angle_deg",
		"carriage_mass_kg",
		"link_mass_kg",
		"link_length_m",
		"maximum_torque_error_nm",
		"maximum_support_load_error_n",
		"maximum_angle_error_rad",
		"maximum_height_drift_m",
		"maximum_joint_rate_rad_s",
		"minimum_floor_contact_fraction",
		"maximum_abs_hold_work_j",
		"minimum_control_angle_error_rad",
		"hold_position_gain_nm_rad",
		"hold_velocity_gain_nm_s_rad",
	]:
		if (
			typeof(configuration[field]) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(configuration[field]))
			or float(configuration[field]) < 0.0
		):
			reasons.append("HINGED_STRUT_FINITE_NONNEGATIVE_INVALID:%s" % field)
	for field in ["carriage_mass_kg", "link_mass_kg", "link_length_m"]:
		if float(configuration[field]) <= 0.0:
			reasons.append("HINGED_STRUT_POSITIVE_VALUE_INVALID:%s" % field)
	if float(configuration["control_angle_deg"]) not in REQUIRED_ANGLES_DEG:
		reasons.append("HINGED_STRUT_CONTROL_ANGLE_INVALID")
	if (
		float(configuration["minimum_floor_contact_fraction"]) <= 0.0
		or float(configuration["minimum_floor_contact_fraction"]) > 1.0
	):
		reasons.append("HINGED_STRUT_CONTACT_FRACTION_INVALID")
	for field in [
		"built_in_motor_enabled",
		"hinge_limit_enabled",
		"passive_tissues_enabled",
		"controller_root_force_enabled",
	]:
		if typeof(configuration[field]) != TYPE_BOOL or bool(configuration[field]):
			reasons.append("HINGED_STRUT_FORBIDDEN_ASSIST:%s" % field)
	if not reasons.is_empty():
		return _failure("HINGED_STRUT_CONFIG_INVALID", reasons)
	var sealed := configuration.duplicate(true)
	sealed["configuration_sha256"] = CanonicalJsonScript.sha256(sealed)
	return {"ok": true, "configuration": FrozenValueScript.snapshot(sealed)}


static func analyze(configuration: Dictionary, trials: Array) -> Dictionary:
	var digest := _verify_digest(configuration)
	if not bool(digest.get("ok", false)):
		return digest
	if trials.size() != REQUIRED_ANGLES_DEG.size() + 1:
		return _failure(
			"HINGED_STRUT_TRIAL_COUNT_MISMATCH",
			["expected=%d actual=%d" % [REQUIRED_ANGLES_DEG.size() + 1, trials.size()]]
		)
	var reasons: Array[String] = []
	var holds: Dictionary = {}
	var control: Dictionary = {}
	for trial_value in trials:
		if trial_value is not Dictionary:
			reasons.append("HINGED_STRUT_TRIAL_NOT_OBJECT")
			continue
		var trial: Dictionary = trial_value
		if not _trial_finite(trial):
			reasons.append("HINGED_STRUT_TRIAL_NONFINITE")
			continue
		var mode := String(trial["mode"])
		var angle := float(trial["target_angle_deg"])
		if mode == "analytic_hold":
			if angle not in REQUIRED_ANGLES_DEG or holds.has(angle):
				reasons.append("HINGED_STRUT_HOLD_ANGLE_INVALID_OR_DUPLICATE")
			else:
				holds[angle] = trial
		elif mode == "zero_torque_control":
			if not control.is_empty() or angle != float(configuration["control_angle_deg"]):
				reasons.append("HINGED_STRUT_CONTROL_INVALID_OR_DUPLICATE")
			else:
				control = trial
		else:
			reasons.append("HINGED_STRUT_MODE_INVALID:%s" % mode)
	if holds.size() != REQUIRED_ANGLES_DEG.size() or control.is_empty():
		reasons.append("HINGED_STRUT_GRID_INCOMPLETE")
	if not reasons.is_empty():
		return _failure("HINGED_STRUT_TRIAL_INVALID", reasons)

	var previous_torque := -INF
	for angle in REQUIRED_ANGLES_DEG:
		var hold: Dictionary = holds[angle]
		if (
			int(hold["valid_sample_count"]) != int(configuration["analysis_ticks"])
			or not bool(hold["rail_contract_exact"])
			or not bool(hold["hinge_contract_exact"])
			or not bool(hold["all_receipts_complete"])
			or int(hold["root_assistance_operation_count"]) != 0
			or int(hold["passive_operation_count"]) != 0
			or bool(hold["actuator_saturated"])
		):
			reasons.append("HINGED_STRUT_HOLD_INTEGRITY:%.1f" % angle)
		if (
			float(hold["maximum_torque_error_nm"])
			> float(configuration["maximum_torque_error_nm"])
		):
			reasons.append("HINGED_STRUT_TORQUE_MISMATCH:%.1f" % angle)
		if (
			float(hold["maximum_support_load_error_n"])
			> float(configuration["maximum_support_load_error_n"])
		):
			reasons.append("HINGED_STRUT_SUPPORT_MISMATCH:%.1f" % angle)
		if float(hold["maximum_angle_error_rad"]) > float(configuration["maximum_angle_error_rad"]):
			reasons.append("HINGED_STRUT_ANGLE_DRIFT:%.1f" % angle)
		if float(hold["maximum_height_drift_m"]) > float(configuration["maximum_height_drift_m"]):
			reasons.append("HINGED_STRUT_HEIGHT_DRIFT:%.1f" % angle)
		if (
			float(hold["maximum_joint_rate_rad_s"])
			> float(configuration["maximum_joint_rate_rad_s"])
		):
			reasons.append("HINGED_STRUT_RATE_EXCEEDED:%.1f" % angle)
		if (
			float(hold["floor_contact_fraction"])
			< float(configuration["minimum_floor_contact_fraction"])
		):
			reasons.append("HINGED_STRUT_CONTACT_INCOMPLETE:%.1f" % angle)
		if absf(float(hold["active_work_j"])) > float(configuration["maximum_abs_hold_work_j"]):
			reasons.append("HINGED_STRUT_HOLD_WORK_EXCEEDED:%.1f" % angle)
		var current_torque := absf(float(hold["mean_applied_torque_nm"]))
		if current_torque + 1.0e-9 < previous_torque:
			reasons.append("HINGED_STRUT_TORQUE_CURVE_NONMONOTONIC")
		previous_torque = current_torque
	if (
		bool(control["held_within_gate"])
		or float(control["maximum_angle_error_rad"])
			< float(configuration["minimum_control_angle_error_rad"])
	):
		reasons.append("HINGED_STRUT_ZERO_TORQUE_CONTROL_DID_NOT_FAIL")
	if (
		not bool(control["rail_contract_exact"])
		or not bool(control["hinge_contract_exact"])
		or int(control["root_assistance_operation_count"]) != 0
		or int(control["passive_operation_count"]) != 0
	):
		reasons.append("HINGED_STRUT_CONTROL_INTEGRITY")
	return {
		"ok": true,
		"accepted": reasons.is_empty(),
		"acceptance_failures": reasons,
		"claim_boundary": CLAIM_BOUNDARY,
		"does_not_establish":
		[
			"two_link_leg",
			"free_root_balance",
			"crouch_or_rise",
			"vertical_disturbance_recovery",
			"standing",
			"bracing",
			"gait",
			"walking",
			"per_foot_load_allocation",
			"automatic_creature_guidance",
		],
		"hold_trial_count": holds.size(),
		"control_failed_as_predicted":
		not bool(control["held_within_gate"])
			and float(control["maximum_angle_error_rad"])
				>= float(configuration["minimum_control_angle_error_rad"]),
		"maximum_hold_torque_error_nm": _max_field(holds, "maximum_torque_error_nm"),
		"maximum_hold_support_error_n": _max_field(holds, "maximum_support_load_error_n"),
		"maximum_hold_angle_error_rad": _max_field(holds, "maximum_angle_error_rad"),
		"maximum_abs_hold_work_j": _max_abs_field(holds, "active_work_j"),
		"motor_or_passive_assist_present": false,
		"rail_scaffold_present": true,
	}


static func _verify_digest(configuration: Dictionary) -> Dictionary:
	var payload := configuration.duplicate(true)
	var recorded := String(payload.get("configuration_sha256", ""))
	payload.erase("configuration_sha256")
	if recorded.is_empty() or recorded != CanonicalJsonScript.sha256(payload):
		return _failure("HINGED_STRUT_CONFIG_DIGEST_MISMATCH", ["digest"])
	var rebuilt := build(payload)
	if (
		not bool(rebuilt.get("ok", false))
		or String((rebuilt["configuration"] as Dictionary)["configuration_sha256"]) != recorded
	):
		return _failure("HINGED_STRUT_CONFIG_DIGEST_MISMATCH", ["semantic"])
	return {"ok": true}


static func _trial_finite(trial: Dictionary) -> bool:
	var required := [
		"mode",
		"target_angle_deg",
		"valid_sample_count",
		"mean_expected_torque_nm",
		"mean_applied_torque_nm",
		"maximum_torque_error_nm",
		"mean_reconstructed_support_n",
		"maximum_support_load_error_n",
		"maximum_angle_error_rad",
		"maximum_height_drift_m",
		"maximum_joint_rate_rad_s",
		"floor_contact_fraction",
		"active_work_j",
		"rail_contract_exact",
		"hinge_contract_exact",
		"all_receipts_complete",
		"root_assistance_operation_count",
		"passive_operation_count",
		"actuator_saturated",
		"held_within_gate",
	]
	for field in required:
		if not trial.has(field):
			return false
	for field in [
		"target_angle_deg",
		"mean_expected_torque_nm",
		"mean_applied_torque_nm",
		"maximum_torque_error_nm",
		"mean_reconstructed_support_n",
		"maximum_support_load_error_n",
		"maximum_angle_error_rad",
		"maximum_height_drift_m",
		"maximum_joint_rate_rad_s",
		"floor_contact_fraction",
		"active_work_j",
	]:
		if typeof(trial[field]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(trial[field])):
			return false
	return true


static func _max_field(holds: Dictionary, field: String) -> float:
	var value := 0.0
	for hold_value in holds.values():
		value = maxf(value, float((hold_value as Dictionary)[field]))
	return value


static func _max_abs_field(holds: Dictionary, field: String) -> float:
	var value := 0.0
	for hold_value in holds.values():
		value = maxf(value, absf(float((hold_value as Dictionary)[field])))
	return value


static func _failure(code: String, reasons: Array) -> Dictionary:
	return {"ok": false, "failure_code": code, "invalid_reasons": reasons}
