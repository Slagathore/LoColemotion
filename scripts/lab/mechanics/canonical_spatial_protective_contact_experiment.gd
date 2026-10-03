class_name LabCanonicalSpatialProtectiveContactExperiment
extends RefCounted

## Exact BR14A.5 candidate protective-contact rejection contract.
##
## One front foot is deliberately cleared while three ordinary stance
## contacts remain. After a matched roll disturbance, the active world drives
## that physical foot to one wider floor target through a bounded
## Jacobian-transpose task-space controller. The control holds the same foot
## at the preregistered clear target.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const StanceExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_stance_experiment.gd"
)

const SCHEMA_VERSION := "canonical_spatial_protective_contact_experiment_v1"
const EXPERIMENT_ID := "BR14A.5.front_right_wide_protective_contact_candidate.v1"
const CANDIDATE_RESULT := "candidate_rejected_no_clearance_quality_recovery_overlap"
const CLAIM_BOUNDARY := (
	"Exact BR14A.5 candidate-rejection commissioning only: the selected BR14A "
	+ "quadruped candidate may clear "
	+ "its front-right foot while retaining three ordinary contacts, receive one "
	+ "declared world-X torso torque impulse, and use receipt-backed "
	+ "Jacobian-transpose joint torques to place that same foot at the exact wider "
	+ "ordinary-floor target, while still failing preregistered geometry, sustained "
	+ "contact, or recovery gates. A passing rejection witness reports only that "
	+ "this exact candidate has no commissioned clearance-quality-recovery overlap. "
	+ "Because positive commissioning required every declared seed to pass, the "
	+ "exact first-seed failure is a sufficient early-stop rejection witness; "
	+ "unexecuted seeds receive no conclusion. "
	+ "It does not prove the morphology or all future controllers incapable. "
	+ "Contact presence is not per-foot measured load or "
	+ "bearing. This is not formal BR14A acceptance, generalized bracing, fall "
	+ "arrest, get-up, load transfer, a locomotor step, gait, walking, repair, "
	+ "automatic application, or creature guidance."
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
	"weight_shift_start_tick",
	"weight_shift_complete_tick",
	"lift_start_tick",
	"lift_complete_tick",
	"disturbance_tick",
	"landing_start_tick",
	"landing_alignment_complete_tick",
	"landing_target_complete_tick",
	"touchdown_deadline_tick",
	"weight_shift_release_start_tick",
	"weight_shift_release_complete_tick",
	"swing_limb_id",
	"swing_contact_id",
	"initial_foot_center_world_m",
	"clear_foot_target_world_m",
	"landing_foot_target_world_m",
	"disturbance_axis_world",
	"disturbance_torque_impulse_nms",
	"precontact_target_torso_shift_world_m",
	"precontact_target_roll_rad",
	"roll_position_gain_nm_per_rad",
	"roll_velocity_gain_nm_s_per_rad",
	"maximum_internal_roll_torque_nm",
	"support_shift_task_position_gain_n_per_m",
	"support_shift_task_velocity_gain_ns_per_m",
	"maximum_support_shift_task_force_n",
	"position_gain_nm_per_rad",
	"velocity_gain_nm_s_per_rad",
	"swing_controller_id",
	"swing_task_position_gain_n_per_m",
	"swing_task_velocity_gain_ns_per_m",
	"maximum_swing_task_force_n",
	"minimum_clear_height_m",
	"minimum_pre_disturbance_clear_ticks",
	"maximum_touchdown_target_error_m",
	"minimum_post_touch_contact_fraction",
	"recovery_height_error_limit_m",
	"recovery_tilt_limit_rad",
	"recovery_full_speed_limit_rad_s",
	"recovery_dwell_ticks_required",
	"maximum_anchor_error_m",
	"maximum_hinge_axis_error_rad",
	"maximum_structural_torque_nm",
	"active_seed_set",
	"rejection_witness_seed",
	"full_seed_success_required",
	"causal_control",
	"allowed_static_bodies",
	"allowed_scaffolds",
	"candidate_result",
	"claim_boundary",
	"physical_commissioning_execution_authorized",
	"formal_milestone_acceptance_authorized",
	"encyclopedia_admission_authorized",
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
		"behavior_state": "FREE_3D_NEW_PROTECTIVE_CONTACT_CANDIDATE_REJECTION",
		"physics_hz": profile["physics_hz"],
		"solver_velocity_steps": profile["solver_velocity_steps"],
		"solver_position_steps": profile["solver_position_steps"],
		"trial_ticks": 960,
		"weight_shift_start_tick": 240,
		"weight_shift_complete_tick": 320,
		"lift_start_tick": 340,
		"lift_complete_tick": 460,
		"disturbance_tick": 480,
		"landing_start_tick": 485,
		"landing_alignment_complete_tick": 490,
		"landing_target_complete_tick": 510,
		"touchdown_deadline_tick": 530,
		"weight_shift_release_start_tick": 530,
		"weight_shift_release_complete_tick": 650,
		"swing_limb_id": "front_right",
		"swing_contact_id": "front_right.foot",
		"initial_foot_center_world_m": [-0.22, 0.05, 0.22],
		"clear_foot_target_world_m": [-0.22, 0.08, 0.30],
		"landing_foot_target_world_m": [-0.27, 0.05, 0.30],
		"disturbance_axis_world": [1.0, 0.0, 0.0],
		"disturbance_torque_impulse_nms": 0.010,
		"precontact_target_torso_shift_world_m": [0.06, 0.0, -0.06],
		"precontact_target_roll_rad": -0.02,
		"roll_position_gain_nm_per_rad": 80.0,
		"roll_velocity_gain_nm_s_per_rad": 4.0,
		"maximum_internal_roll_torque_nm": 8.0,
		"support_shift_task_position_gain_n_per_m": 200.0,
		"support_shift_task_velocity_gain_ns_per_m": 10.0,
		"maximum_support_shift_task_force_n": 30.0,
		"position_gain_nm_per_rad": stance["position_gain_nm_per_rad"],
		"velocity_gain_nm_s_per_rad": stance["velocity_gain_nm_s_per_rad"],
		"swing_controller_id": "measured_jacobian_transpose_task_space_pd_v1",
		"swing_task_position_gain_n_per_m": 1000.0,
		"swing_task_velocity_gain_ns_per_m": 20.0,
		"maximum_swing_task_force_n": 40.0,
		"minimum_clear_height_m": 0.065,
		"minimum_pre_disturbance_clear_ticks": 10,
		"maximum_touchdown_target_error_m": 0.04,
		"minimum_post_touch_contact_fraction": 0.95,
		"recovery_height_error_limit_m": stance["height_error_limit_m"],
		"recovery_tilt_limit_rad": stance["tilt_limit_rad"],
		"recovery_full_speed_limit_rad_s": stance["angular_speed_limit_rad_s"],
		"recovery_dwell_ticks_required": 120,
		"maximum_anchor_error_m": stance["maximum_anchor_error_m"],
		"maximum_hinge_axis_error_rad": stance["maximum_hinge_axis_error_rad"],
		"maximum_structural_torque_nm": stance["maximum_structural_torque_nm"],
		"active_seed_set": profile["seed_set"],
		"rejection_witness_seed": int(profile["seed_set"][0]),
		"full_seed_success_required": true,
		"causal_control": "same_lift_and_disturbance_hold_clear_target_until_incidental_collapse",
		"allowed_static_bodies": ["ordinary_floor"],
		"allowed_scaffolds": [],
		"candidate_result": CANDIDATE_RESULT,
		"claim_boundary": CLAIM_BOUNDARY,
		"physical_commissioning_execution_authorized": true,
		"formal_milestone_acceptance_authorized": false,
		"encyclopedia_admission_authorized": false,
		"locomotor_step_claim_allowed": false,
		"step_gait_or_walking_claim_allowed": false,
		"automatic_creature_guidance_allowed": false,
	}


static func compile(candidate: Dictionary) -> Dictionary:
	if not _exact_fields(candidate, FIELDS):
		return _failure("CANONICAL_SPATIAL_PROTECTIVE_CONTACT_FIELDS_INVALID")
	var canonical := configuration()
	if CanonicalJsonScript.stringify(candidate) != CanonicalJsonScript.stringify(canonical):
		return _failure("CANONICAL_SPATIAL_PROTECTIVE_CONTACT_NOT_EXACT")
	if not _invariants_hold(candidate):
		return _failure("CANONICAL_SPATIAL_PROTECTIVE_CONTACT_INVARIANT_INVALID")
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
		and int(candidate["weight_shift_start_tick"]) < int(candidate["weight_shift_complete_tick"])
		and int(candidate["weight_shift_complete_tick"]) < int(candidate["lift_start_tick"])
		and int(candidate["lift_start_tick"]) < int(candidate["lift_complete_tick"])
		and int(candidate["lift_complete_tick"]) < int(candidate["disturbance_tick"])
		and int(candidate["disturbance_tick"]) < int(candidate["landing_start_tick"])
		and (
			int(candidate["landing_start_tick"]) < int(candidate["landing_alignment_complete_tick"])
		)
		and (
			int(candidate["landing_alignment_complete_tick"])
			< int(candidate["landing_target_complete_tick"])
		)
		and (
			int(candidate["landing_target_complete_tick"])
			< int(candidate["touchdown_deadline_tick"])
		)
		and int(candidate["touchdown_deadline_tick"]) < int(candidate["trial_ticks"])
		and (
			int(candidate["touchdown_deadline_tick"])
			<= int(candidate["weight_shift_release_start_tick"])
		)
		and (
			int(candidate["weight_shift_release_start_tick"])
			< int(candidate["weight_shift_release_complete_tick"])
		)
		and int(candidate["weight_shift_release_complete_tick"]) < int(candidate["trial_ticks"])
		and (
			_vector3(candidate["clear_foot_target_world_m"]).y
			>= float(candidate["minimum_clear_height_m"])
		)
		and (
			_vector3(candidate["landing_foot_target_world_m"]).z
			> _vector3(candidate["initial_foot_center_world_m"]).z
		)
		and _vector3(candidate["disturbance_axis_world"]).is_equal_approx(Vector3.RIGHT)
		and float(candidate["precontact_target_roll_rad"]) < 0.0
		and float(candidate["maximum_internal_roll_torque_nm"]) > 0.0
		and (candidate["active_seed_set"] as Array) == (profile["seed_set"] as Array)
		and int(candidate["rejection_witness_seed"]) == int(profile["seed_set"][0])
		and bool(candidate["full_seed_success_required"])
		and (candidate["allowed_static_bodies"] as Array) == ["ordinary_floor"]
		and (candidate["allowed_scaffolds"] as Array).is_empty()
		and bool(candidate["physical_commissioning_execution_authorized"])
		and not bool(candidate["formal_milestone_acceptance_authorized"])
		and not bool(candidate["encyclopedia_admission_authorized"])
		and not bool(candidate["locomotor_step_claim_allowed"])
		and not bool(candidate["step_gait_or_walking_claim_allowed"])
		and not bool(candidate["automatic_creature_guidance_allowed"])
		and String(candidate["candidate_result"]) == CANDIDATE_RESULT
		and String(candidate["claim_boundary"]) == CLAIM_BOUNDARY
	)


static func _exact_fields(value: Dictionary, fields: Array[String]) -> bool:
	if value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true


static func _vector3(value: Variant) -> Vector3:
	var raw: Array = value
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
