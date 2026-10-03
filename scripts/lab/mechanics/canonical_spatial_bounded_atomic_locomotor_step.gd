class_name LabCanonicalSpatialBoundedAtomicLocomotorStep
extends RefCounted
# gdlint: disable=max-line-length

## Sealed positive contract for one bounded locomotor step.
##
## Candidate 10's physical program is unchanged. This contract distinguishes
## the existence of a complete support-to-support locomotor cycle from accurate
## final foothold placement. The latter remains explicitly unproven.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const Candidate10Script := preload(
	"res://scripts/lab/mechanics/canonical_spatial_post_recontact_body_translation_candidate.gd"
)

const SCHEMA_VERSION := "canonical_spatial_bounded_atomic_locomotor_step_v1"
const EXPERIMENT_ID := "BR14A.5.front_right_bounded_atomic_locomotor_step.v1"
const CANDIDATE_STATUS := "positive_bounded_atomic_locomotor_step"
const ATOMIC_STEP_POLICY_ID := "single_relocation_then_directed_body_translation_v1"
const CLAIM_BOUNDARY := (
	"Exact BR14A.5 atomic-step commissioning only: candidate 10's unchanged "
	+ "nine-body free-3D physical program releases the canonical front-right "
	+ "foot, creates an ordinary relocated floor contact, allows a 600-tick "
	+ "uncommanded settling interval, and then advances whole-system COM and "
	+ "torso along declared positive world X. Across exact seeds 14001, 14002, "
	+ "and 14003, the final moved-foot pose must remain 0.035-0.065 m from its "
	+ "release pose, final nominal-foothold error may not exceed 0.065 m, COM "
	+ "and torso must each advance at least 0.012 m, lateral translation may "
	+ "not exceed 0.003 m, and translation-phase slip at every foot may not "
	+ "exceed 0.010 m. Candidate 10's targeted recontact, long-horizon quiet "
	+ "recovery, four ordinary contacts, zero torso contact, receipt-complete "
	+ "paired actuation, intact joint geometry, zero structural saturation, "
	+ "and zero allocator infeasibility remain mandatory. This establishes one "
	+ "bounded atomic locomotor step for the exact morphology, controller, "
	+ "solver, seeds, and thresholds. Final foothold accuracy is explicitly "
	+ "not established: the foot seats at an unplanned lateral/backward offset. "
	+ "This establishes no second or alternating step, repeated stepping, gait, "
	+ "walking, speed control, steering, terrain robustness, generalized "
	+ "standing or recovery, bracing, fall arrest, get-up, per-foot load "
	+ "allocation, formal milestone acceptance, encyclopedia knowledge, repair, "
	+ "automatic application, or creature guidance."
)


static func configuration() -> Dictionary:
	var candidate := Candidate10Script.configuration().duplicate(true)
	candidate["schema_version"] = SCHEMA_VERSION
	candidate["experiment_id"] = EXPERIMENT_ID
	candidate["behavior_state"] = "FREE_3D_BOUNDED_ATOMIC_LOCOMOTOR_STEP"
	candidate["atomic_step_policy_id"] = ATOMIC_STEP_POLICY_ID
	candidate["minimum_atomic_final_foot_relocation_m"] = 0.035
	candidate["maximum_atomic_final_foot_relocation_m"] = 0.065
	candidate["maximum_atomic_final_foothold_target_error_m"] = 0.065
	candidate["minimum_atomic_settling_delay_ticks"] = 600
	candidate["maximum_atomic_lateral_translation_m"] = 0.003
	candidate["candidate_status"] = CANDIDATE_STATUS
	candidate["candidate_result"] = CANDIDATE_STATUS
	candidate["claim_boundary"] = CLAIM_BOUNDARY
	candidate["locomotor_step_claim_allowed"] = true
	return candidate


static func compile(candidate: Dictionary) -> Dictionary:
	var canonical := configuration()
	if not _same_fields(candidate, canonical):
		return _failure("CANONICAL_SPATIAL_BOUNDED_ATOMIC_LOCOMOTOR_STEP_FIELDS_INVALID")
	if CanonicalJsonScript.stringify(candidate) != CanonicalJsonScript.stringify(canonical):
		return _failure("CANONICAL_SPATIAL_BOUNDED_ATOMIC_LOCOMOTOR_STEP_NOT_EXACT")
	if not _invariants_hold(candidate):
		return _failure("CANONICAL_SPATIAL_BOUNDED_ATOMIC_LOCOMOTOR_STEP_INVARIANT_INVALID")
	var sealed := candidate.duplicate(true)
	sealed["experiment_sha256"] = CanonicalJsonScript.sha256(candidate)
	sealed["bounded_physical_development_execution_authorized"] = true
	return {"ok": true, "experiment": FrozenValueScript.snapshot(sealed)}


static func _invariants_hold(candidate: Dictionary) -> bool:
	return (
		String(candidate["schema_version"]) == SCHEMA_VERSION
		and String(candidate["experiment_id"]) == EXPERIMENT_ID
		and String(candidate["centroidal_controller_id"]) == "post_recontact_body_translation_v1"
		and String(candidate["candidate_status"]) == CANDIDATE_STATUS
		and String(candidate["candidate_result"]) == CANDIDATE_STATUS
		and String(candidate["claim_boundary"]) == CLAIM_BOUNDARY
		and String(candidate["atomic_step_policy_id"]) == ATOMIC_STEP_POLICY_ID
		and String(candidate["swing_limb_id"]) == "front_right"
		and int(candidate["trial_ticks"]) == 2300
		and int(candidate["post_recontact_body_translation_delay_ticks"]) == 600
		and (
			(candidate["post_recontact_body_translation_offset_world_m"] as Array)
			== [0.030, 0.0, 0.0]
		)
		and is_equal_approx(float(candidate["minimum_post_recontact_com_translation_m"]), 0.012)
		and is_equal_approx(float(candidate["minimum_post_recontact_torso_translation_m"]), 0.012)
		and is_equal_approx(float(candidate["maximum_post_recontact_foot_slip_m"]), 0.010)
		and is_equal_approx(float(candidate["minimum_atomic_final_foot_relocation_m"]), 0.035)
		and is_equal_approx(float(candidate["maximum_atomic_final_foot_relocation_m"]), 0.065)
		and is_equal_approx(float(candidate["maximum_atomic_final_foothold_target_error_m"]), 0.065)
		and int(candidate["minimum_atomic_settling_delay_ticks"]) == 600
		and is_equal_approx(float(candidate["maximum_atomic_lateral_translation_m"]), 0.003)
		and bool(candidate["physical_development_execution_authorized"])
		and bool(candidate["physical_commissioning_execution_authorized"])
		and bool(candidate["locomotor_step_claim_allowed"])
		and not bool(candidate["formal_milestone_acceptance_authorized"])
		and not bool(candidate["encyclopedia_admission_authorized"])
		and not bool(candidate["per_foot_load_claim_allowed"])
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
