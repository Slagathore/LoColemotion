class_name LabCanonicalSpatialSemanticReleaseRecontactCandidate
extends RefCounted
# gdlint: disable=max-line-length

## Sealed positive prerequisite for the seventh BR14A.5 controller family.
##
## The selected foot is removed from the commanded support topology before a
## bounded vertical Jacobian-transpose task acts on its physical joints. The
## task stops only after the engine reports semantic contact absence. Logical
## path progress, disturbance, targeted relocation, and touchdown are disabled.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const Candidate6Script := preload(
	"res://scripts/lab/mechanics/canonical_spatial_contact_state_lift_candidate.gd"
)

const SCHEMA_VERSION := "canonical_spatial_semantic_release_recontact_candidate_v1"
const EXPERIMENT_ID := "BR14A.5.front_right_semantic_release_recontact_prerequisite.v1"
const CANDIDATE_STATUS := "positive_bounded_semantic_release_recontact_prerequisite"
const CONTROLLER_ID := "predictive_semantic_release_recontact_allocator_v1"
const CLAIM_BOUNDARY := (
	"Exact BR14A.5 prerequisite commissioning only: across preregistered seeds "
	+ "14001, 14002, and 14003, the selected canonical front-right foot is "
	+ "excluded from commanded support before a bounded vertical "
	+ "Jacobian-transpose task produces engine-observed semantic contact absence "
	+ "for four contiguous ticks, a positive shape gap of at least 0.025 m, and "
	+ "ordinary same-place recontact within eight ticks. The exact 841-tick "
	+ "program suppresses disturbance, logical swing-path progress, targeted "
	+ "relocation, and touchdown, and requires bounded non-collapse and intact "
	+ "joint geometry through its end. Contact state and geometric gap are not "
	+ "measured load or bearing. This establishes only bounded single-foot "
	+ "semantic release and recontact for the exact morphology, controller, "
	+ "solver, seeds, and thresholds. It does not establish long-horizon "
	+ "recovery, BR14A.5 protective contact, per-foot load allocation, a "
	+ "locomotor step, standing, bracing, fall arrest, get-up, gait, walking, "
	+ "formal acceptance, encyclopedia knowledge, repair, automatic application, "
	+ "or creature guidance."
)


static func configuration() -> Dictionary:
	var candidate := Candidate6Script.configuration().duplicate(true)
	candidate["schema_version"] = SCHEMA_VERSION
	candidate["experiment_id"] = EXPERIMENT_ID
	candidate["behavior_state"] = "FREE_3D_SEMANTIC_RELEASE_RECONTACT_PREREQUISITE"
	candidate["centroidal_controller_id"] = CONTROLLER_ID
	candidate["trial_ticks"] = 841
	candidate["semantic_release_commit_ticks"] = 32
	candidate["minimum_semantic_absence_dwell_ticks"] = 4
	candidate["minimum_semantic_release_gap_m"] = 0.025
	candidate["maximum_semantic_release_tick"] = 730
	candidate["maximum_semantic_recontact_latency_ticks"] = 8
	candidate["minimum_post_recontact_observation_ticks"] = 100
	candidate["minimum_bounded_torso_height_m"] = 0.35
	candidate["maximum_bounded_torso_tilt_rad"] = 0.15
	candidate["contact_release_dwell_ticks_required"] = 1
	candidate["candidate_status"] = CANDIDATE_STATUS
	candidate["candidate_result"] = CANDIDATE_STATUS
	candidate["claim_boundary"] = CLAIM_BOUNDARY
	candidate["physical_commissioning_execution_authorized"] = true
	return candidate


static func compile(candidate: Dictionary) -> Dictionary:
	var canonical := configuration()
	if not _same_fields(candidate, canonical):
		return _failure("CANONICAL_SPATIAL_SEMANTIC_RELEASE_RECONTACT_FIELDS_INVALID")
	if CanonicalJsonScript.stringify(candidate) != CanonicalJsonScript.stringify(canonical):
		return _failure("CANONICAL_SPATIAL_SEMANTIC_RELEASE_RECONTACT_NOT_EXACT")
	if not _invariants_hold(candidate):
		return _failure("CANONICAL_SPATIAL_SEMANTIC_RELEASE_RECONTACT_INVARIANT_INVALID")
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
		and int(candidate["trial_ticks"]) == 841
		and int(candidate["semantic_release_commit_ticks"]) == 32
		and int(candidate["minimum_semantic_absence_dwell_ticks"]) == 4
		and is_equal_approx(float(candidate["minimum_semantic_release_gap_m"]), 0.025)
		and int(candidate["maximum_semantic_release_tick"]) == 730
		and int(candidate["maximum_semantic_recontact_latency_ticks"]) == 8
		and int(candidate["minimum_post_recontact_observation_ticks"]) == 100
		and is_equal_approx(float(candidate["minimum_bounded_torso_height_m"]), 0.35)
		and is_equal_approx(float(candidate["maximum_bounded_torso_tilt_rad"]), 0.15)
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
