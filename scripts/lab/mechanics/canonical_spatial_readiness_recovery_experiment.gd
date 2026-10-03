class_name LabCanonicalSpatialReadinessRecoveryExperiment
extends RefCounted
# gdlint: disable=max-line-length

## BR14A.4R four-contact global-readiness recovery commissioning contract.
##
## The selected quadruped keeps all four ordinary feet on the floor while a
## measured whole-system COM/capture controller acquires the support triangle
## that would remain after front-right lift, deliberately returns to nominal
## four-contact geometry, and then reacquires the same handoff. A matched
## control omits only the second reacquisition target.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const StanceExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_stance_experiment.gd"
)

const SCHEMA_VERSION := "canonical_spatial_readiness_recovery_experiment_v1"
const EXPERIMENT_ID := "BR14A.4R.front_right_four_contact_readiness_recovery.v1"
const POSITIVE_CLAIM := "four_contact_front_right_handoff_readiness_reacquired_in_commissioning"
const CLAIM_BOUNDARY := (
	"Exact BR14A.4R commissioning only: the selected unscaffolded nine-body, "
	+ "12-DOF quadruped retains all four ordinary floor contacts while one "
	+ "receipt-backed measured-state controller first acquires, deliberately "
	+ "leaves, and then reacquires the declared COM and linearized-capture "
	+ "margin for the support triangle that excludes the front-right contact. "
	+ "A matched control receives the same first acquisition and readiness-loss "
	+ "targets but not the second reacquisition target. Endpoint and observer "
	+ "values are controller state, not measured contact loads or bearing proof. "
	+ "A pass establishes only repeatable four-contact global handoff-readiness "
	+ "recovery for this exact morphology, controller, solver, seed set, and "
	+ "thresholds. It does not lift or move a foot, create a new contact, allocate "
	+ "per-foot measured load, prove articulated three-contact bearing or capture, "
	+ "establish BR14A.5, standing recovery, bracing, fall arrest, get-up, a "
	+ "locomotor step, gait, walking, formal acceptance, encyclopedia knowledge, "
	+ "repair, automatic application, or creature guidance."
)
const FIELDS: Array[String] = [
	"schema_version",
	"experiment_id",
	"source_profile_id",
	"source_profile_sha256",
	"source_stance_experiment_id",
	"source_stance_experiment_sha256",
	"behavior_state",
	"physics_hz",
	"solver_velocity_steps",
	"solver_position_steps",
	"trial_ticks",
	"settle_complete_tick",
	"first_acquisition_complete_tick",
	"first_ready_window_end_tick",
	"readiness_loss_complete_tick",
	"readiness_loss_window_end_tick",
	"second_acquisition_complete_tick",
	"excluded_handoff_limb_id",
	"dynamic_observer_id",
	"controller_id",
	"position_gain_nm_per_rad",
	"velocity_gain_nm_s_per_rad",
	"horizontal_position_gain_n_per_m",
	"horizontal_velocity_gain_ns_per_m",
	"vertical_position_gain_n_per_m",
	"vertical_velocity_gain_ns_per_m",
	"roll_position_gain_nm_per_rad",
	"roll_velocity_gain_nm_s_per_rad",
	"pitch_position_gain_nm_per_rad",
	"pitch_velocity_gain_nm_s_per_rad",
	"maximum_horizontal_force_n",
	"maximum_vertical_correction_n",
	"maximum_roll_pitch_moment_nm",
	"support_endpoint_position_gain_n_per_m",
	"support_endpoint_velocity_gain_ns_per_m",
	"maximum_support_endpoint_force_n",
	"maximum_support_horizontal_shift_m",
	"minimum_ready_margin_m",
	"maximum_loss_margin_m",
	"readiness_dwell_ticks_required",
	"readiness_loss_dwell_ticks_required",
	"minimum_contact_fraction",
	"height_error_limit_m",
	"tilt_limit_rad",
	"final_linear_speed_limit_m_s",
	"final_angular_speed_limit_rad_s",
	"maximum_anchor_error_m",
	"maximum_hinge_axis_error_rad",
	"maximum_structural_torque_nm",
	"active_seed_set",
	"causal_control",
	"allowed_static_bodies",
	"allowed_scaffolds",
	"positive_claim",
	"claim_boundary",
	"physical_commissioning_execution_authorized",
	"formal_milestone_acceptance_authorized",
	"encyclopedia_admission_authorized",
	"per_foot_load_claim_allowed",
	"locomotor_step_claim_allowed",
	"step_gait_or_walking_claim_allowed",
	"automatic_creature_guidance_allowed",
]


static func configuration() -> Dictionary:
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var stance_result := StanceExperimentScript.compile(StanceExperimentScript.configuration())
	assert(bool(profile_result.get("ok", false)))
	assert(bool(stance_result.get("ok", false)))
	var profile: Dictionary = profile_result["profile"]
	var stance: Dictionary = stance_result["experiment"]
	return {
		"schema_version": SCHEMA_VERSION,
		"experiment_id": EXPERIMENT_ID,
		"source_profile_id": profile["profile_id"],
		"source_profile_sha256": profile["profile_sha256"],
		"source_stance_experiment_id": stance["experiment_id"],
		"source_stance_experiment_sha256": stance["experiment_sha256"],
		"behavior_state": "FREE_3D_FOUR_CONTACT_GLOBAL_READINESS_RECOVERY",
		"physics_hz": profile["physics_hz"],
		"solver_velocity_steps": profile["solver_velocity_steps"],
		"solver_position_steps": profile["solver_position_steps"],
		"trial_ticks": 1500,
		"settle_complete_tick": 240,
		"first_acquisition_complete_tick": 480,
		"first_ready_window_end_tick": 720,
		"readiness_loss_complete_tick": 900,
		"readiness_loss_window_end_tick": 1020,
		"second_acquisition_complete_tick": 1260,
		"excluded_handoff_limb_id": "front_right",
		"dynamic_observer_id": "mass_weighted_com_velocity_linearized_capture_v1",
		"controller_id": "four_contact_global_readiness_endpoint_pd_v1",
		"position_gain_nm_per_rad": stance["position_gain_nm_per_rad"],
		"velocity_gain_nm_s_per_rad": stance["velocity_gain_nm_s_per_rad"],
		"horizontal_position_gain_n_per_m": 400.0,
		"horizontal_velocity_gain_ns_per_m": 50.0,
		"vertical_position_gain_n_per_m": 600.0,
		"vertical_velocity_gain_ns_per_m": 80.0,
		"roll_position_gain_nm_per_rad": 24.0,
		"roll_velocity_gain_nm_s_per_rad": 4.0,
		"pitch_position_gain_nm_per_rad": 0.0,
		"pitch_velocity_gain_nm_s_per_rad": 0.0,
		"maximum_horizontal_force_n": 40.0,
		"maximum_vertical_correction_n": 30.0,
		"maximum_roll_pitch_moment_nm": 20.0,
		"support_endpoint_position_gain_n_per_m": 220.0,
		"support_endpoint_velocity_gain_ns_per_m": 12.0,
		"maximum_support_endpoint_force_n": 35.0,
		"maximum_support_horizontal_shift_m": 0.12,
		"minimum_ready_margin_m": 0.025,
		"maximum_loss_margin_m": 0.010,
		"readiness_dwell_ticks_required": 60,
		"readiness_loss_dwell_ticks_required": 60,
		"minimum_contact_fraction": 0.95,
		"height_error_limit_m": stance["height_error_limit_m"],
		"tilt_limit_rad": stance["tilt_limit_rad"],
		"final_linear_speed_limit_m_s": stance["linear_speed_limit_m_s"],
		"final_angular_speed_limit_rad_s": stance["angular_speed_limit_rad_s"],
		"maximum_anchor_error_m": stance["maximum_anchor_error_m"],
		"maximum_hinge_axis_error_rad": stance["maximum_hinge_axis_error_rad"],
		"maximum_structural_torque_nm": stance["maximum_structural_torque_nm"],
		"active_seed_set": profile["seed_set"],
		"causal_control": "matched_first_acquisition_and_loss_second_reacquisition_withheld_v1",
		"allowed_static_bodies": ["ordinary_floor"],
		"allowed_scaffolds": [],
		"positive_claim": POSITIVE_CLAIM,
		"claim_boundary": CLAIM_BOUNDARY,
		"physical_commissioning_execution_authorized": true,
		"formal_milestone_acceptance_authorized": false,
		"encyclopedia_admission_authorized": false,
		"per_foot_load_claim_allowed": false,
		"locomotor_step_claim_allowed": false,
		"step_gait_or_walking_claim_allowed": false,
		"automatic_creature_guidance_allowed": false,
	}


static func compile(candidate: Dictionary) -> Dictionary:
	if not _exact_fields(candidate, FIELDS):
		return _failure("CANONICAL_SPATIAL_READINESS_RECOVERY_FIELDS_INVALID")
	var canonical := configuration()
	if CanonicalJsonScript.stringify(candidate) != CanonicalJsonScript.stringify(canonical):
		return _failure("CANONICAL_SPATIAL_READINESS_RECOVERY_NOT_EXACT")
	if not _invariants_hold(candidate):
		return _failure("CANONICAL_SPATIAL_READINESS_RECOVERY_INVARIANT_INVALID")
	var sealed := candidate.duplicate(true)
	sealed["experiment_sha256"] = CanonicalJsonScript.sha256(candidate)
	sealed["bounded_physical_commissioning_execution_authorized"] = true
	return {"ok": true, "experiment": FrozenValueScript.snapshot(sealed)}


static func _invariants_hold(candidate: Dictionary) -> bool:
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var stance_result := StanceExperimentScript.compile(StanceExperimentScript.configuration())
	if not bool(profile_result.get("ok", false)) or not bool(stance_result.get("ok", false)):
		return false
	var profile: Dictionary = profile_result["profile"]
	var stance: Dictionary = stance_result["experiment"]
	return (
		String(candidate["source_profile_sha256"]) == String(profile["profile_sha256"])
		and (
			String(candidate["source_stance_experiment_sha256"])
			== String(stance["experiment_sha256"])
		)
		and int(candidate["physics_hz"]) == int(profile["physics_hz"])
		and int(candidate["settle_complete_tick"]) > 0
		and (
			int(candidate["settle_complete_tick"])
			< int(candidate["first_acquisition_complete_tick"])
		)
		and (
			int(candidate["first_acquisition_complete_tick"])
			< int(candidate["first_ready_window_end_tick"])
		)
		and (
			int(candidate["first_ready_window_end_tick"])
			< int(candidate["readiness_loss_complete_tick"])
		)
		and (
			int(candidate["readiness_loss_complete_tick"])
			< int(candidate["readiness_loss_window_end_tick"])
		)
		and (
			int(candidate["readiness_loss_window_end_tick"])
			< int(candidate["second_acquisition_complete_tick"])
		)
		and int(candidate["second_acquisition_complete_tick"]) < int(candidate["trial_ticks"])
		and int(candidate["readiness_dwell_ticks_required"]) > 0
		and int(candidate["readiness_loss_dwell_ticks_required"]) > 0
		and float(candidate["minimum_ready_margin_m"]) > float(candidate["maximum_loss_margin_m"])
		and float(candidate["maximum_support_horizontal_shift_m"]) > 0.0
		and (candidate["active_seed_set"] as Array) == (profile["seed_set"] as Array)
		and (candidate["allowed_static_bodies"] as Array) == ["ordinary_floor"]
		and (candidate["allowed_scaffolds"] as Array).is_empty()
		and float(candidate["height_error_limit_m"]) == float(stance["height_error_limit_m"])
		and float(candidate["tilt_limit_rad"]) == float(stance["tilt_limit_rad"])
		and bool(candidate["physical_commissioning_execution_authorized"])
		and not bool(candidate["formal_milestone_acceptance_authorized"])
		and not bool(candidate["encyclopedia_admission_authorized"])
		and not bool(candidate["per_foot_load_claim_allowed"])
		and not bool(candidate["locomotor_step_claim_allowed"])
		and not bool(candidate["step_gait_or_walking_claim_allowed"])
		and not bool(candidate["automatic_creature_guidance_allowed"])
		and String(candidate["positive_claim"]) == POSITIVE_CLAIM
		and String(candidate["claim_boundary"]) == CLAIM_BOUNDARY
	)


static func _exact_fields(value: Dictionary, fields: Array[String]) -> bool:
	if value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
