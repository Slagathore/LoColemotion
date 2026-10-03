class_name LabCanonicalPlanarGetUpAnalyzer
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-returns

## Digest-bound BR13 paired live canonical get-up analyzer.

const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const EnergyLedgerScript := preload("res://scripts/lab/mechanics/recovery_energy_ledger.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const PoseObserverScript := preload(
	"res://scripts/lab/mechanics/quadruped_recovery_pose_observer.gd"
)
const ProfileScript := preload("res://scripts/lab/mechanics/canonical_get_up_profile.gd")
const SupervisorScript := preload("res://scripts/lab/mechanics/recovery_phase_supervisor.gd")

const CONFIGURATION_SCHEMA := "canonical_planar_get_up_contract_v1"
const CLAIM_BOUNDARY := (
	"BR13 paired live Godot/Jolt recovery for one exact symmetry-collapsed "
	+ "quadruped laboratory profile. Each active seed begins in observed semantic "
	+ "ventral-contact prone, establishes ordinary front-pair and rear-pair distal "
	+ "support, raises measured whole-system center of mass with finite paired "
	+ "actuation, hands exclusively from the recovery controller to the stance "
	+ "controller, and completes the declared stance dwell. Each seed is compared "
	+ "with one same-state zero-command control that remains prone. Command receipts, "
	+ "transition-integrated actuator work, residual-inferred contact dissipation, "
	+ "and the material out-of-plane guide impulse/work boundary remain explicit. "
	+ "The positive conclusion is exactly constrained_planar_get_up for this fixture. "
	+ "It establishes no free-3D recovery, morphology transfer, gait, walking, repair, "
	+ "or automatic creature guidance."
)
const CONFIGURATION_FIELDS: Array[String] = [
	"schema_version",
	"profile_configuration",
	"actuator_configuration",
	"rig_configuration",
	"seeds",
	"minimum_active_com_height_gain_m",
	"maximum_control_com_height_gain_m",
	"maximum_energy_residual_j",
	"maximum_abs_guide_linear_impulse_z_n_s",
	"maximum_out_of_plane_drift_m",
	"maximum_roll_yaw_rad",
	"maximum_final_linear_speed_m_s",
	"maximum_final_angular_speed_rad_s",
	"maximum_root_pitch_rad",
	"maximum_pairing_residual_nm",
	"maximum_applied_torque_nm",
	"constrained_planar_get_up_claim_enabled",
	"free_3d_recovery_claim_enabled",
	"morphology_transfer_claim_enabled",
	"gait_claim_enabled",
	"walking_claim_enabled",
	"automatic_creature_guidance_enabled",
]
const RIG_CONFIGURATION_FIELDS: Array[String] = [
	"physics_hz",
	"trial_ticks",
	"gravity_m_s2",
	"root_mass_kg",
	"root_size_m",
	"initial_root_height_m",
	"reference_stance_height_m",
	"hip_half_span_m",
	"limb_pair_mass_kg",
	"limb_length_m",
	"limb_width_m",
	"limb_depth_m",
	"foot_radius_m",
	"initial_splay_angle_rad",
	"floor_friction",
	"seed_initial_velocity_m_s",
	"joint_position_gain_nm_rad",
	"joint_velocity_gain_nm_s_rad",
	"pose_configuration",
	"supervisor_configuration",
	"energy_configuration",
	"energy_preflight",
]
const SUMMARY_FIELDS: Array[String] = [
	"schema_version",
	"configuration_sha256",
	"profile_sha256",
	"actuator_spec_sha256",
	"seed",
	"recovery_enabled",
	"fixture_complete",
	"fixture_failure_code",
	"executed_ticks",
	"planar_guide_exact",
	"front_hinge_exact",
	"rear_hinge_exact",
	"initial_pose_state",
	"final_pose_state",
	"final_supervisor_phase",
	"phase_trace",
	"phase_first_ticks",
	"complete_observed",
	"initial_com_height_m",
	"final_com_height_m",
	"minimum_com_height_m",
	"maximum_com_height_m",
	"com_height_gain_m",
	"initial_kinetic_energy_j",
	"final_kinetic_energy_j",
	"initial_mechanical_energy_j",
	"final_mechanical_energy_j",
	"actuator_positive_work_j",
	"actuator_absorbed_work_j",
	"net_actuator_work_j",
	"inferred_contact_dissipation_j",
	"inferred_guide_linear_impulse_z_n_s",
	"inferred_guide_work_j",
	"energy_reconciliation_ok",
	"energy_reconciliation_accepted",
	"energy_balance_residual_j",
	"front_contact_fraction",
	"rear_contact_fraction",
	"ventral_contact_fraction",
	"final_front_pair_bearing",
	"final_rear_pair_bearing",
	"final_ventral_contact",
	"final_max_linear_speed_m_s",
	"final_max_angular_speed_rad_s",
	"maximum_root_pitch_rad",
	"maximum_out_of_plane_drift_m",
	"maximum_roll_rad",
	"maximum_yaw_rad",
	"maximum_applied_torque_nm",
	"maximum_pairing_residual_nm",
	"actuator_saturation_count",
	"recovery_command_count",
	"stance_command_count",
	"recovery_command_after_handoff_count",
	"stance_command_during_dwell_count",
	"all_receipts_complete",
	"root_rescue_operation_count",
	"foot_pin_operation_count",
	"pose_teleport_operation_count",
	"automatic_creature_guidance_operation_count",
	"guide_work_is_residual_inferred",
	"contact_dissipation_is_residual_inferred",
	"free_3d_recovery_established",
	"morphology_transfer_established",
	"gait_established",
	"walking_established",
]
const POSITIVE_PHASE_TRACE: Array[String] = [
	"CONFIRM_PRONE",
	"ESTABLISH_DISTAL_CONTACT",
	"RAISE_BODY",
	"STANCE_HANDOFF",
	"STANCE_DWELL",
	"COMPLETE",
]


static func build(configuration: Dictionary) -> Dictionary:
	if not _exact_fields(configuration, CONFIGURATION_FIELDS):
		return _failure("CANONICAL_GET_UP_CONTRACT_FIELDS_INVALID")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA:
		return _failure("CANONICAL_GET_UP_CONTRACT_SCHEMA_INVALID")
	if typeof(configuration.get("profile_configuration")) != TYPE_DICTIONARY:
		return _failure("CANONICAL_GET_UP_PROFILE_CONFIGURATION_INVALID")
	var profile_result := ProfileScript.compile(configuration["profile_configuration"])
	if not bool(profile_result.get("ok", false)):
		return _failure("CANONICAL_GET_UP_PROFILE_INVALID", profile_result)
	if typeof(configuration.get("actuator_configuration")) != TYPE_DICTIONARY:
		return _failure("CANONICAL_GET_UP_ACTUATOR_CONFIGURATION_INVALID")
	var actuator_result := ActuatorSpecScript.compile(configuration["actuator_configuration"])
	if not bool(actuator_result.get("ok", false)):
		return _failure("CANONICAL_GET_UP_ACTUATOR_INVALID", actuator_result)
	var seeds_result := _seeds(configuration.get("seeds"))
	if not bool(seeds_result.get("ok", false)):
		return seeds_result
	var seeds: Array = seeds_result["seeds"]
	if seeds != [13001, 13002, 13003]:
		return _failure("CANONICAL_GET_UP_SEED_SET_MISMATCH")
	if (configuration["profile_configuration"]["seed_set"] as Array) != seeds:
		return _failure("CANONICAL_GET_UP_PROFILE_SEED_MISMATCH")
	if typeof(configuration.get("rig_configuration")) != TYPE_DICTIONARY:
		return _failure("CANONICAL_GET_UP_RIG_CONFIGURATION_INVALID")
	var rig: Dictionary = configuration["rig_configuration"]
	var rig_result := _validate_rig(rig, actuator_result["spec"])
	if not bool(rig_result.get("ok", false)):
		return rig_result
	for field in [
		"minimum_active_com_height_gain_m",
		"maximum_control_com_height_gain_m",
		"maximum_energy_residual_j",
		"maximum_abs_guide_linear_impulse_z_n_s",
		"maximum_out_of_plane_drift_m",
		"maximum_roll_yaw_rad",
		"maximum_final_linear_speed_m_s",
		"maximum_final_angular_speed_rad_s",
		"maximum_root_pitch_rad",
		"maximum_pairing_residual_nm",
		"maximum_applied_torque_nm",
	]:
		if not _finite_number(configuration.get(field)) or float(configuration[field]) < 0.0:
			return _failure("CANONICAL_GET_UP_GATE_INVALID:%s" % field)
	if (
		float(configuration["minimum_active_com_height_gain_m"]) <= 0.0
		or float(configuration["maximum_final_linear_speed_m_s"]) <= 0.0
		or float(configuration["maximum_final_angular_speed_rad_s"]) <= 0.0
		or float(configuration["maximum_applied_torque_nm"]) <= 0.0
	):
		return _failure("CANONICAL_GET_UP_GATE_BOUND_INVALID")
	if (
		typeof(configuration.get("constrained_planar_get_up_claim_enabled")) != TYPE_BOOL
		or not bool(configuration["constrained_planar_get_up_claim_enabled"])
	):
		return _failure("CANONICAL_GET_UP_POSITIVE_CLAIM_DISABLED")
	for field in [
		"free_3d_recovery_claim_enabled",
		"morphology_transfer_claim_enabled",
		"gait_claim_enabled",
		"walking_claim_enabled",
		"automatic_creature_guidance_enabled",
	]:
		if typeof(configuration.get(field)) != TYPE_BOOL or bool(configuration[field]):
			return _failure("CANONICAL_GET_UP_FORBIDDEN_CLAIM_ENABLED:%s" % field)
	var payload := configuration.duplicate(true)
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	payload["profile"] = profile_result["profile"]
	payload["actuator_spec"] = actuator_result["spec"]
	payload["claim_boundary"] = CLAIM_BOUNDARY
	payload["milestone_cell"] = "BR13.4"
	payload["physical_execution_authorized"] = true
	payload["automatic_creature_guidance_authorized"] = false
	return {"ok": true, "contract": FrozenValueScript.snapshot(payload)}


static func analyze(
	contract: Dictionary, active_summaries: Array, control_summaries: Array
) -> Dictionary:
	var contract_check := _verify_contract(contract)
	if not bool(contract_check.get("ok", false)):
		return contract_check
	var seeds: Array = contract["seeds"]
	if active_summaries.size() != seeds.size() or control_summaries.size() != seeds.size():
		return _failure("CANONICAL_GET_UP_PAIRED_CARDINALITY_INVALID")
	var active_by_seed := _index_summaries(contract, active_summaries, true)
	if not bool(active_by_seed.get("ok", false)):
		return active_by_seed
	var control_by_seed := _index_summaries(contract, control_summaries, false)
	if not bool(control_by_seed.get("ok", false)):
		return control_by_seed
	var failures: Array[String] = []
	var cells: Array = []
	for seed_value in seeds:
		var seed := int(seed_value)
		var active: Dictionary = active_by_seed["summaries"][seed]
		var control: Dictionary = control_by_seed["summaries"][seed]
		var seed_failures := _pair_failures(contract, active, control)
		for failure_value in seed_failures:
			failures.append("SEED_%d:%s" % [seed, String(failure_value)])
		(
			cells
			. append(
				{
					"seed": seed,
					"active_complete": bool(active["complete_observed"]),
					"control_complete": bool(control["complete_observed"]),
					"active_com_height_gain_m": float(active["com_height_gain_m"]),
					"control_com_height_gain_m": float(control["com_height_gain_m"]),
					"active_positive_work_j": float(active["actuator_positive_work_j"]),
					"active_energy_residual_j": float(active["energy_balance_residual_j"]),
					"active_guide_impulse_z_n_s":
					float(active["inferred_guide_linear_impulse_z_n_s"]),
					"active_phase_trace": (active["phase_trace"] as Array).duplicate(),
					"control_phase_trace": (control["phase_trace"] as Array).duplicate(),
					"failures": seed_failures,
				}
			)
		)
	return {
		"ok": true,
		"accepted": failures.is_empty(),
		"acceptance_failures": failures,
		"cells": cells,
		"claim_boundary": CLAIM_BOUNDARY,
		"positive_claim": "constrained_planar_get_up",
		"milestone_cells": ["BR13.0", "BR13.1", "BR13.2", "BR13.3", "BR13.4"],
		"does_not_establish":
		[
			"free_3d_recovery",
			"morphology_transfer",
			"gait",
			"walking",
			"creature_repair",
			"automatic_creature_guidance",
		],
	}


static func _pair_failures(
	contract: Dictionary, active: Dictionary, control: Dictionary
) -> Array[String]:
	var failures: Array[String] = []
	if (
		not _near(
			float(active["initial_com_height_m"]), float(control["initial_com_height_m"]), 1.0e-8
		)
		or not _near(
			float(active["initial_kinetic_energy_j"]),
			float(control["initial_kinetic_energy_j"]),
			1.0e-8
		)
		or not _near(
			float(active["initial_mechanical_energy_j"]),
			float(control["initial_mechanical_energy_j"]),
			1.0e-8
		)
		or String(active["initial_pose_state"]) != String(control["initial_pose_state"])
	):
		failures.append("PAIRED_INITIAL_STATE_MISMATCH")
	if (
		not bool(active["complete_observed"])
		or String(active["final_pose_state"]) != "STANCE"
		or String(active["final_supervisor_phase"]) != "COMPLETE"
		or active["phase_trace"] != POSITIVE_PHASE_TRACE
	):
		failures.append("ACTIVE_RECOVERY_SEQUENCE_INCOMPLETE")
	if (
		bool(control["complete_observed"])
		or String(control["final_pose_state"]) != "PRONE"
		or String(control["final_supervisor_phase"]) != "FAILED"
		or float(control["actuator_positive_work_j"]) > 1.0e-9
		or int(control["recovery_command_count"]) != 0
		or int(control["stance_command_count"]) != 0
	):
		failures.append("ZERO_COMMAND_CONTROL_INVALID")
	if (
		float(active["com_height_gain_m"]) < float(contract["minimum_active_com_height_gain_m"])
		or (
			float(control["com_height_gain_m"])
			> float(contract["maximum_control_com_height_gain_m"])
		)
	):
		failures.append("CENTER_OF_MASS_RISE_GATE_FAILED")
	if (
		not bool(active["energy_reconciliation_ok"])
		or not bool(active["energy_reconciliation_accepted"])
		or (
			absf(float(active["energy_balance_residual_j"]))
			> float(contract["maximum_energy_residual_j"])
		)
		or float(active["actuator_positive_work_j"]) <= 0.0
		or float(active["inferred_contact_dissipation_j"]) < 0.0
	):
		failures.append("ACTIVE_ENERGY_ACCOUNTING_FAILED")
	if (
		(
			absf(float(active["inferred_guide_linear_impulse_z_n_s"]))
			> float(contract["maximum_abs_guide_linear_impulse_z_n_s"])
		)
		or absf(float(active["inferred_guide_work_j"])) > 1.0e-9
		or (
			float(active["maximum_out_of_plane_drift_m"])
			> float(contract["maximum_out_of_plane_drift_m"])
		)
		or float(active["maximum_roll_rad"]) > float(contract["maximum_roll_yaw_rad"])
		or float(active["maximum_yaw_rad"]) > float(contract["maximum_roll_yaw_rad"])
	):
		failures.append("PLANAR_GUIDE_ACCOUNTING_FAILED")
	if (
		not bool(active["final_front_pair_bearing"])
		or not bool(active["final_rear_pair_bearing"])
		or bool(active["final_ventral_contact"])
		or (
			float(active["final_max_linear_speed_m_s"])
			> float(contract["maximum_final_linear_speed_m_s"])
		)
		or (
			float(active["final_max_angular_speed_rad_s"])
			> float(contract["maximum_final_angular_speed_rad_s"])
		)
		or int(active["recovery_command_after_handoff_count"]) != 0
		or int(active["stance_command_during_dwell_count"]) <= 0
	):
		failures.append("STANCE_HANDOFF_OR_DWELL_FAILED")
	if (
		not bool(active["all_receipts_complete"])
		or (
			float(active["maximum_pairing_residual_nm"])
			> float(contract["maximum_pairing_residual_nm"])
		)
		or (
			float(active["maximum_applied_torque_nm"])
			> float(contract["maximum_applied_torque_nm"])
		)
		or float(active["maximum_root_pitch_rad"]) > float(contract["maximum_root_pitch_rad"])
		or int(active["recovery_command_count"]) <= 0
		or int(active["stance_command_count"]) <= 0
	):
		failures.append("FINITE_ACTUATION_OR_RECEIPTS_FAILED")
	return failures


static func _index_summaries(
	contract: Dictionary, summaries: Array, expected_enabled: bool
) -> Dictionary:
	var indexed: Dictionary = {}
	for summary_value in summaries:
		if typeof(summary_value) != TYPE_DICTIONARY:
			return _failure("CANONICAL_GET_UP_SUMMARY_NOT_DICTIONARY")
		var summary: Dictionary = summary_value
		var summary_check := _verify_summary(contract, summary, expected_enabled)
		if not bool(summary_check.get("ok", false)):
			return summary_check
		var seed := int(summary["seed"])
		if seed not in contract["seeds"] or indexed.has(seed):
			return _failure("CANONICAL_GET_UP_SUMMARY_SEED_INVALID")
		indexed[seed] = summary
	return {"ok": true, "summaries": indexed}


static func _verify_summary(
	contract: Dictionary, summary: Dictionary, expected_enabled: bool
) -> Dictionary:
	if not _exact_fields(summary, SUMMARY_FIELDS):
		return _failure("CANONICAL_GET_UP_SUMMARY_FIELDS_INVALID")
	if (
		String(summary.get("schema_version", "")) != "canonical_planar_get_up_summary_v1"
		or (
			String(summary.get("configuration_sha256", ""))
			!= String(contract["configuration_sha256"])
		)
		or (
			String(summary.get("profile_sha256", ""))
			!= String(contract["profile"]["profile_sha256"])
		)
		or (
			String(summary.get("actuator_spec_sha256", ""))
			!= String(contract["actuator_spec"]["spec_sha256"])
		)
	):
		return _failure("CANONICAL_GET_UP_SUMMARY_IDENTITY_INVALID")
	if typeof(summary.get("seed")) != TYPE_INT:
		return _failure("CANONICAL_GET_UP_SUMMARY_SEED_TYPE_INVALID")
	for field in [
		"recovery_enabled",
		"fixture_complete",
		"planar_guide_exact",
		"front_hinge_exact",
		"rear_hinge_exact",
		"complete_observed",
		"energy_reconciliation_ok",
		"energy_reconciliation_accepted",
		"final_front_pair_bearing",
		"final_rear_pair_bearing",
		"final_ventral_contact",
		"all_receipts_complete",
		"guide_work_is_residual_inferred",
		"contact_dissipation_is_residual_inferred",
		"free_3d_recovery_established",
		"morphology_transfer_established",
		"gait_established",
		"walking_established",
	]:
		if typeof(summary.get(field)) != TYPE_BOOL:
			return _failure("CANONICAL_GET_UP_SUMMARY_BOOL_INVALID:%s" % field)
	for field in [
		"executed_ticks",
		"actuator_saturation_count",
		"recovery_command_count",
		"stance_command_count",
		"recovery_command_after_handoff_count",
		"stance_command_during_dwell_count",
		"root_rescue_operation_count",
		"foot_pin_operation_count",
		"pose_teleport_operation_count",
		"automatic_creature_guidance_operation_count",
	]:
		if typeof(summary.get(field)) != TYPE_INT or int(summary[field]) < 0:
			return _failure("CANONICAL_GET_UP_SUMMARY_INTEGER_INVALID:%s" % field)
	for field in [
		"initial_com_height_m",
		"final_com_height_m",
		"minimum_com_height_m",
		"maximum_com_height_m",
		"com_height_gain_m",
		"initial_kinetic_energy_j",
		"final_kinetic_energy_j",
		"initial_mechanical_energy_j",
		"final_mechanical_energy_j",
		"actuator_positive_work_j",
		"actuator_absorbed_work_j",
		"net_actuator_work_j",
		"inferred_contact_dissipation_j",
		"inferred_guide_linear_impulse_z_n_s",
		"inferred_guide_work_j",
		"energy_balance_residual_j",
		"front_contact_fraction",
		"rear_contact_fraction",
		"ventral_contact_fraction",
		"final_max_linear_speed_m_s",
		"final_max_angular_speed_rad_s",
		"maximum_root_pitch_rad",
		"maximum_out_of_plane_drift_m",
		"maximum_roll_rad",
		"maximum_yaw_rad",
		"maximum_applied_torque_nm",
		"maximum_pairing_residual_nm",
	]:
		if not _finite_number(summary.get(field)):
			return _failure("CANONICAL_GET_UP_SUMMARY_NUMBER_INVALID:%s" % field)
	if (
		bool(summary["recovery_enabled"]) != expected_enabled
		or not bool(summary["fixture_complete"])
		or not String(summary["fixture_failure_code"]).is_empty()
		or int(summary["executed_ticks"]) != int(contract["rig_configuration"]["trial_ticks"])
		or not bool(summary["planar_guide_exact"])
		or not bool(summary["front_hinge_exact"])
		or not bool(summary["rear_hinge_exact"])
		or not bool(summary["guide_work_is_residual_inferred"])
		or not bool(summary["contact_dissipation_is_residual_inferred"])
	):
		return _failure("CANONICAL_GET_UP_SUMMARY_INTEGRITY_FAILED")
	for field in [
		"root_rescue_operation_count",
		"foot_pin_operation_count",
		"pose_teleport_operation_count",
		"automatic_creature_guidance_operation_count",
	]:
		if int(summary[field]) != 0:
			return _failure("CANONICAL_GET_UP_FORBIDDEN_OPERATION:%s" % field)
	for field in [
		"free_3d_recovery_established",
		"morphology_transfer_established",
		"gait_established",
		"walking_established",
	]:
		if bool(summary[field]):
			return _failure("CANONICAL_GET_UP_FORBIDDEN_RESULT:%s" % field)
	for field in ["front_contact_fraction", "rear_contact_fraction", "ventral_contact_fraction"]:
		if float(summary[field]) < 0.0 or float(summary[field]) > 1.0:
			return _failure("CANONICAL_GET_UP_CONTACT_FRACTION_INVALID:%s" % field)
	if (
		typeof(summary.get("phase_trace")) != TYPE_ARRAY
		or typeof(summary.get("phase_first_ticks")) != TYPE_DICTIONARY
		or typeof(summary.get("fixture_failure_code")) != TYPE_STRING
		or typeof(summary.get("initial_pose_state")) != TYPE_STRING
		or typeof(summary.get("final_pose_state")) != TYPE_STRING
		or typeof(summary.get("final_supervisor_phase")) != TYPE_STRING
	):
		return _failure("CANONICAL_GET_UP_SUMMARY_STRUCTURED_FIELD_INVALID")
	return {"ok": true}


static func _verify_contract(contract: Dictionary) -> Dictionary:
	var source: Dictionary = {}
	for field in CONFIGURATION_FIELDS:
		if not contract.has(field):
			return _failure("CANONICAL_GET_UP_CONTRACT_INCOMPLETE")
		source[field] = contract[field]
	var rebuilt := build(source)
	if not bool(rebuilt.get("ok", false)):
		return rebuilt
	if (
		CanonicalJsonScript.stringify(rebuilt["contract"])
		!= CanonicalJsonScript.stringify(contract)
	):
		return _failure("CANONICAL_GET_UP_CONTRACT_DIGEST_MISMATCH")
	return {"ok": true}


static func _validate_rig(rig: Dictionary, actuator_spec: Dictionary) -> Dictionary:
	if not _exact_fields(rig, RIG_CONFIGURATION_FIELDS):
		return _failure("CANONICAL_GET_UP_RIG_FIELDS_INVALID")
	if (
		typeof(rig.get("physics_hz")) != TYPE_INT
		or int(rig["physics_hz"]) != 120
		or typeof(rig.get("trial_ticks")) != TYPE_INT
		or int(rig["trial_ticks"]) < 600
	):
		return _failure("CANONICAL_GET_UP_RIG_TIMING_INVALID")
	for field in [
		"gravity_m_s2",
		"root_mass_kg",
		"initial_root_height_m",
		"reference_stance_height_m",
		"hip_half_span_m",
		"limb_pair_mass_kg",
		"limb_length_m",
		"limb_width_m",
		"limb_depth_m",
		"foot_radius_m",
		"initial_splay_angle_rad",
		"floor_friction",
		"seed_initial_velocity_m_s",
		"joint_position_gain_nm_rad",
		"joint_velocity_gain_nm_s_rad",
	]:
		if not _finite_number(rig.get(field)) or float(rig[field]) < 0.0:
			return _failure("CANONICAL_GET_UP_RIG_NUMBER_INVALID:%s" % field)
	if not _positive_vector3(rig.get("root_size_m")):
		return _failure("CANONICAL_GET_UP_ROOT_SIZE_INVALID")
	if (
		float(rig["gravity_m_s2"]) <= 0.0
		or float(rig["root_mass_kg"]) <= 0.0
		or float(rig["limb_pair_mass_kg"]) <= 0.0
		or float(rig["limb_length_m"]) <= 0.0
		or float(rig["foot_radius_m"]) <= 0.0
		or float(rig["floor_friction"]) > 1.0
		or float(rig["joint_position_gain_nm_rad"]) <= 0.0
		or float(rig["joint_velocity_gain_nm_s_rad"]) <= 0.0
	):
		return _failure("CANONICAL_GET_UP_RIG_BOUND_INVALID")
	if typeof(rig.get("pose_configuration")) != TYPE_DICTIONARY:
		return _failure("CANONICAL_GET_UP_POSE_CONFIGURATION_INVALID")
	var pose_result := PoseObserverScript.build(rig["pose_configuration"])
	if not bool(pose_result.get("ok", false)):
		return _failure("CANONICAL_GET_UP_POSE_CONFIGURATION_INVALID", pose_result)
	if typeof(rig.get("supervisor_configuration")) != TYPE_DICTIONARY:
		return _failure("CANONICAL_GET_UP_SUPERVISOR_CONFIGURATION_INVALID")
	var supervisor = SupervisorScript.new()
	var supervisor_result := supervisor.configure(rig["supervisor_configuration"])
	if not bool(supervisor_result.get("ok", false)):
		return _failure("CANONICAL_GET_UP_SUPERVISOR_CONFIGURATION_INVALID", supervisor_result)
	if typeof(rig.get("energy_configuration")) != TYPE_DICTIONARY:
		return _failure("CANONICAL_GET_UP_ENERGY_CONFIGURATION_INVALID")
	var energy_result := EnergyLedgerScript.build(rig["energy_configuration"])
	if not bool(energy_result.get("ok", false)):
		return _failure("CANONICAL_GET_UP_ENERGY_CONFIGURATION_INVALID", energy_result)
	if typeof(rig.get("energy_preflight")) != TYPE_DICTIONARY:
		return _failure("CANONICAL_GET_UP_ENERGY_PREFLIGHT_INVALID")
	var preflight := EnergyLedgerScript.preflight(
		rig["energy_configuration"], rig["energy_preflight"]
	)
	if not bool(preflight.get("ok", false)) or not bool(preflight["report"]["feasible"]):
		return _failure("CANONICAL_GET_UP_ENERGY_PREFLIGHT_INFEASIBLE", preflight)
	var expected_mass := float(rig["root_mass_kg"]) + 2.0 * float(rig["limb_pair_mass_kg"])
	if (
		not _near(float(rig["energy_configuration"]["total_mass_kg"]), expected_mass, 1.0e-9)
		or not _near(
			float(rig["energy_configuration"]["gravity_m_s2"]), float(rig["gravity_m_s2"]), 1.0e-9
		)
		or not _near(
			float(rig["energy_preflight"]["available_peak_torque_nm"]),
			float(actuator_spec["max_isometric_torque_nm"]),
			1.0e-9
		)
		or not _near(
			float(rig["energy_preflight"]["available_peak_power_w"]),
			float(actuator_spec["max_positive_power_w"]),
			1.0e-9
		)
		or not _near(
			float(rig["energy_preflight"]["available_structural_torque_nm"]),
			float(actuator_spec["structural_torque_limit_nm"]),
			1.0e-9
		)
	):
		return _failure("CANONICAL_GET_UP_RIG_CROSS_CONTRACT_MISMATCH")
	return {"ok": true}


static func _seeds(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
		return _failure("CANONICAL_GET_UP_SEEDS_INVALID")
	var seeds: Array[int] = []
	var seen: Dictionary = {}
	for item in value:
		if typeof(item) != TYPE_INT or int(item) <= 0 or seen.has(int(item)):
			return _failure("CANONICAL_GET_UP_SEEDS_INVALID")
		seen[int(item)] = true
		seeds.append(int(item))
	return {"ok": true, "seeds": seeds}


static func _positive_vector3(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 3:
		return false
	for item in value:
		if not _finite_number(item) or float(item) <= 0.0:
			return false
	return true


static func _exact_fields(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for field in expected:
		if not value.has(field):
			return false
	return true


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _near(first: float, second: float, tolerance: float) -> bool:
	return absf(first - second) <= tolerance


static func _failure(code: String, details: Dictionary = {}) -> Dictionary:
	var result := {"ok": false, "failure_code": code}
	if not details.is_empty():
		result["details"] = details
	return result
