class_name LabCanonicalSpatialTargetedRelocationRecontactCandidate
extends RefCounted
# gdlint: disable=max-line-length

## Sealed positive prerequisite for the eighth BR14A.5 controller family.
##
## Candidate 7's semantic release is retained, but the post-release task now
## commands a small horizontal relocation before ordinary floor recontact.
## The exact program ends while all seeds remain inside a bounded noncollapse
## and intact-geometry envelope. It deliberately does not claim long-horizon
## recovery or a complete locomotor step.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const Candidate7Script := preload(
	"res://scripts/lab/mechanics/canonical_spatial_semantic_release_recontact_candidate.gd"
)

const SCHEMA_VERSION := "canonical_spatial_targeted_relocation_recontact_candidate_v1"
const EXPERIMENT_ID := "BR14A.5.front_right_targeted_relocation_recontact_prerequisite.v1"
const CANDIDATE_STATUS := "positive_bounded_targeted_relocation_recontact_prerequisite"
const CONTROLLER_ID := "measured_semantic_relocation_recontact_v1"
const CLAIM_BOUNDARY := (
	"Exact BR14A.5 prerequisite commissioning only: across preregistered seeds "
	+ "14001, 14002, and 14003, candidate 7's selected canonical front-right "
	+ "foot is semantically removed from engine contact, receives a bounded "
	+ "two-centimeter horizontal relocation target through the same "
	+ "Jacobian-transpose task family, and creates an ordinary relocated floor "
	+ "contact within ten ticks. Horizontal displacement must be at least "
	+ "0.020 m and horizontal target error no greater than 0.010 m. The exact "
	+ "781-tick program suppresses the external disturbance and legacy logical "
	+ "swing path, then requires at least 47 post-recontact observation ticks, "
	+ "bounded noncollapse, all four ordinary contacts, no torso-floor contact, "
	+ "and intact joint geometry. Contact state, target error, and geometric "
	+ "displacement are not measured load or bearing. This establishes only a "
	+ "bounded targeted single-foot relocation/recontact prerequisite for the "
	+ "exact morphology, controller, solver, seeds, and thresholds. It does not "
	+ "establish long-horizon recovery, BR14A.5 protective contact, per-foot "
	+ "load allocation, a complete locomotor step, body translation, repeatable "
	+ "gait, standing, bracing, fall arrest, get-up, walking, formal acceptance, "
	+ "encyclopedia knowledge, repair, automatic application, or creature guidance."
)


static func configuration() -> Dictionary:
	var candidate := Candidate7Script.configuration().duplicate(true)
	candidate["schema_version"] = SCHEMA_VERSION
	candidate["experiment_id"] = EXPERIMENT_ID
	candidate["behavior_state"] = "FREE_3D_TARGETED_RELOCATION_RECONTACT_PREREQUISITE"
	candidate["centroidal_controller_id"] = CONTROLLER_ID
	candidate["trial_ticks"] = 781
	candidate["semantic_release_commit_ticks"] = 180
	candidate["semantic_relocation_clear_offset_m"] = [0.020, 0.005, 0.0]
	candidate["semantic_relocation_lift_ticks"] = 2
	candidate["semantic_relocation_lower_ticks"] = 8
	candidate["semantic_relocation_position_gain_n_per_m"] = 300.0
	candidate["semantic_relocation_velocity_gain_ns_per_m"] = 20.0
	candidate["maximum_semantic_relocation_task_force_n"] = 12.0
	candidate["semantic_relocation_minimum_upward_velocity_m_s"] = 0.05
	candidate["semantic_relocation_upward_velocity_hold_ticks"] = 4
	candidate["minimum_semantic_absence_dwell_ticks"] = 8
	candidate["maximum_semantic_recontact_latency_ticks"] = 10
	candidate["minimum_post_recontact_observation_ticks"] = 47
	candidate["minimum_semantic_relocation_horizontal_displacement_m"] = 0.020
	candidate["maximum_semantic_relocation_horizontal_target_error_m"] = 0.010
	candidate["minimum_bounded_torso_height_m"] = 0.36
	candidate["maximum_bounded_torso_tilt_rad"] = 0.15
	candidate["candidate_status"] = CANDIDATE_STATUS
	candidate["candidate_result"] = CANDIDATE_STATUS
	candidate["claim_boundary"] = CLAIM_BOUNDARY
	candidate["physical_commissioning_execution_authorized"] = true
	return candidate


static func compile(candidate: Dictionary) -> Dictionary:
	var canonical := configuration()
	if not _same_fields(candidate, canonical):
		return _failure("CANONICAL_SPATIAL_TARGETED_RELOCATION_RECONTACT_FIELDS_INVALID")
	if CanonicalJsonScript.stringify(candidate) != CanonicalJsonScript.stringify(canonical):
		return _failure("CANONICAL_SPATIAL_TARGETED_RELOCATION_RECONTACT_NOT_EXACT")
	if not _invariants_hold(candidate):
		return _failure("CANONICAL_SPATIAL_TARGETED_RELOCATION_RECONTACT_INVARIANT_INVALID")
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
		and int(candidate["trial_ticks"]) == 781
		and int(candidate["semantic_release_commit_ticks"]) == 180
		and (candidate["semantic_relocation_clear_offset_m"] as Array) == [0.020, 0.005, 0.0]
		and int(candidate["semantic_relocation_lift_ticks"]) == 2
		and int(candidate["semantic_relocation_lower_ticks"]) == 8
		and is_equal_approx(float(candidate["semantic_relocation_position_gain_n_per_m"]), 300.0)
		and is_equal_approx(float(candidate["semantic_relocation_velocity_gain_ns_per_m"]), 20.0)
		and is_equal_approx(float(candidate["maximum_semantic_relocation_task_force_n"]), 12.0)
		and is_equal_approx(
			float(candidate["semantic_relocation_minimum_upward_velocity_m_s"]), 0.05
		)
		and int(candidate["semantic_relocation_upward_velocity_hold_ticks"]) == 4
		and int(candidate["minimum_semantic_absence_dwell_ticks"]) == 8
		and int(candidate["maximum_semantic_recontact_latency_ticks"]) == 10
		and int(candidate["minimum_post_recontact_observation_ticks"]) == 47
		and is_equal_approx(
			float(candidate["minimum_semantic_relocation_horizontal_displacement_m"]), 0.020
		)
		and is_equal_approx(
			float(candidate["maximum_semantic_relocation_horizontal_target_error_m"]), 0.010
		)
		and is_equal_approx(float(candidate["minimum_bounded_torso_height_m"]), 0.36)
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
