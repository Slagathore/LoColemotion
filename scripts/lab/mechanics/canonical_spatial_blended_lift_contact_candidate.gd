class_name LabCanonicalSpatialBlendedLiftContactCandidate
extends RefCounted
# gdlint: disable=max-line-length

## Sealed rejection contract for the fifth BR14A.5 controller family.
##
## Candidate 5 separates the zero-preload control from swing motion, expands
## the vertical-first path to half of logical swing time, and blends the
## resolved-rate world-foot servo into the existing relative-pose command.
## The first seed advances but never clears; the event gate retreats safely.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const Candidate4Script := preload(
	"res://scripts/lab/mechanics/canonical_spatial_feasibility_gated_contact_candidate.gd"
)

const SCHEMA_VERSION := "canonical_spatial_blended_lift_contact_candidate_v1"
const EXPERIMENT_ID := "BR14A.5.front_right_blended_lift_contact_candidate.v1"
const CANDIDATE_STATUS := "candidate_rejected_contact_coupled_swing_servo_no_clearance"
const CONTROLLER_ID := "predictive_unload_then_lift_allocator_v1"
const CLAIM_BOUNDARY := (
	"Exact BR14A.5 fifth-candidate rejection commissioning only: the selected "
	+ "nine-body, 12-DOF quadruped retains candidate 4's predictive three-contact "
	+ "wrench and COM/capture gate, uses the exact zero-preload control, expands "
	+ "vertical lift across 60 of 120 logical path ticks, and blends the "
	+ "world-space swing servo over eight logical path ticks. Preferred contact "
	+ "normal values remain commands, never measured load or bearing. The exact "
	+ "first seed advances nine path ticks but the selected foot remains in its "
	+ "ordinary floor contact; the gate retreats to zero, suppresses disturbance "
	+ "and touchdown, and ends back inside the declared final stance envelope. "
	+ "This rejects only the exact all-seed candidate. Unexecuted seeds receive no "
	+ "conclusion. It establishes no contact removal, protective contact, "
	+ "articulated three-contact bearing, per-foot measured load allocation, "
	+ "locomotor step, gait, walking, formal acceptance, encyclopedia knowledge, "
	+ "repair, automatic application, or creature guidance."
)


static func configuration() -> Dictionary:
	var candidate := Candidate4Script.configuration().duplicate(true)
	candidate["schema_version"] = SCHEMA_VERSION
	candidate["experiment_id"] = EXPERIMENT_ID
	candidate["behavior_state"] = "FREE_3D_BLENDED_LIFT_CONTACT_DEVELOPMENT"
	candidate["centroidal_controller_id"] = CONTROLLER_ID
	candidate["vertical_lift_complete_tick"] = int(candidate["lift_start_tick"]) + 60
	candidate["pre_lift_unload_progress_ticks"] = 0
	candidate["swing_servo_blend_progress_ticks"] = 8
	candidate["candidate_status"] = CANDIDATE_STATUS
	candidate["candidate_result"] = CANDIDATE_STATUS
	candidate["claim_boundary"] = CLAIM_BOUNDARY
	return candidate


static func compile(candidate: Dictionary) -> Dictionary:
	var canonical := configuration()
	if not _same_fields(candidate, canonical):
		return _failure("CANONICAL_SPATIAL_BLENDED_LIFT_FIELDS_INVALID")
	if CanonicalJsonScript.stringify(candidate) != CanonicalJsonScript.stringify(canonical):
		return _failure("CANONICAL_SPATIAL_BLENDED_LIFT_NOT_EXACT")
	if not _invariants_hold(candidate):
		return _failure("CANONICAL_SPATIAL_BLENDED_LIFT_INVARIANT_INVALID")
	var sealed := candidate.duplicate(true)
	sealed["experiment_sha256"] = CanonicalJsonScript.sha256(candidate)
	sealed["bounded_physical_development_execution_authorized"] = true
	sealed["bounded_physical_commissioning_execution_authorized"] = true
	return {"ok": true, "experiment": FrozenValueScript.snapshot(sealed)}


static func _invariants_hold(candidate: Dictionary) -> bool:
	return (
		String(candidate["schema_version"]) == SCHEMA_VERSION
		and String(candidate["experiment_id"]) == EXPERIMENT_ID
		and String(candidate["centroidal_controller_id"]) == CONTROLLER_ID
		and String(candidate["candidate_status"]) == CANDIDATE_STATUS
		and String(candidate["candidate_result"]) == CANDIDATE_STATUS
		and String(candidate["claim_boundary"]) == CLAIM_BOUNDARY
		and int(candidate["pre_lift_unload_progress_ticks"]) == 0
		and int(candidate["swing_servo_blend_progress_ticks"]) == 8
		and (
			int(candidate["vertical_lift_complete_tick"]) == int(candidate["lift_start_tick"]) + 60
		)
		and int(candidate["vertical_lift_complete_tick"]) < int(candidate["lift_complete_tick"])
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
