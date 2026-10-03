class_name LabExistingContactBraceAnalyzer
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## Digest-bound BR9 paired existing-contact planar-brace contract.
##
## The positive claim is deliberately narrower than unrestricted bracing. The
## fixture retains BR7's material unpowered out-of-plane guide, already-bearing
## distal contacts, and finite paired joint actuators. It compares a no-brace
## control against one controller that begins only after the first post-impulse
## observation.

const BraceControllerScript := preload("res://scripts/lab/mechanics/brace_controller.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "existing_contact_brace_experiment_configuration_v1"
const CLAIM_BOUNDARY := (
	"BR9 paired existing-contact pitch-arrest bracing on the exact BR7 sagittal "
	+ "scaffold: one no-brace control and one active-brace world; an explicit "
	+ "unpowered out-of-plane guide with in-plane X/Y translation and pitch "
	+ "released; four passive hinges driven only through paired finite joint "
	+ "actuators; two ordinary distal contacts already bearing before one declared "
	+ "positive pitch impulse; first brace command only on the first post-impulse "
	+ "observation; reserve-aware unilateral load redistribution with bounded load "
	+ "rate; command-ledger, executor, and append-only receipt reconciliation; and "
	+ "whole-system angular-momentum reconstruction of the realized external pitch "
	+ "moment. The positive result is lower post-disturbance angular-momentum area "
	+ "and pitch excursion than the paired no-brace control while both original "
	+ "contacts remain bearing. Commanded left/right shares are not measurements. "
	+ "This establishes only scaffold-constrained planar existing-contact pitch "
	+ "arrest. It establishes no new-contact catch step, per-foot measured load "
	+ "allocation, free-3D bracing or standing, articulated limb generality, fall "
	+ "arrest, getting up, gait, walking, creature repair, or automatic creature "
	+ "guidance."
)
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"physics_hz",
	"disturbance_tick",
	"evaluation_delay_ticks",
	"trial_end_tick",
	"baseline_height_m",
	"root_mass_kg",
	"link_mass_kg",
	"link_length_m",
	"foot_radius_m",
	"hip_half_span_m",
	"friction_coefficient",
	"height_position_gain_n_m",
	"height_velocity_gain_n_s_m",
	"prebrace_pitch_position_gain_nm_rad",
	"prebrace_pitch_velocity_gain_nm_s_rad",
	"joint_position_gain_nm_rad",
	"joint_velocity_gain_nm_s_rad",
	"maximum_contact_normal_n",
	"pitch_impulse_n_m_s",
	"brace_configuration",
	"actuator_spec_sha256",
	"minimum_existing_contact_fraction",
	"maximum_controlled_evaluation_momentum_abs_kg_m2_s",
	"maximum_controlled_momentum_area_ratio",
	"maximum_controlled_pitch_excursion_ratio",
	"maximum_controlled_height_error_m",
	"maximum_command_moment_residual_nm",
	"maximum_realized_moment_residual_nm",
	"maximum_pairing_residual_nm",
	"maximum_applied_torque_nm",
	"out_of_plane_planar_guide_enabled",
	"built_in_motors_enabled",
	"joint_limits_enabled",
	"passive_tissues_enabled",
	"controller_root_force_enabled",
	"foot_pin_enabled",
	"new_support_contact_enabled",
	"per_foot_load_sensor_enabled",
	"automatic_creature_guidance_enabled",
	"free_3d_bracing_claim_enabled",
	"catch_step_claim_enabled",
]
const POSITIVE_INTEGER_FIELDS: Array[String] = [
	"physics_hz",
	"disturbance_tick",
	"evaluation_delay_ticks",
	"trial_end_tick",
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
	"prebrace_pitch_position_gain_nm_rad",
	"prebrace_pitch_velocity_gain_nm_s_rad",
	"joint_position_gain_nm_rad",
	"joint_velocity_gain_nm_s_rad",
	"maximum_contact_normal_n",
	"pitch_impulse_n_m_s",
	"minimum_existing_contact_fraction",
	"maximum_controlled_evaluation_momentum_abs_kg_m2_s",
	"maximum_controlled_momentum_area_ratio",
	"maximum_controlled_pitch_excursion_ratio",
	"maximum_controlled_height_error_m",
	"maximum_command_moment_residual_nm",
	"maximum_realized_moment_residual_nm",
	"maximum_pairing_residual_nm",
	"maximum_applied_torque_nm",
]
const POSITIVE_FIELDS: Array[String] = [
	"baseline_height_m",
	"root_mass_kg",
	"link_mass_kg",
	"link_length_m",
	"foot_radius_m",
	"hip_half_span_m",
	"friction_coefficient",
	"height_position_gain_n_m",
	"height_velocity_gain_n_s_m",
	"joint_position_gain_nm_rad",
	"joint_velocity_gain_nm_s_rad",
	"maximum_contact_normal_n",
	"pitch_impulse_n_m_s",
	"minimum_existing_contact_fraction",
	"maximum_controlled_evaluation_momentum_abs_kg_m2_s",
	"maximum_controlled_momentum_area_ratio",
	"maximum_controlled_pitch_excursion_ratio",
	"maximum_controlled_height_error_m",
	"maximum_realized_moment_residual_nm",
	"maximum_applied_torque_nm",
]
const FORBIDDEN_TRUE_FIELDS: Array[String] = [
	"built_in_motors_enabled",
	"joint_limits_enabled",
	"passive_tissues_enabled",
	"controller_root_force_enabled",
	"foot_pin_enabled",
	"new_support_contact_enabled",
	"per_foot_load_sensor_enabled",
	"automatic_creature_guidance_enabled",
	"free_3d_bracing_claim_enabled",
	"catch_step_claim_enabled",
]
const SUMMARY_NUMERIC_FIELDS: Array[String] = [
	"executed_ticks",
	"disturbance_operation_count",
	"first_brace_command_tick",
	"brace_command_count",
	"stabilize_handoff_tick",
	"controller_rate_limited_count",
	"maximum_command_moment_residual_nm",
	"maximum_realized_moment_residual_nm",
	"maximum_normal_load_rate_n_s",
	"maximum_tangent_load_rate_n_s",
	"maximum_pairing_residual_nm",
	"maximum_applied_torque_nm",
	"actuator_saturation_count",
	"post_impulse_angular_momentum_z_kg_m2_s",
	"evaluation_angular_momentum_z_kg_m2_s",
	"final_angular_momentum_z_kg_m2_s",
	"angular_momentum_abs_area_kg_m2",
	"maximum_pitch_excursion_rad",
	"signed_pitch_excursion_rad",
	"maximum_height_error_m",
	"left_existing_contact_fraction",
	"right_existing_contact_fraction",
	"post_disturbance_sample_count",
	"last_left_command_normal_n",
	"last_right_command_normal_n",
	"root_rescue_operation_count",
	"foot_pin_operation_count",
	"new_support_contact_operation_count",
	"automatic_creature_guidance_operation_count",
]
const SUMMARY_BOOL_FIELDS: Array[String] = [
	"fixture_complete",
	"brace_enabled",
	"planar_guide_exact",
	"hinges_exact",
	"all_receipts_complete",
	"per_contact_commands_are_measurements",
	"per_foot_measured_load_allocation_available",
]


static func build(configuration: Dictionary) -> Dictionary:
	var keys: Array = configuration.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("EXISTING_CONTACT_BRACE_CONFIGURATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("EXISTING_CONTACT_BRACE_CONFIGURATION_SCHEMA_UNSUPPORTED")
	for field in POSITIVE_INTEGER_FIELDS:
		var value: Variant = configuration.get(field)
		if (
			typeof(value) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(value))
			or float(value) != floorf(float(value))
			or int(value) <= 0
		):
			return _failure("EXISTING_CONTACT_BRACE_POSITIVE_INTEGER_INVALID:%s" % field)
	for field in NUMERIC_FIELDS:
		var value: Variant = configuration.get(field)
		if (
			typeof(value) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(value))
			or float(value) < 0.0
		):
			return _failure("EXISTING_CONTACT_BRACE_FINITE_NONNEGATIVE_INVALID:%s" % field)
	for field in POSITIVE_FIELDS:
		if float(configuration[field]) <= 0.0:
			return _failure("EXISTING_CONTACT_BRACE_POSITIVE_VALUE_INVALID:%s" % field)
	if (
		(
			int(configuration["disturbance_tick"]) + int(configuration["evaluation_delay_ticks"])
			>= int(configuration["trial_end_tick"])
		)
		or float(configuration["minimum_existing_contact_fraction"]) > 1.0
		or float(configuration["maximum_controlled_momentum_area_ratio"]) >= 1.0
		or float(configuration["maximum_controlled_pitch_excursion_ratio"]) >= 1.0
	):
		return _failure("EXISTING_CONTACT_BRACE_CONFIGURATION_RANGE_INVALID")
	var cosine := (
		(float(configuration["baseline_height_m"]) - float(configuration["foot_radius_m"]))
		/ (2.0 * float(configuration["link_length_m"]))
	)
	if cosine <= 0.0 or cosine > 1.0:
		return _failure("EXISTING_CONTACT_BRACE_INITIAL_IK_INVALID")
	if (
		typeof(configuration.get("out_of_plane_planar_guide_enabled")) != TYPE_BOOL
		or not bool(configuration["out_of_plane_planar_guide_enabled"])
	):
		return _failure("EXISTING_CONTACT_BRACE_EXPLICIT_GUIDE_REQUIRED")
	for field in FORBIDDEN_TRUE_FIELDS:
		if typeof(configuration.get(field)) != TYPE_BOOL or bool(configuration[field]):
			return _failure("EXISTING_CONTACT_BRACE_FORBIDDEN_ASSIST_OR_CLAIM:%s" % field)
	if not configuration.get("brace_configuration") is Dictionary:
		return _failure("EXISTING_CONTACT_BRACE_CONTROLLER_CONFIGURATION_MISSING")
	var brace_validation := BraceControllerScript.validate_configuration(
		configuration["brace_configuration"]
	)
	if not bool(brace_validation.get("ok", false)):
		return _failure(
			"EXISTING_CONTACT_BRACE_CONTROLLER_CONFIGURATION_INVALID",
			{"controller_failure_code": brace_validation.get("failure_code", "")}
		)
	var actuator_sha := String(configuration.get("actuator_spec_sha256", ""))
	if (
		not actuator_sha.begins_with("sha256:")
		or actuator_sha.length() != 71
		or not actuator_sha.trim_prefix("sha256:").is_valid_hex_number(false)
	):
		return _failure("EXISTING_CONTACT_BRACE_ACTUATOR_DIGEST_INVALID")
	var payload := configuration.duplicate(true)
	payload["brace_configuration_sha256"] = String(
		brace_validation["configuration"]["configuration_sha256"]
	)
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	payload["expected_first_brace_command_tick"] = int(configuration["disturbance_tick"]) + 1
	payload["expected_brace_command_count"] = (
		int(configuration["trial_end_tick"]) - int(configuration["disturbance_tick"]) - 1
	)
	payload["claim_boundary"] = CLAIM_BOUNDARY
	return {"ok": true, "contract": FrozenValueScript.snapshot(payload)}


static func analyze(
	contract: Dictionary, no_brace_summary: Dictionary, brace_summary: Dictionary
) -> Dictionary:
	var verified := _verify_contract(contract)
	if not bool(verified.get("ok", false)):
		return verified
	for summary_value in [no_brace_summary, brace_summary]:
		var summary: Dictionary = summary_value
		if String(summary.get("schema_version", "")) != "existing_contact_brace_fixture_summary_v1":
			return _failure("EXISTING_CONTACT_BRACE_SUMMARY_SCHEMA_INVALID")
		if (
			String(summary.get("configuration_sha256", ""))
			!= String(contract["configuration_sha256"])
		):
			return _failure("EXISTING_CONTACT_BRACE_SUMMARY_CONFIGURATION_DIGEST_MISMATCH")
		if (
			String(summary.get("actuator_spec_sha256", ""))
			!= String(contract["actuator_spec_sha256"])
		):
			return _failure("EXISTING_CONTACT_BRACE_SUMMARY_ACTUATOR_DIGEST_MISMATCH")
		for field in SUMMARY_NUMERIC_FIELDS:
			if (
				not summary.has(field)
				or typeof(summary[field]) not in [TYPE_INT, TYPE_FLOAT]
				or not is_finite(float(summary[field]))
			):
				return _failure("EXISTING_CONTACT_BRACE_SUMMARY_NONFINITE_OR_MISSING:%s" % field)
		for field in SUMMARY_BOOL_FIELDS:
			if not summary.has(field) or typeof(summary[field]) != TYPE_BOOL:
				return _failure("EXISTING_CONTACT_BRACE_SUMMARY_BOOL_MISSING:%s" % field)
		for field in ["command_handoff_state", "last_controller_failure"]:
			if not summary.has(field):
				return _failure("EXISTING_CONTACT_BRACE_SUMMARY_FIELD_MISSING:%s" % field)
		if not summary["last_controller_failure"] is Dictionary:
			return _failure("EXISTING_CONTACT_BRACE_CONTROLLER_FAILURE_FIELD_INVALID")

	var failures: Array[String] = []
	if (
		bool(no_brace_summary["brace_enabled"])
		or not bool(brace_summary["brace_enabled"])
		or not _fixture_integrity(no_brace_summary, int(contract["trial_end_tick"]))
		or not _fixture_integrity(brace_summary, int(contract["trial_end_tick"]))
	):
		failures.append("EXISTING_CONTACT_BRACE_PAIRED_FIXTURE_INTEGRITY")
	if (
		int(no_brace_summary["disturbance_operation_count"]) != 1
		or int(brace_summary["disturbance_operation_count"]) != 1
		or float(no_brace_summary["post_impulse_angular_momentum_z_kg_m2_s"]) <= 0.0
		or float(brace_summary["post_impulse_angular_momentum_z_kg_m2_s"]) <= 0.0
		or (
			absf(
				(
					float(no_brace_summary["post_impulse_angular_momentum_z_kg_m2_s"])
					- float(brace_summary["post_impulse_angular_momentum_z_kg_m2_s"])
				)
			)
			> 1.0e-6
		)
	):
		failures.append("EXISTING_CONTACT_BRACE_DISTURBANCE_PAIRING")
	if (
		int(no_brace_summary["brace_command_count"]) != 0
		or int(no_brace_summary["first_brace_command_tick"]) != -1
		or int(no_brace_summary["stabilize_handoff_tick"]) != -1
		or String(no_brace_summary["command_handoff_state"]) != "NO_BRACE_CONTROL"
		or (
			int(brace_summary["first_brace_command_tick"])
			!= int(contract["expected_first_brace_command_tick"])
		)
		or (
			int(brace_summary["brace_command_count"])
			!= int(contract["expected_brace_command_count"])
		)
		or (
			int(brace_summary["stabilize_handoff_tick"])
			<= int(brace_summary["first_brace_command_tick"])
		)
		or String(brace_summary["command_handoff_state"]) != "STABILIZE"
		or not (brace_summary["last_controller_failure"] as Dictionary).is_empty()
	):
		failures.append("EXISTING_CONTACT_BRACE_CAUSAL_COMMAND_OR_HANDOFF")
	if (
		(
			absf(float(brace_summary["evaluation_angular_momentum_z_kg_m2_s"]))
			> float(contract["maximum_controlled_evaluation_momentum_abs_kg_m2_s"])
		)
		or float(no_brace_summary["angular_momentum_abs_area_kg_m2"]) <= 0.0
		or (
			float(brace_summary["angular_momentum_abs_area_kg_m2"])
			> (
				float(no_brace_summary["angular_momentum_abs_area_kg_m2"])
				* float(contract["maximum_controlled_momentum_area_ratio"])
			)
		)
	):
		failures.append("EXISTING_CONTACT_BRACE_MOMENTUM_ARREST")
	if (
		float(no_brace_summary["maximum_pitch_excursion_rad"]) <= 0.0
		or float(brace_summary["signed_pitch_excursion_rad"]) <= 0.0
		or (
			float(brace_summary["maximum_pitch_excursion_rad"])
			> (
				float(no_brace_summary["maximum_pitch_excursion_rad"])
				* float(contract["maximum_controlled_pitch_excursion_ratio"])
			)
		)
		or (
			float(brace_summary["maximum_height_error_m"])
			> float(contract["maximum_controlled_height_error_m"])
		)
	):
		failures.append("EXISTING_CONTACT_BRACE_POSE_BOUNDARY")
	if (
		(
			float(brace_summary["left_existing_contact_fraction"])
			< float(contract["minimum_existing_contact_fraction"])
		)
		or (
			float(brace_summary["right_existing_contact_fraction"])
			< float(contract["minimum_existing_contact_fraction"])
		)
	):
		failures.append("EXISTING_CONTACT_BRACE_EXISTING_CONTACT_SET")
	var brace_configuration: Dictionary = contract["brace_configuration"]
	if (
		(
			float(brace_summary["maximum_normal_load_rate_n_s"])
			> float(brace_configuration["max_normal_load_rate_n_s"]) + 1.0e-6
		)
		or (
			float(brace_summary["maximum_tangent_load_rate_n_s"])
			> float(brace_configuration["max_tangent_load_rate_n_s"]) + 1.0e-6
		)
		or (
			float(brace_summary["maximum_command_moment_residual_nm"])
			> float(contract["maximum_command_moment_residual_nm"])
		)
		or (
			float(brace_summary["maximum_realized_moment_residual_nm"])
			> float(contract["maximum_realized_moment_residual_nm"])
		)
	):
		failures.append("EXISTING_CONTACT_BRACE_WRENCH_OR_RATE_BOUNDARY")
	if (
		(
			float(brace_summary["maximum_pairing_residual_nm"])
			> float(contract["maximum_pairing_residual_nm"])
		)
		or (
			float(brace_summary["maximum_applied_torque_nm"])
			> float(contract["maximum_applied_torque_nm"])
		)
		or int(brace_summary["actuator_saturation_count"]) != 0
	):
		failures.append("EXISTING_CONTACT_BRACE_ACTUATOR_BOUNDARY")
	for summary_value in [no_brace_summary, brace_summary]:
		var summary: Dictionary = summary_value
		if (
			int(summary["root_rescue_operation_count"]) != 0
			or int(summary["foot_pin_operation_count"]) != 0
			or int(summary["new_support_contact_operation_count"]) != 0
			or int(summary["automatic_creature_guidance_operation_count"]) != 0
			or bool(summary["per_contact_commands_are_measurements"])
			or bool(summary["per_foot_measured_load_allocation_available"])
		):
			failures.append("EXISTING_CONTACT_BRACE_INTERVENTION_OR_MEASUREMENT_BOUNDARY")
			break
	return {
		"ok": true,
		"accepted": failures.is_empty(),
		"acceptance_failures": failures,
		"claim_boundary": CLAIM_BOUNDARY,
		"milestone_cells": ["BR9.0", "BR9.1", "BR9.2", "BR9.3"],
		"integrity_cell": "BR9.4",
		"existing_contact_planar_brace_executed": failures.is_empty(),
		"out_of_plane_scaffold_present": true,
		"new_support_contact_created": false,
		"aggregate_external_pitch_moment_reconstructed": true,
		"per_foot_measured_load_allocation_available": false,
		"automatic_creature_guidance": false,
		"does_not_establish":
		[
			"new_contact_catch_step",
			"per_foot_measured_load_allocation",
			"free_3d_bracing",
			"free_3d_standing",
			"articulated_limb_generality",
			"fall_arrest",
			"getting_up",
			"gait",
			"walking",
			"creature_repair",
			"automatic_creature_guidance",
		],
	}


static func claim_boundary() -> String:
	return CLAIM_BOUNDARY


static func _fixture_integrity(summary: Dictionary, expected_ticks: int) -> bool:
	return (
		bool(summary["fixture_complete"])
		and int(summary["executed_ticks"]) == expected_ticks
		and bool(summary["planar_guide_exact"])
		and bool(summary["hinges_exact"])
		and bool(summary["all_receipts_complete"])
	)


static func _verify_contract(contract: Dictionary) -> Dictionary:
	var configuration: Dictionary = {}
	for field in REQUIRED_FIELDS:
		if not contract.has(field):
			return _failure("EXISTING_CONTACT_BRACE_CONTRACT_INCOMPLETE")
		configuration[field] = contract[field]
	var rebuilt := build(configuration)
	if (
		not bool(rebuilt.get("ok", false))
		or (
			CanonicalJsonScript.stringify(rebuilt["contract"])
			!= CanonicalJsonScript.stringify(contract)
		)
	):
		return _failure("EXISTING_CONTACT_BRACE_CONTRACT_DIGEST_MISMATCH")
	return {"ok": true}


static func _failure(code: String, details: Variant = null) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"details": details,
	}
