class_name LabCanonicalSpatialCentroidalContactCandidate
extends RefCounted
# gdlint: disable=max-line-length

## Sealed rejection contract for the second BR14A.5 controller family.
##
## Unlike the frozen first-candidate rejection, this family closes support
## feedback on measured whole-system COM position and velocity and replaces
## the swing map with damped least squares. The first required seed clears and
## provisionally retouches but fails the complete preregistered overlap, which
## is sufficient to reject this exact all-seed candidate.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const StanceExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_stance_experiment.gd"
)

const SCHEMA_VERSION := "canonical_spatial_centroidal_contact_candidate_v1"
const EXPERIMENT_ID := "BR14A.5.front_right_centroidal_protective_contact_candidate.v1"
const CANDIDATE_STATUS := "candidate_rejected_dynamic_support_geometry_recovery_no_overlap"
const CANDIDATE_RESULT := CANDIDATE_STATUS
const CLAIM_BOUNDARY := (
	"Exact BR14A.5 second-candidate rejection commissioning only: the selected nine-body, "
	+ "12-DOF quadruped may execute one source-pinned front-right foot-clearance, "
	+ "declared roll-disturbance, and wider ordinary-floor placement probe while a "
	+ "read-only mass-weighted COM/capture observer drives bounded stance-endpoint "
	+ "commands and a measured damped-least-squares swing map through receipt-backed "
	+ "joint torques. Endpoint values are controller commands, not measured loads. "
	+ "One exact first-seed "
	+ "failure rejects this all-seed candidate after it clears and provisionally "
	+ "retouches but fails dynamic-support, sustained-contact, geometry, and "
	+ "recovery overlap. Unexecuted seeds receive no conclusion, and this does "
	+ "not prove the morphology or all future controllers incapable. It "
	+ "establishes no per-foot measured load allocation, bearing, load transfer, "
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
	"weight_shift_start_tick",
	"weight_shift_complete_tick",
	"lift_start_tick",
	"vertical_lift_complete_tick",
	"lift_complete_tick",
	"disturbance_tick",
	"landing_start_tick",
	"landing_alignment_complete_tick",
	"landing_target_complete_tick",
	"touchdown_deadline_tick",
	"support_recenter_start_tick",
	"support_recenter_complete_tick",
	"swing_limb_id",
	"swing_contact_id",
	"initial_foot_center_world_m",
	"clear_foot_target_world_m",
	"landing_foot_target_world_m",
	"post_touch_press_depth_m",
	"disturbance_axis_world",
	"disturbance_torque_impulse_nms",
	"support_target_policy",
	"triangle_incenter_target_fraction",
	"dynamic_observer_id",
	"centroidal_controller_id",
	"horizontal_position_gain_n_per_m",
	"horizontal_velocity_gain_ns_per_m",
	"airborne_horizontal_position_gain_n_per_m",
	"airborne_horizontal_velocity_gain_ns_per_m",
	"vertical_position_gain_n_per_m",
	"vertical_velocity_gain_ns_per_m",
	"roll_position_gain_nm_per_rad",
	"roll_velocity_gain_nm_s_per_rad",
	"airborne_roll_position_gain_nm_per_rad",
	"airborne_roll_velocity_gain_nm_s_per_rad",
	"pitch_position_gain_nm_per_rad",
	"pitch_velocity_gain_nm_s_per_rad",
	"airborne_pitch_position_gain_nm_per_rad",
	"airborne_pitch_velocity_gain_nm_s_per_rad",
	"maximum_horizontal_force_n",
	"airborne_maximum_horizontal_force_n",
	"maximum_vertical_correction_n",
	"maximum_roll_pitch_moment_nm",
	"support_endpoint_position_gain_n_per_m",
	"support_endpoint_velocity_gain_ns_per_m",
	"maximum_support_endpoint_force_n",
	"airborne_maximum_support_endpoint_force_n",
	"maximum_support_horizontal_shift_m",
	"airborne_maximum_support_horizontal_shift_m",
	"support_authority_ramp_ticks",
	"support_authority_full_capture_margin_m",
	"support_authority_release_capture_margin_m",
	"three_contact_vertical_support_shift_m",
	"four_contact_commanded_normal_load_fraction",
	"three_contact_commanded_normal_load_fraction",
	"position_gain_nm_per_rad",
	"velocity_gain_nm_s_per_rad",
	"swing_controller_id",
	"swing_lift_path_policy",
	"swing_task_position_gain_per_s",
	"swing_dls_damping_m",
	"maximum_swing_endpoint_speed_m_s",
	"maximum_swing_joint_speed_rad_s",
	"swing_joint_velocity_gain_nm_s_per_rad",
	"maximum_swing_joint_torque_nm",
	"minimum_clear_height_m",
	"minimum_pre_disturbance_clear_ticks",
	"minimum_three_contact_handoff_margin_m",
	"minimum_lift_entry_dynamic_margin_m",
	"minimum_three_contact_com_margin_m",
	"minimum_three_contact_capture_margin_m",
	"maximum_touchdown_target_error_m",
	"minimum_post_touch_contact_fraction",
	"minimum_support_contact_fraction",
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
	"candidate_status",
	"candidate_result",
	"claim_boundary",
	"physical_development_execution_authorized",
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
		"behavior_state": "FREE_3D_CENTROIDAL_PROTECTIVE_CONTACT_DEVELOPMENT",
		"physics_hz": profile["physics_hz"],
		"solver_velocity_steps": profile["solver_velocity_steps"],
		"solver_position_steps": profile["solver_position_steps"],
		"trial_ticks": 1700,
		"weight_shift_start_tick": 240,
		"weight_shift_complete_tick": 480,
		"lift_start_tick": 720,
		"vertical_lift_complete_tick": 721,
		"lift_complete_tick": 840,
		"disturbance_tick": 900,
		"landing_start_tick": 910,
		"landing_alignment_complete_tick": 970,
		"landing_target_complete_tick": 1060,
		"touchdown_deadline_tick": 1130,
		"support_recenter_start_tick": 1180,
		"support_recenter_complete_tick": 1340,
		"swing_limb_id": "front_right",
		"swing_contact_id": "front_right.foot",
		"initial_foot_center_world_m": [-0.22, 0.05, 0.22],
		"clear_foot_target_world_m": [-0.22, 0.15, 0.30],
		"landing_foot_target_world_m": [-0.27, 0.05, 0.30],
		"post_touch_press_depth_m": 0.003,
		"disturbance_axis_world": [1.0, 0.0, 0.0],
		"disturbance_torque_impulse_nms": 0.010,
		"support_target_policy": "live_triangle_incenter_then_live_four_contact_centroid_v1",
		"triangle_incenter_target_fraction": 1.0,
		"dynamic_observer_id": "mass_weighted_com_velocity_linearized_capture_v1",
		"centroidal_controller_id": "capture_risk_scheduled_layered_stance_endpoint_pd_v3",
		"horizontal_position_gain_n_per_m": 400.0,
		"horizontal_velocity_gain_ns_per_m": 50.0,
		"airborne_horizontal_position_gain_n_per_m": 800.0,
		"airborne_horizontal_velocity_gain_ns_per_m": 80.0,
		"vertical_position_gain_n_per_m": 600.0,
		"vertical_velocity_gain_ns_per_m": 80.0,
		"roll_position_gain_nm_per_rad": 24.0,
		"roll_velocity_gain_nm_s_per_rad": 4.0,
		"airborne_roll_position_gain_nm_per_rad": 160.0,
		"airborne_roll_velocity_gain_nm_s_per_rad": 30.0,
		"pitch_position_gain_nm_per_rad": 0.0,
		"pitch_velocity_gain_nm_s_per_rad": 0.0,
		"airborne_pitch_position_gain_nm_per_rad": 80.0,
		"airborne_pitch_velocity_gain_nm_s_per_rad": 12.0,
		"maximum_horizontal_force_n": 40.0,
		"airborne_maximum_horizontal_force_n": 90.0,
		"maximum_vertical_correction_n": 30.0,
		"maximum_roll_pitch_moment_nm": 20.0,
		"support_endpoint_position_gain_n_per_m": 220.0,
		"support_endpoint_velocity_gain_ns_per_m": 12.0,
		"maximum_support_endpoint_force_n": 35.0,
		"airborne_maximum_support_endpoint_force_n": 60.0,
		"maximum_support_horizontal_shift_m": 0.12,
		"airborne_maximum_support_horizontal_shift_m": 0.25,
		"support_authority_ramp_ticks": 40,
		"support_authority_full_capture_margin_m": 0.005,
		"support_authority_release_capture_margin_m": 0.035,
		"three_contact_vertical_support_shift_m": 0.0,
		"four_contact_commanded_normal_load_fraction": 0.25,
		"three_contact_commanded_normal_load_fraction": 1.0 / 3.0,
		"position_gain_nm_per_rad": stance["position_gain_nm_per_rad"],
		"velocity_gain_nm_s_per_rad": stance["velocity_gain_nm_s_per_rad"],
		"swing_controller_id": "measured_damped_least_squares_resolved_rate_v1",
		"swing_lift_path_policy": "simultaneous_xyz_smoothstep_v1",
		"swing_task_position_gain_per_s": 8.0,
		"swing_dls_damping_m": 0.030,
		"maximum_swing_endpoint_speed_m_s": 0.35,
		"maximum_swing_joint_speed_rad_s": 5.0,
		"swing_joint_velocity_gain_nm_s_per_rad": 6.0,
		"maximum_swing_joint_torque_nm": 20.0,
		"minimum_clear_height_m": 0.070,
		"minimum_pre_disturbance_clear_ticks": 20,
		"minimum_three_contact_handoff_margin_m": 0.025,
		"minimum_lift_entry_dynamic_margin_m": 0.020,
		"minimum_three_contact_com_margin_m": 0.0,
		"minimum_three_contact_capture_margin_m": 0.0,
		"maximum_touchdown_target_error_m": 0.04,
		"minimum_post_touch_contact_fraction": 0.95,
		"minimum_support_contact_fraction": 0.90,
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
		"causal_control": "source_pinned_shift_lift_disturbance_and_touchdown_timeline_v1",
		"allowed_static_bodies": ["ordinary_floor"],
		"allowed_scaffolds": [],
		"candidate_status": CANDIDATE_STATUS,
		"candidate_result": CANDIDATE_RESULT,
		"claim_boundary": CLAIM_BOUNDARY,
		"physical_development_execution_authorized": true,
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
		return _failure("CANONICAL_SPATIAL_CENTROIDAL_CONTACT_FIELDS_INVALID")
	var canonical := configuration()
	if CanonicalJsonScript.stringify(candidate) != CanonicalJsonScript.stringify(canonical):
		return _failure("CANONICAL_SPATIAL_CENTROIDAL_CONTACT_NOT_EXACT")
	if not _invariants_hold(candidate):
		return _failure("CANONICAL_SPATIAL_CENTROIDAL_CONTACT_INVARIANT_INVALID")
	var sealed := candidate.duplicate(true)
	sealed["experiment_sha256"] = CanonicalJsonScript.sha256(candidate)
	sealed["bounded_physical_development_execution_authorized"] = true
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
		and int(candidate["weight_shift_start_tick"]) < int(candidate["weight_shift_complete_tick"])
		and int(candidate["weight_shift_complete_tick"]) < int(candidate["lift_start_tick"])
		and int(candidate["lift_start_tick"]) < int(candidate["vertical_lift_complete_tick"])
		and int(candidate["vertical_lift_complete_tick"]) < int(candidate["lift_complete_tick"])
		and int(candidate["lift_complete_tick"]) < int(candidate["disturbance_tick"])
		and int(candidate["disturbance_tick"]) < int(candidate["landing_start_tick"])
		and int(candidate["landing_start_tick"]) < int(candidate["landing_alignment_complete_tick"])
		and (
			int(candidate["landing_alignment_complete_tick"])
			< int(candidate["landing_target_complete_tick"])
		)
		and (
			int(candidate["landing_target_complete_tick"])
			< int(candidate["touchdown_deadline_tick"])
		)
		and (
			int(candidate["touchdown_deadline_tick"])
			< int(candidate["support_recenter_start_tick"])
		)
		and (
			int(candidate["support_recenter_start_tick"])
			< int(candidate["support_recenter_complete_tick"])
		)
		and int(candidate["support_recenter_complete_tick"]) < int(candidate["trial_ticks"])
		and (
			_vector3(candidate["clear_foot_target_world_m"]).y
			>= float(candidate["minimum_clear_height_m"])
		)
		and (
			_vector3(candidate["landing_foot_target_world_m"]).z
			> _vector3(candidate["initial_foot_center_world_m"]).z
		)
		and _vector3(candidate["disturbance_axis_world"]).is_equal_approx(Vector3.RIGHT)
		and float(candidate["post_touch_press_depth_m"]) >= 0.0
		and float(candidate["minimum_lift_entry_dynamic_margin_m"]) > 0.0
		and (
			float(candidate["minimum_three_contact_handoff_margin_m"])
			>= float(candidate["minimum_lift_entry_dynamic_margin_m"])
		)
		and float(candidate["triangle_incenter_target_fraction"]) > 0.0
		and float(candidate["triangle_incenter_target_fraction"]) <= 1.0
		and float(candidate["support_authority_full_capture_margin_m"]) >= 0.0
		and (
			float(candidate["support_authority_full_capture_margin_m"])
			< float(candidate["support_authority_release_capture_margin_m"])
		)
		and is_equal_approx(float(candidate["four_contact_commanded_normal_load_fraction"]), 0.25)
		and is_equal_approx(
			float(candidate["three_contact_commanded_normal_load_fraction"]), 1.0 / 3.0
		)
		and (candidate["active_seed_set"] as Array) == (profile["seed_set"] as Array)
		and int(candidate["rejection_witness_seed"]) == int(profile["seed_set"][0])
		and bool(candidate["full_seed_success_required"])
		and (candidate["allowed_static_bodies"] as Array) == ["ordinary_floor"]
		and (candidate["allowed_scaffolds"] as Array).is_empty()
		and String(candidate["candidate_status"]) == CANDIDATE_STATUS
		and String(candidate["candidate_result"]) == CANDIDATE_RESULT
		and String(candidate["claim_boundary"]) == CLAIM_BOUNDARY
		and bool(candidate["physical_development_execution_authorized"])
		and bool(candidate["physical_commissioning_execution_authorized"])
		and not bool(candidate["formal_milestone_acceptance_authorized"])
		and not bool(candidate["encyclopedia_admission_authorized"])
		and not bool(candidate["per_foot_load_claim_allowed"])
		and not bool(candidate["locomotor_step_claim_allowed"])
		and not bool(candidate["step_gait_or_walking_claim_allowed"])
		and not bool(candidate["automatic_creature_guidance_allowed"])
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
