class_name LabPlanarStanceAnalyzer
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## Digest-bound BR7 planar two-contact stance contract.
##
## The accepted positive scope is deliberately narrower than "standing": the
## root is free only in sagittal translation and pitch. An explicit unpowered
## Generic6DOF guide removes out-of-plane translation, roll, and yaw.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "planar_stance_configuration_v1"
const CLAIM_BOUNDARY := (
	"BR7 exact two-contact sagittal stance on an explicit unpowered out-of-plane "
	+ "guide, with in-plane X/Y translation and pitch released, four paired finite "
	+ "hinge actuators, two ordinary distal sphere contacts, strict unilateral "
	+ "planar wrench allocation, whole-system momentum-derived aggregate support "
	+ "and pitch-wrench reconstruction, one declared positive pitch impulse, and "
	+ "one declared right-support removal followed by a fail-closed infeasible "
	+ "stop. This establishes scaffold-constrained planar height/pitch stance and "
	+ "support-loss detection only. Commanded left/right loads are not measurements. "
	+ "It establishes no free 3D standing, per-foot measured load allocation, "
	+ "bracing, fall arrest, getting up, gait, walking, or automatic creature guidance."
)
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"physics_hz",
	"static_measure_start_tick",
	"disturbance_tick",
	"support_loss_tick",
	"post_loss_ticks",
	"baseline_height_m",
	"root_mass_kg",
	"link_mass_kg",
	"link_length_m",
	"foot_radius_m",
	"hip_half_span_m",
	"friction_coefficient",
	"height_position_gain_n_m",
	"height_velocity_gain_n_s_m",
	"pitch_position_gain_nm_rad",
	"pitch_velocity_gain_nm_s_rad",
	"joint_position_gain_nm_rad",
	"joint_velocity_gain_nm_s_rad",
	"maximum_contact_normal_n",
	"controller_feasibility_reserve_fraction",
	"pitch_impulse_n_m_s",
	"recovery_pitch_error_rad",
	"recovery_pitch_rate_rad_s",
	"recovery_height_error_m",
	"recovery_dwell_ticks",
	"maximum_static_height_error_m",
	"maximum_static_pitch_error_rad",
	"maximum_static_support_error_n",
	"minimum_contact_fraction",
	"maximum_realized_vertical_wrench_residual_n",
	"maximum_realized_pitch_wrench_residual_nm",
	"minimum_pitch_excursion_rad",
	"maximum_pitch_excursion_rad",
	"maximum_disturbance_recovery_ticks",
	"maximum_pairing_residual_nm",
	"maximum_applied_torque_nm",
	"out_of_plane_planar_guide_enabled",
	"built_in_motors_enabled",
	"joint_limits_enabled",
	"passive_tissues_enabled",
	"controller_root_force_enabled",
	"foot_pin_enabled",
	"per_foot_load_sensor_enabled",
	"automatic_creature_guidance_enabled",
	"free_3d_standing_claim_enabled",
]
const POSITIVE_INTEGER_FIELDS: Array[String] = [
	"physics_hz",
	"static_measure_start_tick",
	"disturbance_tick",
	"support_loss_tick",
	"post_loss_ticks",
	"recovery_dwell_ticks",
	"maximum_disturbance_recovery_ticks",
]
const NUMERIC_FIELDS: Array[String] = [
	"baseline_height_m",
	"root_mass_kg",
	"link_mass_kg",
	"link_length_m",
	"foot_radius_m",
	"hip_half_span_m",
	"friction_coefficient",
	"height_position_gain_n_m",
	"height_velocity_gain_n_s_m",
	"pitch_position_gain_nm_rad",
	"pitch_velocity_gain_nm_s_rad",
	"joint_position_gain_nm_rad",
	"joint_velocity_gain_nm_s_rad",
	"maximum_contact_normal_n",
	"controller_feasibility_reserve_fraction",
	"pitch_impulse_n_m_s",
	"recovery_pitch_error_rad",
	"recovery_pitch_rate_rad_s",
	"recovery_height_error_m",
	"maximum_static_height_error_m",
	"maximum_static_pitch_error_rad",
	"maximum_static_support_error_n",
	"minimum_contact_fraction",
	"maximum_realized_vertical_wrench_residual_n",
	"maximum_realized_pitch_wrench_residual_nm",
	"minimum_pitch_excursion_rad",
	"maximum_pitch_excursion_rad",
	"maximum_pairing_residual_nm",
	"maximum_applied_torque_nm",
]
const FORBIDDEN_TRUE_FIELDS: Array[String] = [
	"built_in_motors_enabled",
	"joint_limits_enabled",
	"passive_tissues_enabled",
	"controller_root_force_enabled",
	"foot_pin_enabled",
	"per_foot_load_sensor_enabled",
	"automatic_creature_guidance_enabled",
	"free_3d_standing_claim_enabled",
]
const SUMMARY_NUMERIC_FIELDS: Array[String] = [
	"executed_ticks",
	"maximum_pairing_residual_nm",
	"maximum_requested_torque_nm",
	"maximum_applied_torque_nm",
	"actuator_saturation_count",
	"allocator_infeasible_before_loss_count",
	"allocation_maximum_force_residual_n",
	"allocation_maximum_moment_residual_nm",
	"controller_wrench_saturation_count",
	"static_maximum_height_error_m",
	"static_maximum_pitch_error_rad",
	"static_maximum_vertical_velocity_m_s",
	"static_maximum_pitch_rate_rad_s",
	"static_maximum_support_error_n",
	"static_maximum_realized_vertical_wrench_residual_n",
	"static_maximum_realized_pitch_wrench_residual_nm",
	"left_contact_fraction",
	"right_contact_fraction",
	"disturbance_operation_count",
	"maximum_pitch_excursion_rad",
	"signed_pitch_excursion_rad",
	"disturbance_recovery_ticks",
	"support_loss_event_count",
	"support_loss_event_tick",
	"last_infeasible_tick",
	"last_infeasible_desired_vertical_n",
	"last_infeasible_desired_moment_nm",
	"last_infeasible_root_height_m",
	"last_infeasible_root_pitch_rad",
	"last_infeasible_root_vertical_velocity_m_s",
	"last_infeasible_root_pitch_rate_rad_s",
	"root_rescue_operation_count",
	"foot_pin_operation_count",
	"passive_operation_count",
]
const SUMMARY_BOOL_FIELDS: Array[String] = [
	"fixture_complete",
	"planar_guide_exact",
	"hinges_exact",
	"all_receipts_complete",
	"disturbance_recovered",
	"controlled_stop",
	"per_contact_commands_are_measurements",
	"per_foot_measured_load_allocation_available",
]


static func build(configuration: Dictionary) -> Dictionary:
	var keys: Array = configuration.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("PLANAR_STANCE_CONFIGURATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("PLANAR_STANCE_CONFIGURATION_SCHEMA_UNSUPPORTED")
	for field in POSITIVE_INTEGER_FIELDS:
		var value: Variant = configuration.get(field)
		if (
			typeof(value) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(value))
			or float(value) != floorf(float(value))
			or int(value) <= 0
		):
			return _failure("PLANAR_STANCE_POSITIVE_INTEGER_INVALID:%s" % field)
	for field in NUMERIC_FIELDS:
		var value: Variant = configuration.get(field)
		if (
			typeof(value) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(value))
			or float(value) < 0.0
		):
			return _failure("PLANAR_STANCE_FINITE_NONNEGATIVE_INVALID:%s" % field)
	for field in [
		"baseline_height_m",
		"root_mass_kg",
		"link_mass_kg",
		"link_length_m",
		"foot_radius_m",
		"hip_half_span_m",
		"friction_coefficient",
		"height_position_gain_n_m",
		"height_velocity_gain_n_s_m",
		"pitch_position_gain_nm_rad",
		"pitch_velocity_gain_nm_s_rad",
		"joint_position_gain_nm_rad",
		"joint_velocity_gain_nm_s_rad",
		"maximum_contact_normal_n",
		"pitch_impulse_n_m_s",
		"recovery_pitch_error_rad",
		"recovery_pitch_rate_rad_s",
		"recovery_height_error_m",
		"minimum_contact_fraction",
		"maximum_applied_torque_nm",
	]:
		if float(configuration[field]) <= 0.0:
			return _failure("PLANAR_STANCE_POSITIVE_VALUE_INVALID:%s" % field)
	if (
		int(configuration["static_measure_start_tick"]) >= int(configuration["disturbance_tick"])
		or int(configuration["disturbance_tick"]) >= int(configuration["support_loss_tick"])
		or float(configuration["controller_feasibility_reserve_fraction"]) <= 0.0
		or float(configuration["controller_feasibility_reserve_fraction"]) > 1.0
		or float(configuration["minimum_contact_fraction"]) > 1.0
		or (
			float(configuration["minimum_pitch_excursion_rad"])
			>= float(configuration["maximum_pitch_excursion_rad"])
		)
	):
		return _failure("PLANAR_STANCE_RANGE_INVALID")
	var cosine := (
		(float(configuration["baseline_height_m"]) - float(configuration["foot_radius_m"]))
		/ (2.0 * float(configuration["link_length_m"]))
	)
	if cosine <= 0.0 or cosine > 1.0:
		return _failure("PLANAR_STANCE_INITIAL_IK_INVALID")
	if (
		typeof(configuration.get("out_of_plane_planar_guide_enabled")) != TYPE_BOOL
		or not bool(configuration["out_of_plane_planar_guide_enabled"])
	):
		return _failure("PLANAR_STANCE_EXPLICIT_GUIDE_REQUIRED")
	for field in FORBIDDEN_TRUE_FIELDS:
		if typeof(configuration.get(field)) != TYPE_BOOL or bool(configuration[field]):
			return _failure("PLANAR_STANCE_FORBIDDEN_ASSIST_OR_CLAIM:%s" % field)
	var payload := configuration.duplicate(true)
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	payload["total_ticks"] = (
		int(configuration["support_loss_tick"]) + int(configuration["post_loss_ticks"])
	)
	payload["support_loss_event_tick_window"] = [
		int(configuration["support_loss_tick"]),
		int(configuration["support_loss_tick"]) + 2,
	]
	payload["claim_boundary"] = CLAIM_BOUNDARY
	return {"ok": true, "contract": FrozenValueScript.snapshot(payload)}


static func analyze(contract: Dictionary, summary: Dictionary) -> Dictionary:
	var verified := _verify_contract(contract)
	if not bool(verified.get("ok", false)):
		return verified
	for field in SUMMARY_NUMERIC_FIELDS:
		if (
			not summary.has(field)
			or typeof(summary[field]) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(summary[field]))
		):
			return _failure("PLANAR_STANCE_SUMMARY_NONFINITE_OR_MISSING:%s" % field)
	for field in SUMMARY_BOOL_FIELDS:
		if not summary.has(field) or typeof(summary[field]) != TYPE_BOOL:
			return _failure("PLANAR_STANCE_SUMMARY_BOOL_MISSING:%s" % field)
	for field in ["support_loss_response", "last_infeasible_reasons"]:
		if not summary.has(field):
			return _failure("PLANAR_STANCE_SUMMARY_FIELD_MISSING:%s" % field)
	if not summary["last_infeasible_reasons"] is Array:
		return _failure("PLANAR_STANCE_INFEASIBILITY_REASONS_INVALID")
	var failures: Array[String] = []
	if (
		not bool(summary["fixture_complete"])
		or not bool(summary["planar_guide_exact"])
		or not bool(summary["hinges_exact"])
		or not bool(summary["all_receipts_complete"])
	):
		failures.append("PLANAR_STANCE_FIXTURE_INTEGRITY")
	if (
		int(summary["allocator_infeasible_before_loss_count"]) != 0
		or float(summary["allocation_maximum_force_residual_n"]) > 1.0e-7
		or float(summary["allocation_maximum_moment_residual_nm"]) > 1.0e-7
	):
		failures.append("PLANAR_STANCE_ALLOCATION_ARITHMETIC")
	if (
		(
			float(summary["maximum_pairing_residual_nm"])
			> float(contract["maximum_pairing_residual_nm"])
		)
		or (
			float(summary["maximum_applied_torque_nm"])
			> float(contract["maximum_applied_torque_nm"])
		)
		or int(summary["actuator_saturation_count"]) != 0
		or int(summary["controller_wrench_saturation_count"]) != 0
	):
		failures.append("PLANAR_STANCE_ACTUATOR_OR_GOVERNOR_BOUNDARY")
	if (
		float(summary["left_contact_fraction"]) < float(contract["minimum_contact_fraction"])
		or float(summary["right_contact_fraction"]) < float(contract["minimum_contact_fraction"])
		or (
			float(summary["static_maximum_height_error_m"])
			> float(contract["maximum_static_height_error_m"])
		)
		or (
			float(summary["static_maximum_pitch_error_rad"])
			> float(contract["maximum_static_pitch_error_rad"])
		)
		or (
			float(summary["static_maximum_support_error_n"])
			> float(contract["maximum_static_support_error_n"])
		)
	):
		failures.append("PLANAR_STANCE_STATIC_SUPPORT")
	if (
		(
			float(summary["static_maximum_realized_vertical_wrench_residual_n"])
			> float(contract["maximum_realized_vertical_wrench_residual_n"])
		)
		or (
			float(summary["static_maximum_realized_pitch_wrench_residual_nm"])
			> float(contract["maximum_realized_pitch_wrench_residual_nm"])
		)
	):
		failures.append("PLANAR_STANCE_REALIZED_WRENCH")
	if (
		int(summary["disturbance_operation_count"]) != 1
		or (
			float(summary["maximum_pitch_excursion_rad"])
			< float(contract["minimum_pitch_excursion_rad"])
		)
		or (
			float(summary["maximum_pitch_excursion_rad"])
			> float(contract["maximum_pitch_excursion_rad"])
		)
		or float(summary["signed_pitch_excursion_rad"]) <= 0.0
		or not bool(summary["disturbance_recovered"])
		or (
			int(summary["disturbance_recovery_ticks"])
			> int(contract["maximum_disturbance_recovery_ticks"])
		)
	):
		failures.append("PLANAR_STANCE_PITCH_DISTURBANCE")
	var loss_window: Array = contract["support_loss_event_tick_window"]
	if (
		int(summary["support_loss_event_count"]) != 1
		or int(summary["support_loss_event_tick"]) < int(loss_window[0])
		or int(summary["support_loss_event_tick"]) > int(loss_window[1])
		or String(summary["support_loss_response"]) != "DECLARE_INFEASIBLE_STOP"
		or not bool(summary["controlled_stop"])
		or int(summary["last_infeasible_tick"]) != int(summary["support_loss_event_tick"])
		or not (summary["last_infeasible_reasons"] as Array).has("PITCH_MOMENT_RESIDUAL")
	):
		failures.append("PLANAR_STANCE_SUPPORT_LOSS")
	if (
		int(summary["root_rescue_operation_count"]) != 0
		or int(summary["foot_pin_operation_count"]) != 0
		or int(summary["passive_operation_count"]) != 0
		or bool(summary["per_contact_commands_are_measurements"])
		or bool(summary["per_foot_measured_load_allocation_available"])
	):
		failures.append("PLANAR_STANCE_INTERVENTION_OR_MEASUREMENT_BOUNDARY")
	return {
		"ok": true,
		"accepted": failures.is_empty(),
		"acceptance_failures": failures,
		"claim_boundary": CLAIM_BOUNDARY,
		"out_of_plane_scaffold_present": true,
		"in_plane_translation_and_pitch_released": true,
		"aggregate_support_measurement_available": true,
		"per_foot_measured_load_allocation_available": false,
		"does_not_establish":
		[
			"free_3d_standing",
			"unconstrained_balance",
			"per_foot_measured_load_allocation",
			"bracing",
			"fall_arrest",
			"getting_up",
			"gait",
			"walking",
			"automatic_creature_guidance",
		],
	}


static func claim_boundary() -> String:
	return CLAIM_BOUNDARY


static func _verify_contract(contract: Dictionary) -> Dictionary:
	var configuration: Dictionary = {}
	for field in REQUIRED_FIELDS:
		if not contract.has(field):
			return _failure("PLANAR_STANCE_CONTRACT_INCOMPLETE")
		configuration[field] = contract[field]
	var rebuilt := build(configuration)
	if (
		not bool(rebuilt.get("ok", false))
		or (
			CanonicalJsonScript.stringify(rebuilt["contract"])
			!= CanonicalJsonScript.stringify(contract)
		)
	):
		return _failure("PLANAR_STANCE_CONTRACT_DIGEST_MISMATCH")
	return {"ok": true}


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
