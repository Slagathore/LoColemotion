class_name LabCanonicalSpatialTargetedRelocationRecoveryCandidate
extends RefCounted
# gdlint: disable=max-line-length

## Sealed positive prerequisite for the ninth BR14A.5 controller family.
##
## Candidate 8's targeted semantic release/recontact is retained exactly and
## extended to the original 1700-tick horizon. A measured swing-joint rate norm
## at ordinary recontact selects either swing-limb-only or all-limb bounded
## relative-rate damping through the receipt-backed paired-torque path.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const Candidate8Script := preload(
	"res://scripts/lab/mechanics/canonical_spatial_targeted_relocation_recontact_candidate.gd"
)

const SCHEMA_VERSION := "canonical_spatial_targeted_relocation_recovery_candidate_v1"
const EXPERIMENT_ID := "BR14A.5.front_right_targeted_relocation_recovery_prerequisite.v1"
const CANDIDATE_STATUS := "positive_long_horizon_targeted_relocation_recovery_prerequisite"
const CONTROLLER_ID := "measured_semantic_recontact_joint_damping_v1"
const CLAIM_BOUNDARY := (
	"Exact BR14A.5 prerequisite commissioning only: candidate 8's canonical "
	+ "front-right foot release, 0.020 m horizontal relocation target, and "
	+ "ordinary relocated recontact are retained across seeds 14001, 14002, "
	+ "and 14003. At recontact, the measured Euclidean norm of the three swing "
	+ "joint rates selects bounded post-contact damping: values at or above "
	+ "3.7 rad/s enable all twelve joints, while lower values enable only the "
	+ "three swing-limb joints. Damping gain is 0.2 N m s/rad and each added "
	+ "joint command is capped at 0.5 N m through the existing paired-torque "
	+ "receipt path. The exact 1700-tick program requires at least 900 "
	+ "post-recontact observation ticks, all four ordinary contacts, no torso "
	+ "floor contact, final height at least 0.39 m, tilt at most 0.05 rad, "
	+ "angular speed at most 0.05 rad/s, intact geometry, feasible allocator "
	+ "history, and zero structural saturation. The adaptive threshold was "
	+ "developed for this exact morphology and seed set and grants no "
	+ "out-of-sample robustness. This establishes only a long-horizon targeted "
	+ "single-foot relocation/recontact recovery prerequisite for the exact "
	+ "morphology, controller, solver, seeds, and thresholds. It does not "
	+ "establish body translation, a complete locomotor step, repeated stepping, "
	+ "gait, walking, general standing or recovery, bracing, fall arrest, "
	+ "get-up, per-foot load allocation, formal acceptance, encyclopedia "
	+ "knowledge, repair, automatic application, or creature guidance."
)


static func configuration() -> Dictionary:
	var candidate := Candidate8Script.configuration().duplicate(true)
	candidate["schema_version"] = SCHEMA_VERSION
	candidate["experiment_id"] = EXPERIMENT_ID
	candidate["behavior_state"] = "FREE_3D_TARGETED_RELOCATION_RECOVERY_PREREQUISITE"
	candidate["centroidal_controller_id"] = CONTROLLER_ID
	candidate["trial_ticks"] = 1700
	candidate["semantic_joint_rate_damping_nm_s_per_rad"] = 0.2
	candidate["maximum_semantic_joint_damping_torque_nm"] = 0.5
	candidate["semantic_joint_damping_ticks"] = 1000
	candidate["semantic_joint_damping_limb_scope"] = "adaptive_swing_rate_norm_v1"
	candidate["semantic_all_limb_damping_activation_rate_rad_s"] = 3.7
	candidate["minimum_semantic_joint_damping_command_ticks"] = 900
	candidate["minimum_post_recontact_recovery_observation_ticks"] = 900
	candidate["minimum_long_horizon_torso_height_m"] = 0.39
	candidate["maximum_long_horizon_torso_tilt_rad"] = 0.05
	candidate["maximum_long_horizon_torso_speed_rad_s"] = 0.05
	candidate["expected_all_limb_damping_seed_set"] = [14001]
	candidate["candidate_status"] = CANDIDATE_STATUS
	candidate["candidate_result"] = CANDIDATE_STATUS
	candidate["claim_boundary"] = CLAIM_BOUNDARY
	candidate["physical_commissioning_execution_authorized"] = true
	return candidate


static func compile(candidate: Dictionary) -> Dictionary:
	var canonical := configuration()
	if not _same_fields(candidate, canonical):
		return _failure("CANONICAL_SPATIAL_TARGETED_RELOCATION_RECOVERY_FIELDS_INVALID")
	if CanonicalJsonScript.stringify(candidate) != CanonicalJsonScript.stringify(canonical):
		return _failure("CANONICAL_SPATIAL_TARGETED_RELOCATION_RECOVERY_NOT_EXACT")
	if not _invariants_hold(candidate):
		return _failure("CANONICAL_SPATIAL_TARGETED_RELOCATION_RECOVERY_INVARIANT_INVALID")
	var sealed := candidate.duplicate(true)
	sealed["experiment_sha256"] = CanonicalJsonScript.sha256(candidate)
	sealed["bounded_physical_development_execution_authorized"] = true
	return {"ok": true, "experiment": FrozenValueScript.snapshot(sealed)}


static func _invariants_hold(candidate: Dictionary) -> bool:
	return (
		String(candidate["schema_version"]) == SCHEMA_VERSION
		and String(candidate["experiment_id"]) == EXPERIMENT_ID
		and String(candidate["centroidal_controller_id"]) == CONTROLLER_ID
		and String(candidate["candidate_status"]) == CANDIDATE_STATUS
		and String(candidate["candidate_result"]) == CANDIDATE_STATUS
		and String(candidate["claim_boundary"]) == CLAIM_BOUNDARY
		and int(candidate["trial_ticks"]) == 1700
		and is_equal_approx(float(candidate["semantic_joint_rate_damping_nm_s_per_rad"]), 0.2)
		and is_equal_approx(float(candidate["maximum_semantic_joint_damping_torque_nm"]), 0.5)
		and int(candidate["semantic_joint_damping_ticks"]) == 1000
		and String(candidate["semantic_joint_damping_limb_scope"]) == "adaptive_swing_rate_norm_v1"
		and is_equal_approx(
			float(candidate["semantic_all_limb_damping_activation_rate_rad_s"]), 3.7
		)
		and int(candidate["minimum_semantic_joint_damping_command_ticks"]) == 900
		and int(candidate["minimum_post_recontact_recovery_observation_ticks"]) == 900
		and is_equal_approx(float(candidate["minimum_long_horizon_torso_height_m"]), 0.39)
		and is_equal_approx(float(candidate["maximum_long_horizon_torso_tilt_rad"]), 0.05)
		and is_equal_approx(float(candidate["maximum_long_horizon_torso_speed_rad_s"]), 0.05)
		and (candidate["expected_all_limb_damping_seed_set"] as Array) == [14001]
		and bool(candidate["physical_development_execution_authorized"])
		and bool(candidate["physical_commissioning_execution_authorized"])
		and not bool(candidate["formal_milestone_acceptance_authorized"])
		and not bool(candidate["encyclopedia_admission_authorized"])
		and not bool(candidate["per_foot_load_claim_allowed"])
		and not bool(candidate["locomotor_step_claim_allowed"])
		and not bool(candidate["step_gait_or_walking_claim_allowed"])
		and not bool(candidate["automatic_creature_guidance_allowed"])
	)


static func _same_fields(value: Dictionary, canonical: Dictionary) -> bool:
	if value.size() != canonical.size():
		return false
	for field in canonical:
		if not value.has(field):
			return false
	return true


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
