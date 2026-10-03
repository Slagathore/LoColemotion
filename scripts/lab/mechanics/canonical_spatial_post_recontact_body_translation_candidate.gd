class_name LabCanonicalSpatialPostRecontactBodyTranslationCandidate
extends RefCounted
# gdlint: disable=max-line-length

## Sealed positive prerequisite for the tenth BR14A.5 controller family.
##
## Candidate 9 is retained exactly through targeted recontact and its measured
## damping branch. After a long delay, the paired-torque support endpoint
## controller receives a small forward whole-system COM target. Final foot
## placement retention is measured but deliberately remains outside the
## positive claim.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const Candidate9Script := preload(
	"res://scripts/lab/mechanics/canonical_spatial_targeted_relocation_recovery_candidate.gd"
)

const SCHEMA_VERSION := "canonical_spatial_post_recontact_body_translation_prerequisite_v1"
const EXPERIMENT_ID := "BR14A.5.front_right_post_recontact_body_translation_prerequisite.v1"
const CANDIDATE_STATUS := "positive_bounded_post_recontact_body_translation_prerequisite"
const CONTROLLER_ID := "post_recontact_body_translation_v1"
const CLAIM_BOUNDARY := (
	"Exact BR14A.5 prerequisite commissioning only: candidate 9's targeted "
	+ "front-right relocation, ordinary recontact, and measured damping branch "
	+ "are retained. At least 600 ticks after recontact, the existing "
	+ "receipt-backed support-endpoint controller ramps a 0.030 m target along "
	+ "the declared positive world-x forward axis. Across seeds 14001, 14002, "
	+ "and 14003, the exact 2300-tick program requires at least 0.012 m of "
	+ "directed whole-system COM and torso translation, at least 900 translation "
	+ "command ticks, no more than 0.010 m horizontal slip at any foot during "
	+ "that phase, candidate 9's long-horizon recovery predicate, four ordinary "
	+ "contacts, no torso contact, intact geometry, receipt-complete actuation, "
	+ "zero structural saturation, and zero allocator infeasibility. Final "
	+ "placement retention is measured but is not required or established. "
	+ "This establishes only a bounded post-recontact body-translation "
	+ "prerequisite for the exact morphology, controller, solver, seeds, and "
	+ "thresholds. It establishes no complete locomotor step, repeated stepping, "
	+ "gait, walking, generalized "
	+ "standing or recovery, bracing, fall arrest, get-up, per-foot load "
	+ "allocation, formal acceptance, encyclopedia knowledge, repair, "
	+ "automatic application, or creature guidance."
)


static func configuration() -> Dictionary:
	var candidate := Candidate9Script.configuration().duplicate(true)
	candidate["schema_version"] = SCHEMA_VERSION
	candidate["experiment_id"] = EXPERIMENT_ID
	candidate["behavior_state"] = "FREE_3D_POST_RECONTACT_BODY_TRANSLATION_PREREQUISITE"
	candidate["centroidal_controller_id"] = CONTROLLER_ID
	candidate["trial_ticks"] = 2300
	candidate["semantic_joint_damping_ticks"] = 1800
	candidate["minimum_semantic_joint_damping_command_ticks"] = 1500
	candidate["minimum_post_recontact_recovery_observation_ticks"] = 1500
	candidate["post_recontact_body_translation_delay_ticks"] = 600
	candidate["post_recontact_body_translation_ramp_ticks"] = 480
	candidate["post_recontact_body_translation_offset_world_m"] = [0.030, 0.0, 0.0]
	candidate["post_recontact_body_translation_position_gain_n_per_m"] = 120.0
	candidate["post_recontact_body_translation_velocity_gain_ns_per_m"] = 30.0
	candidate["maximum_post_recontact_body_translation_horizontal_force_n"] = 8.0
	candidate["maximum_post_recontact_body_translation_support_shift_m"] = 0.05
	candidate["post_recontact_body_translation_endpoint_position_gain_n_per_m"] = 120.0
	candidate["post_recontact_body_translation_endpoint_velocity_gain_ns_per_m"] = 8.0
	candidate["maximum_post_recontact_body_translation_endpoint_force_n"] = 12.0
	candidate["minimum_post_recontact_body_translation_command_ticks"] = 900
	candidate["minimum_post_recontact_com_translation_m"] = 0.012
	candidate["minimum_post_recontact_torso_translation_m"] = 0.012
	candidate["maximum_post_recontact_foot_slip_m"] = 0.010
	candidate["candidate_status"] = CANDIDATE_STATUS
	candidate["candidate_result"] = CANDIDATE_STATUS
	candidate["claim_boundary"] = CLAIM_BOUNDARY
	candidate["physical_commissioning_execution_authorized"] = true
	return candidate


static func compile(candidate: Dictionary) -> Dictionary:
	var canonical := configuration()
	if not _same_fields(candidate, canonical):
		return _failure("CANONICAL_SPATIAL_POST_RECONTACT_BODY_TRANSLATION_FIELDS_INVALID")
	if CanonicalJsonScript.stringify(candidate) != CanonicalJsonScript.stringify(canonical):
		return _failure("CANONICAL_SPATIAL_POST_RECONTACT_BODY_TRANSLATION_NOT_EXACT")
	if not _invariants_hold(candidate):
		return _failure("CANONICAL_SPATIAL_POST_RECONTACT_BODY_TRANSLATION_INVARIANT_INVALID")
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
		and int(candidate["trial_ticks"]) == 2300
		and int(candidate["semantic_joint_damping_ticks"]) == 1800
		and int(candidate["minimum_semantic_joint_damping_command_ticks"]) == 1500
		and int(candidate["minimum_post_recontact_recovery_observation_ticks"]) == 1500
		and int(candidate["post_recontact_body_translation_delay_ticks"]) == 600
		and int(candidate["post_recontact_body_translation_ramp_ticks"]) == 480
		and (
			(candidate["post_recontact_body_translation_offset_world_m"] as Array)
			== [0.030, 0.0, 0.0]
		)
		and is_equal_approx(
			float(candidate["post_recontact_body_translation_position_gain_n_per_m"]), 120.0
		)
		and is_equal_approx(
			float(candidate["post_recontact_body_translation_velocity_gain_ns_per_m"]), 30.0
		)
		and is_equal_approx(
			float(candidate["maximum_post_recontact_body_translation_horizontal_force_n"]), 8.0
		)
		and is_equal_approx(
			float(candidate["maximum_post_recontact_body_translation_support_shift_m"]), 0.05
		)
		and is_equal_approx(
			float(candidate["post_recontact_body_translation_endpoint_position_gain_n_per_m"]),
			120.0
		)
		and is_equal_approx(
			float(candidate["post_recontact_body_translation_endpoint_velocity_gain_ns_per_m"]), 8.0
		)
		and is_equal_approx(
			float(candidate["maximum_post_recontact_body_translation_endpoint_force_n"]), 12.0
		)
		and int(candidate["minimum_post_recontact_body_translation_command_ticks"]) == 900
		and is_equal_approx(float(candidate["minimum_post_recontact_com_translation_m"]), 0.012)
		and is_equal_approx(float(candidate["minimum_post_recontact_torso_translation_m"]), 0.012)
		and is_equal_approx(float(candidate["maximum_post_recontact_foot_slip_m"]), 0.010)
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
